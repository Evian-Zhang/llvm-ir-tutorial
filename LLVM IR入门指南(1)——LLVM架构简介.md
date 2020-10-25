# LLVM是什么

随着计算机技术的不断发展以及各种领域需求的增多，近几年来，许多编程语言如雨后春笋般出现，大多为了解决某一些特定领域的需求，比如说为JavaScript增加静态类型检查的TypeScript，为解决服务器端高并发的Golang，为解决内存安全和线程安全的Rust。随着编程语言的增多，编程语言的开发者往往都会遇到一些相似的问题：

* 怎样让我的编程语言能在尽可能多的平台上运行
* 怎样让我的编程语言充分利用各个平台自身的优势，做到最大程度的优化
* 怎样让我的编程语言在汇编层面实现「定制」，能够控制如符号表中的函数名、函数调用时参数的传递方法等汇编层面的概念

有的编程语言选择了使用C语言来解决这种问题，如[早期的Haskell](https://stackoverflow.com/a/52038291/10005095)等。它们将使用自己语言的源代码编译成C代码，然后再在各个平台调用C编译器来生成可执行程序。为什么要选择C作为目标代码的语言呢？有几个原因：

第一，绝大部分的操作系统都是由C和汇编语言写成，因此平台大多会提供一个C编译器可以使用，这样就解决了第一个问题。

第二，绝大部分的操作系统都会提供C语言的接口，以及C库。我们的编程语言因此可以很方便地调用相应的接口来实现更广泛的功能。

第三，C语言本身并没有笨重的运行时，代码很贴近底层，可以使用一定程度的定制。

以上三个理由让许多的编程语言开发者选择将自己的语言编译成C代码。

然而，我们知道，一个平台最终运行的二进制可执行文件，实际上就是在运行与之等价的汇编代码。与汇编代码比起来，C语言还是太抽象了，我们希望能更灵活地操作一些更底层的部分。同时，我们也希望相应代码在各个平台能有和C语言一致，甚至比其更好的优化程度。

因此，LLVM出现后，成了一个更好的选择。我们可以从[LLVM官网](https://llvm.org)中看到：

> The LLVM Core libraries provide a modern source- and target-independent optimizer, along with code generation support for many popular CPUs (as well as some less common ones!) These libraries are built around a well specified code representation known as the LLVM intermediate representation ("LLVM IR"). The LLVM Core libraries are well documented, and it is particularly easy to invent your own language (or port an existing compiler) to use LLVM as an optimizer and code generator.

简单地说，LLVM代替了C语言在现代语言编译器实现中的地位。我们可以将自己语言的源代码编译成LLVM中间代码（LLVM IR），然后由LLVM自己的后端对这个中间代码进行优化，并且编译到相应的平台的二进制程序。

LLVM的优点正好对应我们之前讲的三个问题：

* LLVM后端支持的平台很多，我们不需要担心CPU、操作系统的问题（运行库除外）
* LLVM后端的优化水平较高，我们只需要将代码编译成LLVM IR，就可以由LLVM后端作相应的优化
* LLVM IR本身比较贴近汇编语言，同时也提供了许多ABI层面的定制化功能

因为LLVM的优越性，除了LLVM自己研发的C编译器Clang，许多新的工程都选择了使用LLVM，我们可以在[其官网](http://llvm.org/ProjectsWithLLVM)看到使用LLVM的项目的列表，其中，最著名的就是Rust、Swift等语言了。

# LLVM架构

要解释使用LLVM后端的编译器整体架构，我们就拿最著名的C语言编译器Clang为例。

在一台x86_64指令集的macOS系统上，我有一个最简单的C程序`test.c`：

```c
int main() {
    return 0;
}
```

我们使用

```shell
clang test.c -o test
```

究竟经历了哪几个步骤呢？

## 前端的语法分析

首先，Clang的前端编译器会将这个C语言的代码进行预处理、语法分析、语义分析，也就是我们常说的parse the source code。这里不同语言会有不同的做法。总之，我们是将「源代码」这一字符串转化为内存中有意义的数据，表示我们这个代码究竟想表达什么。

我们可以使用

```shell
clang -Xclang -ast-dump -fsyntax-only test.c
```

输出我们`test.c`经过编译器前端的预处理、语法分析、语义分析之后，生成的抽象语法树（AST）：

```
TranslationUnitDecl 0x7fc02681ea08 <<invalid sloc>> <invalid sloc>
|-TypedefDecl 0x7fc02681f2a0 <<invalid sloc>> <invalid sloc> implicit __int128_t '__int128'
| `-BuiltinType 0x7fc02681efa0 '__int128'
|-TypedefDecl 0x7fc02681f310 <<invalid sloc>> <invalid sloc> implicit __uint128_t 'unsigned __int128'
| `-BuiltinType 0x7fc02681efc0 'unsigned __int128'
|-TypedefDecl 0x7fc02681f5f8 <<invalid sloc>> <invalid sloc> implicit __NSConstantString 'struct __NSConstantString_tag'
| `-RecordType 0x7fc02681f3f0 'struct __NSConstantString_tag'
|   `-Record 0x7fc02681f368 '__NSConstantString_tag'
|-TypedefDecl 0x7fc02681f690 <<invalid sloc>> <invalid sloc> implicit __builtin_ms_va_list 'char *'
| `-PointerType 0x7fc02681f650 'char *'
|   `-BuiltinType 0x7fc02681eaa0 'char'
|-TypedefDecl 0x7fc02681f968 <<invalid sloc>> <invalid sloc> implicit __builtin_va_list 'struct __va_list_tag [1]'
| `-ConstantArrayType 0x7fc02681f910 'struct __va_list_tag [1]' 1
|   `-RecordType 0x7fc02681f770 'struct __va_list_tag'
|     `-Record 0x7fc02681f6e8 '__va_list_tag'
`-FunctionDecl 0x7fc02585a228 <test.c:1:1, line:3:1> line:1:5 main 'int ()'
  `-CompoundStmt 0x7fc02585a340 <col:12, line:3:1>
    `-ReturnStmt 0x7fc02585a330 <line:2:5, col:12>
      `-IntegerLiteral 0x7fc02585a310 <col:12> 'int' 0
```

这一长串输出看上去就让人眼花缭乱，然而，我们只需要关注最后四行：

```
`-FunctionDecl 0x7fc02585a228 <test.c:1:1, line:3:1> line:1:5 main 'int ()'
  `-CompoundStmt 0x7fc02585a340 <col:12, line:3:1>
    `-ReturnStmt 0x7fc02585a330 <line:2:5, col:12>
      `-IntegerLiteral 0x7fc02585a310 <col:12> 'int' 0
```

这才是我们源代码的AST。可以很方便地看出，经过Clang前端的预处理、语法分析、语义分析，我们的代码被分析成一个函数，其函数体是一个复合语句，这个复合语句包含一个返回语句，返回语句中使用了一个整型字面量`0`。

因此，总结而言，我们基于LLVM的编译器的第一步，就是将源代码转化为内存中的抽象语法树AST。

## 前端生成中间代码

第二个步骤，就是根据内存中的抽象语法树AST生成LLVM IR中间代码（有的比较新的编译器还会先将AST转化为MLIR再转化为IR）。

我们知道，我们写编译器的最终目的，是将源代码交给LLVM后端处理，让LLVM后端帮我们优化，并编译到相应的平台。而LLVM后端为我们提供的中介，就是LLVM IR。我们只需要将内存中的AST转化为LLVM IR就可以放手不管了，接下来的所有事都是LLVM后端帮我们实现。

关于LLVM IR，我在下面会详细解释。我们现在先看看将AST转化之后，会产生什么样的LLVM IR。我们使用

```shell
clang -S -emit-llvm test.c
```

这时，会生成一个`test.ll`文件：

```llvm
; ModuleID = 'test.c'
source_filename = "test.c"
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Function Attrs: noinline nounwind optnone ssp uwtable
define i32 @main() #0 {
  %1 = alloca i32, align 4
  store i32 0, i32* %1, align 4
  ret i32 0
}

attributes #0 = { noinline nounwind optnone ssp uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "darwin-stkchk-strong-link" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "probe-stack"="___chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="penryn" "target-features"="+cx16,+cx8,+fxsr,+mmx,+sahf,+sse,+sse2,+sse3,+sse4.1,+ssse3,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 2, !"SDK Version", [3 x i32] [i32 10, i32 15, i32 4]}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{i32 7, !"PIC Level", i32 2}
!3 = !{!"Apple clang version 11.0.3 (clang-1103.0.32.62)"}
```

这看上去更加让人迷惑。然而，我们同样地只需要关注五行内容：

```llvm
define i32 @main() #0 {
  %1 = alloca i32, align 4
  store i32 0, i32* %1, align 4
  ret i32 0
}
```

这是我们AST转化为LLVM IR中最核心的部分，可以隐约感受到这个代码所表达的意思。

## LLVM后端优化IR

LLVM后端在读取了IR之后，就会对这个IR进行优化。这在LLVM后端中是由`opt`这个组件完成的，它会根据我们输入的LLVM IR和相应的优化等级，进行相应的优化，并输出对应的LLVM IR。

我们可以用

```shell
opt test.ll -S --O3
```

对相应的代码进行优化，也可以直接用

```shell
clang -S -emit-llvm -O3 test.c
```

优化，并输出相应的优化结果：

```llvm
; ModuleID = 'test.c'
source_filename = "test.c"
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Function Attrs: norecurse nounwind readnone ssp uwtable
define i32 @main() local_unnamed_addr #0 {
  ret i32 0
}

attributes #0 = { norecurse nounwind readnone ssp uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "darwin-stkchk-strong-link" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "probe-stack"="___chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="penryn" "target-features"="+cx16,+cx8,+fxsr,+mmx,+sahf,+sse,+sse2,+sse3,+sse4.1,+ssse3,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 2, !"SDK Version", [3 x i32] [i32 10, i32 15, i32 4]}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{i32 7, !"PIC Level", i32 2}
!3 = !{!"Apple clang version 11.0.3 (clang-1103.0.32.62)"}
```

我们观察`@main`函数，可以发现其函数体确实减少了不少。

## LLVM后端生成汇编代码

LLVM后端帮我们做的最后一步，就是由LLVM IR生成汇编代码，这是由`llc`这个组件完成的。

我们可以用

```shell
llc test.ll
```

生成`test.s`：

```assembly
	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 10, 15	sdk_version 10, 15, 4
	.globl	_main                   ## -- Begin function main
	.p2align	4, 0x90
_main:                                  ## @main
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	xorl	%eax, %eax
	movl	$0, -4(%rbp)
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function

.subsections_via_symbols
```

这就回到了我们熟悉的汇编代码中。

有了汇编代码之后，我们就需要调用操作系统自带的汇编器、链接器，最终生成可执行程序。

# LLVM IR

根据我们上面讲的，一个基于LLVM后端的编译器的整体过程是

```
.c --frontend--> AST --frontend--> LLVM IR --LLVM opt--> LLVM IR --LLVM llc--> .s Assembly --OS Assembler--> .o --OS Linker--> executable
```

这样一个过程。由此我们可以见，LLVM IR是连接编译器前端与LLVM后端的一个桥梁。同时，整个LLVM后端也是围绕着LLVM IR来进行的。所以，我的这个系列就打算介绍的是LLVM IR的入门级教程。

那么，LLVM IR究竟是什么呢？它的全称是LLVM Intermediate Representation，也就是LLVM的中间表示，我们可以在这篇[LangRef](https://llvm.org/docs/LangRef.html)中查看其所有信息。这看起来模糊不清的名字，也容易让人产生疑问。事实上，在我理解中，LLVM IR同时表示了三种东西：

* 内存中的LLVM IR
* 比特码形式的LLVM IR
* 可读形式的LLVM IR

内存中的LLVM IR是编译器作者最常接触的一个形式，也是其最本质的形式。当我们在内存中处理抽象语法树AST时，需要根据当前的项，生成对应的LLVM IR，这也就是编译器前端所做的事。我们的编译器前端可以用许多语言写，LLVM也为许多语言提供了Binding，但其本身还是用C++写的，所以这里就拿C++为例。

LLVM的C++接口在`llvm/IR`目录下提供了许多的头文件，如`llvm/IR/Instructions.h`等，我们可以使用其中的`Value`, `Function`, `ReturnInst`等等成千上万的类来完成我们的工作。也就是说，我们并不需要把AST变成一个个字符串，如`ret i32 0`等，而是需要将AST变成LLVM提供的IR类的实例，然后在内存中交给LLVM后端处理。

而比特码形式和可读形式则是将内存中的LLVM IR持久化的方法。比特码是采用特定格式的二进制序列，而可读形式的LLVM IR则是采用特定格式的human readable的代码。我们可以用

```shell
clang -S -emit-llvm test.c
```

生成可读形式的LLVM IR文件`test.ll`，采用

```shell
clang -c -emit-llvm test.c
```

生成比特码形式的LLVM IR文件`test.bc`，采用

```shell
llvm-as test.ll
```

将可读形式的`test.ll`转化为比特码`test.bc`，采用

```shell
llvm-dis test.bc
```

将比特码`test.bc`转化为可读形式的`test.ll`。

我这个系列，将主要介绍的是可读形式的LLVM IR的语法。

# LLVM的下载与安装

macOS的Xcode会自带`clang`、`clang++`、`swiftc`等基于LLVM的编译器，但并不会带全部的LLVM的套件，如`llc`, `opt`等。类似的，Windows的Visual Studio同样也可以下载Clang编译器，但依然没有带全部的套件。而Linux下则并没有自带编译器或套件。

我们可以直接在LLVM的官网上[下载LLVM全部套件](https://releases.llvm.org/download.html)，但也可以去相应的系统包管理器中下载：

在macOS中，可以直接使用

```shell
brew install llvm
```

下载，而在Ubuntu下，也可以使用

```shell
apt-get install llvm
```

进行下载。使用系统包管理器下载的好处在于，我们可以使用国内的镜像，能够更快地实现下载。

# 在哪可以看到我的文章

我的LLVM IR入门指南系列可以在[我的个人博客](https://evian-zhang.top/writings/series/LLVM%20IR入门指南)、GitHub：[Evian-Zhang/llvm-ir-tutorial](https://github.com/Evian-Zhang/llvm-ir-tutorial)、[知乎](https://zhuanlan.zhihu.com/c_1267851596689457152)、[CSDN](https://blog.csdn.net/evianzhang/category_10210126.html)中查看，本教程中涉及的大部分代码也都在同一GitHub仓库中。

本人水平有限，写此文章仅希望与大家分享学习经验，文章中必有缺漏、错误之处，望方家不吝斧正，与大家共同学习，共同进步，谢谢大家！