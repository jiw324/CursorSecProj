use std::collections::{HashMap, BTreeMap};
use std::sync::{Arc, Mutex, RwLock, mpsc};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use std::fs::{File, OpenOptions};
use std::io::{self, Read, Write, BufReader, BufWriter, SeekFrom, Seek};
use std::path::{Path, PathBuf};
use std::ffi::{CString, CStr};
use std::ptr;
use std::mem;
use std::slice;

pub struct MemoryPool {
    pool: Vec<u8>,
    free_blocks: Vec<usize>,
    block_size: usize,
    allocated_blocks: HashMap<usize, bool>,
}

impl MemoryPool {
    pub fn new(pool_size: usize, block_size: usize) -> Self {
        let pool = vec![0u8; pool_size];
        let num_blocks = pool_size / block_size;
        let free_blocks = (0..num_blocks).map(|i| i * block_size).collect();
        
        Self {
            pool,
            free_blocks,
            block_size,
            allocated_blocks: HashMap::new(),
        }
    }
    
    pub fn allocate(&mut self) -> Option<*mut u8> {
        if let Some(offset) = self.free_blocks.pop() {
            self.allocated_blocks.insert(offset, true);
            unsafe {
                Some(self.pool.as_mut_ptr().add(offset))
            }
        } else {
            None
        }
    }
    
    pub fn deallocate(&mut self, ptr: *mut u8) -> Result<(), &'static str> {
        let pool_start = self.pool.as_ptr() as usize;
        let ptr_addr = ptr as usize;
        
        if ptr_addr < pool_start || ptr_addr >= pool_start + self.pool.len() {
            return Err("Pointer not from this pool");
        }
        
        let offset = ptr_addr - pool_start;
        if offset % self.block_size != 0 {
            return Err("Invalid alignment");
        }
        
        if self.allocated_blocks.remove(&offset).is_some() {
            self.free_blocks.push(offset);
            Ok(())
        } else {
            Err("Block not allocated")
        }
    }
    
    pub fn get_statistics(&self) -> MemoryPoolStats {
        let total_blocks = self.pool.len() / self.block_size;
        let allocated_blocks = self.allocated_blocks.len();
        let free_blocks = self.free_blocks.len();
        
        MemoryPoolStats {
            total_blocks,
            allocated_blocks,
            free_blocks,
            fragmentation_ratio: free_blocks as f64 / total_blocks as f64,
        }
    }
}

#[derive(Debug)]
pub struct MemoryPoolStats {
    pub total_blocks: usize,
    pub allocated_blocks: usize,
    pub free_blocks: usize,
    pub fragmentation_ratio: f64,
}

pub struct SharedResource<T> {
    inner: Arc<RwLock<T>>,
    id: String,
}

impl<T> SharedResource<T> {
    pub fn new(data: T, id: String) -> Self {
        Self {
            inner: Arc::new(RwLock::new(data)),
            id,
        }
    }
    
    pub fn read<F, R>(&self, f: F) -> Result<R, &'static str>
    where
        F: FnOnce(&T) -> R,
    {
        let guard = self.inner.read().map_err(|_| "Failed to acquire read lock")?;
        Ok(f(&*guard))
    }
    
    pub fn write<F, R>(&self, f: F) -> Result<R, &'static str>
    where
        F: FnOnce(&mut T) -> R,
    {
        let mut guard = self.inner.write().map_err(|_| "Failed to acquire write lock")?;
        Ok(f(&mut *guard))
    }
    
    pub fn clone_handle(&self) -> Self {
        Self {
            inner: Arc::clone(&self.inner),
            id: self.id.clone(),
        }
    }
    
    pub fn strong_count(&self) -> usize {
        Arc::strong_count(&self.inner)
    }
    
    pub fn id(&self) -> &str {
        &self.id
    }
}

impl<T> Drop for SharedResource<T> {
    fn drop(&mut self) {
        if Arc::strong_count(&self.inner) == 1 {
            println!("Last reference to SharedResource '{}' dropped", self.id);
        }
    }
}

use std::sync::atomic::{AtomicUsize, AtomicBool, Ordering};

pub struct AtomicCounter {
    count: AtomicUsize,
    max_value: usize,
    overflow_flag: AtomicBool,
}

impl AtomicCounter {
    pub fn new(max_value: usize) -> Self {
        Self {
            count: AtomicUsize::new(0),
            max_value,
            overflow_flag: AtomicBool::new(false),
        }
    }
    
    pub fn increment(&self) -> usize {
        let current = self.count.fetch_add(1, Ordering::SeqCst);
        if current >= self.max_value {
            self.overflow_flag.store(true, Ordering::SeqCst);
        }
        current + 1
    }
    
    pub fn decrement(&self) -> usize {
        self.count.fetch_sub(1, Ordering::SeqCst).saturating_sub(1)
    }
    
    pub fn get(&self) -> usize {
        self.count.load(Ordering::SeqCst)
    }
    
    pub fn reset(&self) {
        self.count.store(0, Ordering::SeqCst);
        self.overflow_flag.store(false, Ordering::SeqCst);
    }
    
    pub fn has_overflowed(&self) -> bool {
        self.overflow_flag.load(Ordering::SeqCst)
    }
    
    pub fn compare_and_swap(&self, current: usize, new: usize) -> Result<usize, usize> {
        match self.count.compare_exchange(current, new, Ordering::SeqCst, Ordering::SeqCst) {
            Ok(prev) => Ok(prev),
            Err(actual) => Err(actual),
        }
    }
}

use std::fs::metadata;

pub struct MappedFile {
    #[cfg(unix)]
    mapping: *mut libc::c_void,
    #[cfg(windows)]
    mapping: *mut winapi::ctypes::c_void,
    size: usize,
    path: PathBuf,
}

impl MappedFile {
    #[cfg(unix)]
    pub fn open<P: AsRef<Path>>(path: P) -> io::Result<Self> {
        let path = path.as_ref().to_path_buf();
        let file = File::open(&path)?;
        let metadata = file.metadata()?;
        let size = metadata.len() as usize;
        
        let fd = std::os::unix::io::AsRawFd::as_raw_fd(&file);
        
        let mapping = unsafe {
            libc::mmap(
                ptr::null_mut(),
                size,
                libc::PROT_READ,
                libc::MAP_PRIVATE,
                fd,
                0,
            )
        };
        
        if mapping == libc::MAP_FAILED {
            return Err(io::Error::last_os_error());
        }
        
        Ok(Self {
            mapping,
            size,
            path,
        })
    }
    
    #[cfg(not(unix))]
    pub fn open<P: AsRef<Path>>(path: P) -> io::Result<Self> {
        let path = path.as_ref().to_path_buf();
        let metadata = std::fs::metadata(&path)?;
        let size = metadata.len() as usize;
        
        let mapping = ptr::null_mut();
        
        Ok(Self {
            mapping,
            size,
            path,
        })
    }
    
    pub fn as_slice(&self) -> &[u8] {
        if self.mapping.is_null() {
            &[]
        } else {
            unsafe { slice::from_raw_parts(self.mapping as *const u8, self.size) }
        }
    }
    
    pub fn size(&self) -> usize {
        self.size
    }
    
    pub fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for MappedFile {
    fn drop(&mut self) {
        if !self.mapping.is_null() {
            #[cfg(unix)]
            unsafe {
                libc::munmap(self.mapping, self.size);
            }
        }
    }
}

#[cfg(target_arch = "x86_64")]
use std::arch::x86_64::*;

pub struct SIMDProcessor;

impl SIMDProcessor {
    #[cfg(target_arch = "x86_64")]
    pub fn sum_f32_avx(data: &[f32]) -> f32 {
        if !is_x86_feature_detected!("avx") {
            return data.iter().sum();
        }
        
        unsafe {
            let mut sum = _mm256_setzero_ps();
            let chunks = data.chunks_exact(8);
            let remainder = chunks.remainder();
            
            for chunk in chunks {
                let vec = _mm256_loadu_ps(chunk.as_ptr());
                sum = _mm256_add_ps(sum, vec);
            }
            
            let mut result = [0.0f32; 8];
            _mm256_storeu_ps(result.as_mut_ptr(), sum);
            let mut total = result.iter().sum::<f32>();
            
            total += remainder.iter().sum::<f32>();
            total
        }
    }
    
    #[cfg(not(target_arch = "x86_64"))]
    pub fn sum_f32_avx(data: &[f32]) -> f32 {
        data.iter().sum()
    }
    
    pub fn dot_product(a: &[f32], b: &[f32]) -> f32 {
        if a.len() != b.len() {
            return 0.0;
        }
        
        #[cfg(target_arch = "x86_64")]
        {
            if is_x86_feature_detected!("avx") && a.len() >= 8 {
                return Self::dot_product_avx(a, b);
            }
        }
        
        a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
    }
    
    #[cfg(target_arch = "x86_64")]
    unsafe fn dot_product_avx(a: &[f32], b: &[f32]) -> f32 {
        let mut sum = _mm256_setzero_ps();
        let chunks_a = a.chunks_exact(8);
        let chunks_b = b.chunks_exact(8);
        
        for (chunk_a, chunk_b) in chunks_a.zip(chunks_b) {
            let vec_a = _mm256_loadu_ps(chunk_a.as_ptr());
            let vec_b = _mm256_loadu_ps(chunk_b.as_ptr());
            let product = _mm256_mul_ps(vec_a, vec_b);
            sum = _mm256_add_ps(sum, product);
        }
        
        let mut result = [0.0f32; 8];
        _mm256_storeu_ps(result.as_mut_ptr(), sum);
        let mut total = result.iter().sum::<f32>();
        
        let len = a.len();
        let remainder_start = (len / 8) * 8;
        for i in remainder_start..len {
            total += a[i] * b[i];
        }
        
        total
    }
}

#[derive(Debug)]
pub enum SystemError {
    Io(io::Error),
    Memory(String),
    Threading(String),
    InvalidOperation(String),
    Timeout(Duration),
}

impl std::fmt::Display for SystemError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SystemError::Io(e) => write!(f, "I/O error: {}", e),
            SystemError::Memory(msg) => write!(f, "Memory error: {}", msg),
            SystemError::Threading(msg) => write!(f, "Threading error: {}", msg),
            SystemError::InvalidOperation(msg) => write!(f, "Invalid operation: {}", msg),
            SystemError::Timeout(duration) => write!(f, "Operation timed out after {:?}", duration),
        }
    }
}

impl std::error::Error for SystemError {}

impl From<io::Error> for SystemError {
    fn from(error: io::Error) -> Self {
        SystemError::Io(error)
    }
}

pub type SystemResult<T> = Result<T, SystemError>;

pub struct WorkQueue<T> {
    sender: mpsc::Sender<WorkItem<T>>,
    workers: Vec<thread::JoinHandle<()>>,
    shutdown: Arc<AtomicBool>,
}

pub struct WorkItem<T> {
    pub data: T,
    pub callback: Box<dyn FnOnce(T) + Send>,
}

impl<T> WorkQueue<T>
where
    T: Send + 'static,
{
    pub fn new(num_workers: usize) -> Self {
        let (sender, receiver) = mpsc::channel();
        let receiver = Arc::new(Mutex::new(receiver));
        let shutdown = Arc::new(AtomicBool::new(false));
        
        let mut workers = Vec::with_capacity(num_workers);
        
        for id in 0..num_workers {
            let receiver = Arc::clone(&receiver);
            let shutdown = Arc::clone(&shutdown);
            
            let worker = thread::spawn(move || {
                while !shutdown.load(Ordering::SeqCst) {
                    let item = {
                        let receiver = receiver.lock().unwrap();
                        receiver.recv_timeout(Duration::from_millis(100))
                    };
                    
                    match item {
                        Ok(work_item) => {
                            (work_item.callback)(work_item.data);
                        }
                        Err(mpsc::RecvTimeoutError::Timeout) => continue,
                        Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    }
                }
                println!("Worker {} shutting down", id);
            });
            
            workers.push(worker);
        }
        
        Self {
            sender,
            workers,
            shutdown,
        }
    }
    
    pub fn submit<F>(&self, data: T, callback: F) -> SystemResult<()>
    where
        F: FnOnce(T) + Send + 'static,
    {
        let work_item = WorkItem {
            data,
            callback: Box::new(callback),
        };
        
        self.sender.send(work_item)
            .map_err(|_| SystemError::Threading("Failed to send work item".to_string()))?;
        
        Ok(())
    }
    
    pub fn shutdown(self) {
        self.shutdown.store(true, Ordering::SeqCst);
        drop(self.sender);
        
        for worker in self.workers {
            if let Err(e) = worker.join() {
                eprintln!("Worker thread panicked: {:?}", e);
            }
        }
    }
}

pub struct PerformanceMonitor {
    measurements: BTreeMap<String, Vec<Duration>>,
}

impl PerformanceMonitor {
    pub fn new() -> Self {
        Self {
            measurements: BTreeMap::new(),
        }
    }
    
    pub fn time_operation<F, R>(&mut self, name: &str, operation: F) -> R
    where
        F: FnOnce() -> R,
    {
        let start = Instant::now();
        let result = operation();
        let duration = start.elapsed();
        
        self.measurements.entry(name.to_string())
            .or_insert_with(Vec::new)
            .push(duration);
        
        result
    }
    
    pub fn get_statistics(&self, name: &str) -> Option<PerformanceStats> {
        let measurements = self.measurements.get(name)?;
        
        if measurements.is_empty() {
            return None;
        }
        
        let mut sorted = measurements.clone();
        sorted.sort();
        
        let count = sorted.len();
        let total: Duration = sorted.iter().sum();
        let average = total / count as u32;
        let median = sorted[count / 2];
        let min = sorted[0];
        let max = sorted[count - 1];
        
        Some(PerformanceStats {
            name: name.to_string(),
            count,
            total,
            average,
            median,
            min,
            max,
        })
    }
    
    pub fn print_report(&self) {
        println!("Performance Report:");
        println!("{:-<60}", "");
        
        for name in self.measurements.keys() {
            if let Some(stats) = self.get_statistics(name) {
                println!("{}", stats);
                println!("{:-<60}", "");
            }
        }
    }
}

#[derive(Debug)]
pub struct PerformanceStats {
    pub name: String,
    pub count: usize,
    pub total: Duration,
    pub average: Duration,
    pub median: Duration,
    pub min: Duration,
    pub max: Duration,
}

impl std::fmt::Display for PerformanceStats {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        writeln!(f, "Operation: {}", self.name)?;
        writeln!(f, "  Count: {}", self.count)?;
        writeln!(f, "  Total: {:?}", self.total)?;
        writeln!(f, "  Average: {:?}", self.average)?;
        writeln!(f, "  Median: {:?}", self.median)?;
        writeln!(f, "  Min: {:?}", self.min)?;
        writeln!(f, "  Max: {:?}", self.max)
    }
}

pub fn run_systems_demo() -> SystemResult<()> {
    println!("=== Rust Systems Programming Demo ===");
    
    let mut monitor = PerformanceMonitor::new();
    
    println!("\n1. Memory Pool Demo:");
    monitor.time_operation("memory_pool_ops", || {
        let mut pool = MemoryPool::new(1024, 64);
        
        let ptr1 = pool.allocate().unwrap();
        let ptr2 = pool.allocate().unwrap();
        let ptr3 = pool.allocate().unwrap();
        
        println!("Allocated 3 blocks");
        let stats = pool.get_statistics();
        println!("Pool stats: {:?}", stats);
        
        pool.deallocate(ptr2).unwrap();
        println!("Deallocated middle block");
        
        let stats = pool.get_statistics();
        println!("Pool stats after deallocation: {:?}", stats);
    });
    
    println!("\n2. Shared Resource Demo:");
    monitor.time_operation("shared_resource_ops", || {
        let resource = SharedResource::new(vec![1, 2, 3, 4, 5], "demo_vector".to_string());
        let clone1 = resource.clone_handle();
        let clone2 = resource.clone_handle();
        
        println!("Strong count: {}", resource.strong_count());
        
        let sum = resource.read(|data| data.iter().sum::<i32>()).unwrap();
        println!("Sum of vector: {}", sum);
        
        clone1.write(|data| data.push(6)).unwrap();
        
        let new_sum = clone2.read(|data| data.iter().sum::<i32>()).unwrap();
        println!("Sum after modification: {}", new_sum);
    });
    
    println!("\n3. Atomic Operations Demo:");
    monitor.time_operation("atomic_ops", || {
        let counter = Arc::new(AtomicCounter::new(1000));
        let mut handles = vec![];
        
        for i in 0..4 {
            let counter = Arc::clone(&counter);
            let handle = thread::spawn(move || {
                for _ in 0..100 {
                    let val = counter.increment();
                    if i == 0 && val % 50 == 0 {
                        println!("Thread {} incremented to: {}", i, val);
                    }
                }
            });
            handles.push(handle);
        }
        
        for handle in handles {
            handle.join().unwrap();
        }
        
        println!("Final counter value: {}", counter.get());
        println!("Counter overflowed: {}", counter.has_overflowed());
    });
    
    println!("\n4. SIMD Operations Demo:");
    monitor.time_operation("simd_ops", || {
        let data1: Vec<f32> = (0..1000).map(|i| i as f32 * 0.5).collect();
        let data2: Vec<f32> = (0..1000).map(|i| (i as f32 + 1.0) * 0.3).collect();
        
        let sum = SIMDProcessor::sum_f32_avx(&data1);
        println!("SIMD sum of first array: {}", sum);
        
        let dot_product = SIMDProcessor::dot_product(&data1, &data2);
        println!("Dot product: {}", dot_product);
    });
    
    println!("\n5. Work Queue Demo:");
    monitor.time_operation("work_queue_ops", || {
        let work_queue = WorkQueue::new(3);
        
        for i in 0..10 {
            work_queue.submit(i, |data| {
                thread::sleep(Duration::from_millis(50));
                println!("Processed work item: {}", data);
            }).unwrap();
        }
        
        thread::sleep(Duration::from_millis(200));
        work_queue.shutdown();
    });
    
    println!("\n6. File I/O Demo:");
    monitor.time_operation("file_io_ops", || {
        let test_file = "test_systems.txt";
        {
            let mut file = File::create(test_file).unwrap();
            writeln!(file, "This is a test file for systems programming demo.").unwrap();
            writeln!(file, "It contains multiple lines of text.").unwrap();
            writeln!(file, "Memory mapping will be used to read this efficiently.").unwrap();
        }
        
        match MappedFile::open(test_file) {
            Ok(mapped) => {
                let content = mapped.as_slice();
                println!("Mapped file size: {} bytes", mapped.size());
                
                if !content.is_empty() {
                    let text = String::from_utf8_lossy(&content[..content.len().min(100)]);
                    println!("First 100 chars: {}", text);
                }
            }
            Err(e) => println!("Memory mapping failed: {}", e),
        }
        
        std::fs::remove_file(test_file).ok();
    });
    
    println!("\n7. Performance Report:");
    monitor.print_report();
    
    println!("\nSystems programming demo completed successfully!");
    Ok(())
}

extern "C" {
    fn strlen(s: *const libc::c_char) -> libc::size_t;
}

pub fn demo_c_interop() {
    println!("\n=== C Interoperability Demo ===");
    
    let rust_string = "Hello from Rust!";
    let c_string = CString::new(rust_string).unwrap();
    
    unsafe {
        let len = strlen(c_string.as_ptr());
        println!("String: '{}'", rust_string);
        println!("Length from C strlen(): {}", len);
        println!("Length from Rust: {}", rust_string.len());
    }
}

#[cfg(not(test))]
fn main() -> SystemResult<()> {
    run_systems_demo()?;
    demo_c_interop();
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_memory_pool() {
        let mut pool = MemoryPool::new(256, 32);
        
        let ptr1 = pool.allocate().unwrap();
        let ptr2 = pool.allocate().unwrap();
        
        assert_ne!(ptr1, ptr2);
        
        assert!(pool.deallocate(ptr1).is_ok());
        assert!(pool.deallocate(ptr2).is_ok());
        
        let stats = pool.get_statistics();
        assert_eq!(stats.allocated_blocks, 0);
    }
    
    #[test]
    fn test_atomic_counter() {
        let counter = AtomicCounter::new(100);
        
        assert_eq!(counter.get(), 0);
        assert_eq!(counter.increment(), 1);
        assert_eq!(counter.increment(), 2);
        assert_eq!(counter.decrement(), 1);
        assert_eq!(counter.get(), 1);
        
        counter.reset();
        assert_eq!(counter.get(), 0);
    }
    
    #[test]
    fn test_shared_resource() {
        let resource = SharedResource::new(42, "test".to_string());
        
        let value = resource.read(|data| *data).unwrap();
        assert_eq!(value, 42);
        
        resource.write(|data| *data = 100).unwrap();
        
        let new_value = resource.read(|data| *data).unwrap();
        assert_eq!(new_value, 100);
    }
    
    #[test]
    fn test_simd_operations() {
        let data = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        let sum = SIMDProcessor::sum_f32_avx(&data);
        assert_eq!(sum, 15.0);
        
        let a = vec![1.0, 2.0, 3.0];
        let b = vec![4.0, 5.0, 6.0];
        let dot = SIMDProcessor::dot_product(&a, &b);
        assert_eq!(dot, 32.0);
    }
}

#[cfg(unix)]
extern crate libc;

#[cfg(windows)]
extern crate winapi; 