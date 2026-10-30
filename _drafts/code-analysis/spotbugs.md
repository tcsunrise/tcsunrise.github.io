---
title: 代码质量 | SpotBugs静态代码分析
date: 2026-10-27
description: 本文介绍什么是SpotBugs，为什么以及如何使用它来做代码质量分析，提高系统代码质量
categories: 
- Code Quality Control
tags: [Code Quality, SpotBugs, CI, Tutorial]
---


## 写在前面

看了标题，或许会有人反驳现在都是AI Coding了，写代码又快又好，还需要使用额外的工具做代码分析？还需要
用工具去检查代码质量？AI写的代码run起来完全没问题，功能也都正常啊？

如果你认为完全没有必要，全部都丢给AI就行了，那就没有必要继续往下看嘞~

经过最近一年对Claude Code和Codex编程的使用，我发现要想让AI写出逻辑清晰健壮的代码，首先需要给它一个
明确的规范，不然它很容易自己随意发挥；记得有次某个同事用Claude Code写了一堆代码，真的烂的不行，一个
方法300多行，变量命名也是非常费解。究其原因，不是AI能力不行，而是它缺少一套编码规范；如果没有规范限
制AI的发挥，写的代码虽然能跑起来，功能也没问题，但终究可能会出问题，尤其是一些边界条件。如果能前置
地在AI编码期间就给它一套编码规范，让它在有限的规则域内发挥，就更容易产出高质量的代码。

所以，可以完全在项目中接入代码分析工具，限制和协助AI写出质量更优，更健壮的代码，多一道代码质量门禁
是件好事。从个人角度，在这个过程中，也可以让自己见识到更多代码问题，会发现之前自己从来没有想到的问题，
都会被工具暴露出来，提高自己编写健壮代码的能力。


## Why SpotBugs

SpotBugs前身是Maryland大学维护的FindBugs™项目，但是这个项目从2017年开始就不怎么维护了，后来社区
从这个项目fork出来，新项目就叫SpotBugs。相比而言，SpotBugs项目社区维护非常积极活跃，基本上每周都有
多个新的提交合并。

社区活跃性是一方面，SpotBugs有很多著名大型的开源项目都在使用，比如Apache ZooKeeper，Apache Kafka等，
其内部包含了400多种常见的BUG代码模式，这些BUG都可以作为AI的编程工具，输出检查报告喂给AI，实现AI自己
写代码，自己纠正。

同时SpotBugs还支持插件机制，开发团队可以自定义自己的代码检查规则，检查不在内置400多重BUG清单中的代
码模式，进一步扩展其检查代码漏洞的能力。社区也有一些更新很活跃的SpotBugs插件。其中，fb-contrib在
SpotBugs基础上，扩展了300多种BugPattern，而且作者也在定期维护；同时还有一个find-sec-bugs插件，这
个插件是主要是来检查Web应用中常见的安全漏洞，目前项目主页显示已经可以检测超过140多种常见的安全漏洞。

SpotBugs内置的Bug清单和以上两个主要的插件其检查的Bug以及安全漏洞，包括了部分收集在CWE和OWASP目录中
的，这表明其检测到的Bug问题是业界内常见的代码漏洞，使用起来也有据可依。



## 基本使用

使用SpotBugs的场景主要有三种，分别是系统终端命令行、构建系统集成以及IDE界面开发环境，下面将逐一介绍
每种方式的安装和使用方式。

但是在上手使用之前，我们需要先了解SpotBugs的四个相关的GitHub项目：
- `findbugsproject/findbugs`：SpotBugs的前身，现在基本上社区已经不维护了，上文已有相关介绍；
- `spotbugs/spotbugs`：SpotBugs的核心组件，其它用法都是围绕这个项目构建的；
- `spotbugs/spotbugs-maven-plugin`：Maven插件，用于将SpotBugs应用到Maven构建的生命周期中；
- `JetBrains/spotbugs-intellij-plugin`：JetBrains IDEA插件，用于在IDEA中界面化地使用SpotBugs。

### 命令行方式

SpotBugs虽说是用来检查Java程序代码的，但其实其本身也是用Java实现的；它的命令行使用方式和Java业界
其它工具使用方式基本一样，要不就是直接执行jar文件，但是直接执行jar不方便，所以还会附带常见操作系统
的脚本，比如Windows的.bat和.ps1，类Unix系统的.sh脚本，使用相应的平台脚本间接调用jar文件。比如常用
的Apache Maven，Apache ZooKeeper，Alibaba Arthas等，都是这种方式。

在命令行中使用Java命令行工具一般就是三个步骤：
1. 下载分发包压缩文件并解压；
2. 配置系统环境变量，把脚本bin目录配置到系统路径中；
3. 在系统终端命令行执行对应的help命令，查看可用命令。

SpotBugs下载地址：<https://github.com/spotbugs/spotbugs/releases#release-4.10.5>

![SpotBugs GitHub Release Assets](/assets/img/post/spotbugs-github-release-assets-light.png){: .light .rounded-10 .shadow }
![SpotBugs GitHub Release Assets](/assets/img/post/spotbugs-github-release-assets-dark.png){: .dark .rounded-10 .shadow }




### Maven项目集成



### IDEA插件






插件扩展
和SonarQube




## 内部机制


Confidence
Rank

Filter file

findbugs.xml

BugCategory 
BugCode 
BugPattern 


Detector




```shell
mvn help:describe -Dplugin=com.github.spotbugs:spotbugs-maven-plugin
mvn help:describe -Dplugin=com.github.spotbugs:spotbugs-maven-plugin -Ddetail
```


SpotBugs manual
https://spotbugs.readthedocs.io/en/stable/


CWE
https://cwe.mitre.org/
https://github.com/OWASP
https://owasp.org/

https://spotbugs.github.io
https://spotbugs.readthedocs.io/en/stable/

https://fb-contrib.sourceforge.net/
https://find-sec-bugs.github.io/

https://github.com/spotbugs
https://github.com/findbugsproject


https://github.com/JetBrains/spotbugs-intellij-plugin
https://github.com/alibaba/arthas
