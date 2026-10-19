---
title: Java并发 | 理解显式锁ReentrantLock
date: 2026-10-16
description: 本文以ReentrantLock为切入点，试图较为系统地讨论和分析Java中的显式锁机制
categories: 
- Java
tags:
- concurrency
- lock
---

记得刚入行学习Java时，那会儿为了准备面试，恶补了很多所谓的“八股文“；比如什么`synchronized`
关键字，`ConcurrentHashMap`，`ArrayBlockingQueue`等等，诸如此类，当然`ReentrantLock`也是
其中之一。

当时只知道网上都叫它“可再入锁”，是线程安全的，但也就知道这些了，更不知道如何使用。即
使在进入工作岗位之后，平时也很少接触或者刻意使用它，能想到用`ConcurrentHashMap`就很不错了，
甚至有的人都不知道这个类，只知道`synchronized`关键字。

前段时间在开发业务代码时，随便翻了一下线程池内部的实现，看到内部就用到了`ReentrantLock`来
管理线程池的内部状态，就借机会更系统全面地梳理了一下这个类。但这篇文章只是理解一下它在实践
上的一些问题，不涉及其内部的底层实现，比如AQS，原子变量之类的。

这篇文章首先会简单介绍一下锁机制，说明什么是内置锁和显式锁，然后梳理一下相关显式锁的API，最
后是一些在实际使用场景上的原型建议。


## 什么是锁

我觉得有必要先理解一下什么叫做锁（_Lock_）。

锁是一种用来实现**线程安全类**的同步机制（_synchronization mechanism_）[^1]。一般我们很少
说一个程序是线程安全的，而是说某一个类是线程安全的，因此就有了类似`@ThreadSafe`这样的类注
解，所以我在这里强调了一下“类”，而不是泛泛地说线程安全。

那什么叫做“同步”呢？锁的作用具体体现是什么？下面举个简单的例子理解一下。

现代服务器主机或者个人电脑的CPU一般都是多核CPU，即一颗物理CPU内部有多个CPU核心，这些CPU核心
可以独立执行程序指令而且互不干扰。很早我们就知道，“进程是操作系统分配资源的最小单元，而线程
是操作系统调度的最小单元”。不同的线程可以由操作系统调度在不同的CPU核心上同时运行，互不干扰，
而且互相不知道彼此的存在。

但是当线程之间共享一块内存区域，一份数据的时候，这个时候，线程之间就产生一些对彼此的限制。它们
对同一份数据的访问受到彼此的影响。

一般情况下Java对象是在JVM堆（_JVM heap_）上分配的，而堆是线程共享的内存区域。假设线程A在CPU
核心C1上运行，线程B在CPU核心C2上运行。当某个堆变量f在线程A和线程B间共享时，由于每个CPU核心都
有自己的缓存，线程A内对变量f的修改，另一个线程B可能无法立刻看到，甚至于线程B永远都看不到线程A
对变量f的最新修改。简单来讲，使用锁，就可以让线程B立即看到变量f最新的值，这个机制就叫做同步，
这里需要跨线程同步的就是变量f的最新值。这有点类似于在工作中，某个同事对你说：这个设计方案到
时候也和测试和BI部门同步一下，保持相关同事对某个信息都是知晓的。类似的，这种保持每个线程都能看
到其它线程对某个共享变量的最新修改，就叫做“可见性”。

当然，锁的作用不仅仅是保障变量的可见性，还有操作的原子性，顺序性等，这里就不详细展开了。

## 介绍显式锁

上面简单介绍了一下锁的作用，接下来的篇幅主要介绍显式锁（_explicit lock_）。

与显式锁相对的是隐式锁（_implicit lock_），如果说`ReentrantLock`是显式锁，那么`synchronized`就
是隐式锁。实际上，Java中所说的隐式锁就是指`synchronized`关键字实现的锁，而显式锁一共有两个，分别
是`Lock`和`ReadWriteLock`两个接口为代表的显式锁实现。

### Lock

Lock[^2] 

### ReadWriteLock

ReadWriteLock[^3]

## ReentrantLock还是synchronized？
Lock

## 小结


---
[^1]: 我们平时所说的“同步”（_synchronization_）是一个很大的概念，不能狭隘地理解成“锁”。更合
适的表达是：“同步”指的是协调多个线程对共享状态的访问从而保障程序的正确性，而“锁”只是其中的一种
“同步机制”。在多线程环境下保证程序的正确性不一定非要通过“锁”来实现，还可以通过`volatile`关键字
，`final`关键字，原子变量等，更全面的要参考Java内存模型规范。
[^2]: [java.util.concurrent.locks.Lock.java](https://github.com/openjdk/jdk/blob/dfacda488bfbe2e11e8d607a6d08527710286982/src/java.base/share/classes/java/util/concurrent/locks/Lock.java)
[^3]: [java.util.concurrent.locks.ReadWriteLock](https://github.com/openjdk/jdk/blob/dfacda488bfbe2e11e8d607a6d08527710286982/src/java.base/share/classes/java/util/concurrent/locks/ReadWriteLock.java)
