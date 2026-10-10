---
title: 在线程任务中如何正确处理异常和中断？
date: 2026-10-01
categories: 
- Java
tags:
- Concurrency
---

在业务开发中，为了快速执行并退出当前的方法，利用多核CPU提高应用的吞吐率，我们会想到在当前方法中新建一个线程，并通过将部分任务放到另一个线程中并行执行的方式，加快当前方法的执行速度。以Web应用为例，就是让接口可以快速的返回响应。

这里涉及两个基础概念：其一，**任务（Task）**：在代码中，常用的方式是实现Runnable接口，这样的实现我们把它称为一个任务，任务是一小块自洽的业务逻辑单元，具体的任务实现细节在Runnable的run方法中；其二，**线程（Thread）**：线程是用来执行任务的（这从线程的构造函数可以看出），线程会调用Runnable的run方法，同时线程也有它自己的生命周期以及状态等等。任务一般通过线程的构造参数转递给线程，在线程中得到执行。

任务在执行的过程中一般会有下列情形：

- **情形1：执行完整任务单元**：run方法从头执行到尾，走完所有的编码逻辑，中间没有任何异常等错误分支，行为是完全可预测的；
- **情形2：任务执行出现异常**：run方法的执行过程中，出现了异常，这个异常可能是预料中的，也可能是编码时事先无法提前预知的（比如checked异常和unchecked异常）；
- **情形3：任务的执行被取消**：一般通过外部中断任务所在的线程，同时任务内部检查当前线程的中断状态，来取消任务的执行。

上面的情形1是最简单的情况，代码是按照正常的业务流程走完的，其执行的结果也是正常完整的业务流程。但是情形2和3则需要我们多考虑一些，如果代码不做处理，可能会发生一些我们不希望遇到的情况。

接下来将以下单咖啡为例，描述上面提到的情形2和情形3：

```java
public class CoffeeOrderDemo {

    static void main() {
        // 从jdk19开始, ExecutorService 实现了 AutoCloseable, 可以使用try-with-resource
        try (ExecutorService exec = Executors.newSingleThreadExecutor()) {

            // 为了简化，这里直接定义了一个service和domain对象
            CoffeeOrderService service = new CoffeeOrderServiceImpl();
            Americano americano = new Americano();
            // 向线程池提交下单任务
            exec.execute(
                    new Runnable() {
                        @Override
                        public void run() {
                            service.order(americano);
                        }
                    }
            );
        }
        // try 代码块结束
    }

}
```

## 0x01下单服务内部抛出未知异常

上面run方法中，只有一条语句，就是直接调用下单服务的order方法，没有其它。但是，我们并不知道order方法内部具体的业务实现，其中可能会抛出运行时异常，比如`NullPointerException`等，这个时候会出现什么情况呢？因为在run方法中我们没有处理这类运行时异常，那么异常就会上抛给到了线程所在的线程池。这个时候，线程池会将发生异常的线程线程池中移除，并创建一个新的线程。这就是由于任务异常的传递，造成的线程销毁和创建的开销。

下面是`ThreadPoolExecutor`的相关源码部分：

```java
final void runWorker(Worker w) {
	...
    boolean completedAbruptly = true;
    try {
        // 发生异常会导致此循环退出
        while (task != null || (task = getTask()) != null) {
			...
            try {
                beforeExecute(wt, task);
                try {
                    task.run();
                    afterExecute(task, null);
                } catch (Throwable ex) {
                    afterExecute(task, ex);
                    // 再次抛出任务中未及时捕获的异常
                    throw ex;
                }
            } finally {
                task = null;
                w.completedTasks++;
                w.unlock();
            }
        }
        completedAbruptly = false;
    } finally {
        // 具体的线程移除和新增逻辑在 completedAbruptly = true
        processWorkerExit(w, completedAbruptly);
    }
}

private void processWorkerExit(Worker w, boolean completedAbruptly) {
    if (completedAbruptly) // If abrupt, then workerCount wasn't adjusted
        decrementWorkerCount();

    // 移除线程
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        completedTaskCount += w.completedTasks;
        workers.remove(w);
    } finally {
        mainLock.unlock();
    }

    ...

    int c = ctl.get();
    if (runStateLessThan(c, STOP)) {
		...
        // 如果线程池没有关闭，就调用addWorker方法，注意，并不是调了这个方法一定会新增线程，
        // 内部还会看此时线程池的状态还有当前工作者线程的数量
        addWorker(null, false);
    }
}
```

从上面的源码可以看出，如果线程中的任务发生了异常，工作者线程就退出了**从队列不断拉取任务执行的循环**（见`runWorker`方法），在`processWorkerExit`方法中会将线程从线程池中移除，当调用到`addWorker`方法时，就会导致新增一个新的线程，带来线程的销毁和创建开销。

## 0x02任务被取消或线程中断

假设调用了上面的order方法之后，程序想取消操作怎么办？（这里假设下单服务是支持取消的）又例如，下单服务内部调用了一个外部的较为耗时的API，在等待API返回的时候，接口已经超过了正常的响应时间，程序需要立即取消并提示用户下单超时怎么办？

在Java多线程编程场景中，一般使用中断线程来取消线程中正在执行的任务。可以这么说，Java线程的中断机制就是用来取消线程中正在执行的任务的。

> Interruption is usually the most sensible way to implement cancellation.
>
> *—— Java Concurrency in Practice, Brian Goetz*

在Thread类中，有如下一个表示线程是否已经处于中断状态的字段，另外interrupt方法用于将当前线程置为中断状态：

```java
// interrupt status (read/written by VM)
volatile boolean interrupted;

// Interrupts this thread.
public void interrupt() {
    ...
}
```

但是，调用了interrupt方法只是将线程的中断状态置为true，并不代表任务会响应中断！

> Calling interrupt does not necessarily stop the target thread from doing what it is doing; it merely delivers the
> message that interruption has been requested.
>
> *—— Java Concurrency in Practice, Brian Goetz*

正常一个支持取消的任务应该在合适的时候，去检查线程的中断状态，当检测到中断的时候，进行任务的取消操作。任务支持取消的机制一般有以下两种：

1. 如果任务本身是在一个循环中，那么可以在循环条件中，检查当前的线程状态。如果检测到已被中断，则取消或回滚相关操作；
2. 如果任务内部是多个步骤组成的，则可以在每一个步骤之前，检查当前线程非中断状态再继续执行，例如在相关方法的入口处。

```java
Thread thread = Thread.currentThread();
// 拿到线程对象后，调用此方法中断线程
thread.interrupt();

// 拿到线程对象后，判断线程是否已经被中断
thread.isInterrupted();
// 一般在任务中，用以下两行代码之一判断任务所在线程是否已经被中断
Thread.currentThread().isInterrupted();
// 或者
Thread.interrupted();
```

这里要注意`Thread.interrupted();`方法会返回线程的中断状态，并将清除线程中断状态。（由此可知，线程中断的状态是可以被多次置为中断和清除的）。而`Thread.currentThread().isInterrupted();`只是返回当前线程是否已经被中断，不会清除线程的中断状态。

这里我们需要遵循一个规则，可以当作是最佳实践吧！在任务代码中，如果检测到线程被中断（通过上面的两个方法或者检测到了`InterruptedException`异常），则必须在退出任务之前，恢复所在线程的中断状态。

具体的细节在此我暂时没有深入了解，在《Java并发编程实践》这本书中，作者认为，线程的中断应该由线程的拥有者（即线程池）去响应和处理，任务中如果检测到了线程中断，应该保留线程的中断状态，以让线程的拥有者去做相应的处理。同时，Java标准类库中，也都采纳了此最佳实践，例如：

```java
// java.util.concurrent.ExecutorService#close
@Override
default void close() {
    boolean terminated = isTerminated();
    if (!terminated) {
        shutdown();
        // 用于保留中断状态，同时避免多次调用shutdownNow
        boolean interrupted = false;
        while (!terminated) {
            try {
                terminated = awaitTermination(1L, TimeUnit.DAYS);
            } catch (InterruptedException e) {
                if (!interrupted) {
                    shutdownNow();
                    interrupted = true;
                }
            }
        }
        // 在退出时，恢复调用线程的中断状态
        if (interrupted) {
            Thread.currentThread().interrupt();
        }
    }
}
```

一般除了我们自己去管理线程的生命周期和中断状态，实现类似于线程池一样的机制，一般方法内检测到线程中断，在方法退出之前，都要恢复线程的中断状态，让更高层的代码去处理。

## 0x03下单任务的最佳实践

经过以上的分析，假设我们的下单接口实现会抛出InterruptedException异常，我们应该写出以下代码：

```java
public class CoffeeOrderDemo {

    private static final Logger log = Logger.getLogger(CoffeeOrderDemo.class.getName());

    static void main() {
        // 从jdk19开始, ExecutorService 实现了 AutoCloseable, 可以使用try-with-resource
        try (ExecutorService exec = Executors.newSingleThreadExecutor()) {
            // 为了简化，这里直接定义了一个service和domain对象
            CoffeeOrderService service = new CoffeeOrderServiceImpl();
            Americano americano = new Americano();
            // 向线程池提交下单任务
            exec.execute(
                    new Runnable() {
                        @Override
                        public void run() {
                            try {
                                service.order(americano);
                            } catch (InterruptedException e) {
                                // 恢复中断状态
                                Thread.currentThread().interrupt();
                            } catch (Throwable e) {
                                // 捕获其它所有异常
                                log.severe("下单未知错误: " + e.getMessage());
                            }
                        }
                    }
            );
        }
        // try 代码块结束
    }

}
```

当调用下单服务抛出中断异常时，我们需要保留所在线程的中断状态；同时为了防止下单抛出其它运行时异常，捕获所有异常并进行先关的处理，比如记录日志等等，避免将异常抛出到外部代码。
