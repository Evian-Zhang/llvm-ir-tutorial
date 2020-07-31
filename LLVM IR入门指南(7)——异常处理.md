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

所谓怎么抛，就是如何抛出异常，主要需要保证抛出的异常结构体不会因为stack unwinding而释放，并且能够改变控制流。

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

然后就是要处理第二点，也就是正确地改变控制流。这里的方法是使用另一个C++运行时提供的API：`__cxa_throw`。这个API开启了我们的stack unwinding。我们可以在[libc++abi Specification](http://libcxxabi.llvm.org/spec.html)中看到这个函数的签名：

```c++
void __cxa_throw(void* thrown_exception, struct std::type_info * tinfo, void (*dest)(void*));
```

其第一个参数，是指向我们需要抛出的异常结构体的指针，在LLVM IR的代码中就是我们的`%1`。第二个参数，`std::type_info`如果了解C++底层的人就会知道，这是C++的一个RTTI的结构体。简单来讲，就是存储了异常结构体的类型信息，以便在后面`catch`的时候能够在运行时对比类型信息。第三个参数，则是用于销毁这个异常结构体时的函数指针。

这个函数是如何改变控制流的呢？粗略来说，它依次做了以下几件事：

1. 把一部分信息进一步储存在异常结构体中
2. 调用`_Unwind_RaiseException`进行stack unwinding

也就是说，用来改变控制流的核心，就是`_Unwind_RaiseException`这个函数。这个函数也可以在我上面提供的Itanium的ABI指南中找到。

## 怎么接

所谓怎么接，就是当stack unwinding遇到`try`块之后，如何处理相应的异常。

# 在哪可以看到我的文章

我的LLVM IR入门指南系列可以在[我的个人博客](https://evian-zhang.top/writings/series/LLVM%20IR入门指南)、GitHub：[Evian-Zhang/llvm-ir-tutorial](https://github.com/Evian-Zhang/llvm-ir-tutorial)、[知乎](https://zhuanlan.zhihu.com/c_1267851596689457152)、[CSDN](https://blog.csdn.net/evianzhang/category_10210126.html)中查看，本教程中涉及的大部分代码也都在同一GitHub仓库中。

本人水平有限，写此文章仅希望与大家分享学习经验，文章中必有缺漏、错误之处，望方家不吝斧正，与大家共同学习，共同进步，谢谢大家！