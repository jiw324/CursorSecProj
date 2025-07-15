#!/usr/bin/env python3

import asyncio
import concurrent.futures
import functools
import logging
import multiprocessing
import queue
import random
import threading
import time
from abc import ABC, abstractmethod
from contextlib import asynccontextmanager, contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any, Callable, Dict, List, Optional, TypeVar, Generic
import weakref

import aiofiles
import aiohttp

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - [%(thread)d] %(message)s'
)
logger = logging.getLogger(__name__)

T = TypeVar('T')

@asynccontextmanager
async def async_timer(name: str):
    start_time = time.time()
    logger.info(f"Starting {name}")
    try:
        yield
    finally:
        elapsed = time.time() - start_time
        logger.info(f"Completed {name} in {elapsed:.4f} seconds")

class AsyncRateLimiter:
    def __init__(self, rate: int, per: float):
        self.rate = rate
        self.per = per
        self.allowance = rate
        self.last_check = time.time()
        self._lock = asyncio.Lock()
    
    async def acquire(self):
        async with self._lock:
            current = time.time()
            time_passed = current - self.last_check
            self.last_check = current
            
            self.allowance += time_passed * (self.rate / self.per)
            if self.allowance > self.rate:
                self.allowance = self.rate
            
            if self.allowance < 1.0:
                sleep_time = (1.0 - self.allowance) * (self.per / self.rate)
                await asyncio.sleep(sleep_time)
                self.allowance = 0.0
            else:
                self.allowance -= 1.0

class AsyncTaskQueue(Generic[T]):
    def __init__(self, max_workers: int = 5, max_queue_size: int = 100):
        self.max_workers = max_workers
        self.queue = asyncio.Queue(maxsize=max_queue_size)
        self.workers: List[asyncio.Task] = []
        self.results: Dict[str, Any] = {}
        self.running = False
        self._task_counter = 0
    
    async def start_workers(self):
        self.running = True
        self.workers = [
            asyncio.create_task(self._worker(f"worker-{i}"))
            for i in range(self.max_workers)
        ]
        logger.info(f"Started {self.max_workers} workers")
    
    async def stop_workers(self):
        self.running = False
        
        for worker in self.workers:
            worker.cancel()
        
        await asyncio.gather(*self.workers, return_exceptions=True)
        logger.info("All workers stopped")
    
    async def submit_task(self, coro: Callable[..., T], *args, **kwargs) -> str:
        task_id = f"task-{self._task_counter}"
        self._task_counter += 1
        
        await self.queue.put({
            'id': task_id,
            'coro': coro,
            'args': args,
            'kwargs': kwargs
        })
        
        return task_id
    
    async def get_result(self, task_id: str, timeout: float = 10.0) -> T:
        deadline = time.time() + timeout
        
        while time.time() < deadline:
            if task_id in self.results:
                result = self.results.pop(task_id)
                if isinstance(result, Exception):
                    raise result
                return result
            
            await asyncio.sleep(0.1)
        
        raise TimeoutError(f"Task {task_id} did not complete within {timeout} seconds")
    
    async def _worker(self, worker_name: str):
        logger.info(f"{worker_name} started")
        
        while self.running:
            try:
                task = await asyncio.wait_for(self.queue.get(), timeout=1.0)
                
                logger.info(f"{worker_name} processing {task['id']}")
                
                try:
                    result = await task['coro'](*task['args'], **task['kwargs'])
                    self.results[task['id']] = result
                    logger.info(f"{worker_name} completed {task['id']}")
                    
                except Exception as e:
                    logger.error(f"{worker_name} error in {task['id']}: {e}")
                    self.results[task['id']] = e
                
                finally:
                    self.queue.task_done()
                    
            except asyncio.TimeoutError:
                continue
            
            except Exception as e:
                logger.error(f"{worker_name} unexpected error: {e}")
        
        logger.info(f"{worker_name} stopped")

class AsyncConnectionPool:
    def __init__(self, max_connections: int = 10, timeout: float = 30.0):
        self.max_connections = max_connections
        self.timeout = timeout
        self.pool = asyncio.Queue(maxsize=max_connections)
        self.created_connections = 0
        self._lock = asyncio.Lock()
    
    async def get_connection(self) -> aiohttp.ClientSession:
        try:
            session = self.pool.get_nowait()
            if not session.closed:
                return session
        except asyncio.QueueEmpty:
            pass
        
        async with self._lock:
            if self.created_connections < self.max_connections:
                timeout = aiohttp.ClientTimeout(total=self.timeout)
                session = aiohttp.ClientSession(timeout=timeout)
                self.created_connections += 1
                return session
        
        session = await self.pool.get()
        return session
    
    async def return_connection(self, session: aiohttp.ClientSession):
        if not session.closed:
            try:
                self.pool.put_nowait(session)
            except asyncio.QueueFull:
                await session.close()
    
    async def close_all(self):
        while not self.pool.empty():
            try:
                session = self.pool.get_nowait()
                await session.close()
            except asyncio.QueueEmpty:
                break

class AsyncProducerConsumer:
    def __init__(self, queue_size: int = 50):
        self.queue = asyncio.Queue(maxsize=queue_size)
        self.producers: List[asyncio.Task] = []
        self.consumers: List[asyncio.Task] = []
        self.running = False
        self.metrics = {
            'produced': 0,
            'consumed': 0,
            'errors': 0
        }
    
    async def start(self, num_producers: int = 2, num_consumers: int = 3):
        self.running = True
        
        self.producers = [
            asyncio.create_task(self._producer(f"producer-{i}"))
            for i in range(num_producers)
        ]
        
        self.consumers = [
            asyncio.create_task(self._consumer(f"consumer-{i}"))
            for i in range(num_consumers)
        ]
        
        logger.info(f"Started {num_producers} producers and {num_consumers} consumers")
    
    async def stop(self):
        self.running = False
        
        all_tasks = self.producers + self.consumers
        for task in all_tasks:
            task.cancel()
        
        await asyncio.gather(*all_tasks, return_exceptions=True)
        
        logger.info("Producer-consumer system stopped")
        logger.info(f"Metrics: {self.metrics}")
    
    async def _producer(self, name: str):
        logger.info(f"{name} started")
        
        while self.running:
            try:
                work_item = {
                    'id': f"{name}-{self.metrics['produced']}",
                    'data': random.randint(1, 100),
                    'timestamp': time.time()
                }
                
                await self.queue.put(work_item)
                self.metrics['produced'] += 1
                
                logger.debug(f"{name} produced {work_item['id']}")
                
                await asyncio.sleep(random.uniform(0.5, 2.0))
                
            except Exception as e:
                logger.error(f"{name} error: {e}")
                self.metrics['errors'] += 1
        
        logger.info(f"{name} stopped")
    
    async def _consumer(self, name: str):
        logger.info(f"{name} started")
        
        while self.running:
            try:
                work_item = await asyncio.wait_for(self.queue.get(), timeout=1.0)
                
                await self._process_item(work_item)
                
                self.metrics['consumed'] += 1
                logger.debug(f"{name} consumed {work_item['id']}")
                
                self.queue.task_done()
                
            except asyncio.TimeoutError:
                continue
            
            except Exception as e:
                logger.error(f"{name} error: {e}")
                self.metrics['errors'] += 1
        
        logger.info(f"{name} stopped")
    
    async def _process_item(self, item: Dict[str, Any]):
        processing_time = item['data'] / 100.0
        await asyncio.sleep(processing_time)

class ThreadSafeCounter:
    def __init__(self, initial_value: int = 0):
        self._value = initial_value
        self._lock = threading.Lock()
    
    def increment(self, amount: int = 1) -> int:
        with self._lock:
            self._value += amount
            return self._value
    
    def decrement(self, amount: int = 1) -> int:
        with self._lock:
            self._value -= amount
            return self._value
    
    @property
    def value(self) -> int:
        with self._lock:
            return self._value
    
    def reset(self) -> int:
        with self._lock:
            old_value = self._value
            self._value = 0
            return old_value

class AsyncFileProcessor:
    def __init__(self, max_concurrent_files: int = 5):
        self.semaphore = asyncio.Semaphore(max_concurrent_files)
        self.processed_count = 0
        self.error_count = 0
    
    async def process_files(self, file_paths: List[str]) -> Dict[str, Any]:
        async with async_timer(f"Processing {len(file_paths)} files"):
            tasks = [self._process_file(path) for path in file_paths]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            successes = sum(1 for r in results if not isinstance(r, Exception))
            errors = len(results) - successes
            
            return {
                'total_files': len(file_paths),
                'successful': successes,
                'errors': errors,
                'results': results
            }
    
    async def _process_file(self, file_path: str) -> Dict[str, Any]:
        async with self.semaphore:
            try:
                async with aiofiles.open(file_path, 'r') as file:
                    content = await file.read()
                    
                    await asyncio.sleep(0.1)
                    
                    word_count = len(content.split())
                    char_count = len(content)
                    
                    return {
                        'file_path': file_path,
                        'word_count': word_count,
                        'char_count': char_count,
                        'processed_at': datetime.now().isoformat()
                    }
                    
            except Exception as e:
                logger.error(f"Error processing {file_path}: {e}")
                raise

class MultiprocessingWorker:
    def __init__(self, max_workers: Optional[int] = None):
        self.max_workers = max_workers or multiprocessing.cpu_count()
    
    @staticmethod
    def cpu_intensive_task(data: List[int]) -> Dict[str, Any]:
        start_time = time.time()
        
        result = sum(x * x for x in data for _ in range(1000))
        
        return {
            'result': result,
            'data_size': len(data),
            'computation_time': time.time() - start_time,
            'process_id': multiprocessing.current_process().pid
        }
    
    async def process_data_chunks(self, data: List[int], chunk_size: int = 1000) -> List[Dict[str, Any]]:
        chunks = [data[i:i + chunk_size] for i in range(0, len(data), chunk_size)]
        
        loop = asyncio.get_event_loop()
        
        with concurrent.futures.ProcessPoolExecutor(max_workers=self.max_workers) as executor:
            futures = [
                loop.run_in_executor(executor, self.cpu_intensive_task, chunk)
                for chunk in chunks
            ]
            
            results = await asyncio.gather(*futures)
            
        logger.info(f"Processed {len(chunks)} chunks using {self.max_workers} processes")
        return results

class AsyncBatchProcessor:
    def __init__(self, batch_size: int = 10, max_retries: int = 3):
        self.batch_size = batch_size
        self.max_retries = max_retries
        self.retry_delay = 1.0
    
    async def process_items(self, items: List[Any], processor_func: Callable) -> Dict[str, Any]:
        batches = [items[i:i + self.batch_size] for i in range(0, len(items), self.batch_size)]
        
        successful_batches = 0
        failed_batches = 0
        all_results = []
        
        for i, batch in enumerate(batches):
            logger.info(f"Processing batch {i + 1}/{len(batches)}")
            
            for attempt in range(self.max_retries + 1):
                try:
                    batch_results = await self._process_batch(batch, processor_func)
                    all_results.extend(batch_results)
                    successful_batches += 1
                    break
                    
                except Exception as e:
                    if attempt < self.max_retries:
                        wait_time = self.retry_delay * (2 ** attempt)
                        logger.warning(f"Batch {i + 1} failed (attempt {attempt + 1}), retrying in {wait_time}s: {e}")
                        await asyncio.sleep(wait_time)
                    else:
                        logger.error(f"Batch {i + 1} failed after {self.max_retries + 1} attempts: {e}")
                        failed_batches += 1
        
        return {
            'total_batches': len(batches),
            'successful_batches': successful_batches,
            'failed_batches': failed_batches,
            'results': all_results
        }
    
    async def _process_batch(self, batch: List[Any], processor_func: Callable) -> List[Any]:
        tasks = [processor_func(item) for item in batch]
        results = await asyncio.gather(*tasks)
        return results

class AsyncEventEmitter:
    def __init__(self):
        self._listeners: Dict[str, List[Callable]] = {}
        self._max_listeners = 10
    
    def on(self, event: str, handler: Callable):
        if event not in self._listeners:
            self._listeners[event] = []
        
        if len(self._listeners[event]) >= self._max_listeners:
            logger.warning(f"Maximum listeners ({self._max_listeners}) reached for event '{event}'")
        
        self._listeners[event].append(handler)
    
    def off(self, event: str, handler: Callable):
        if event in self._listeners:
            try:
                self._listeners[event].remove(handler)
            except ValueError:
                pass
    
    async def emit(self, event: str, *args, **kwargs):
        if event not in self._listeners:
            return
        
        handlers = self._listeners[event].copy()
        tasks = []
        
        for handler in handlers:
            try:
                if asyncio.iscoroutinefunction(handler):
                    tasks.append(handler(*args, **kwargs))
                else:
                    loop = asyncio.get_event_loop()
                    task = loop.run_in_executor(None, functools.partial(handler, *args, **kwargs))
                    tasks.append(task)
            except Exception as e:
                logger.error(f"Error creating task for handler {handler}: {e}")
        
        if tasks:
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    logger.error(f"Event handler {handlers[i]} raised exception: {result}")

async def demonstrate_async_patterns():
    print("=== Async/Concurrency Patterns Demo ===")
    
    print("\n1. Testing Async Task Queue...")
    task_queue = AsyncTaskQueue(max_workers=3)
    await task_queue.start_workers()
    
    async def sample_task(n: int) -> int:
        await asyncio.sleep(0.5)
        return n * n
    
    task_ids = []
    for i in range(5):
        task_id = await task_queue.submit_task(sample_task, i)
        task_ids.append(task_id)
    
    for task_id in task_ids:
        result = await task_queue.get_result(task_id)
        print(f"Task {task_id} result: {result}")
    
    await task_queue.stop_workers()
    
    print("\n2. Testing Producer-Consumer Pattern...")
    pc_system = AsyncProducerConsumer(queue_size=20)
    await pc_system.start(num_producers=2, num_consumers=3)
    
    await asyncio.sleep(5)
    await pc_system.stop()
    
    print("\n3. Testing Async File Processing...")
    
    import tempfile
    import os
    
    temp_dir = tempfile.mkdtemp()
    file_paths = []
    
    for i in range(3):
        file_path = os.path.join(temp_dir, f"sample_{i}.txt")
        with open(file_path, 'w') as f:
            f.write(f"This is sample file {i} with some content for testing.\n" * 10)
        file_paths.append(file_path)
    
    file_processor = AsyncFileProcessor(max_concurrent_files=2)
    results = await file_processor.process_files(file_paths)
    
    print(f"File processing results: {results}")
    
    for file_path in file_paths:
        os.unlink(file_path)
    os.rmdir(temp_dir)
    
    print("\n4. Testing Multiprocessing for CPU-bound work...")
    mp_worker = MultiprocessingWorker(max_workers=2)
    
    sample_data = list(range(10000))
    
    results = await mp_worker.process_data_chunks(sample_data, chunk_size=2500)
    
    total_time = sum(r['computation_time'] for r in results)
    print(f"Processed {len(sample_data)} numbers in {total_time:.4f}s using multiprocessing")
    
    print("\n5. Testing Async Event System...")
    event_emitter = AsyncEventEmitter()
    
    async def async_handler(message: str):
        print(f"Async handler received: {message}")
        await asyncio.sleep(0.1)
    
    def sync_handler(message: str):
        print(f"Sync handler received: {message}")
    
    event_emitter.on('test_event', async_handler)
    event_emitter.on('test_event', sync_handler)
    
    await event_emitter.emit('test_event', "Hello from async event system!")
    
    print("\nAsync/concurrency patterns demonstration completed!")

async def benchmark_async_vs_sync():
    print("\n=== Async vs Sync Performance Benchmark ===")
    
    async def async_http_request(session: aiohttp.ClientSession, url: str) -> Dict[str, Any]:
        try:
            async with session.get(url) as response:
                return {
                    'url': url,
                    'status': response.status,
                    'size': len(await response.text())
                }
        except Exception as e:
            return {'url': url, 'error': str(e)}
    
    test_urls = [
        'https://httpbin.org/delay/1',
        'https://httpbin.org/delay/1',
        'https://httpbin.org/delay/1',
        'https://httpbin.org/delay/1',
        'https://httpbin.org/delay/1'
    ]
    
    start_time = time.time()
    async with aiohttp.ClientSession() as session:
        tasks = [async_http_request(session, url) for url in test_urls]
        async_results = await asyncio.gather(*tasks)
    
    async_time = time.time() - start_time
    
    print(f"Async version: {len(test_urls)} requests in {async_time:.2f} seconds")
    print(f"Average time per request: {async_time / len(test_urls):.2f} seconds")
    
    print(f"Sync version would take: ~{len(test_urls)} seconds (sequential)")
    print(f"Async speedup: ~{len(test_urls) / async_time:.2f}x faster")

if __name__ == "__main__":
    asyncio.run(demonstrate_async_patterns())
    asyncio.run(benchmark_async_vs_sync()) 