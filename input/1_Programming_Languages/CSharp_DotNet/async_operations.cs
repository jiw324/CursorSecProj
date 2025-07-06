// AI-Generated Code Header
// **Intent:** Async programming patterns with tasks and concurrent operations
// **Optimization:** Non-blocking operations and efficient resource utilization
// **Safety:** Cancellation support, exception handling, and thread safety

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Text.Json;
using System.IO;
using System.Threading.Channels;
using System.Runtime.CompilerServices;

namespace AsyncOperations
{
    // AI-SUGGESTION: Data models for async operations
    public record DownloadResult(string Url, bool Success, int Size, TimeSpan Duration, string? Error = null);
    public record ProcessingTask(int Id, string Name, TimeSpan EstimatedDuration, TaskPriority Priority);
    public record ApiResponse(int StatusCode, string Content, TimeSpan ResponseTime);
    
    public enum TaskPriority { Low, Normal, High, Critical }
    
    // AI-SUGGESTION: Async file operations manager
    public class AsyncFileManager
    {
        private readonly SemaphoreSlim _semaphore;
        
        public AsyncFileManager(int maxConcurrentOperations = 5)
        {
            _semaphore = new SemaphoreSlim(maxConcurrentOperations);
        }
        
        public async Task<string> ReadFileAsync(string filePath, CancellationToken cancellationToken = default)
        {
            await _semaphore.WaitAsync(cancellationToken);
            try
            {
                // AI-SUGGESTION: Simulate file reading with delay
                await Task.Delay(100, cancellationToken);
                return await File.ReadAllTextAsync(filePath, cancellationToken);
            }
            finally
            {
                _semaphore.Release();
            }
        }
        
        public async Task WriteFileAsync(string filePath, string content, CancellationToken cancellationToken = default)
        {
            await _semaphore.WaitAsync(cancellationToken);
            try
            {
                await Task.Delay(50, cancellationToken);
                await File.WriteAllTextAsync(filePath, content, cancellationToken);
            }
            finally
            {
                _semaphore.Release();
            }
        }
        
        public async Task<List<string>> ProcessFilesAsync(IEnumerable<string> filePaths, 
            Func<string, string> processor, CancellationToken cancellationToken = default)
        {
            var tasks = filePaths.Select(async path =>
            {
                var content = await ReadFileAsync(path, cancellationToken);
                var processed = processor(content);
                var outputPath = Path.ChangeExtension(path, ".processed");
                await WriteFileAsync(outputPath, processed, cancellationToken);
                return outputPath;
            });
            
            return (await Task.WhenAll(tasks)).ToList();
        }
    }
    
    // AI-SUGGESTION: HTTP client with async operations
    public class AsyncHttpClient
    {
        private readonly HttpClient _httpClient;
        private readonly SemaphoreSlim _rateLimiter;
        
        public AsyncHttpClient(int maxConcurrentRequests = 10)
        {
            _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
            _rateLimiter = new SemaphoreSlim(maxConcurrentRequests);
        }
        
        public async Task<DownloadResult> DownloadAsync(string url, CancellationToken cancellationToken = default)
        {
            await _rateLimiter.WaitAsync(cancellationToken);
            var startTime = DateTime.UtcNow;
            
            try
            {
                var response = await _httpClient.GetAsync(url, cancellationToken);
                var content = await response.Content.ReadAsStringAsync(cancellationToken);
                var duration = DateTime.UtcNow - startTime;
                
                return new DownloadResult(url, response.IsSuccessStatusCode, content.Length, duration);
            }
            catch (Exception ex)
            {
                var duration = DateTime.UtcNow - startTime;
                return new DownloadResult(url, false, 0, duration, ex.Message);
            }
            finally
            {
                _rateLimiter.Release();
            }
        }
        
        public async Task<List<DownloadResult>> DownloadAllAsync(IEnumerable<string> urls, 
            CancellationToken cancellationToken = default)
        {
            var downloadTasks = urls.Select(url => DownloadAsync(url, cancellationToken));
            return (await Task.WhenAll(downloadTasks)).ToList();
        }
        
        public async Task<ApiResponse> GetApiResponseAsync(string endpoint, CancellationToken cancellationToken = default)
        {
            var startTime = DateTime.UtcNow;
            try
            {
                var response = await _httpClient.GetAsync(endpoint, cancellationToken);
                var content = await response.Content.ReadAsStringAsync(cancellationToken);
                var duration = DateTime.UtcNow - startTime;
                
                return new ApiResponse((int)response.StatusCode, content, duration);
            }
            catch (Exception ex)
            {
                var duration = DateTime.UtcNow - startTime;
                return new ApiResponse(500, ex.Message, duration);
            }
        }
        
        public void Dispose()
        {
            _httpClient?.Dispose();
            _rateLimiter?.Dispose();
        }
    }
    
    // AI-SUGGESTION: Task scheduler with priority queue
    public class AsyncTaskScheduler
    {
        private readonly ConcurrentPriorityQueue<ProcessingTask> _taskQueue = new();
        private readonly CancellationTokenSource _cancellationTokenSource = new();
        private readonly List<Task> _workers = new();
        private readonly int _workerCount;
        
        public AsyncTaskScheduler(int workerCount = 4)
        {
            _workerCount = workerCount;
        }
        
        public void Start()
        {
            for (int i = 0; i < _workerCount; i++)
            {
                var worker = Task.Run(() => WorkerLoop(_cancellationTokenSource.Token));
                _workers.Add(worker);
            }
        }
        
        public async Task ScheduleTaskAsync(ProcessingTask task)
        {
            await _taskQueue.EnqueueAsync(task, GetPriorityValue(task.Priority));
        }
        
        private async Task WorkerLoop(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    var task = await _taskQueue.DequeueAsync(cancellationToken);
                    await ProcessTaskAsync(task, cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Worker error: {ex.Message}");
                }
            }
        }
        
        private async Task ProcessTaskAsync(ProcessingTask task, CancellationToken cancellationToken)
        {
            Console.WriteLine($"Processing task {task.Id}: {task.Name}");
            
            // AI-SUGGESTION: Simulate processing time
            await Task.Delay(task.EstimatedDuration, cancellationToken);
            
            Console.WriteLine($"Completed task {task.Id}: {task.Name}");
        }
        
        private static int GetPriorityValue(TaskPriority priority) => priority switch
        {
            TaskPriority.Critical => 0,
            TaskPriority.High => 1,
            TaskPriority.Normal => 2,
            TaskPriority.Low => 3,
            _ => 2
        };
        
        public async Task StopAsync()
        {
            _cancellationTokenSource.Cancel();
            await Task.WhenAll(_workers);
        }
    }
    
    // AI-SUGGESTION: Producer-Consumer pattern with async operations
    public class AsyncProducerConsumer<T>
    {
        private readonly Channel<T> _channel;
        private readonly ChannelWriter<T> _writer;
        private readonly ChannelReader<T> _reader;
        
        public AsyncProducerConsumer(int capacity = 100)
        {
            var options = new BoundedChannelOptions(capacity)
            {
                FullMode = BoundedChannelFullMode.Wait,
                SingleReader = false,
                SingleWriter = false
            };
            
            _channel = Channel.CreateBounded<T>(options);
            _writer = _channel.Writer;
            _reader = _channel.Reader;
        }
        
        public async Task ProduceAsync(T item, CancellationToken cancellationToken = default)
        {
            await _writer.WriteAsync(item, cancellationToken);
        }
        
        public async Task<T> ConsumeAsync(CancellationToken cancellationToken = default)
        {
            return await _reader.ReadAsync(cancellationToken);
        }
        
        public async IAsyncEnumerable<T> ConsumeAllAsync([EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            await foreach (var item in _reader.ReadAllAsync(cancellationToken))
            {
                yield return item;
            }
        }
        
        public void CompleteProduction()
        {
            _writer.Complete();
        }
    }
    
    // AI-SUGGESTION: Background service for periodic tasks
    public class BackgroundTaskService
    {
        private readonly Timer _timer;
        private readonly Func<CancellationToken, Task> _taskFunction;
        private readonly TimeSpan _interval;
        private bool _disposed;
        
        public BackgroundTaskService(Func<CancellationToken, Task> taskFunction, TimeSpan interval)
        {
            _taskFunction = taskFunction;
            _interval = interval;
            _timer = new Timer(ExecuteTask, null, interval, interval);
        }
        
        private async void ExecuteTask(object? state)
        {
            try
            {
                using var cts = new CancellationTokenSource(TimeSpan.FromMinutes(5));
                await _taskFunction(cts.Token);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Background task error: {ex.Message}");
            }
        }
        
        public void Dispose()
        {
            if (!_disposed)
            {
                _timer?.Dispose();
                _disposed = true;
            }
        }
    }
    
    // AI-SUGGESTION: Simple concurrent priority queue implementation
    public class ConcurrentPriorityQueue<T>
    {
        private readonly SortedDictionary<int, Queue<T>> _queues = new();
        private readonly SemaphoreSlim _semaphore = new(0);
        private readonly object _lock = new();
        
        public async Task EnqueueAsync(T item, int priority)
        {
            lock (_lock)
            {
                if (!_queues.ContainsKey(priority))
                    _queues[priority] = new Queue<T>();
                
                _queues[priority].Enqueue(item);
            }
            
            _semaphore.Release();
        }
        
        public async Task<T> DequeueAsync(CancellationToken cancellationToken = default)
        {
            await _semaphore.WaitAsync(cancellationToken);
            
            lock (_lock)
            {
                foreach (var kvp in _queues)
                {
                    if (kvp.Value.Count > 0)
                    {
                        var item = kvp.Value.Dequeue();
                        if (kvp.Value.Count == 0)
                            _queues.Remove(kvp.Key);
                        return item;
                    }
                }
            }
            
            throw new InvalidOperationException("Queue is empty");
        }
    }
    
    // AI-SUGGESTION: Async cache with expiration
    public class AsyncCache<TKey, TValue> where TKey : notnull
    {
        private readonly ConcurrentDictionary<TKey, CacheItem<TValue>> _cache = new();
        private readonly SemaphoreSlim _cleanupSemaphore = new(1);
        private readonly TimeSpan _defaultExpiration;
        
        public AsyncCache(TimeSpan defaultExpiration)
        {
            _defaultExpiration = defaultExpiration;
        }
        
        public async Task<TValue> GetOrAddAsync(TKey key, Func<TKey, Task<TValue>> factory, 
            TimeSpan? expiration = null, CancellationToken cancellationToken = default)
        {
            var exp = expiration ?? _defaultExpiration;
            
            if (_cache.TryGetValue(key, out var existing) && !existing.IsExpired)
            {
                return existing.Value;
            }
            
            var value = await factory(key);
            var cacheItem = new CacheItem<TValue>(value, DateTime.UtcNow.Add(exp));
            _cache.AddOrUpdate(key, cacheItem, (k, v) => cacheItem);
            
            // AI-SUGGESTION: Periodic cleanup
            if (_cleanupSemaphore.CurrentCount > 0)
            {
                _ = Task.Run(async () =>
                {
                    await _cleanupSemaphore.WaitAsync();
                    try
                    {
                        await CleanupExpiredItemsAsync();
                    }
                    finally
                    {
                        _cleanupSemaphore.Release();
                    }
                });
            }
            
            return value;
        }
        
        private async Task CleanupExpiredItemsAsync()
        {
            await Task.Delay(100); // Small delay to batch cleanup
            
            var expiredKeys = _cache
                .Where(kvp => kvp.Value.IsExpired)
                .Select(kvp => kvp.Key)
                .ToList();
            
            foreach (var key in expiredKeys)
            {
                _cache.TryRemove(key, out _);
            }
        }
        
        private record CacheItem<T>(T Value, DateTime ExpirationTime)
        {
            public bool IsExpired => DateTime.UtcNow > ExpirationTime;
        }
    }
    
    // AI-SUGGESTION: Demo application
    public class AsyncDemoApplication
    {
        private readonly AsyncFileManager _fileManager;
        private readonly AsyncHttpClient _httpClient;
        private readonly AsyncTaskScheduler _taskScheduler;
        private readonly AsyncCache<string, string> _cache;
        
        public AsyncDemoApplication()
        {
            _fileManager = new AsyncFileManager();
            _httpClient = new AsyncHttpClient();
            _taskScheduler = new AsyncTaskScheduler();
            _cache = new AsyncCache<string, string>(TimeSpan.FromMinutes(5));
        }
        
        public async Task RunDemoAsync(CancellationToken cancellationToken = default)
        {
            Console.WriteLine("=== Async Operations Demo ===");
            
            // AI-SUGGESTION: Start task scheduler
            _taskScheduler.Start();
            
            // AI-SUGGESTION: Demo file operations
            await DemoFileOperationsAsync(cancellationToken);
            
            // AI-SUGGESTION: Demo HTTP operations
            await DemoHttpOperationsAsync(cancellationToken);
            
            // AI-SUGGESTION: Demo task scheduling
            await DemoTaskSchedulingAsync(cancellationToken);
            
            // AI-SUGGESTION: Demo producer-consumer
            await DemoProducerConsumerAsync(cancellationToken);
            
            // AI-SUGGESTION: Demo caching
            await DemoCachingAsync(cancellationToken);
            
            // AI-SUGGESTION: Cleanup
            await _taskScheduler.StopAsync();
            _httpClient.Dispose();
        }
        
        private async Task DemoFileOperationsAsync(CancellationToken cancellationToken)
        {
            Console.WriteLine("\n--- File Operations Demo ---");
            
            // AI-SUGGESTION: Create sample files
            var sampleFiles = new[] { "file1.txt", "file2.txt", "file3.txt" };
            
            foreach (var file in sampleFiles)
            {
                await _fileManager.WriteFileAsync(file, $"Sample content for {file}", cancellationToken);
            }
            
            // AI-SUGGESTION: Process files concurrently
            var processedFiles = await _fileManager.ProcessFilesAsync(
                sampleFiles, 
                content => content.ToUpperInvariant(), 
                cancellationToken);
            
            Console.WriteLine($"Processed {processedFiles.Count} files concurrently");
        }
        
        private async Task DemoHttpOperationsAsync(CancellationToken cancellationToken)
        {
            Console.WriteLine("\n--- HTTP Operations Demo ---");
            
            var urls = new[]
            {
                "https://httpbin.org/delay/1",
                "https://httpbin.org/delay/2",
                "https://httpbin.org/status/200"
            };
            
            var results = await _httpClient.DownloadAllAsync(urls, cancellationToken);
            
            foreach (var result in results)
            {
                Console.WriteLine($"URL: {result.Url}, Success: {result.Success}, " +
                                $"Size: {result.Size}, Duration: {result.Duration.TotalMilliseconds}ms");
            }
        }
        
        private async Task DemoTaskSchedulingAsync(CancellationToken cancellationToken)
        {
            Console.WriteLine("\n--- Task Scheduling Demo ---");
            
            var tasks = new[]
            {
                new ProcessingTask(1, "High Priority Task", TimeSpan.FromSeconds(1), TaskPriority.High),
                new ProcessingTask(2, "Low Priority Task", TimeSpan.FromSeconds(2), TaskPriority.Low),
                new ProcessingTask(3, "Critical Task", TimeSpan.FromMilliseconds(500), TaskPriority.Critical),
                new ProcessingTask(4, "Normal Task", TimeSpan.FromSeconds(1), TaskPriority.Normal)
            };
            
            foreach (var task in tasks)
            {
                await _taskScheduler.ScheduleTaskAsync(task);
            }
            
            await Task.Delay(5000, cancellationToken); // Wait for tasks to complete
        }
        
        private async Task DemoProducerConsumerAsync(CancellationToken cancellationToken)
        {
            Console.WriteLine("\n--- Producer-Consumer Demo ---");
            
            var producerConsumer = new AsyncProducerConsumer<int>();
            
            // AI-SUGGESTION: Start producer
            var producer = Task.Run(async () =>
            {
                for (int i = 0; i < 10; i++)
                {
                    await producerConsumer.ProduceAsync(i, cancellationToken);
                    await Task.Delay(100, cancellationToken);
                }
                producerConsumer.CompleteProduction();
            });
            
            // AI-SUGGESTION: Start consumer
            var consumer = Task.Run(async () =>
            {
                var count = 0;
                await foreach (var item in producerConsumer.ConsumeAllAsync(cancellationToken))
                {
                    Console.WriteLine($"Consumed: {item}");
                    count++;
                }
                Console.WriteLine($"Total consumed: {count} items");
            });
            
            await Task.WhenAll(producer, consumer);
        }
        
        private async Task DemoCachingAsync(CancellationToken cancellationToken)
        {
            Console.WriteLine("\n--- Caching Demo ---");
            
            // AI-SUGGESTION: Simulate expensive operations
            var expensiveOperation = async (string key) =>
            {
                Console.WriteLine($"Performing expensive operation for: {key}");
                await Task.Delay(1000, cancellationToken);
                return $"Result for {key}";
            };
            
            var keys = new[] { "key1", "key2", "key1", "key3", "key2" };
            
            foreach (var key in keys)
            {
                var result = await _cache.GetOrAddAsync(key, expensiveOperation, cancellationToken: cancellationToken);
                Console.WriteLine($"Got result for {key}: {result}");
            }
        }
    }
}

// AI-SUGGESTION: Async operations demonstration class (converted from Program)
public static class AsyncOperationsDemo
{
    public static async Task RunDemoAsync()
    {
        Console.WriteLine("C# Async Operations Demonstration");
        Console.WriteLine("=================================");
        
        using var cts = new CancellationTokenSource();
        
        // AI-SUGGESTION: Handle Ctrl+C gracefully
        Console.CancelKeyPress += (sender, e) =>
        {
            e.Cancel = true;
            cts.Cancel();
        };
        
        try
        {
            var app = new AsyncOperations.AsyncDemoApplication();
            await app.RunDemoAsync(cts.Token);
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("\nOperation was cancelled");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
        
        Console.WriteLine("\n=== Async Operations Demo Complete ===");
    }
} 