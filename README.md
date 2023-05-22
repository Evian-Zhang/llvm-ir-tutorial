# LLVM IR入门指南

本仓库是我写的LLVM IR入门指南。

推荐前往<https://Evian-Zhang.github.io/llvm-ir-tutorial>阅读以获得最佳排版及语法高亮体验。PDF版本下载请点击前述网页的右上角。本教程中涉及的大部分代码也都在本GitHub仓库中。

LLVM是当下最通用的编译器后端之一，无论是想自己动手制作一个编译器，还是为主流的编程语言增加功能，又或者是做软件的静态分析，都离不开LLVM。LLVM IR是LLVM架构中一个重要的组成成分，编译器前端将抽象语法树转变为LLVM IR，而编译器后端则根据LLVM IR进行优化，生成可执行程序。但是，目前对LLVM IR的中文介绍少之又少。因此，我就写了这样的一系列文章，介绍了LLVM的架构，并且从LLVM IR的层面，让大家系统地了解LLVM。

最近（2023年6月），这个GitHub仓库的star数即将达到一千。因此，我打算基于现有的脉络，大范围更新现有的文章，推出LLVM IR入门指南2.0版。我这次更新的原因主要有以下几点：

* LLVM版本更新

   LLVM是一个不断演进的，由社区积极维护的项目。本系列文章写作于2020年，会有一些落后的知识点，也会有一些新的技术没有涵盖到。因此，本次更新将针对最新的LLVM 16进行写作。
* 操作系统变化

   在1.0版中，我是以macOS为操作系统来介绍的。但是，随着Apple Silicon Mac占据主流地位，使用Intel芯片的Mac越来越少。由于文章中会大量地使用LLVM IR编译后的AMD64汇编指令作为解释说明，所以本次更新将从macOS转变为Linux，从而也可以使更多的读者能够在自己的机器中对文章中的代码进行验证。
* 知识水平提升

   在过去的这三年里，我也学习了很多新的知识。并且，我也写出了不少关于底层二进制相关的系列文章，如：

   * [macOS上的汇编入门](https://github.com/Evian-Zhang/Assembly-on-macOS)

      针对Intel芯片Mac的macOS下AMD64架构汇编入门教程
   * [在Apple Silicon Mac上入门汇编语言](https://github.com/Evian-Zhang/learn-assembly-on-Apple-Silicon-Mac)

      针对Apple Silicon Mac的macOS下AArch64架构汇编入门教程
   * [WASM汇编入门教程](https://github.com/Evian-Zhang/wasm-tutorial)

      针对浏览器中的前端新宠儿WebAssembly汇编入门教程

   在这些经验的积累下，我可以更具体、更准确地对文章的内容进行修补。

本人水平有限，写此系列文章仅希望与大家分享学习经验，文章中必有缺漏、错误之处，望方家不吝斧正，与大家共同学习，共同进步，谢谢大家！

## 前置知识

本系列文章所需的前置知识包括

* 掌握Linux基本命令（如使用命令行等）
* 掌握C语言编程知识
* 掌握AMD64指令集汇编知识

## 环境

本系列文章使用的环境包括

* CPU

   Intel i9-12900K
* 操作系统

   Ubuntu 22.04，内核为Linux 5.19.0
* 编译器

   C语言采用Clang 16编译器。LLVM采用LLVM 16版本。

#### License

<sup>
本仓库遵循<a href="https://creativecommons.org/licenses/by/4.0/">CC-BY-4.0版权协议</a>。
</sup>

<br/>

<sub>
作为<a href="https://copyleft.org/">copyleft</a>的支持者之一，我由衷地欢迎大家积极热情地参与到开源社区中。Happy coding!
</sub>
