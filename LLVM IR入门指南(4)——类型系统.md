我们知道，汇编语言是弱类型的，我们操作汇编语言的时候，实际上考虑的是一些二进制串。但是，LLVM IR却是强类型的，在LLVM IR中所有变量都必须有类型。这是因为，我们在使用高级语言编程的时候，往往都会使用强类型的语言，弱类型的语言无必要性，也不利于维护。因此，使用强类型语言，LLVM IR可以更好地进行优化。

# 基本的数据类型

LLVM IR中比较基本的数据类型包括：

* 空类型（`void`）
* 整型（`iN`）
* 浮点型（`float`、`double`等）

空类型一般是作为不返回值的函数的返回类型，没有特别的含义，就代表「什么都没有」。

整型是指`i1`, `i8`, `i16`, `i32`, `i64`这类的数据类型。这里`iN`的`N`可以是任意正整数，可以是`i3`，`i1942652`。但最常用，最符合常理的就是`i1`以及8的整数倍。`i1`有两个值：`true`和`false`。也就是说，下面的代码可以正确编译：

```llvm
%boolean_variable = alloca i1
store i1 true, i1* %boolean_variable
```

对于大于1位的整型，也就是如`i8`, `i16`等类型，我们可以直接用数字字面量赋值：

```llvm
%integer_variable = alloca i32
store i32 128, i32* %integer_variable
store i32 -128, i32* %integer_variable
```

## 符号

有一点需要注意的是，在LLVM IR中，整型默认是有符号整型，也就是说我们可以直接将`-128`以补码形式赋值给`i32`类型的变量。在LLVM IR中，整型的有无符号是体现在操作指令而非类型上的，比方说，对于两个整型变量的除法，LLVM IR分别提供了`udiv`和`sdiv`指令分别适用于无符号整型除法和有符号整型除法：

```llvm
%1 = udiv i8 -6, 2	; get (256 - 6) / 2 = 125
%2 = sdiv i8 -6, 2	; get (-6) / 2 = -3
```

我们可以用这样一个简单的程序验证：

```llvm
; div_test.ll
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

define i8 @main() {
	%1 = udiv i8 -6, 2
	%2 = sdiv i8 -6, 2
	
	ret i8 %1
}
```

分别将`ret`语句的参数换成`%1`和`%2`以后，将代码编译成可执行文件，在终端下运行并查看返回值即可。

总结一下就是，LLVM IR中的整型默认按有符号补码存储，但一个变量究竟是否要被看作有无符号数需要看其参与的指令。

## 转换指令

与整型密切相关的就是转换指令，比如说，将`i8`类型的数`-127`转换成`i32`类型的数，将`i32`类型的数`257`转换成`i8`类型的数等。总的来说，LLVM IR中提供三种指令：`trunc` .. `to`指令，`zext` .. `to`指令和`sext` .. `to`指令。

将长的整型转换成短的整型很简单，直接把多余的高位去掉就行，LLVM IR提供的是`trunc` .. `to`指令：

```llvm
%trunc_integer = trunc i32 257 to i8 ; trunc 32 bit 100000001 to 8 bit, get 1
```

将短的整型变成长的整型则相对比较复杂。这是因为，在补码中最高位是符号位，并不表示实际的数值。因此，如果单纯地在更高位补`0`，那么`i8`类型的`-1`（补码为`11111111`）就会变成`i32`的`255`。这虽然符合道理，但有时候我们需要`i8`类型的`-1`扩展到`i32`时仍然是`-1`。LLVM IR为我们提供了两种指令：零扩展的`zext` .. `to`指令和符号扩展的`sext` .. `to`指令。

零扩展就是最简单的，直接在高位补`0`，而符号扩展则是用原数的符号位来填充。也就是说我们如下的代码：

```llvm
%zext_integer = zext i8 -1 to i32 ; extend 8 bit 0xFF to 32 bit 0x000000FF, get 255
%sext_integer = sext i8 -1 to i32 ; extend 8 bit 0xFF to 32 bit 0xFFFFFFFF, get -1
```

类似地，浮点型的数和整型的数也可以相互转换，使用`fptoui` .. `to`, `fptosi` .. `to`, `uitofp` .. `to`, `sitofp` .. `to`可以分别将浮点数转换为无符号、有符号整型，将无符号、有符号整型转换为浮点数。不过有一点要注意的是，如果将大数转换为小的数，那么并不保证截断，如将浮点型的`257.1`转换成`i8`（上限为`128`），那么就会产生未定义行为。所以，在浮点型和整型相互转换的时候，需要在高级语言层面做一些调整，如使用饱和转换等，具体方案可以看Rust最近1.45.0的更新[Announcing Rust 1.45.0](https://blog.rust-lang.org/2020/07/16/Rust-1.45.0.html)和GitHub上的PR：[Out of range float to int conversions using `as` has been defined as a saturating conversion.](https://github.com/rust-lang/rust/pull/71269/)。

# 指针类型

将基本的数据类型后加上一个`*`就变成了指针类型`i8*`, `i16*`, `float*`等。我们之前提到，LLVM IR中的全局变量和栈上分配的变量都是指针，所以其类型都是指针类型。

在高级语言中，直接操作裸指针的机会都比较少，除非在性能极其敏感的场景下，由最厉害的大佬才能操作裸指针。这是因为，裸指针极其危险，稍有不慎就会出现段错误等致命错误，所以我们使用指针时应该慎之又慎。

LLVM IR为大佬们提供了操作裸指针的一些指令。在C语言中，我们会遇到这种场景：

```c
int x, y;
size_t address_of_x = (size_t)&x;
size_t address_of_y = address_of_x - sizeof(int);
int also_y = *(int *)address_of_y;
```

这种场景比较无脑，但确实是合理的，需要将指针看作一个具体的数值进行加减。到x86_64的汇编语言层次，取地址就变成了`lea`命令，解引用倒是比较正常，就是一个简单的`mov`。

在LLVM IR层次，为了使指针能像整型一样加减，提供了`ptrtoint` .. `to`指令和`inttoptr` .. `to`指令，分别解决将指针转换为整型，和将整型转换为指针的功能。也就是说，我们可以粗略地将上面的程序转写为

```llvm
%x = alloca i32 ; %x is of type i32*, which is the address of variable x
%y = alloca i32 ; %y is of type i32*, which is the address of variable y
%address_of_x = ptrtoint i32* %x to i64
%address_of_y = sub i64 %address_of_x, 4
%also_y = inttoptr i64 %address_of_y to i32* ; %also_y is of type i32*, which is the address of variable y
```

# 聚合类型

比起指针类型而言，更重要的是聚合类型。我们在C语言中常见的聚合类型有数组和结构体，LLVM IR也为我们提供了相应的支持。

数组类型很简单，我们要声明一个类似C语言中的`int a[4]`，只需要

```llvm
%a = alloca [4 x i32]
```

也就是说，C语言中的`int[4]`类型在LLVM IR中可以写成`[4 x i32]`。注意，这里面是个`x`不是`*`。

我们也可以使用类似地语法进行初始化：

```llvm
@global_array = global [4 x i32] [i32 0, i32 1, i32 2, i32 3]
```

特别地，我们知道，字符串在底层可以看作字符组成的数组，所以LLVM IR为我们提供了语法糖：

```llvm
@global_string = global [12 x i8] c"Hello world\00"
```

在字符串中，转义字符必须以`\xy`的形式出现，其中`xy`是这个转义字符的ASCII码。比如说，字符串的结尾，C语言中的`\0`，在LLVM IR中就表现为`\00`。

结构体的类型也相对比较简单，在C语言中的结构体

```c
struct MyStruct {
	int x;
	char y;
};
```

在LLVM IR中就成了

```llvm
%MyStruct = type {
	i32,
	i8
}
```

我们初始化一个结构体也很简单：

```llvm
@global_structure = global %MyStruct { i32 1, i8 0 }
; or
@global_structure = global { i32, i8 } { i32 1, i8 0 }
```

值得注意的是，无论是数组还是结构体，其作为全局变量或栈上变量，依然是指针，也就是说，`@global_array`的类型是`[4 x i32]*`, `@global_structure`的类型是`%MyStruct*`也就是`{ i32, i8 }*`。接下来的问题就是，我们如何对聚合类型进行操作呢？

## `getelementptr`

首先，我们要讲的是对聚合类型的指针进行操作。一个最全面的例子，用C语言来说，就是

```c
struct MyStruct {
	int x;
	int y;
};

struct MyStruct my_structs[4];
```

我们有一个长度为4的`MyStruct`类型的数组`my_structs`，我们需要的是`my_structs[2].y`这个数。

我们先直接看结论，用LLVM IR来表示为

```llvm
%MyStruct = type {
	i32,
	i32
}
%my_structs = alloca [4 x %MyStruct]

%1 = getelementptr [4 x %MyStruct], [4 x %MyStruct]* %my_structs, i64 2, i32 1 ; %1 is pointer to my_structs[2].y
%2 = load i32, i32* %1 ; %2 is value of my_structs[2].y
```

核心就在于`getelementptr`这个指令。这个指令的前两个参数很显然，第一个是这个聚合类型的类型，第二个则是这个聚合类型对象的指针，也就是我们的`my_structs`。第三个参数，则是指明在数组中的第几个元素，第四个，则是指明在结构体中的第几个字段（LLVM IR中结构体的字段不是按名称，而是按下标索引来区分）。用人话来说，`%1`就是`my_structs`数组第2个元素的第1个字段的地址。

这看上去似乎很好理解，但是，下面的例子就似乎有些特殊了：

```llvm
%MyStruct = type {
	i32,
	i32
}
%my_struct = alloca %MyStruct

%1 = getelementptr %MyStruct, %MyStruct* %my_struct, i64 0, i32 1 ; %1 is pointer to my_struct.y
```

没想到吧，如果想根据结构体的指针获取结构体的字段，`getelementptr`的第三个参数居然还需要一个`i64 0`。这是做什么用的呢？这里就是指数组的第一个元素，想象一下我们有一个C语言代码：

```c
struct MyStruct {
	int x;
	int y;
};

struct MyStruct my_struct;
struct MyStruct* my_struct_ptr = &my_struct;
int *y_ptr = my_struct_ptr[0].y;
```

这里的`my_struct_ptr[0]`就代表了我们`getelementptr`的第三个参数，这万万不可省略。

此外，`getelementptr`还可以接多个参数，类似于级联调用。我们有C程序：

```c
struct MyStruct {
	int x;
	int y[5];
};

struct MyStruct my_structs[4];
```

那么如果我们想获得`my_structs[2].y[3]`的地址，只需要

```llvm
%MyStruct = type {
	i32,
	[5 x i32]
}
%my_structs = alloca [4 x %MyStruct]

%1 = getelementptr [4 x %MyStruct], [4 x %MyStruct]* %my_structs, i64 2, i32 1, i64 3
```

我们可以查看官方提供的[The Often Misunderstood GEP Instruction](http://llvm.org/docs/GetElementPtr.html)指南更多地了解`getelementptr`的机理。

## `extractvalue`和`insertvalue`

除了我们上面讲的这种情况，也就是把结构体分配在栈或者全局变量，然后操作其指针以外，还有什么情况呢？我们考虑这种情况：

```llvm
; extract_insert_value.ll
%MyStruct = type {
	i32,
	i32
}
@my_struct = global %MyStruct { i32 1, i32 2 }

define i32 @main() {
	%1 = load %MyStruct, %MyStruct* @my_struct

	ret i32 0
}
```

这时，我们的结构体是直接放在虚拟寄存器`%1`里，`%1`并不是存储`@my_struct`的指针，而是直接存储这个结构体的值。这时，我们并不能用`getelementptr`来操作`%1`，因为这个指令需要的是一个指针。因此，LLVM IR提供了`extractvalue`和`insertvalue`指令。

因此，如果要获得`@my_struct`第二个字段的值，我们需要

```llvm
%2 = extractvalue %MyStruct %1, 1
```

这里的`1`就代表第二个字段（从`0`开始）。

类似地，如果要将`%1`的第二个字段赋值为`233`，只需要

```llvm
%3 = insertvalue %MyStruct %1, i32 233, 1
```

然后`%3`就会是`%1`将第二个字段赋值为`233`后的值。

`extractvalue`和`insertvalue`并不只适用于结构体，也同样适用于存储在虚拟寄存器中的数组，这里不再赘述。

# 标签类型

在汇编语言中，一切的控制语句、函数调用都是由标签来控制的，在LLVM IR中，控制语句也是需要标签来完成。其具体的内容我会在之后专门有一篇控制语句的文章来解释。

# 元数据类型

在我们使用Clang将C语言程序输出成LLVM IR时，会发现代码的最后几行有

```llvm
!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}

!0 = !{i32 2, !"SDK Version", [3 x i32] [i32 10, i32 15, i32 4]}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{i32 7, !"PIC Level", i32 2}
!3 = !{!"Apple clang version 11.0.3 (clang-1103.0.32.62)"}
```

类似于这样的东西。

在LLVM IR中，以`!`开头的标识符为元数据。元数据是为了将额外的信息附加在程序中传递给LLVM后端，使后端能够好地优化或生成代码。用于Debug的信息就是通过元数据形式传递的。我们可以使用`-g`选项：

```shell
clang -S -emit-llvm -g test.c
```

来在LLVM IR中附加额外的Debug信息。

LLVM IR的语法指南中有专门的一大章[Metadata](http://llvm.org/docs/LangRef.html#metadata)来解释各种元数据，这里与我们核心内容联系不太密切，我就不再赘述了。

# 属性

最后，还有一种叫做属性的概念。属性并不是类型，其一般用于函数。比如说，告诉编译器这个函数不会抛出错误，不需要某些优化等等。我们可以看到

```llvm
define void @foo() nounwind {
	; ...
}
```

这里`nounwind`就是一个属性。

有时候，一个函数的属性会特别特别多，并且有多个函数都有相同的属性。那么，就会有大量重复的篇幅用来给每一个函数说明属性。因此，LLVM IR引入了属性组的概念，我们在将一个简单的C程序编译成LLVM IR时，会发现代码中有

```llvm
attributes #0 = { noinline nounwind optnone ssp uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "darwin-stkchk-strong-link" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "probe-stack"="___chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="penryn" "target-features"="+cx16,+cx8,+fxsr,+mmx,+sahf,+sse,+sse2,+sse3,+sse4.1,+ssse3,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
```

这种一大长串的，就是属性组。属性组总是以`#`开头。当我们函数需要它的时候，只需要

```llvm
define void @foo #0 {
	; ...
}
```

直接使用`#0`即可。

# 在哪可以看到我的文章

我的LLVM IR入门指南系列可以在[我的个人博客](https://evian-zhang.top/writings/series/LLVM%20IR入门指南)、GitHub：[Evian-Zhang/llvm-ir-tutorial](https://github.com/Evian-Zhang/llvm-ir-tutorial)、[知乎](https://zhuanlan.zhihu.com/c_1267851596689457152)、[CSDN](https://blog.csdn.net/evianzhang/category_10210126.html)中查看，本教程中涉及的大部分代码也都在同一GitHub仓库中。

本人水平有限，写此文章仅希望与大家分享学习经验，文章中必有缺漏、错误之处，望方家不吝斧正，与大家共同学习，共同进步，谢谢大家！