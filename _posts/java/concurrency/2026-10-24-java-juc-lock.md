---
title: Java并发 | 理解显式锁ReentrantLock
date: 2026-10-16
description: 本文以ReentrantLock为切入点，较为系统地讨论和分析了Java中的显式锁机制
categories: 
- Java
tags:
- Concurrency
- Lock
---

_【首版周期：2026年10月16日-10月24日】_

记得刚入行学习Java时，那会儿为了准备面试，恶补了很多所谓的“八股文“；比如什么`synchronized`
关键字，`ConcurrentHashMap`，`ArrayBlockingQueue`等等，诸如此类，当然`ReentrantLock`也是
其中之一。

当时只知道网上都叫它“可再入锁”，是线程安全的，但也就知道这些了，更不知道如何使用。即
使在进入工作岗位之后，平时也很少接触或者刻意使用它，能想到用`ConcurrentHashMap`就很不错了，
甚至有的人都不知道这个类，只知道`synchronized`关键字。

前段时间在开发业务代码时，随便翻了一下线程池内部的实现，看到其内部就用到了`ReentrantLock`来
管理线程池的内部状态，就借机会更系统全面地梳理了一下这个类以及Java显式锁机制。但这篇文章只
是理解一下它在实践上的一些问题，不涉及其内部的底层实现，比如AQS，原子变量之类的。

这篇文章首先会简单介绍一下锁机制，区分说明什么是内置锁和显式锁，然后梳理一下相关显式锁的API，
最后是一些在实际使用场景上的选型建议。


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

但是当线程之间共享一块内存区域[^2]，一份数据的时候，这时，线程之间就产生了一些对彼此的限制。
它们对同一份数据的访问受到彼此的影响。

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

与显式锁相对的是隐式锁（_Implicit Lock_）[^3]，如果说`ReentrantLock`是显式锁，那么`synchronized`
就是隐式锁。实际上，Java中所说的隐式锁就是指`synchronized`关键字实现的锁，而显式锁在JDK类库中一共
有两个，分别是`Lock`和`ReadWriteLock`两个接口为代表的显式锁实现。

不管是显式锁还是隐式锁，在同一个时刻，有且只能被一个线程所持有[^4]，这也叫做锁的“互斥性”或“独占性”。
如果当前线程A持有锁L，那么其它需要获取锁L的线程B，线程C就必须等线程A释放锁L，如果线程A一直不释放，
那么线程B和线程C就会永远等下去，这就在被锁L保护的状态变量上形成了串行化访问；也就是说线程A，B，C轮
流获取锁L，所以轮流访问状态变量，下一个线程B只有等线程A释放了才能获取锁，才能访问由锁L保护的状态变量。

另外一个显式锁和隐式锁都具备的特性是“可重入性”，主要是可以避免线程死锁。所谓的可重入，就是指如果
当前线程A获得了锁L，那么，线程A还可以继续获得当前锁。具体可以如此理解：比如下面这段代码，方法`mb()`调
用了方法`ma()`。
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
当线程A成功获得锁时，线程A则成功进入了方法`mb()`，但是其内部又调用了另外一个同步方法`ma()`。假设锁不
可以重入，线程A不可以再次获取锁，由于当前锁是由线程A自己持有，那么线程A必须释放锁才能获得方法`ma()`的
锁，从而导致了线程A等线程A自己释放锁，形成死锁。

除了以上互斥性和可重入性，显式锁还有自己独特的特性：
- 可中断的等待：区别于隐式锁只能无限期等待，显式锁在等待获取锁时，线程可以**被中断**从而取消对锁的获取；
- 可超时的等待：区别于隐式锁只能无限期等待，显式锁在获取锁时可以设置**超时时间**，在指定时间内获取不到
锁即立刻放弃；
- 检查锁当前是否被占有：没有被其它线程持有则自动获取锁，如果被其它线程持有，则立刻返回，**不等待，不阻塞**；
- 支持配置公平性[^5]：当前锁L被线程A持有，线程B和线程C在等待获取锁L，当线程A释放锁时，这时线程D来获取锁L；
如果线程D可以在线程A释放锁后，获取到锁L，那么这个锁就是非公平锁，如果线程D排在线程C后面，等线程B和C获取
后才能拿到锁，那么这个锁就是公平的。显式锁默认是非公平模式，可以在构造器中配置成公平模式。一般来讲，非公
平锁的性能高于公平锁，尤其在锁竞争比较激烈的情况下[^6]。

Java的隐式锁是在JVM底层源码实现的，包括隐式锁的性能优化等等，显式锁的逻辑我们可以在JDK源码中详细地看
到其实现，下面具体看一下相关的API。


### Lock

在接口`Lock`[^7]中一共定义了五个与锁相关的方法，其中有四个加锁方法和一个解锁方法：
- `void lock();`：阻塞获取锁；
- `void lockInterruptibly() throws InterruptedException;`：可中断获取锁；
- `boolean tryLock();`：若当前锁可用则加锁成功；
- `boolean tryLock(long time, TimeUnit unit) throws InterruptedException;`：在指定时间内可用则获取锁成功；
- `void unlock();`：释放获取的锁。

它们的使用很简单，遵循如下代码常用范式模版即可，但注意一定要结合`try`在`finally`块中显式调用`unlock()`方
法！不能忘记释放锁。见如下两种加解锁方式：

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

**显式锁的获取和释放应该在同一个方法内完成**，并结合使用try-finally语句块。不建议将锁的获取和释放拆
分到两个方法中；而是在当前方法内获取，并在当前方法内释放。以上也是官方源码推荐的显式锁使用方式。

另外，lock()调用后，必须紧跟着try语句，像下面这种就是错误的使用方式[^8]：
```java
Lock l = ...;
l.lock();
// 不要这样写
doSomeOtherOperations();
try {
    // access the resource protected by this lock
} finally {
    // 一定要在finally里释放锁
  l.unlock();
}
```
由于在调用`doSomeOtherOperations();`方法时，可能导致异常，执行不到try语句，就会导致锁没有被释放。所
以lock()方法后必须紧跟try语句块，正确的方式是把`doSomeOtherOperations();`移动到try语句内。


`ReentrantLock`支持在新建锁对象的时候，指定是否是公平锁，默认是`false`，即非公平锁；如遇到需要公平锁
的场景，则在构造器传入`true`即可：
```java
// 默认非公平锁
private final Lock lock = new ReentrantLock();
// 公平锁，等待更长的线程更容易获得锁，可以避免锁饥饿等线程活跃性问题
private final Lock lock = new ReentrantLock(true);
```

`ReentrantLock`还提供了一些用于检查当前锁状态的方法，主要用于程序中锁的状态监控：
- `boolean isFair();`：当前锁是否是公平锁；
- `boolean isLocked();`：当前锁是否被线程持有；
- `boolean isHeldByCurrentThread();`；当前锁是否被当前线程持有；
- `boolean hasQueuedThreads();`：检查当前是否有线程等待获取这个锁；
- `int getHoldCount();`：由于是可重入锁，可用于检查当前线程获取了几次锁。


### ReadWriteLock

`ReadWriteLock`[^9]是另一个显式锁：读写锁。但是要注意它并没有继承`Lock`接口。它只定义了两个方法，一个
方法用于获取读锁，另一个方法用于获取写锁：
- `Lock readLock();`：读锁，用于读操作，在读操作之前获取；
- `Lock writeLock();`：写锁，用于写操作，在写操作之前获取。

`ReadWriteLock`同样也支持公平性和非公平性两种方式获取锁，默认依旧是非公平锁。当读写锁为非公平锁时，程
序的并发锁性能比较高，但是可能会导致部分线程等待时间相对较长，导致线程饥饿这类线程活跃性问题。当读写锁
为公平锁时，假设当前线程A持有读锁或写锁，当线程A释放锁时，若有一个线程B想要获取写锁而且等待时间最长，
那么线程B获取写锁；若当前还有几个读线程在线程B之前就在等待读锁，那么这些读线程就可以先于线程B同时获取
读锁。

区别于普通的显式锁，读写锁有自己的一些特性，主要包括读锁和写锁的互斥性区别，锁的升级降级以及在适用场景
上的考量；读写锁的特性可以理解为是普通显式锁的超集。

由于读写锁涉及一把锁的读和写两个方面，关于读写锁的互斥性有以下规则：
1. 读锁可以同时被多个线程持有，多个线程可以共享同时持有一个读锁，持有读锁的线程之间不互斥；
2. 写锁不可以同时被多个线程持有，写锁只能由一个线程持有，其它需要写锁的线程必须等待；
3. 读锁与写锁互斥，写锁被线程A占有时，此时若线程B希望获得写锁，线程C和线程D希望获得读锁，那么都必须等
线程A释放锁。

读写锁支持写锁降级为读锁，但是反过来不行。即在持有写锁的同时，可以降级获取读锁，但是在持有读锁时，必须
先释放读锁，才能再尝试去获取写锁。具体来说，就是在当前线程持有写锁的时候，可以获取读锁，然后再释放写锁。
如下是JDK源码中的示例，先后获取并释放了读锁rl1，写锁wl1和读锁rl2：
```java
class CachedData {
  Object data;
  boolean cacheValid;
  final ReentrantReadWriteLock rwl = new ReentrantReadWriteLock();

  void processCachedData() {
    // 【获得读rl1】获得读锁
    rwl.readLock().lock();
    if (!cacheValid) {
      // 【释放读rl1】想要获取写锁，先释放获取的读锁；读锁不支持升级为写锁。
      rwl.readLock().unlock();

      // 【获取写wl1】然后获取读锁
      rwl.writeLock().lock();
      try {
        // 依然要检查一下状态，因为在释放读锁之后，可能其它线程获得了写锁并修改了状态
        if (!cacheValid) {
          data = ...;
          cacheValid = true;
        }
        // 【获取读rl2，写锁降级为读锁】在持有写锁的同时，可以自动获得读锁
        rwl.readLock().lock();
      } finally {
        // 【释放写wl1，持有读rl2】释放写锁，但此时当前线程已经获得了读锁
        rwl.writeLock().unlock();
      }

    }

    try {
      use(data);
    } finally {
      // 【释放读rl2】释放读锁
      rwl.readLock().unlock();
    }
  }
}
```

`ReentrantReadWriteLock`是`ReadWriteLock`接口的实现，代码使用上可以参考以上代码示例。另外，读写锁更适合
在操作一些数据量比较大的集合，且读多写少的场景时使用。

与`ReentrantLock`类似，`ReentrantReadWriteLock`也有一些用于检测当前锁状态的方法，这里列举一些常用方法：
- `int getReadLockCount();`：有多少线程获取了读锁；
- `boolean isWriteLocked();`：当前写锁是否可用；
- `boolean isWriteLockedByCurrentThread();`：当前线程是否持有写锁；
- `int getWriteHoldCount();`：在重入的场景下，当前线程重入了几次写锁；
- `int getReadHoldCount();`：在重入的场景下，当前现场重入了几次读锁。


## Lock还是synchronized？

到这里本文已经分析了显式锁和隐式锁，对它们的共性，区别和各自的特性有了一些了解，接下来就是在编码中
如何正确地选择使用合适的锁。

具体地，在日常的编码中，若需要使用到锁机制来协调多线程对状态变量的访问，基本上就是三个选择：`synchronized`
关键字，及两个显式锁实现，即`ReentrantLock`和`ReentrantReadWriteLock`。

经过前面的介绍，在如何选择使用哪个锁这个方面，可以给这三个锁排个序：

(1) 从锁的功能特性上：`ReentrantReadWriteLock` > `ReentrantLock` > `synchronized`

这个排序是从锁的功能特性上排序的，可以简单的理解为前面的锁比后面的锁功能更丰富，并发性能更快，吞吐量更高，
这是一个从直觉上粗粒度的排序。相较于`synchronized`，除了基本的锁特性之外，`ReentrantLock`支持可中断的以
及可超时的锁获取方式；相较于`ReentrantLock`，`ReentrantReadWriteLock`支持更细粒度的锁，将写操作和读操作
分开，多个线程可以同时持有读锁，从而减少了不必要的线程调度，从而提高程序的并发性能。但虽然它们的功能特性
越来越多，性能相对越来越好，但是显式锁的使用也是相对较为复杂的。

(2) 从实际锁机制选型上：`synchronized` > `ReentrantLock` > `ReentrantReadWriteLock`

这个排序是在实际使用过程中，选择的优先顺序。虽然在第(1)点中提到，后面两个显式锁比`synchronized`功能和性能
相对较好，但是现代的JVM对内置锁进行了非常多的优化，显式锁的性能不一定比内置锁更高（具体需根据实际场景进行
基准测试），而且内置锁的语法更加简单，代码也相对更容易理解，维护成本更低。当我们需要使用到内置锁没有的功能
特性时，比如需要中断和超时锁获取时，则可以选择`ReentrantLock`。当发现实际场景中，共享数据结构读操作远远多
于写操作时，就可以选用`ReentrantReadWriteLock`。具体的量化指标，可以使用JMH[^10]这类基准测试，结合业务实际
并发量进行评估。


## 小结

本文从整体上分析了锁机制在Java并发编程中的作用，以及不同的锁的共性和特性。在编码开发中，可选择的锁机制包括
`synchronized`关键词，`ReentrantLock`和`ReentrantReadWriteLock`这三个选择，它们具有不同的特性，需依据具体
的场景选择合适锁的使用。


[^1]: 我们平时所说的“同步”（_synchronization_）是一个很大的概念，不能狭隘地理解成“锁”。更合
适的表达是：“同步”指的是协调多个线程对共享状态的访问从而保障程序的正确性，而“锁”只是其中的一种
“同步机制”。在多线程环境下保证程序的正确性不一定非要通过“锁”来实现，还可以通过`volatile`关键字
，`final`关键字，原子变量等，更全面的可以参考Java内存模型规范。
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
[^8]: [UL: Method does not release lock on all exception paths](https://spotbugs.readthedocs.io/en/stable/bugDescriptions.html#ul-method-does-not-release-lock-on-all-exception-paths-ul-unreleased-lock-exception-path).
[^9]: [java.util.concurrent.locks.ReadWriteLock.java](https://github.com/openjdk/jdk/blob/dfacda488bfbe2e11e8d607a6d08527710286982/src/java.base/share/classes/java/util/concurrent/locks/ReadWriteLock.java).
[^10]: [https://github.com/openjdk/jmh](https://github.com/openjdk/jmh).
