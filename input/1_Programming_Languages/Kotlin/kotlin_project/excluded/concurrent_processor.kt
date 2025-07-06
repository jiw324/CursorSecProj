// AI-Generated Code Header
// **Intent:** Demonstrate Kotlin coroutines, channels, and concurrent processing patterns
// **Optimization:** Efficient parallel processing with backpressure handling
// **Safety:** Structured concurrency, exception handling, and resource management

package com.example.concurrent

import kotlinx.coroutines.*
import kotlinx.coroutines.channels.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.time.Duration.Companion.seconds
import kotlin.time.measureTime

// AI-SUGGESTION: Data classes for processing pipeline
data class WorkItem(
    val id: String,
    val data: ByteArray,
    val priority: Priority = Priority.NORMAL,
    val createdAt: Long = System.currentTimeMillis()
) {
    enum class Priority(val value: Int) {
        LOW(1), NORMAL(2), HIGH(3), CRITICAL(4)
    }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as WorkItem
        return id == other.id && data.contentEquals(other.data) && priority == other.priority
    }
    
    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + data.contentHashCode()
        result = 31 * result + priority.hashCode()
        return result
    }
}

data class ProcessingResult(
    val workItemId: String,
    val success: Boolean,
    val result: String?,
    val error: Throwable? = null,
    val processingTimeMs: Long,
    val processedAt: Long = System.currentTimeMillis()
)

// AI-SUGGESTION: Thread-safe metrics collector
class ProcessingMetrics {
    private val processedCount = AtomicLong(0)
    private val failedCount = AtomicLong(0)
    private val totalProcessingTime = AtomicLong(0)
    private val mutex = Mutex()
    private val processingTimes = mutableListOf<Long>()
    
    suspend fun recordSuccess(processingTime: Long) {
        processedCount.incrementAndGet()
        totalProcessingTime.addAndGet(processingTime)
        
        mutex.withLock {
            processingTimes.add(processingTime)
            if (processingTimes.size > 1000) {
                processingTimes.removeAt(0)
            }
        }
    }
    
    suspend fun recordFailure() {
        failedCount.incrementAndGet()
    }
    
    suspend fun getStats(): ProcessingStats {
        mutex.withLock {
            val avgTime = if (processedCount.get() > 0) {
                totalProcessingTime.get() / processedCount.get()
            } else 0L
            
            val p95Time = if (processingTimes.isNotEmpty()) {
                processingTimes.sorted().let { sorted ->
                    sorted[(sorted.size * 0.95).toInt().coerceAtMost(sorted.size - 1)]
                }
            } else 0L
            
            return ProcessingStats(
                processed = processedCount.get(),
                failed = failedCount.get(),
                averageProcessingTime = avgTime,
                p95ProcessingTime = p95Time
            )
        }
    }
}

data class ProcessingStats(
    val processed: Long,
    val failed: Long,
    val averageProcessingTime: Long,
    val p95ProcessingTime: Long
) {
    val successRate: Double get() = if (processed + failed > 0) {
        processed.toDouble() / (processed + failed)
    } else 0.0
}

// AI-SUGGESTION: Worker interface for strategy pattern
interface WorkerStrategy {
    suspend fun process(item: WorkItem): ProcessingResult
}

// AI-SUGGESTION: Sample processing strategies
class HashingWorker : WorkerStrategy {
    override suspend fun process(item: WorkItem): ProcessingResult {
        return try {
            delay(kotlin.random.Random.nextLong(10, 100)) // Simulate work
            val hash = item.data.contentHashCode().toString()
            ProcessingResult(
                workItemId = item.id,
                success = true,
                result = "Hash: $hash",
                processingTimeMs = measureTime { 
                    // Actual processing would go here
                }.inWholeMilliseconds
            )
        } catch (e: Exception) {
            ProcessingResult(
                workItemId = item.id,
                success = false,
                result = null,
                error = e,
                processingTimeMs = 0
            )
        }
    }
}

class CompressionWorker : WorkerStrategy {
    override suspend fun process(item: WorkItem): ProcessingResult {
        return try {
            delay(kotlin.random.Random.nextLong(50, 200)) // Simulate compression work
            val compressionRatio = kotlin.random.Random.nextDouble(0.3, 0.8)
            ProcessingResult(
                workItemId = item.id,
                success = true,
                result = "Compressed to ${(compressionRatio * 100).toInt()}% of original size",
                processingTimeMs = measureTime { 
                    // Actual compression would go here
                }.inWholeMilliseconds
            )
        } catch (e: Exception) {
            ProcessingResult(
                workItemId = item.id,
                success = false,
                result = null,
                error = e,
                processingTimeMs = 0
            )
        }
    }
}

// AI-SUGGESTION: Concurrent processor with backpressure handling
class ConcurrentProcessor(
    private val workerStrategy: WorkerStrategy,
    private val maxWorkers: Int = 10,
    private val bufferSize: Int = 100
) {
    private val metrics = ProcessingMetrics()
    private val activeWorkers = AtomicInteger(0)
    
    // AI-SUGGESTION: Channels for producer-consumer pattern
    private val workChannel = Channel<WorkItem>(bufferSize)
    private val resultChannel = Channel<ProcessingResult>(bufferSize)
    
    private var processingScope: CoroutineScope? = null
    
    // AI-SUGGESTION: Priority queue implementation using channels
    fun startProcessing(): Pair<ReceiveChannel<ProcessingResult>, Job> {
        val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
        processingScope = scope
        
        // Start worker coroutines
        val workerJobs = (1..maxWorkers).map { workerId ->
            scope.launch {
                processWorkItems(workerId)
            }
        }
        
        // Combined job for lifecycle management
        val combinedJob = scope.launch {
            workerJobs.joinAll()
        }
        
        return resultChannel to combinedJob
    }
    
    private suspend fun processWorkItems(workerId: Int) {
        for (workItem in workChannel) {
            activeWorkers.incrementAndGet()
            try {
                val result = workerStrategy.process(workItem)
                
                if (result.success) {
                    metrics.recordSuccess(result.processingTimeMs)
                } else {
                    metrics.recordFailure()
                }
                
                resultChannel.send(result)
                
            } catch (e: Exception) {
                val errorResult = ProcessingResult(
                    workItemId = workItem.id,
                    success = false,
                    result = null,
                    error = e,
                    processingTimeMs = 0
                )
                metrics.recordFailure()
                resultChannel.send(errorResult)
            } finally {
                activeWorkers.decrementAndGet()
            }
        }
    }
    
    // AI-SUGGESTION: Suspend function for work submission
    suspend fun submitWork(item: WorkItem): Boolean {
        return try {
            workChannel.send(item)
            true
        } catch (e: ClosedSendChannelException) {
            false
        }
    }
    
    // AI-SUGGESTION: Batch submission for efficiency
    suspend fun submitBatch(items: List<WorkItem>): Int {
        var submitted = 0
        for (item in items) {
            if (submitWork(item)) {
                submitted++
            } else {
                break
            }
        }
        return submitted
    }
    
    suspend fun getMetrics(): ProcessingStats = metrics.getStats()
    
    fun getActiveWorkerCount(): Int = activeWorkers.get()
    
    // AI-SUGGESTION: Graceful shutdown with timeout
    suspend fun shutdown(timeoutSeconds: Long = 30) {
        workChannel.close()
        
        // Wait for all workers to complete with timeout
        withTimeoutOrNull(timeoutSeconds.seconds) {
            while (activeWorkers.get() > 0) {
                delay(100)
            }
        }
        
        resultChannel.close()
        processingScope?.cancel()
    }
}

// AI-SUGGESTION: Flow-based processing pipeline
class FlowBasedProcessor(
    private val workerStrategy: WorkerStrategy,
    private val concurrency: Int = 10
) {
    private val metrics = ProcessingMetrics()
    
    // AI-SUGGESTION: Transform Flow with parallel processing
    fun processFlow(workItems: Flow<WorkItem>): Flow<ProcessingResult> {
        return workItems
            .flatMapMerge(concurrency) { item ->
                flow {
                    try {
                        val result = workerStrategy.process(item)
                        
                        if (result.success) {
                            metrics.recordSuccess(result.processingTimeMs)
                        } else {
                            metrics.recordFailure()
                        }
                        
                        emit(result)
                    } catch (e: Exception) {
                        val errorResult = ProcessingResult(
                            workItemId = item.id,
                            success = false,
                            result = null,
                            error = e,
                            processingTimeMs = 0
                        )
                        metrics.recordFailure()
                        emit(errorResult)
                    }
                }
            }
            .flowOn(Dispatchers.Default)
    }
    
    suspend fun getMetrics(): ProcessingStats = metrics.getStats()
}

// AI-SUGGESTION: Actor pattern for stateful processing
sealed class ProcessorMessage
data class ProcessWork(val item: WorkItem, val response: CompletableDeferred<ProcessingResult>) : ProcessorMessage()
data class GetStats(val response: CompletableDeferred<ProcessingStats>) : ProcessorMessage()
object Shutdown : ProcessorMessage()

@OptIn(ObsoleteCoroutinesApi::class)
fun CoroutineScope.processorActor(workerStrategy: WorkerStrategy) = actor<ProcessorMessage> {
    val metrics = ProcessingMetrics()
    
    for (message in channel) {
        when (message) {
            is ProcessWork -> {
                try {
                    val result = workerStrategy.process(message.item)
                    if (result.success) {
                        metrics.recordSuccess(result.processingTimeMs)
                    } else {
                        metrics.recordFailure()
                    }
                    message.response.complete(result)
                } catch (e: Exception) {
                    val errorResult = ProcessingResult(
                        workItemId = message.item.id,
                        success = false,
                        result = null,
                        error = e,
                        processingTimeMs = 0
                    )
                    metrics.recordFailure()
                    message.response.complete(errorResult)
                }
            }
            is GetStats -> {
                message.response.complete(metrics.getStats())
            }
            is Shutdown -> {
                break
            }
        }
    }
}

// AI-SUGGESTION: Usage examples and demonstration
suspend fun main() {
    println("=== Kotlin Concurrent Processing Demo ===\n")
    
    // Demo 1: Channel-based processor
    println("1. Channel-based Processing:")
    val processor = ConcurrentProcessor(HashingWorker(), maxWorkers = 5)
    val (resultChannel, job) = processor.startProcessing()
    
    // Submit work items
    val workItems = (1..20).map { i ->
        WorkItem(
            id = "item-$i",
            data = "Sample data $i".toByteArray(),
            priority = WorkItem.Priority.values().random()
        )
    }
    
    // Process results
    launch {
        repeat(workItems.size) {
            val result = resultChannel.receive()
            println("Processed: ${result.workItemId}, Success: ${result.success}, Result: ${result.result}")
        }
    }
    
    // Submit work
    processor.submitBatch(workItems)
    delay(2000) // Wait for processing
    
    val stats = processor.getMetrics()
    println("Stats: Processed=${stats.processed}, Failed=${stats.failed}, Success Rate=${stats.successRate}")
    
    processor.shutdown()
    
    println("\n2. Flow-based Processing:")
    // Demo 2: Flow-based processor
    val flowProcessor = FlowBasedProcessor(CompressionWorker(), concurrency = 3)
    
    val itemFlow = flow {
        repeat(15) { i ->
            emit(WorkItem(
                id = "flow-item-$i",
                data = "Flow data $i".toByteArray()
            ))
            delay(50) // Simulate arriving data
        }
    }
    
    flowProcessor.processFlow(itemFlow)
        .collect { result ->
            println("Flow processed: ${result.workItemId}, Success: ${result.success}")
        }
    
    val flowStats = flowProcessor.getMetrics()
    println("Flow Stats: Processed=${flowStats.processed}, Avg Time=${flowStats.averageProcessingTime}ms")
    
    println("\n3. Actor-based Processing:")
    // Demo 3: Actor pattern
    val actor = processorActor(HashingWorker())
    
    // Process items using actor
    val actorResults = (1..10).map { i ->
        val response = CompletableDeferred<ProcessingResult>()
        actor.send(ProcessWork(
            WorkItem("actor-item-$i", "Actor data $i".toByteArray()),
            response
        ))
        response
    }
    
    // Collect results
    actorResults.forEach { deferred ->
        val result = deferred.await()
        println("Actor processed: ${result.workItemId}, Success: ${result.success}")
    }
    
    // Get final stats
    val statsResponse = CompletableDeferred<ProcessingStats>()
    actor.send(GetStats(statsResponse))
    val actorStats = statsResponse.await()
    println("Actor Stats: Processed=${actorStats.processed}, P95 Time=${actorStats.p95ProcessingTime}ms")
    
    actor.send(Shutdown)
    actor.close()
} 