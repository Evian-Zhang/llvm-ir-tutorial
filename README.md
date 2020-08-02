# LLVM IR入门指南

本仓库是我写的LLVM IR入门指南。

目前提供[PDF版本](https://github.com/Evian-Zhang/llvm-ir-tutorial/releases/latest/download/LLVM-IR-tutorial.pdf)和[epub版本](https://github.com/Evian-Zhang/llvm-ir-tutorial/releases/latest/download/LLVM-IR-tutorial.epub)下载。（当前版本：v1.0）

## 目录

* [LLVM IR入门指南(1)——LLVM架构简介](./LLVM%20IR入门指南(1)——LLVM架构简介.md)
* [LLVM IR入门指南(2)——Hello world](./LLVM%20IR入门指南(2)——Hello%20world.md)
* [LLVM IR入门指南(3)——数据表示](./LLVM%20IR入门指南(3)——数据表示.md)
* [LLVM IR入门指南(4)——类型系统](./LLVM%20IR入门指南(4)——类型系统.md)
* [LLVM IR入门指南(5)——控制语句](./LLVM%20IR入门指南(5)——控制语句.md)
* [LLVM IR入门指南(6)——函数](./LLVM%20IR入门指南(6)——函数.md)
* [LLVM IR入门指南(7)——异常处理](./LLVM%20IR入门指南(7)——异常处理.md)

## 在哪可以看到我的文章

我的LLVM IR入门指南系列可以在[我的个人博客](https://evian-zhang.top/writings/series/LLVM%20IR入门指南)、GitHub：[Evian-Zhang/llvm-ir-tutorial](https://github.com/Evian-Zhang/llvm-ir-tutorial)、[知乎](https://zhuanlan.zhihu.com/c_1267851596689457152)、[CSDN](https://blog.csdn.net/evianzhang/category_10210126.html)中查看，本教程中涉及的大部分代码也都在同一GitHub仓库中。

本人水平有限，写此系列文章仅希望与大家分享学习经验，文章中必有缺漏、错误之处，望方家不吝斧正，与大家共同学习，共同进步，谢谢大家！

## 从源码编译

若想手动将本仓库的markdown文件转化为PDF，epub格式或其他阅读格式：

1. 下载安装[MarkdownPP](https://github.com/jreese/markdown-pp)以及相应的依赖

2. 在本目录下使用

	```shell
	markdown-pp index.mdpp -o LLVM-IR-tutorial.md
	```

	后会得到`LLVM-IR-tutorial.md`的markdown文档

3. 选择自己喜欢的markdown格式转换工具进行相应的格式转换

目前，我使用的是Typora自带的格式转换工具生成PDF和epub文档。

还有其他可以选择的方案，但均有优劣：

* [gitbook-cli](https://github.com/GitbookIO/gitbook-cli)<br />很可惜项目已经被废弃，目前在我电脑中已经无法正常运行
* [mdBook](https://github.com/rust-lang/mdBook)<br />很有前景的方案，但仍在开发中，尚未成熟，无法导出符合要求的epub文档
* [pandoc](https://github.com/jgm/pandoc)<br />生成的PDF较为丑陋，而且要支持中文需要额外的配置
* [sphinx-doc](https://github.com/sphinx-doc/sphinx)<br />原生支持的是reStructuredText格式的文本，对markdown格式还是通过插件支持的，在markdown里插入图片会有错误

如果大家了解什么目前能用的，能将markdown转化为比较好看的PDF及epub格式的工具，欢迎提issue或PR。