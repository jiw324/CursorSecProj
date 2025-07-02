// AI-Generated Code Header
// **Intent:** Concurrent data processing with multithreading, futures, and parallel streams
// **Optimization:** Efficient parallel processing and thread pool management
// **Safety:** Thread safety, deadlock prevention, and proper resource cleanup

package com.concurrent.processor;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

// AI-SUGGESTION: Data models for processing
class DataRecord {
    private final Long id;
    private final String data;
    private final LocalDateTime timestamp;
    private final DataType type;
    private volatile ProcessingStatus status;

    public enum DataType {
        TEXT, NUMERIC, JSON, XML, CSV
    }

    public enum ProcessingStatus {
        PENDING, PROCESSING, COMPLETED, FAILED
    }

    public DataRecord(Long id, String data, DataType type) {
        this.id = id;
        this.data = data;
        this.type = type;
        this.timestamp = LocalDateTime.now();
        this.status = ProcessingStatus.PENDING;
    }

    // AI-SUGGESTION: Thread-safe getters and setters
    public Long getId() { return id; }
    public String getData() { return data; }
    public LocalDateTime getTimestamp() { return timestamp; }
    public DataType getType() { return type; }
    
    public ProcessingStatus getStatus() { return status; }
    public void setStatus(ProcessingStatus status) { this.status = status; }

    @Override
    public String toString() {
        return String.format("DataRecord{id=%d, type=%s, status=%s, timestamp=%s}", 
            id, type, status, timestamp);
    }
}

class ProcessingResult {
    private final Long recordId;
    private final String processedData;
    private final Duration processingTime;
    private final boolean successful;
    private final String errorMessage;
    private final String processorName;

    public ProcessingResult(Long recordId, String processedData, Duration processingTime, 
                          boolean successful, String errorMessage, String processorName) {
        this.recordId = recordId;
        this.processedData = processedData;
        this.processingTime = processingTime;
        this.successful = successful;
        this.errorMessage = errorMessage;
        this.processorName = processorName;
    }

    public Long getRecordId() { return recordId; }
    public String getProcessedData() { return processedData; }
    public Duration getProcessingTime() { return processingTime; }
    public boolean isSuccessful() { return successful; }
    public String getErrorMessage() { return errorMessage; }
    public String getProcessorName() { return processorName; }

    @Override
    public String toString() {
        return String.format("ProcessingResult{recordId=%d, successful=%s, time=%dms, processor=%s}", 
            recordId, successful, processingTime.toMillis(), processorName);
    }
}

// AI-SUGGESTION: Processor interface and implementations
interface DataProcessor {
    ProcessingResult process(DataRecord record);
    String getName();
    boolean canProcess(DataRecord.DataType type);
}

class TextProcessor implements DataProcessor {
    @Override
    public ProcessingResult process(DataRecord record) {
        long start = System.nanoTime();
        
        try {
            // AI-SUGGESTION: Simulate text processing
            Thread.sleep(ThreadLocalRandom.current().nextInt(100, 300));
            
            String processedData = record.getData().toUpperCase().trim();
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            
            return new ProcessingResult(record.getId(), processedData, duration, 
                                      true, null, getName());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            return new ProcessingResult(record.getId(), null, duration, 
                                      false, "Processing interrupted", getName());
        } catch (Exception e) {
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            return new ProcessingResult(record.getId(), null, duration, 
                                      false, e.getMessage(), getName());
        }
    }

    @Override
    public String getName() { return "TextProcessor"; }

    @Override
    public boolean canProcess(DataRecord.DataType type) {
        return type == DataRecord.DataType.TEXT;
    }
}

class NumericProcessor implements DataProcessor {
    @Override
    public ProcessingResult process(DataRecord record) {
        long start = System.nanoTime();
        
        try {
            Thread.sleep(ThreadLocalRandom.current().nextInt(50, 200));
            
            // AI-SUGGESTION: Extract numbers and calculate sum
            String[] parts = record.getData().split("[^0-9.]+");
            double sum = Arrays.stream(parts)
                .filter(s -> !s.isEmpty())
                .mapToDouble(s -> {
                    try { return Double.parseDouble(s); }
                    catch (NumberFormatException e) { return 0.0; }
                })
                .sum();
            
            String processedData = String.format("Sum: %.2f", sum);
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            
            return new ProcessingResult(record.getId(), processedData, duration, 
                                      true, null, getName());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            return new ProcessingResult(record.getId(), null, duration, 
                                      false, "Processing interrupted", getName());
        } catch (Exception e) {
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            return new ProcessingResult(record.getId(), null, duration, 
                                      false, e.getMessage(), getName());
        }
    }

    @Override
    public String getName() { return "NumericProcessor"; }

    @Override
    public boolean canProcess(DataRecord.DataType type) {
        return type == DataRecord.DataType.NUMERIC;
    }
}

class JSONProcessor implements DataProcessor {
    @Override
    public ProcessingResult process(DataRecord record) {
        long start = System.nanoTime();
        
        try {
            Thread.sleep(ThreadLocalRandom.current().nextInt(200, 500));
            
            // AI-SUGGESTION: Simple JSON processing simulation
            String data = record.getData();
            int objectCount = data.split("\\{").length - 1;
            int arrayCount = data.split("\\[").length - 1;
            
            String processedData = String.format("Objects: %d, Arrays: %d", objectCount, arrayCount);
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            
            return new ProcessingResult(record.getId(), processedData, duration, 
                                      true, null, getName());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            return new ProcessingResult(record.getId(), null, duration, 
                                      false, "Processing interrupted", getName());
        } catch (Exception e) {
            Duration duration = Duration.ofNanos(System.nanoTime() - start);
            return new ProcessingResult(record.getId(), null, duration, 
                                      false, e.getMessage(), getName());
        }
    }

    @Override
    public String getName() { return "JSONProcessor"; }

    @Override
    public boolean canProcess(DataRecord.DataType type) {
        return type == DataRecord.DataType.JSON;
    }
}

// AI-SUGGESTION: Concurrent processing engine
class ConcurrentProcessingEngine {
    private final ExecutorService executorService;
    private final Map<DataRecord.DataType, DataProcessor> processors;
    private final BlockingQueue<DataRecord> inputQueue;
    private final BlockingQueue<ProcessingResult> resultQueue;
    private final AtomicInteger processedCount;
    private final AtomicInteger failedCount;
    private final AtomicLong totalProcessingTime;
    private volatile boolean running;

    public ConcurrentProcessingEngine(int threadPoolSize) {
        this.executorService = Executors.newFixedThreadPool(threadPoolSize);
        this.processors = new ConcurrentHashMap<>();
        this.inputQueue = new LinkedBlockingQueue<>();
        this.resultQueue = new LinkedBlockingQueue<>();
        this.processedCount = new AtomicInteger(0);
        this.failedCount = new AtomicInteger(0);
        this.totalProcessingTime = new AtomicLong(0);
        this.running = false;
        
        // AI-SUGGESTION: Register processors
        registerProcessor(new TextProcessor());
        registerProcessor(new NumericProcessor());
        registerProcessor(new JSONProcessor());
    }

    public void registerProcessor(DataProcessor processor) {
        for (DataRecord.DataType type : DataRecord.DataType.values()) {
            if (processor.canProcess(type)) {
                processors.put(type, processor);
            }
        }
    }

    public void start() {
        if (running) {
            throw new IllegalStateException("Engine is already running");
        }
        
        running = true;
        System.out.println("Starting concurrent processing engine...");
        
        // AI-SUGGESTION: Start worker threads
        for (int i = 0; i < Runtime.getRuntime().availableProcessors(); i++) {
            executorService.submit(this::processRecords);
        }
        
        // AI-SUGGESTION: Start result collector
        executorService.submit(this::collectResults);
    }

    private void processRecords() {
        while (running || !inputQueue.isEmpty()) {
            try {
                DataRecord record = inputQueue.poll(1, TimeUnit.SECONDS);
                if (record != null) {
                    processRecord(record);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    private void processRecord(DataRecord record) {
        record.setStatus(DataRecord.ProcessingStatus.PROCESSING);
        
        DataProcessor processor = processors.get(record.getType());
        if (processor == null) {
            ProcessingResult failedResult = new ProcessingResult(
                record.getId(), null, Duration.ZERO, false, 
                "No processor found for type: " + record.getType(), "Unknown");
            resultQueue.offer(failedResult);
            record.setStatus(DataRecord.ProcessingStatus.FAILED);
            return;
        }

        try {
            ProcessingResult result = processor.process(record);
            resultQueue.offer(result);
            
            if (result.isSuccessful()) {
                record.setStatus(DataRecord.ProcessingStatus.COMPLETED);
            } else {
                record.setStatus(DataRecord.ProcessingStatus.FAILED);
            }
        } catch (Exception e) {
            ProcessingResult errorResult = new ProcessingResult(
                record.getId(), null, Duration.ZERO, false, 
                "Unexpected error: " + e.getMessage(), processor.getName());
            resultQueue.offer(errorResult);
            record.setStatus(DataRecord.ProcessingStatus.FAILED);
        }
    }

    private void collectResults() {
        while (running || !resultQueue.isEmpty()) {
            try {
                ProcessingResult result = resultQueue.poll(1, TimeUnit.SECONDS);
                if (result != null) {
                    handleResult(result);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    private void handleResult(ProcessingResult result) {
        if (result.isSuccessful()) {
            processedCount.incrementAndGet();
        } else {
            failedCount.incrementAndGet();
            System.err.println("Processing failed: " + result.getErrorMessage());
        }
        
        totalProcessingTime.addAndGet(result.getProcessingTime().toNanos());
    }

    public void submitRecord(DataRecord record) {
        if (!running) {
            throw new IllegalStateException("Engine is not running");
        }
        
        inputQueue.offer(record);
    }

    public void submitRecords(Collection<DataRecord> records) {
        records.forEach(this::submitRecord);
    }

    public CompletableFuture<List<ProcessingResult>> processRecordsAsync(List<DataRecord> records) {
        List<CompletableFuture<ProcessingResult>> futures = records.stream()
            .map(record -> CompletableFuture.supplyAsync(() -> {
                DataProcessor processor = processors.get(record.getType());
                if (processor != null) {
                    return processor.process(record);
                } else {
                    return new ProcessingResult(record.getId(), null, Duration.ZERO, 
                                              false, "No processor available", "None");
                }
            }, executorService))
            .collect(Collectors.toList());

        return CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]))
            .thenApply(v -> futures.stream()
                .map(CompletableFuture::join)
                .collect(Collectors.toList()));
    }

    public void stop() {
        System.out.println("Stopping processing engine...");
        running = false;
        
        try {
            if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
                executorService.shutdownNow();
            }
        } catch (InterruptedException e) {
            executorService.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }

    public ProcessingStatistics getStatistics() {
        return new ProcessingStatistics(
            processedCount.get(),
            failedCount.get(),
            totalProcessingTime.get(),
            inputQueue.size(),
            resultQueue.size()
        );
    }
}

// AI-SUGGESTION: Statistics and metrics
class ProcessingStatistics {
    private final int processedCount;
    private final int failedCount;
    private final long totalProcessingTimeNanos;
    private final int queuedRecords;
    private final int pendingResults;

    public ProcessingStatistics(int processedCount, int failedCount, 
                              long totalProcessingTimeNanos, int queuedRecords, int pendingResults) {
        this.processedCount = processedCount;
        this.failedCount = failedCount;
        this.totalProcessingTimeNanos = totalProcessingTimeNanos;
        this.queuedRecords = queuedRecords;
        this.pendingResults = pendingResults;
    }

    public int getProcessedCount() { return processedCount; }
    public int getFailedCount() { return failedCount; }
    public int getTotalCount() { return processedCount + failedCount; }
    public double getSuccessRate() { 
        return getTotalCount() > 0 ? (double) processedCount / getTotalCount() * 100 : 0;
    }
    
    public Duration getAverageProcessingTime() {
        return processedCount > 0 ? 
            Duration.ofNanos(totalProcessingTimeNanos / processedCount) : 
            Duration.ZERO;
    }
    
    public int getQueuedRecords() { return queuedRecords; }
    public int getPendingResults() { return pendingResults; }

    @Override
    public String toString() {
        return String.format(
            "ProcessingStatistics{processed=%d, failed=%d, successRate=%.1f%%, avgTime=%dms, queued=%d, pending=%d}",
            processedCount, failedCount, getSuccessRate(), 
            getAverageProcessingTime().toMillis(), queuedRecords, pendingResults);
    }
}

// AI-SUGGESTION: Main application class
public class ConcurrentDataProcessor {
    private static final int THREAD_POOL_SIZE = Runtime.getRuntime().availableProcessors();
    private static final int RECORD_COUNT = 1000;

    public static void main(String[] args) {
        System.out.println("Concurrent Data Processor Demo");
        System.out.println("==============================");

        ConcurrentProcessingEngine engine = new ConcurrentProcessingEngine(THREAD_POOL_SIZE);
        
        try {
            // AI-SUGGESTION: Generate test data
            System.out.println("\n--- Generating Test Data ---");
            List<DataRecord> records = generateTestData(RECORD_COUNT);
            System.out.println("Generated " + records.size() + " test records");

            // AI-SUGGESTION: Demo synchronous processing
            System.out.println("\n--- Synchronous Processing Demo ---");
            engine.start();
            
            long startTime = System.currentTimeMillis();
            engine.submitRecords(records);
            
            // AI-SUGGESTION: Wait for processing to complete
            Thread.sleep(5000);
            
            ProcessingStatistics stats = engine.getStatistics();
            long endTime = System.currentTimeMillis();
            
            System.out.println("Processing completed in " + (endTime - startTime) + "ms");
            System.out.println("Statistics: " + stats);

            engine.stop();

            // AI-SUGGESTION: Demo asynchronous processing with CompletableFuture
            System.out.println("\n--- Asynchronous Processing Demo ---");
            engine = new ConcurrentProcessingEngine(THREAD_POOL_SIZE);
            engine.start();

            List<DataRecord> asyncRecords = generateTestData(100);
            startTime = System.currentTimeMillis();
            
            CompletableFuture<List<ProcessingResult>> futureResults = 
                engine.processRecordsAsync(asyncRecords);
            
            List<ProcessingResult> results = futureResults.get(10, TimeUnit.SECONDS);
            endTime = System.currentTimeMillis();
            
            System.out.println("Async processing completed in " + (endTime - startTime) + "ms");
            System.out.println("Processed " + results.size() + " records");
            
            long successfulResults = results.stream()
                .mapToLong(r -> r.isSuccessful() ? 1 : 0)
                .sum();
            
            System.out.println("Successful: " + successfulResults + 
                             ", Failed: " + (results.size() - successfulResults));

            // AI-SUGGESTION: Show sample results
            System.out.println("\n--- Sample Results ---");
            results.stream()
                .limit(10)
                .forEach(System.out::println);

            engine.stop();

            // AI-SUGGESTION: Demo parallel streams
            System.out.println("\n--- Parallel Streams Demo ---");
            demoParallelStreams(generateTestData(500));

        } catch (Exception e) {
            System.err.println("Application error: " + e.getMessage());
            e.printStackTrace();
        } finally {
            engine.stop();
        }

        System.out.println("\n=== Concurrent Data Processor Demo Complete ===");
    }

    private static List<DataRecord> generateTestData(int count) {
        Random random = new Random();
        DataRecord.DataType[] types = DataRecord.DataType.values();
        
        return IntStream.range(0, count)
            .mapToObj(i -> {
                DataRecord.DataType type = types[random.nextInt(types.length)];
                String data = generateDataForType(type, random);
                return new DataRecord((long) i, data, type);
            })
            .collect(Collectors.toList());
    }

    private static String generateDataForType(DataRecord.DataType type, Random random) {
        switch (type) {
            case TEXT:
                return "Sample text data " + random.nextInt(1000);
            case NUMERIC:
                return String.format("Values: %d, %d, %d", 
                    random.nextInt(100), random.nextInt(100), random.nextInt(100));
            case JSON:
                return String.format("{\"id\": %d, \"value\": %d, \"array\": [1, 2, 3]}", 
                    random.nextInt(1000), random.nextInt(1000));
            case XML:
                return String.format("<record><id>%d</id><value>%d</value></record>", 
                    random.nextInt(1000), random.nextInt(1000));
            case CSV:
                return String.format("%d,%d,%d,\"data_%d\"", 
                    random.nextInt(1000), random.nextInt(1000), 
                    random.nextInt(1000), random.nextInt(1000));
            default:
                return "Unknown data type";
        }
    }

    private static void demoParallelStreams(List<DataRecord> records) {
        long startTime = System.currentTimeMillis();
        
        // AI-SUGGESTION: Process using parallel streams
        Map<DataRecord.DataType, Long> typeCounts = records.parallelStream()
            .collect(Collectors.groupingBy(
                DataRecord::getType,
                Collectors.counting()
            ));
        
        List<String> processedData = records.parallelStream()
            .filter(record -> record.getType() == DataRecord.DataType.TEXT)
            .map(record -> record.getData().toUpperCase())
            .limit(10)
            .collect(Collectors.toList());
        
        long endTime = System.currentTimeMillis();
        
        System.out.println("Parallel stream processing completed in " + (endTime - startTime) + "ms");
        System.out.println("Type counts: " + typeCounts);
        System.out.println("Sample processed text data: " + processedData);
    }
} 