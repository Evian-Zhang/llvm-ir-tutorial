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

# LLVM架构

