LLVM IR和其它的汇编语言类似，其核心就是对数据的操作。这涉及到了两个问题：什么数据和怎么操作。具体到这篇文章中，我就将介绍的是，在LLVM IR中，是如何表示一个数据的。

# 汇编层次的数据表示

LLVM IR是最接近汇编语言的一层抽象，所以我们首先需要了解在计算机底层，汇编语言的层次中，数据是怎样表示的。

谈到汇编层次的数据表示，一个老生常谈的程序就是

```c
#include <stdlib.h>

int global_data = 0;

int main() {
	int stack_data = 0;
	int *heap_pointer = (int *)malloc(16 * sizeof(int));
	return 0;
}
```

我们知道，一个C语言从代码到执行的过程是代码-->硬盘上的二进制程序-->内存中的进程。在代码被编译到二进制程序的时候，`global_data`本身就写在了二进制程序中。在操作系统将二进制程序载入内存时，就会在特定的区域（数据区）初始化这些值。而`stack_data`代表的局部变量，则是在程序执行其所在的函数时，在栈上初始化，类似地，`heap_pointer`这个指针也是在栈上，而其指向的内容，则是操作系统分配在堆上的。

用一个图可以简单地表示：

```
+------------------------------+
|          stack_data          |
|         heap_pointer         |  <------------- stack
+------------------------------+
|                              |
|                              |  <------------- available memory space
|                              |
+------------------------------+
| data pointed by heap_pointer |  <------------- heap
+------------------------------|
|          global_data         |  <------------- .DATA section
+------------------------------+
```

这就是一个简化后的进程的内存模型。也就是说，一共有三种数据：

* 栈上的数据
* 堆中的数据
* 数据区里的数据

但是，我们仔细考虑一下，在堆中的数据，能否独立存在。操作系统提供的在堆上创建数据的接口如`malloc`等，都是返回一个指针，那么这个指针会存在哪里呢？寄存器里，栈上，数据区里，或者是另一个被分配在堆上的指针。也就是说，可能会是：

```c
#include <stdlib.h>

int *global_pointer = (int *)malloc(16 * sizeof(int));

int main() {
	int *stack_pointer = (int *)malloc(16 * sizeof(int));
	int **heap_pointer = (int **)malloc(sizeof(int *));
	*heap_pointer = (int *)malloc(16 * sizeof(int));
	return 0;
}
```

但不管怎样，堆中的数据都不可能独立存在，一定会有一个位于其他位置的引用。所以，在内存中的数据按其表示来说，一共分为两类：

* 栈上的数据
* 数据区里的数据

除了内存之外，还有一个存储数据的地方，那就是寄存器。因此，我们在程序中可以用来表示的数据，一共分为三类：

* 寄存器中的数据
* 栈上的数据
* 数据区里的数据

# LLVM IR中的数据表示

LLVM IR中，我们需要表示的数据也是以上三种。那么，这三种数据各有什么特点，又需要根据LLVM的特性做出什么样的调整呢？

## 数据区里的数据

我们知道，数据区里的数据，其最大的特点就是，能够给整个程序的任何一个地方使用。同时，数据区里的数据也是占静态的二进制可执行程序的体积的。所以，我们应该只将需要全程序使用的变量放在数据区中。而现代编程语言的经验告诉我们，这类全局静态变量应该越少越好。

同时，由于LLVM是面向多平台的，所以我们还需要考虑的是该怎么处理这些数据。一般来说，大多数平台的可执行程序格式中都会包含`.DATA`分区，用来存储这类的数据。但除此之外，每个平台还有专门的更加细致的分区，比如说，Linux的ELF格式中就有`.rodata`来存储只读的数据。因此，LLVM的策略是，让我们尽可能细致地定义一个全局变量，比如说注明其是否只读等，然后依据各个平台，如果平台的可执行程序格式支持相应的特性，就可以进行优化。

一般来说，在LLVM IR中定义一个存储在数据区中的全局变量，其格式为：

```llvm
@global_variable = global i32 0
```

这个语句定义了一个`i32`类型的全局变量`@global_variable`，并且将其初始化为`0`。

如果是只读的全局变量，也就是常量，我们可以用`constant`来代替`global`：

```llvm
@global_constant = constant i32 0
```

这个语句定义了一个`i32`类型的全局常量`@global_constant`，并将其初始化为`0`。

### 符号表

关于在数据区的数据，有一个特别需要注意的，就是数据的名称与二进制文件中的符号表。在LLVM IR中，所有的全局变量的名称都需要用`@`开头。我们有一个这样的LLVM IR：

```llvm
; global_variable_test.ll
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

@global_variable = global i32 0

define i32 @main() {
	ret i32 0
}
```

也就是说，在之前最基本的程序的基础上，新增了一个全局变量`@global_variable`。我们将其直接编译成可执行文件：

```shell
clang global_variable_test.ll -o global_variable_test
```

然后，我们使用`nm`命令查看其符号表：

```shell
nm global_variable_test
```

结果为：

```
0000000100000000 T __mh_execute_header
0000000100001000 S _global_variable
0000000100000f70 T _main
                 U dyld_stub_binder
```

我们注意到，出现了`_global_variable`这个字段。这里开头的`_`可以不用关注，这是Mach-O的name mangling策略导致的，我们在Ubuntu下可以用同样的步骤，查看到出现的是`global_variable`字段。

这表明，直接定义的全局变量，其名称会出现在符号表之中。那么，怎么控制这个行为呢？首先，我们需要简单地了解一下符号表。

简单来说，ELF文件中的符号表会有两个区域：`.symtab`和`.dynsym`。在最初只有静态链接的时期，符号表的作用主要有两个：Debug和静态链接。我们在Debug的时候，往往会需要某些数据的符号，而这就是放在`.symtab`里的；同样地，当我们用链接器将两个目标文件链接的时候，也需要解决其中的符号交叉引用，这时的信息也是放在`.symtab`里。然而，这些信息有一个特点：不需要在运行时载入内存。我们在运行时根本不关心某些数据的符号，也不需要链接，所以`.symtab`在运行时不会载入内存。然而，在出现了动态链接之后，就产生了变化。动态链接允许可执行文件在载入内存、运行这两个阶段再链接动态链接库，那么这时就需要解决符号的交叉引用。因此，有些符号就需要在运行时载入内存。将整个`.symtab`全部载入内存是不现实的，所以大家就把一部分需要载入内存的符号拷贝到`.dynsym`这个分区，也就是动态符号表中。

在LLVM IR中，控制符号表与两个概念密切相关：链接与可见性，LLVM IR也提供了[Linkage Type](http://llvm.org/docs/LangRef.html#id1217)和[Visibility Styles](http://llvm.org/docs/LangRef.html#id1219)这两个修饰符来控制相应的行为。

### 链接类型

对于链接类型，我们常用的主要有什么都不加（默认为`external`）、`private`和`internal`。

什么都不加的话，就像我们刚刚那样，直接把全局变量的名字放在了符号表中，用`nm`查看出来，在`_global_variable`之前是`S`，表示除了几个主流分区之外的其它分区，如果我们用`llc`将代码输出成汇编的话，可以看到`global_varaible`在macOS下是在`__DATA`段的`__common`节。

用`private`，则代表这个变量的名字不会出现在符号表中。我们将原来的代码改写成

```llvm
@global_variable = private global i32 0
```

那么，用`nm`查看其编译出的可执行文件：

```
0000000100000000 T __mh_execute_header
0000000100000f70 T _main
                 U dyld_stub_binder
```

这个变量的名字就消失了。

用`internal`则表示这个变量是以局部符号的身份出现（全局变量的局部符号，可以理解成C中的`static`关键词）。我们将原来的代码改写成

```llvm
@global_variable = internal global i32 0
```

那么，再次将其编译成可执行程序，并用`nm`查看：

```
0000000100000000 T __mh_execute_header
0000000100001000 b _global_variable
0000000100000f70 T _main
                 U dyld_stub_binder
```

`_global_variable`前面的符号变成了小写的`b`，这代表这个变量是位于`__bss`节的局部符号。

LLVM IR层次的链接类型也就控制了实际目标文件的链接策略，什么符号是导出的，什么符号是本地的，什么符号是消失的。但是，这个变量放在可执行程序中的哪个区、哪个节并不是统一的，是与平台相关的，如在macOS上什么都不加的`global_variable`是放在`__DATA`段的`__common`节，而`internal`的`global_variable`则是处于`__DATA`段的`__bss`节。而在Ubuntu上，什么都不加的`global_variable`则是位于`.bss`节，`internal`的`global_variable`也是处于`.bss`的局部符号。

### 可见性

可见性在实际使用中则比较少，主要分为三种`default`, `hidden`和`protected`，这里主要的区别在于符号能否被重载。`default`的符合可以被重载，而`protected`的符号则不可以；此外，`hidden`则不将变量放在动态符号表中，因此其它的模块不可以直接引用这个符号。

## 寄存器内的数据和栈上的数据

这两种数据我选择放在一起讲。我们知道，除了DMA等奇技淫巧之外，大多数对数据的操作，如加减乘除、比大小等，都需要操作的是寄存器内的数据。那么，我们为什么需要把数据放在栈上呢？主要有两个原因：

* 寄存器数量不够
* 需要操作内存地址

如果我们一个函数内有三四十个局部变量，但是家用型CPU最多也就十几个通用寄存器，所以我们不可能把所有变量都放在寄存器中，因此我们需要把一部分数据放在内存中，栈就是一个很好的存储数据的地方；此外，有时候我们需要直接操作内存地址，但是寄存器并没有通用的地址表示，所以只能把数据放在栈上来完成对地址的操作。

因此，在不操作内存地址的前提下，栈只是寄存器的一个替代品。有一个很简单的例子可以解释这个概念。我们有一个很简单的C程序：

```c
// max.c
int max(int a, int b) {
	if (a > b) {
		return a;
	} else {
		return b;
	}
}

int main() {
	int a = max(1, 2);
	return 0;
}
```

在x86_64架构macOS上编译的话，我们首先来看`max(1, 2)`是如何调用的：

```assembly
movl	$1, %edi
movl	$2, %esi
callq	_max
```

将参数`1`和`2`分别放到了寄存器`edi`和`esi`里。那么，`max`函数又是如何操作的呢？

```assembly
	pushq	%rbp
	movq	%rsp, %rbp
	movl	%edi, -8(%rbp)		# move data stored in %edi to stack at -8(%rbp)
	movl	%esi, -12(%rbp)		# move data stored in %esi to stack at -12(%rbp)
	movl	-8(%rbp), %eax		# move data stored in stack at -8(%rbp) to register %eax
	cmpl	-12(%rbp), %eax		# compare data stored in stack at -12(%rbp) with data stored in %eax
	jle	LBB0_2					# if compare result is less than or equal to, then go to label LBB0_2
## %bb.1:
	movl	-8(%rbp), %eax		# move data stored in stack at -8(%rbp) to register %eax
	movl	%eax, -4(%rbp)		# move data stored in %eax to stack at -4(%rbp)
	jmp	LBB0_3					# go to label LBB0_3
LBB0_2:
	movl	-12(%rbp), %eax		# move data stored in stack at -12(%rbp) to register %eax
	movl	%eax, -4(%rbp)		# move data stored in %eax to stack at -4(%rbp)
LBB0_3:
	movl	-4(%rbp), %eax		# move data stored in stack at -4(%rbp) to register %eax
	popq	%rbp
	retq
```

考虑到篇幅，我将这个汇编每一个重要步骤所做的事都以注释形式写在了代码里面。这个看上去很复杂，但实际上做的是这样的事：

1. 把`int a`和`int b`看作局部变量，分别存储在栈上的`-8(%rbp)`和`-12(%rbp)`上
2. 为了比较这两个局部变量，将一个由栈上导入寄存器`eax`中
3. 比较`eax`寄存器中的值和另一个局部变量
4. 将两者中比较大的那个局部变量存储在栈上的`-4(%rbp)`上（由于x86_64架构不允许直接将内存中的一个值拷贝到另一个内存区域中，所以得先把内存区域中的值拷贝到`eax`寄存器里，再从`eax`寄存器里拷贝到目标内存中）
5. 将栈上`-4(%rbp)`这个用来存储返回值的区域的值拷贝到`eax`中，并返回

这看上去真是太费事了。但是，这也是无可奈何之举。这是因为，在不开优化的情况下，一个C的函数中的局部变量（包括传入参数）和返回值都应该存储在函数本身的栈帧中，所以，我们得把这简单的两个值在不同的内存区域和寄存器里来回拷贝。

那么，如果我们优化一下会怎样呢？我们使用

```shell
clang -O1 -S max.c
```

之后，我们的`_max`函数的汇编代码是：

```assembly
pushq	%rbp
movq	%rsp, %rbp
movl	%esi, %eax
cmpl	%esi, %edi
cmovgel	%edi, %eax
popq	%rbp
retq
```

那么长的一串代码竟然变的如此简洁了。这个代码翻译成伪代码就是

```pseudocode
function max(register a, register b) {
	register c = register b
	if (register a >= register b) {
		register c = register a
	}
	return register c
}
```

很简单的事，并且把所有的操作都从对内存的操作变成了对寄存器的操作。

因此，由这个简单的例子我们可以看出来，如果寄存器的数量足够，并且代码中没有需要操作内存地址的时候，寄存器是足够胜任的，并且更加高效的。