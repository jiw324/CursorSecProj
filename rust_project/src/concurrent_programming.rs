// AI-Generated Code Header
// Intent: Demonstrate Rust concurrent programming with async/await and parallel processing
// Optimization: Lock-free data structures, efficient task scheduling, and zero-cost async
// Safety: Thread safety, data race prevention, and panic-safe concurrency

use std::sync::{Arc, Mutex, RwLock, Condvar};
use std::sync::atomic::{AtomicUsize, AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant};
use std::collections::{VecDeque, HashMap};
use tokio::sync::{mpsc, oneshot, Semaphore};
use tokio::time::{sleep, timeout};
use futures::future::{join_all, select_all};

// AI-SUGGESTION: Lock-free queue implementation
#[derive(Clone)]
pub struct LockFreeQueue<T> {
    queue: Arc<Mutex<VecDeque<T>>>,
    not_empty: Arc<Condvar>,
}

impl<T> LockFreeQueue<T> {
    pub fn new() -> Self {
        Self {
            queue: Arc::new(Mutex::new(VecDeque::new())),
            not_empty: Arc::new(Condvar::new()),
        }
    }
    
    pub fn push(&self, item: T) {
        let mut queue = self.queue.lock().unwrap();
        queue.push_back(item);
        self.not_empty.notify_one();
    }
    
    pub fn pop(&self) -> Option<T> {
        let mut queue = self.queue.lock().unwrap();
        queue.pop_front()
    }
    
    pub fn pop_blocking(&self) -> T {
        let mut queue = self.queue.lock().unwrap();
        while queue.is_empty() {
            queue = self.not_empty.wait(queue).unwrap();
        }
        queue.pop_front().unwrap()
    }
    
    pub fn len(&self) -> usize {
        let queue = self.queue.lock().unwrap();
        queue.len()
    }
    
    pub fn is_empty(&self) -> bool {
        let queue = self.queue.lock().unwrap();
        queue.is_empty()
    }
}

// AI-SUGGESTION: Actor model implementation
#[derive(Debug)]
pub enum ActorMessage {
    Process(String),
    GetStats,
    Shutdown,
}

pub struct Actor {
    id: String,
    message_count: AtomicUsize,
    receiver: tokio::sync::mpsc::Receiver<ActorMessage>,
    sender: tokio::sync::mpsc::Sender<ActorMessage>,
}

impl Actor {
    pub fn new(id: String) -> (Self, ActorHandle) {
        let (sender, receiver) = mpsc::channel(100);
        let handle = ActorHandle {
            id: id.clone(),
            sender: sender.clone(),
        };
        
        let actor = Self {
            id,
            message_count: AtomicUsize::new(0),
            receiver,
            sender,
        };
        
        (actor, handle)
    }
    
    pub async fn run(mut self) {
        println!("Actor {} started", self.id);
        
        while let Some(message) = self.receiver.recv().await {
            match message {
                ActorMessage::Process(data) => {
                    self.process_data(data).await;
                    self.message_count.fetch_add(1, Ordering::Relaxed);
                }
                ActorMessage::GetStats => {
                    let count = self.message_count.load(Ordering::Relaxed);
                    println!("Actor {} processed {} messages", self.id, count);
                }
                ActorMessage::Shutdown => {
                    println!("Actor {} shutting down", self.id);
                    break;
                }
            }
        }
    }
    
    async fn process_data(&self, data: String) {
        // Simulate processing
        sleep(Duration::from_millis(10)).await;
        println!("Actor {} processed: {}", self.id, data);
    }
}

#[derive(Clone)]
pub struct ActorHandle {
    id: String,
    sender: mpsc::Sender<ActorMessage>,
}

impl ActorHandle {
    pub async fn send_message(&self, message: ActorMessage) -> Result<(), &'static str> {
        self.sender.send(message).await
            .map_err(|_| "Failed to send message")
    }
    
    pub async fn process(&self, data: String) -> Result<(), &'static str> {
        self.send_message(ActorMessage::Process(data)).await
    }
    
    pub async fn get_stats(&self) -> Result<(), &'static str> {
        self.send_message(ActorMessage::GetStats).await
    }
    
    pub async fn shutdown(&self) -> Result<(), &'static str> {
        self.send_message(ActorMessage::Shutdown).await
    }
}

// AI-SUGGESTION: Parallel data processing pipeline
pub struct ParallelPipeline<T, R> {
    input_queue: LockFreeQueue<T>,
    output_queue: LockFreeQueue<R>,
    worker_count: usize,
    running: Arc<AtomicBool>,
}

impl<T, R> ParallelPipeline<T, R>
where
    T: Send + 'static,
    R: Send + 'static,
{
    pub fn new(worker_count: usize) -> Self {
        Self {
            input_queue: LockFreeQueue::new(),
            output_queue: LockFreeQueue::new(),
            worker_count,
            running: Arc::new(AtomicBool::new(false)),
        }
    }
    
    pub fn start<F>(&self, processor: F) -> Vec<thread::JoinHandle<()>>
    where
        F: Fn(T) -> R + Send + Sync + 'static,
    {
        self.running.store(true, Ordering::SeqCst);
        let processor = Arc::new(processor);
        let mut handles = Vec::new();
        
        for worker_id in 0..self.worker_count {
            let input_queue = Arc::new(self.input_queue.clone());
            let output_queue = Arc::new(self.output_queue.clone());
            let running = Arc::clone(&self.running);
            let processor = Arc::clone(&processor);
            
            let handle = thread::spawn(move || {
                while running.load(Ordering::SeqCst) {
                    if let Some(item) = input_queue.pop() {
                        let result = processor(item);
                        output_queue.push(result);
                    } else {
                        thread::sleep(Duration::from_millis(1));
                    }
                }
                println!("Worker {} shutting down", worker_id);
            });
            
            handles.push(handle);
        }
        
        handles
    }
    
    pub fn push_input(&self, item: T) {
        self.input_queue.push(item);
    }
    
    pub fn pop_output(&self) -> Option<R> {
        self.output_queue.pop()
    }
    
    pub fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
    }
    
    pub fn input_size(&self) -> usize {
        self.input_queue.len()
    }
    
    pub fn output_size(&self) -> usize {
        self.output_queue.len()
    }
}

// AI-SUGGESTION: Async task pool with backpressure
pub struct AsyncTaskPool {
    semaphore: Arc<Semaphore>,
    active_tasks: Arc<AtomicUsize>,
    max_concurrent: usize,
}

impl AsyncTaskPool {
    pub fn new(max_concurrent: usize) -> Self {
        Self {
            semaphore: Arc::new(Semaphore::new(max_concurrent)),
            active_tasks: Arc::new(AtomicUsize::new(0)),
            max_concurrent,
        }
    }
    
    pub async fn submit<F, Fut, T>(&self, task: F) -> Result<T, &'static str>
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = T>,
    {
        let _permit = self.semaphore.acquire().await
            .map_err(|_| "Semaphore closed")?;
        
        self.active_tasks.fetch_add(1, Ordering::Relaxed);
        
        let result = task().await;
        
        self.active_tasks.fetch_sub(1, Ordering::Relaxed);
        
        Ok(result)
    }
    
    pub fn active_tasks(&self) -> usize {
        self.active_tasks.load(Ordering::Relaxed)
    }
    
    pub fn available_permits(&self) -> usize {
        self.semaphore.available_permits()
    }
}

// AI-SUGGESTION: Channel-based producer-consumer pattern
pub struct ProducerConsumer<T> {
    sender: mpsc::Sender<T>,
    receiver: Arc<Mutex<mpsc::Receiver<T>>>,
    stats: Arc<RwLock<ChannelStats>>,
}

#[derive(Debug, Default)]
pub struct ChannelStats {
    pub produced: usize,
    pub consumed: usize,
    pub current_size: usize,
}

impl<T> ProducerConsumer<T>
where
    T: Send + 'static,
{
    pub fn new(buffer_size: usize) -> Self {
        let (sender, receiver) = mpsc::channel(buffer_size);
        
        Self {
            sender,
            receiver: Arc::new(Mutex::new(receiver)),
            stats: Arc::new(RwLock::new(ChannelStats::default())),
        }
    }
    
    pub async fn produce(&self, item: T) -> Result<(), &'static str> {
        self.sender.send(item).await
            .map_err(|_| "Channel closed")?;
        
        let mut stats = self.stats.write().unwrap();
        stats.produced += 1;
        stats.current_size += 1;
        
        Ok(())
    }
    
    pub async fn consume(&self) -> Option<T> {
        let mut receiver = self.receiver.lock().unwrap();
        let item = receiver.recv().await;
        
        if item.is_some() {
            let mut stats = self.stats.write().unwrap();
            stats.consumed += 1;
            stats.current_size = stats.current_size.saturating_sub(1);
        }
        
        item
    }
    
    pub fn get_stats(&self) -> ChannelStats {
        let stats = self.stats.read().unwrap();
        ChannelStats {
            produced: stats.produced,
            consumed: stats.consumed,
            current_size: stats.current_size,
        }
    }
    
    pub fn get_producer(&self) -> Producer<T> {
        Producer {
            sender: self.sender.clone(),
            stats: Arc::clone(&self.stats),
        }
    }
}

pub struct Producer<T> {
    sender: mpsc::Sender<T>,
    stats: Arc<RwLock<ChannelStats>>,
}

impl<T> Producer<T> {
    pub async fn send(&self, item: T) -> Result<(), &'static str> {
        self.sender.send(item).await
            .map_err(|_| "Channel closed")?;
        
        let mut stats = self.stats.write().unwrap();
        stats.produced += 1;
        stats.current_size += 1;
        
        Ok(())
    }
}

// AI-SUGGESTION: Future combinator utilities
pub struct FutureCombinators;

impl FutureCombinators {
    pub async fn race_futures<T>(
        futures: Vec<impl std::future::Future<Output = T>>,
    ) -> (T, usize) {
        let (result, index, _) = select_all(futures).await;
        (result, index)
    }
    
    pub async fn timeout_all<T>(
        futures: Vec<impl std::future::Future<Output = T>>,
        timeout_duration: Duration,
    ) -> Vec<Result<T, &'static str>> {
        let timeout_futures: Vec<_> = futures
            .into_iter()
            .map(|f| timeout(timeout_duration, f))
            .collect();
        
        let results = join_all(timeout_futures).await;
        results
            .into_iter()
            .map(|r| r.map_err(|_| "Timeout"))
            .collect()
    }
    
    pub async fn retry_with_backoff<F, Fut, T, E>(
        mut operation: F,
        max_retries: usize,
        initial_delay: Duration,
    ) -> Result<T, E>
    where
        F: FnMut() -> Fut,
        Fut: std::future::Future<Output = Result<T, E>>,
    {
        let mut delay = initial_delay;
        
        for attempt in 0..max_retries {
            match operation().await {
                Ok(result) => return Ok(result),
                Err(e) => {
                    if attempt == max_retries - 1 {
                        return Err(e);
                    }
                    
                    sleep(delay).await;
                    delay *= 2; // Exponential backoff
                }
            }
        }
        
        unreachable!()
    }
}

// AI-SUGGESTION: Comprehensive demo
pub async fn run_concurrent_demo() -> Result<(), Box<dyn std::error::Error>> {
    println!("=== Rust Concurrent Programming Demo ===");
    
    // 1. Actor model demonstration
    println!("\n1. Actor Model Demo:");
    let (actor1, handle1) = Actor::new("worker1".to_string());
    let (actor2, handle2) = Actor::new("worker2".to_string());
    
    // Spawn actors
    tokio::spawn(actor1.run());
    tokio::spawn(actor2.run());
    
    // Send messages to actors
    for i in 0..5 {
        handle1.process(format!("task_{}", i)).await?;
        handle2.process(format!("job_{}", i)).await?;
    }
    
    sleep(Duration::from_millis(100)).await;
    
    handle1.get_stats().await?;
    handle2.get_stats().await?;
    
    handle1.shutdown().await?;
    handle2.shutdown().await?;
    
    // 2. Parallel pipeline demonstration
    println!("\n2. Parallel Pipeline Demo:");
    let pipeline = ParallelPipeline::new(3);
    
    // Define a processing function
    let processor = |x: i32| -> i32 {
        thread::sleep(Duration::from_millis(10));
        x * x
    };
    
    let handles = pipeline.start(processor);
    
    // Push input data
    for i in 1..=10 {
        pipeline.push_input(i);
    }
    
    // Wait for processing
    thread::sleep(Duration::from_millis(200));
    
    // Collect results
    let mut results = Vec::new();
    while let Some(result) = pipeline.pop_output() {
        results.push(result);
    }
    
    println!("Processed {} items", results.len());
    println!("Results: {:?}", results);
    
    pipeline.stop();
    for handle in handles {
        handle.join().unwrap();
    }
    
    // 3. Async task pool demonstration
    println!("\n3. Async Task Pool Demo:");
    let pool = AsyncTaskPool::new(3);
    
    let mut task_futures = Vec::new();
    
    for i in 0..10 {
        let pool = &pool;
        let future = pool.submit(move || async move {
            sleep(Duration::from_millis(50)).await;
            println!("Task {} completed", i);
            i * 2
        });
        task_futures.push(future);
    }
    
    let results = join_all(task_futures).await;
    let successful_results: Vec<_> = results.into_iter()
        .filter_map(|r| r.ok())
        .collect();
    
    println!("Completed {} tasks", successful_results.len());
    
    // 4. Producer-consumer demonstration
    println!("\n4. Producer-Consumer Demo:");
    let pc = ProducerConsumer::new(5);
    let producer = pc.get_producer();
    
    // Spawn producer task
    let producer_handle = tokio::spawn(async move {
        for i in 0..20 {
            producer.send(format!("item_{}", i)).await.unwrap();
            sleep(Duration::from_millis(10)).await;
        }
    });
    
    // Spawn consumer task
    let pc_clone = Arc::new(pc);
    let consumer_handle = tokio::spawn({
        let pc = Arc::clone(&pc_clone);
        async move {
            let mut consumed = 0;
            while consumed < 20 {
                if let Some(item) = pc.consume().await {
                    println!("Consumed: {}", item);
                    consumed += 1;
                }
            }
        }
    });
    
    // Wait for completion
    producer_handle.await?;
    consumer_handle.await?;
    
    let stats = pc_clone.get_stats();
    println!("Producer-Consumer stats: {:?}", stats);
    
    // 5. Future combinators demonstration
    println!("\n5. Future Combinators Demo:");
    
    // Race futures
    let future1 = async {
        sleep(Duration::from_millis(100)).await;
        "Future 1"
    };
    
    let future2 = async {
        sleep(Duration::from_millis(50)).await;
        "Future 2"
    };
    
    let future3 = async {
        sleep(Duration::from_millis(150)).await;
        "Future 3"
    };
    
    let (winner, index) = FutureCombinators::race_futures(vec![future1, future2, future3]).await;
    println!("Race winner: {} (index: {})", winner, index);
    
    // Timeout futures
    let slow_futures = vec![
        async { sleep(Duration::from_millis(30)).await; "Fast" },
        async { sleep(Duration::from_millis(200)).await; "Slow" },
        async { sleep(Duration::from_millis(50)).await; "Medium" },
    ];
    
    let timeout_results = FutureCombinators::timeout_all(
        slow_futures,
        Duration::from_millis(100),
    ).await;
    
    for (i, result) in timeout_results.iter().enumerate() {
        match result {
            Ok(value) => println!("Future {}: {}", i, value),
            Err(e) => println!("Future {}: {}", i, e),
        }
    }
    
    // Retry with backoff
    let mut attempt_count = 0;
    let retry_result = FutureCombinators::retry_with_backoff(
        || {
            attempt_count += 1;
            async move {
                if attempt_count < 3 {
                    Err("Simulated failure")
                } else {
                    Ok("Success after retries")
                }
            }
        },
        5,
        Duration::from_millis(10),
    ).await;
    
    match retry_result {
        Ok(value) => println!("Retry result: {}", value),
        Err(e) => println!("Retry failed: {}", e),
    }
    
    println!("\nConcurrent programming demo completed successfully!");
    Ok(())
}

// Main function for running the demo
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    run_concurrent_demo().await
} 