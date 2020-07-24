这篇文章我们来讲函数。有过汇编基础的同学都知道，在汇编层面，一个函数与一个控制语句极其相似，都是由标签组成，只不过在跳转时增加了一些附加的操作。而在LLVM IR层面，函数则得到了更高一层的抽象。

# 定义与声明

## 函数定义

在LLVM中，一个最基本的函数定义的样子我们之前已经遇到过多次，就是`@main`函数的样子：

```llvm
define i32 @main() {
	ret i32 0
}
```

在函数名之后可以加上参数列表，如：

```llvm
define i32 @foo(i32 %a, i64 %b) {
	ret i32 0
}
```

一个函数定义最基本的框架，就是返回值（`i32`）+函数名（`@foo`）+参数列表（`(i32 %a, i64 %b）`）+函数体（`{ ret i32 0 }`）。

我们可以看到，函数的名称和全局变量一样，都是以`@`开头的。并且，如果我们查看符号表的话，也会发现其和全局变量一样进入了符号表。因此，函数也有和全局变量完全一致的Linkage Types和Visibility Style，来控制函数名在符号表中的出现情况，因此，可以出现如

```llvm
define private i32 @foo() {
	; ...
}
```

这样的修饰符。

此外，我们还可以在参数列表之后加上之前说的属性，也就是控制优化器和代码生成器的指令。在之前讲属性组的时候，我就提过，如果我们单纯编译一个简单的C代码：

```c
void foo() { }
int main() {
	return 0;
}
```

可以看到`@foo`函数之后会跟上一个属性组`#0`，在macOS下其内容为

```llvm
attributes #0 = { noinline nounwind optnone ssp uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "darwin-stkchk-strong-link" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "probe-stack"="___chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="penryn" "target-features"="+cx16,+cx8,+fxsr,+mmx,+sahf,+sse,+sse2,+sse3,+sse4.1,+ssse3,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
```

我们通过对一个函数附加许多属性，来控制最终的优化和代码生成。大部分的属性可以在[Function Attributes](http://llvm.org/docs/LangRef.html#function-attributes)一节看到，把这些属性放在一起一个一个来讲显然是不明智的举措，我会在之后提到某些与某个属性相关的概念时再阐述某个属性的含义。这里只需要知道，在函数的参数列表之后可以加上属性或属性组，如：

```llvm
define void @foo() nounwind { ret void }
; or
define void @foo() #0 { ret void }
attributes #0 {
	; ...
}
```

## 函数声明

除了函数定义之外，还有一种情况十分常见，那就是函数声明。我们在一个编译单元（模块）下，可以使用别的模块的函数，这时候就需要在本模块先声明这个函数，才能保证编译时不出错，从而在链接时正确将声明的函数与别的模块下其定义进行链接。

函数声明也相对比较简单，就是使用`declare`关键词替换`define`：

```llvm
declare i32 @printf(i8*, ...) #1
```

这个就是在C代码中调用`stdio.h`库的`printf`函数时，在LLVM IR代码中可以看到的函数声明，其中`#1`就是又一大串属性组成的属性组。

# 函数的调用

在LLVM IR中，函数的调用与高级语言几乎没有什么区别：

```llvm
define i32 @foo(i32 %a) {
	; ...
}

define void @bar() {
	%1 = call i32 @foo(i32 1)
}
```

使用`call`指令可以像高级语言那样直接调用函数。我们来仔细分析一下这里做了哪几件事：

* 传递参数
* 执行函数
* 获得返回值

居然能干这么多事，这是汇编语言所羡慕不已的。

## 执行函数

我们知道，如果一个函数没有任何参数，返回值也是`void`类型，也就是说在C语言下这个函数是

```c
void foo() {
	// ...
}
```

那么调用这个函数就没有了传递参数和获得返回值这两件事，只剩下执行函数，而这是一个最简单的事：

1. 把函数返回地址压栈
2. 跳转到相应函数的地址

函数返回也是一个最简单的事：

1. 弹栈获得函数返回地址
2. 跳转到相应的返回地址

这个在我们的汇编语言基础中已经反复遇到过多次，相信大家都会十分熟练。

## 传递参数与获得返回值

谈到这两点，就不得不说调用约定了。我们知道，在汇编语言中，是没有参数传递和返回值的概念的，有的仅仅是让当前的控制流跳转到指定函数执行。所以，一切的参数传递和返回值都需要我们人为约定。

最广泛使用的调用约定是C调用约定，也就是各个操作系统的标准库使用的调用约定。在x86_64架构下，C调用约定是System V版本的，所有参数从右往左，按顺序放入指定寄存器，如果寄存器不够，剩余的则压栈。而返回值则是按先后顺序放入寄存器，如果只有一个返回值，那么就会放在`rax`里。

在LLVM IR中，函数的调用默认使用C调用约定。为了验证，我们可以写一个简单的程序：

```llvm
; calling_convention_test.ll
%ReturnType = type { i32, i32 }
define %ReturnType @foo(i32 %a1, i32 %a2, i32 %a3, i32 %a4, i32 %a5, i32 %a6, i32 %a7, i32 %a8) {
	ret %ReturnType { i32 1, i32 2 }
}

define i32 @main() {
	%1 = call %ReturnType @foo(i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8)
	ret i32 0
}
```

我们在x86_64架构的macOS上查看其编译出来的汇编代码。在`main`函数中，参数传递是：

```assembly
movl	$1, %edi
movl	$2, %esi
movl	$3, %edx
movl	$4, %ecx
movl	$5, %r8d
movl	$6, %r9d
movl	$7, (%rsp)
movl	$8, 8(%rsp)
callq	_foo
```

而在`foo`函数内部，返回值传递是：

```assembly
movl	$1, %eax
movl	$2, %edx
retq
```

如果大家去查阅System V的指南的话，会发现完全符合。

