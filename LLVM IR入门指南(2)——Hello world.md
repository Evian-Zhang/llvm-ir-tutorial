在系统学习LLVM IR语法之前，我们应当首先掌握的是使用LLVM IR写的最简单的程序，也就是大家常说的Hello world版程序。这是因为，编程语言的学习，往往需要伴随着练习。但是一个独立的程序需要许多的前置语法基础，那么我们不可能在了解了所有前置语法基础之后才完成第一个独立程序，否则在学习前置语法基础的时候，就没有办法在实际的程序中练习了。因此，正确的学习方式应该是，首先掌握这门语言独立程序的基础框架，然后每学习一个新的语法知识，就在框架中练习，并编译看结果是否是自己期望的结果。

综上所述，学习一门语言的第一步，就是掌握其最简单的程序的基本框架是如何写的。

# 最基本的程序

以macOS 10.15为例，我们最基本的程序为：

```llvm
; main.ll
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

define i32 @main() {
	ret i32 0
}
```

这个程序可以看作最简单的C语言代码：

```c
int main() {
	return 0;
}
```

在macOS 10.15上编译而成的结果。

我们可以直接测试这个代码的正确性：

```shell
clang main.ll -o main
./main
```

使用`clang`可以直接将`main.ll`编译成可执行文件`main`。运行这个程序后，程序自动退出，并返回`0`。这正符合我们的预期。

# 基本概念

下面，我们对`main.ll`逐行解释一些比较基本的概念。

## 注释

首先，第一行`; main.ll`。这是一个注释。在LLVM IR中，注释以`;`开头，并一直延伸到行尾。所以在LLVM IR中，并没有像C语言中的`/* comment block */`这样的注释块，而全都类似于`// comment line`这样的注释行。

## 目标数据分布和平台

第二行和第三行的`target datalayout`和`target triple`，则是注明了目标汇编代码的数据分布和平台。我们之前提到过，LLVM是一个面向多平台的深度定制化编译器后端，而我们LLVM IR的目的，则是让LLVM后端根据IR代码生成相应平台的汇编代码。所以，我们需要在IR代码中指明我们需要生成哪一个平台的代码，也就是`target triple`字段。类似地，我们还需要定制数据的大小端序、对齐形式等需求，所以我们也需要指明`target datalayout`字段。关于这两个字段的值的详细情况，我们可以参考[Data Layout](http://llvm.org/docs/LangRef.html#id1248)和[Target Triple](http://llvm.org/docs/LangRef.html#id1249)这两个官方文档。我们可以对照官方文档，解释我们在macOS上得到的结果：

```llvm
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
```

表示：

* `e`: 小端序
* `m:o`: 符号表中使用Mach-O格式的name mangling（这玩意儿我一直不知道中文是啥，就是把程序中的标识符经过处理得到可执行文件中的符号表中的符号）
* `i64:64`: 将`i64`类型的变量采用64比特的ABI对齐
* `f80:128`: 将`long double`类型的变量采用128比特的ABI对齐
* `n8:16:32:64`: 目标CPU的原生整型包含8比特、16比特、32比特和64比特
* `S128`: 栈以128比特自然对齐

```llvm
target triple = "x86_64-apple-macosx10.15.0"
```

表示：

* `x86_64`: 目标架构为x86_64架构
* `apple`: 供应商为Apple
* `macosx10.15.0`: 目标操作系统为macOS 10.15

在一般情况下，我们都是想生成当前平台的代码，也就是说不太会改动这两个值。因此，我们可以直接写一个简单的`test.c`程序，然后使用

```shell
clang -S -emit-llvm test.c
```

生成LLVM IR代码`test.ll`，在`test.ll`中找到`target datalayout`和`target triple`这两个字段，然后拷贝到我们的代码中即可。

比方说，我在x86_64指令集的Ubuntu 20.04的机器上得到的就是：

```llvm
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"
```

和我们在macOS上生成的代码就不太一样。

## 主程序

我们知道，主程序是可执行程序的入口点，所以任何可执行程序都需要`main`函数才能运行。所以，

```llvm
define i32 @main() {
	ret i32 0
}
```

就是这段代码的主程序。关于正式的函数、指令的定义，我会在之后的文章中提及。这里我们只需要知道，在`@main()`之后的，就是这个函数的函数体，`ret i32 0`就代表C语言中的`return 0;`。因此，如果我们要增加代码，就只需要在大括号内，`ret i32 0`前增加代码即可。

# 在哪可以看到我的文章

我的LLVM IR入门指南系列可以在[我的个人博客](https://evian-zhang.top/writings/series/LLVM%20IR入门指南)、GitHub：[Evian-Zhang/llvm-ir-tutorial](https://github.com/Evian-Zhang/llvm-ir-tutorial)、[知乎](https://zhuanlan.zhihu.com/c_1267851596689457152)、[CSDN](https://blog.csdn.net/evianzhang/category_10210126.html)中查看，本教程中涉及的大部分代码也都在同一GitHub仓库中。

本人水平有限，写此文章仅希望与大家分享学习经验，文章中必有缺漏、错误之处，望方家不吝斧正，与大家共同学习，共同进步，谢谢大家！