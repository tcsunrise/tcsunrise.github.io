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

前段时间在开发业务代码时，随便翻了一下线程池内部的实现，看到其内部就用到了`ReentrantLock`来
管理线程池的内部状态，就借机会更系统全面地梳理了一下这个类。但这篇文章只是理解一下它在实践
上的一些问题，不涉及其内部的底层实现，比如AQS，原子变量之类的。

这篇文章首先会简单介绍一下锁机制，区分说明什么是内置锁和显式锁，然后梳理一下相关显式锁的API，
最后是一些在实际使用场景上的原型建议。


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

但是当线程之间共享一块内存区域[^2]，一份数据的时候，这时，线程之间就产生了一些对彼此的限制。它们
对同一份数据的访问受到彼此的影响。

一般情况下Java对象是在JVM堆（_JVM heap_）上分配的，而堆是线程共享的内存区域。假设线程A在CPU
核心C1上运行，线程B在CPU核心C2上运行。当某个堆变量f在线程A和线程B间共享时，由于每个CPU核心都
有自己的缓存，线程A内对变量f的修改，另一个线程B可能无法立刻看到，甚至于线程B永远都看不到线程A
对变量f的最新修改。那什么是“同步”？简单来讲，使用锁，就可以让线程B立即看到变量f最新的值，这
个机制就叫做同步，这里需要跨线程同步的就是变量f的最新值。这有点类似于在工作中，某个同事对你说：
这个设计方案到时候也和测试和BI部门同步一下，保持相关同事对某个信息都是知晓的。类似的，这种保持
每个线程都能看到其它线程对某个共享变量的最新修改，就叫做“可见性”（_Visibility_）。

当然，锁的作用不仅仅是保障变量的可见性，还有操作的原子性（_Atomicity_），有序性（_Ordering_）
等，这里就不详细展开了。

## 介绍显式锁

上面简单介绍了一下锁的作用，接下来的篇幅主要介绍显式锁（_Explicit Lock_）。

与显式锁相对的是隐式锁（_Implicit Lock_）[^3]，如果说`ReentrantLock`是显式锁，那么`synchronized`就
是隐式锁。实际上，Java中所说的隐式锁就是指`synchronized`关键字实现的锁，而显式锁在JDK类库中一共有两个，
分别是`Lock`和`ReadWriteLock`两个接口为代表的显式锁实现。

不管是显式锁还是隐式锁，在同一个时刻，有且只能被一个线程所持有[^4]，这也叫做锁的“互斥性”或“独占性”。
如果当前线程A持有锁L，那么其它需要获取锁L的线程B，线程C就必须等线程A释放锁L，如果线程A一直不释放，那么
线程B和线程C就会永远等下去，这就在被锁L保护的状态变量上形成了串行化访问；也就是说线程A，B，C轮流获取锁L，
所以轮流访问状态变量，下一个线程B只有等线程A释放了才能获取锁，才能访问由锁L保护的状态变量。

另外一个显式锁和隐式锁都具备的特性是“可重入性”，主要是可以避免线程死锁。所谓的可重入，就是指如果当前线
程A获得了锁L，那么，线程A还可以继续获得当前锁。具体可以如此理解：比如下面这段代码，方法`mb()`调用了方法`ma()`。
```java
class LockExample {
    public synchronized void ma() {
        // some operations
    }

    public synchronized void mb() {
        // 
        ma();
    }
}
```
当线程A成功获得锁时，线程A则成功进入了方法`mb()`，但是其内部又调用了另外一个同步方法`ma()`。假设锁不可以重入，
线程A不可以再次获取锁，由于当前锁是由线程A自己持有，那么线程A必须释放锁才能获得方法`ma()`的锁，从而导致了线程
A等线程A自己释放锁，形成死锁。

除了以上互斥性和可重入性，显式锁还有自己独特的特性：
- 可中断的等待：区别于隐式锁只能无限期等待，显式锁在等待获取锁时，线程可以**被中断**从而取消对锁的获取；
- 可超时的等待：区别于隐式锁只能无限期等待，显式锁在获取锁时可以设置**超时时间**，在指定时间内获取不到
锁即立刻放弃；
- 检查锁当前是否被占有，没有被其它线程持有则自动获取锁，如果被其它线程持有，则立刻返回，**不等待，不阻塞**；
- 支持配置公平性[^5]：当前锁L被线程A持有，线程B和线程C在等待获取锁L，当线程A释放锁时，这时线程D来获取锁L；
如果线程D可以在线程A释放锁后，获取到锁L，那么这个锁就是非公平锁，如果线程D排在线程C后面，等线程B和C获取后
才能拿到锁，那么这个锁就是公平的。显式锁默认是非公平模式，可以在构造器中配置成公平模式，一般来讲，非公平锁
的性能高于公平锁，尤其在锁竞争比较激烈的情况下[^6]。

Java的隐式锁是在JVM底层源码实现的，包括隐式锁的性能优化等等，显式锁的逻辑我们可以在JDK源码中详细地看
到其实现，下面具体看一下相关的API。


### Lock

`Lock`[^7]接口一共定义了四个加锁方法和一个解锁方法：
- void lock();
- void lockInterruptibly() throws InterruptedException;
- boolean tryLock();
- boolean tryLock(long time, TimeUnit unit) throws InterruptedException;
- void unlock();

它们的使用很简单，遵循如下代码常用范式模版即可，但注意一定要结合`try`在`finally`块中显式调用`unlock()`方法！

方式一：当前线程阻塞并等待获取锁。
```java
Lock l = ...;
l.lock(); // or l.lockInterruptibly();
try {
    // access the resource protected by this lock
} finally {
    // 一定要在finally里释放锁
  l.unlock();
}
```
方式二：当前线程尝试获取锁，若当前锁不可用就立刻放弃，不在锁上等待。
```java
Lock lock = ...;
if (lock.tryLock()) {
  try {
    // manipulate protected state
  } finally {
    // 一定要在finally里释放锁
    lock.unlock();
  }
} else {
  // perform alternative actions
}
```
`ReentrantLock`是`Lock`接口的实现，在代码语法使用上是一样的。

### ReadWriteLock

`ReadWriteLock`[^8]是另一个显式锁：读写锁，但是要注意它并没有继承`Lock`接口。它只定义了两个方法，一个方法
用于获取读锁，另一个方法用于获取写锁：
- Lock readLock();
- Lock writeLock();



## ReentrantLock还是synchronized？
Lock

## 小结



[^1]: 我们平时所说的“同步”（_synchronization_）是一个很大的概念，不能狭隘地理解成“锁”。更合
适的表达是：“同步”指的是协调多个线程对共享状态的访问从而保障程序的正确性，而“锁”只是其中的一种
“同步机制”。在多线程环境下保证程序的正确性不一定非要通过“锁”来实现，还可以通过`volatile`关键字
，`final`关键字，原子变量等，更全面的要参考Java内存模型规范。
[^2]: 进程（_processes_）是操作系统分配资源的最小单元，其内存地址空间由进程内部所有线程（_threads_）共享。
[^3]: 显式锁还有其它书面上的叫法，比如内置锁（_instrinsic lock_），监视器锁（_monitor lock_），
互斥锁（_mutexes_），在代码层面的表现都是`synchronized`代码块和`synchronized`方法。
[^4]: 有的锁是可以同时由多个线程同时持有的，这里主要想说的是独占锁或排他锁，比如读写锁中的读锁可以
有多个线程同时持有。
[^5]: `Lock`接口中并没有对公平性的要求，但`ReentrantLock`支持公平和非公平两种模式。
[^6]: 当由锁保护的代码块比较小（_finer-grained_），执行比较快，获得锁的线程可以快进快出时，由
于**线程的唤醒和调度需要时间**，如果线程D可以不排队，直接抢占线程A释放后的锁L，那么在线程B和线程C被
唤醒开始抢锁之前，线程D甚至可以完成锁L的获取和退出，然后线程B或线程C获取到了锁，省去了线程D的挂起排队，
可以显著提高锁的吞吐量，提高并发性能。
[^7]: [java.util.concurrent.locks.Lock.java](https://github.com/openjdk/jdk/blob/dfacda488bfbe2e11e8d607a6d08527710286982/src/java.base/share/classes/java/util/concurrent/locks/Lock.java).
[^8]: [java.util.concurrent.locks.ReadWriteLock.java](https://github.com/openjdk/jdk/blob/dfacda488bfbe2e11e8d607a6d08527710286982/src/java.base/share/classes/java/util/concurrent/locks/ReadWriteLock.java).

