在这篇文章中，我主要介绍的是LLVM IR中的异常处理的方法。主要的参考文献是[Exception Handling in LLVM](http://llvm.org/docs/ExceptionHandling.html)。

# 异常处理的要求

异常处理在许多高级语言中都是很常见的，在诸多语言的异常处理的方法中，`try` .. `catch`块的方法是最多的。对于用返回值来做异常处理的语言（如C、Rust、Go等）来说，可以直接在高级语言层面完成所有的事情，但是，如果使用`try` .. `catch`，就必须在语言的底层也做一些处理，而LLVM的异常处理则就是针对这种情况来做的。

首先，我们来看一看一个典型的使用`try` .. `catch`来做的异常处理应该满足怎样的要求。C++就是一个典型的使用`try` .. `catch`来做异常处理的语言，我们就来看看它的异常处理的语法：

```c++
// try_catch_test.cpp
struct SomeOtherStruct { };
struct AnotherError { };

struct MyError { /* ... */ };
void foo() {
	SomeOtherStruct other_struct;
	throw MyError();
	return;
}

void bar() {
	try {
		foo();
	} catch (MyError err) {
		// do something with err
	} catch (AnotherError err) {
		// do something with err
	} catch (...) {
		// do something
	}
}

int main() {
	return 0;
}
```

这是一串典型的异常处理的代码。我们来看看C++中的异常处理是怎样一个过程（可以参考[throw expression](https://en.cppreference.com/w/cpp/language/throw)和[try-block](https://en.cppreference.com/w/cpp/language/try_catch)）：

当遇到`throw`语句的时候，控制流会沿着函数调用栈一直向上寻找，直到找到一个`try`块。然后将抛出的异常与`catch`相比较，看看是否被捕获。如果异常没有被捕获，则继续沿着栈向上寻找，直到最终能被捕获，或者整个程序调用`std::terminate`结束。

按照我们上面的例子，控制流在执行`bar`的时候，首先执行`foo`，然后分配了一个局部变量`other_struct`，接着遇到了一个`throw`语句，便向上寻找，在`foo`函数内部没有找到`try`块，就去调用`foo`的`bar`函数里面寻找，发现有`try`块，然后通过对比进入了第一个`catch`块，顺利处理了异常。

这一过程叫stack unwinding，其中有许多细节需要我们注意。

第一，是在控制流沿着函数调用栈向上寻找的时候，会调用所有遇到的自动变量（大部分时候就是函数的局部变量）的析构函数。也就是说，在我们上面的例子里，当控制流找完了`foo`函数，去`bar`函数找之前，就会调用`other_struct`的析构函数。

第二，是如何匹配`catch`块。C++的标准中给出了一长串的匹配原则，在大多数情况下，我们只需要了解，只要`catch`所匹配的类型与抛出的异常的类型相同，或者是引用，或者是抛出异常类型的基类，就算成功。

所以，我们总结出，使用`try` .. `catch`来处理异常，需要考虑以下要求：

* 能够改变控制流
* 能够正确处理栈
* 能够保证抛出的异常结构体不会因为stack unwinding而释放
* 能够在运行时进行类型匹配

# LLVM IR的异常处理

下面，我们就看看在LLVM IR层面，是怎么进行异常处理的。

我们要指出，异常处理实际上有许多种形式。我这篇文章主要以Clang对C++的异常处理为例来说的。而这主要是基于Itanium提出的零开销的一种错误处理ABI标准，关于这个的详细的信息，可以参考[Itanium C++ ABI: Exception Handling](http://itanium-cxx-abi.github.io/cxx-abi/abi-eh.html)。

首先，我们把上面的`try_catch_test.cpp`代码编译成LLVM IR：

```shell
clang++ -S -emit-llvm try_catch_test.cpp
```

然后，我们仔细研究一下错误处理。

关于上面的异常处理的需求，我们发现，可以分为两类：怎么抛，怎么接。

## 怎么抛

所谓怎么抛，就是如何抛出异常，主要需要保证抛出的异常结构体不会因为stack unwinding而释放，并且能够正确处理栈。

对于第一点，也就是让异常结构体存活，我们就需要不在栈上分配它。同时，我们也不能直接裸调用`malloc`等在堆上分配的方法，因为这个结构体也不需要我们手动释放。C++中采用的方法是运行时提供一个API：`__cxa_allocate_exception`。我们可以在`foo`函数编译而成的`@_Z3foov`中看到：

```llvm
define void @_Z3foov() #0 {
	%1 = call i8* @__cxa_allocate_exception(i64 1) #3
	%2 = bitcast i8* %1 to %struct.MyError*
	call void @__cxa_throw(i8* %1, i8* bitcast ({ i8*, i8* }* @_ZTI7MyError to i8*), i8* null) #4
	unreachable
}
```

第一步就使用了`@__cxa_allocate_exception`这个函数，为我们异常结构体开辟了内存。

然后就是要处理第二点，也就是正确地处理栈。这里的方法是使用另一个C++运行时提供的API：`__cxa_throw`，这个API同时也兼具了改变控制流的作用。这个API开启了我们的stack unwinding。我们可以在[libc++abi Specification](http://libcxxabi.llvm.org/spec.html)中看到这个函数的签名：

```c++
void __cxa_throw(void* thrown_exception, struct std::type_info * tinfo, void (*dest)(void*));
```

其第一个参数，是指向我们需要抛出的异常结构体的指针，在LLVM IR的代码中就是我们的`%1`。第二个参数，`std::type_info`如果了解C++底层的人就会知道，这是C++的一个RTTI的结构体。简单来讲，就是存储了异常结构体的类型信息，以便在后面`catch`的时候能够在运行时对比类型信息。第三个参数，则是用于销毁这个异常结构体时的函数指针。

这个函数是如何处理栈并改变控制流的呢？粗略来说，它依次做了以下几件事：

1. 把一部分信息进一步储存在异常结构体中
2. 调用`_Unwind_RaiseException`进行stack unwinding

也就是说，用来处理栈并改变控制流的核心，就是`_Unwind_RaiseException`这个函数。这个函数也可以在我上面提供的Itanium的ABI指南中找到。

## 怎么接

所谓怎么接，就是当stack unwinding遇到`try`块之后，如何处理相应的异常。根据我们上面提出的要求，怎么接应该处理的是如何改变控制流并且在运行时进行类型匹配。

首先，我们来看如果`bar`单纯地调用`foo`，而非在`try`块内调用，也就是

```c++
void bar() {
	foo();
}
```

编译出的LLVM IR是：

```llvm
define void @_Z3barv() #0 {
	call void @_Z3foov()
	ret void
}
```

和我们正常的不会抛出异常的函数的调用形式一样，使用的是`call`指令。

那么，如果我们代码改成之前的例子，也就是

```c++
void bar() {
	try {
		foo();
	} catch (MyError err) {
		// do something with err
	} catch (AnotherError err) {
		// do something with err
	} catch (...) {
		// do something
	}
}
```

其编译出的LLVM IR是一个很长很长的函数。其开头是：

```llvm
define void @_Z3barv() #0 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) {
	%1 = alloca i8*
	%2 = alloca i32
	%3 = alloca %struct.AnotherError, align 1
	%4 = alloca %struct.MyError, align 1
	invoke void @_Z3foov()
		to label %5 unwind label %6
	; ...
}
```

我们发现，传统的`call`调用变成了一个复杂的`invoke` .. `to` .. `unwind`的指令，这个指令是什么意思呢？

`invoke`指令就是我们改变控制流的另一个关键，我们可以在[`invoke` instruction](http://llvm.org/docs/LangRef.html#invoke-instruction)中看到其详细的解释。粗略来说，在我们上面编译出的LLVM IR代码中

```llvm
invoke void @_Z3foov() to label %5 unwind label %6
```

这个代码的意思是：

1. 调用`@_Z3foov`函数
2. 判断函数返回的方式：
	* 如果是以`ret`指令正常返回，则跳转至标签`%5`
	* 如果是以`resume`指令或者其他异常处理机制返回（如我们上面所说的`__cxa_throw`函数），则跳转至标签`%6`

所以这个`invoke`指令其实和我们之前在跳转中讲到的`phi`指令很类似，都是根据之前的控制流来进行之后的跳转的。

我们的`%5`的标签很简单，因为原来C++代码中，在`try` .. `catch`块之后啥也没做，就直接返回了，所以其就是简单的

```llvm
5:
	br label %18
18:
	ret void
```

而我们的`catch`的方法，也就是在运行时进行类型匹配的关键，就隐藏在`%6`标签内。

我们通常称在调用函数之后，用来处理异常的代码块为landing pad，而`%6`标签，就是一个landing pad。我们来看看`%6`标签内是怎样的代码：

```llvm
6:
	%7 = landingpad { i8*, i32 }
		catch i8* bitcast ({ i8*, i8* }* @_ZTI7MyError to i8*) ; is MyError or its derived class
		catch i8* bitcast ({ i8*, i8* }* @_ZTI12AnotherError to i8*) ; is AnotherError or its derived class
		catch i8* null ; is other type
	%8 = extractvalue { i8*, i32 } %7, 0
	store i8* %8, i8** %1, align 8
	%9 = extractvalue { i8*, i32 } %7, 1
	store i32 %9, i32* %2, align 4
	br label %10
10:
	%11 = load i32, i32* %2, align 4
	%12 = call i32 @llvm.eh.typeid.for(i8* bitcast ({ i8*, i8* }* @_ZTI7MyError to i8*)) #3
	%13 = icmp eq i32 %11, %12 ; compare if is MyError by typeid
	br i1 %13, label %14, label %19
19:
  	%20 = call i32 @llvm.eh.typeid.for(i8* bitcast ({ i8*, i8* }* @_ZTI12AnotherError to i8*)) #3
  	%21 = icmp eq i32 %11, %20 ; compare if is Another Error by typeid
  	br i1 %21, label %22, label %26
```

说人话的话，是这样一个步骤：

1. `landingpad`将捕获的异常进行类型对比，并返回一个结构体。这个结构体的第一个字段是`i8*`类型，指向异常结构体。第二个字段表示其捕获的类型：
	* 如果是`MyError`类型或其子类，第二个字段为`MyError`的TypeID
	* 如果是`AnotherError`类型或其子类，第二个字段为`AnotherError`的TypeID
	* 如果都不是（体现在`catch i8* null`），第二个字段为`null`的TypeID
2. 根据获得的TypeID来判断应该进哪个`catch`块

我将上面代码中一些重要的步骤之后都写上了注释。

我们之前一直纠结的如何在运行时比较类型信息，`landingpad`帮我们做好了，其本质还是根据C++的RTTI结构。

在判断出了类型信息之后，我们会根据TypeID进入不同的标签：

* 如果是`MyError`类型或其子类，进入`%14`标签
* 如果是`AnotherError`类型或其子类，进入`%22`标签
* 如果都不是，进入`%26`标签

这些标签内错误处理的框架都很类似，我们来看`%14`标签：

```llvm
14:
	%15 = load i8*, i8** %1, align 8
	%16 = call i8* @__cxa_begin_catch(i8* %15) #3
	%17 = bitcast i8* %16 to %struct.MyError*
	call void @__cxa_end_catch()
	br label %18
```

都是以`@__cxa_begin_catch`开始，以`@__cxa_end_catch`结束。简单来说，这里就是：

1. 从异常结构体中获得抛出的异常对象本身（异常结构体可能还包含其他信息）
2. 进行异常处理
3. 结束异常处理，回收、释放相应的结构体

# 在哪可以看到我的文章

我的LLVM IR入门指南系列可以在[我的个人博客](https://evian-zhang.top/writings/series/LLVM%20IR入门指南)、GitHub：[Evian-Zhang/llvm-ir-tutorial](https://github.com/Evian-Zhang/llvm-ir-tutorial)、[知乎](https://zhuanlan.zhihu.com/c_1267851596689457152)、[CSDN](https://blog.csdn.net/evianzhang/category_10210126.html)中查看，本教程中涉及的大部分代码也都在同一GitHub仓库中。

本人水平有限，写此文章仅希望与大家分享学习经验，文章中必有缺漏、错误之处，望方家不吝斧正，与大家共同学习，共同进步，谢谢大家！