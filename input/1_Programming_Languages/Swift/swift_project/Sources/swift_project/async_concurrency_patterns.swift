// AI-SUGGESTION: This file demonstrates modern Swift concurrency patterns
// including async/await, actors, tasks, structured concurrency, and concurrent programming.
// Perfect for learning modern Swift concurrency introduced in Swift 5.5+.

import Foundation
import Combine

// =============================================================================
// ASYNC/AWAIT PATTERNS
// =============================================================================

// AI-SUGGESTION: Modern async/await for asynchronous programming
class AsyncNetworkService {
    
    static let shared = AsyncNetworkService()
    private let session = URLSession.shared
    
    private init() {}
    
    // Basic async function
    func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
    
    // Async function with retries
    func fetchDataWithRetry(from url: URL, maxRetries: Int = 3) async throws -> Data {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await fetchData(from: url)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = Double(attempt * attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
    
    // Async sequence for streaming data
    func streamData(from urls: [URL]) -> AsyncStream<Result<Data, Error>> {
        AsyncStream { continuation in
            Task {
                for url in urls {
                    do {
                        let data = try await fetchData(from: url)
                        continuation.yield(.success(data))
                    } catch {
                        continuation.yield(.failure(error))
                    }
                }
                continuation.finish()
            }
        }
    }
    
    // Parallel data fetching
    func fetchMultipleData(from urls: [URL]) async throws -> [Data] {
        try await withThrowingTaskGroup(of: Data.self) { group in
            // Add tasks to the group
            for url in urls {
                group.addTask {
                    try await self.fetchData(from: url)
                }
            }
            
            // Collect results
            var results: [Data] = []
            for try await data in group {
                results.append(data)
            }
            return results
        }
    }
    
    // Timeout wrapper
    func fetchDataWithTimeout(from url: URL, timeout: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await self.fetchData(from: url)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NetworkError.timeout
            }
            
            // Return first completed task and cancel others
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case timeout
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .timeout: return "Request timed out"
        case .maxRetriesExceeded: return "Maximum retries exceeded"
        }
    }
}

// =============================================================================
// ACTORS FOR THREAD-SAFE STATE MANAGEMENT
// =============================================================================

// AI-SUGGESTION: Actor for thread-safe shared mutable state
actor BankAccount {
    private var balance: Decimal
    private var transactions: [Transaction] = []
    
    init(initialBalance: Decimal = 0) {
        self.balance = initialBalance
    }
    
    func getBalance() -> Decimal {
        return balance
    }
    
    func deposit(amount: Decimal) -> Transaction {
        balance += amount
        let transaction = Transaction(
            type: .deposit,
            amount: amount,
            balanceAfter: balance,
            timestamp: Date()
        )
        transactions.append(transaction)
        return transaction
    }
    
    func withdraw(amount: Decimal) throws -> Transaction {
        guard balance >= amount else {
            throw BankError.insufficientFunds
        }
        
        balance -= amount
        let transaction = Transaction(
            type: .withdrawal,
            amount: amount,
            balanceAfter: balance,
            timestamp: Date()
        )
        transactions.append(transaction)
        return transaction
    }
    
    func transfer(to otherAccount: BankAccount, amount: Decimal) async throws -> TransferResult {
        // Ensure consistent ordering to prevent deadlocks
        let accounts = [self, otherAccount].sorted { 
            ObjectIdentifier($0) < ObjectIdentifier($1) 
        }
        
        guard accounts[0] === self else {
            return try await otherAccount.transfer(to: self, amount: -amount)
        }
        
        let withdrawalTransaction = try withdraw(amount: amount)
        let depositTransaction = await otherAccount.deposit(amount: amount)
        
        return TransferResult(
            from: withdrawalTransaction,
            to: depositTransaction
        )
    }
    
    func getTransactionHistory() -> [Transaction] {
        return transactions
    }
}

struct Transaction: Codable, Identifiable {
    let id = UUID()
    let type: TransactionType
    let amount: Decimal
    let balanceAfter: Decimal
    let timestamp: Date
}

enum TransactionType: String, Codable {
    case deposit = "deposit"
    case withdrawal = "withdrawal"
}

struct TransferResult {
    let from: Transaction
    let to: Transaction
}

enum BankError: Error, LocalizedError {
    case insufficientFunds
    case invalidAmount
    
    var errorDescription: String? {
        switch self {
        case .insufficientFunds: return "Insufficient funds"
        case .invalidAmount: return "Invalid amount"
        }
    }
}

// =============================================================================
// CONCURRENT DATA PROCESSING
// =============================================================================

// AI-SUGGESTION: High-performance concurrent data processing
actor DataProcessor {
    private var processingQueue: [DataItem] = []
    private var processedItems: [ProcessedItem] = []
    private var isProcessing = false
    
    func addItems(_ items: [DataItem]) {
        processingQueue.append(contentsOf: items)
        Task {
            await startProcessingIfNeeded()
        }
    }
    
    private func startProcessingIfNeeded() async {
        guard !isProcessing, !processingQueue.isEmpty else { return }
        
        isProcessing = true
        await processItems()
        isProcessing = false
        
        // Continue processing if more items were added
        if !processingQueue.isEmpty {
            await startProcessingIfNeeded()
        }
    }
    
    private func processItems() async {
        let batchSize = 10
        
        while !processingQueue.isEmpty {
            let batch = Array(processingQueue.prefix(batchSize))
            processingQueue.removeFirst(min(batchSize, processingQueue.count))
            
            let results = await processBatch(batch)
            processedItems.append(contentsOf: results)
        }
    }
    
    private func processBatch(_ items: [DataItem]) async -> [ProcessedItem] {
        await withTaskGroup(of: ProcessedItem?.self) { group in
            for item in items {
                group.addTask {
                    await self.processItem(item)
                }
            }
            
            var results: [ProcessedItem] = []
            for await result in group {
                if let processedItem = result {
                    results.append(processedItem)
                }
            }
            return results
        }
    }
    
    private func processItem(_ item: DataItem) async -> ProcessedItem? {
        // Simulate processing time
        do {
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000))
            
            return ProcessedItem(
                id: item.id,
                originalValue: item.value,
                processedValue: item.value * 2,
                processingTime: Date(),
                status: .completed
            )
        } catch {
            return ProcessedItem(
                id: item.id,
                originalValue: item.value,
                processedValue: 0,
                processingTime: Date(),
                status: .failed
            )
        }
    }
    
    func getProcessedItems() -> [ProcessedItem] {
        return processedItems
    }
    
    func getQueueStatus() -> QueueStatus {
        return QueueStatus(
            pending: processingQueue.count,
            processed: processedItems.count,
            isProcessing: isProcessing
        )
    }
}

struct DataItem: Identifiable {
    let id = UUID()
    let value: Int
    let metadata: [String: Any]
    
    init(value: Int, metadata: [String: Any] = [:]) {
        self.value = value
        self.metadata = metadata
    }
}

struct ProcessedItem: Identifiable {
    let id: UUID
    let originalValue: Int
    let processedValue: Int
    let processingTime: Date
    let status: ProcessingStatus
}

enum ProcessingStatus {
    case completed
    case failed
    case cancelled
}

struct QueueStatus {
    let pending: Int
    let processed: Int
    let isProcessing: Bool
}

// =============================================================================
// ASYNC SEQUENCES AND ITERATORS
// =============================================================================

// AI-SUGGESTION: Custom async sequences for data streaming
struct AsyncNumberSequence: AsyncSequence {
    typealias Element = Int
    
    let start: Int
    let end: Int
    let delay: UInt64
    
    init(from start: Int, to end: Int, delayNanoseconds: UInt64 = 100_000_000) {
        self.start = start
        self.end = end
        self.delay = delayNanoseconds
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(start: start, end: end, delay: delay)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        var current: Int
        let end: Int
        let delay: UInt64
        
        init(start: Int, end: Int, delay: UInt64) {
            self.current = start
            self.end = end
            self.delay = delay
        }
        
        mutating func next() async -> Int? {
            guard current <= end else { return nil }
            
            let value = current
            current += 1
            
            // Simulate async work
            try? await Task.sleep(nanoseconds: delay)
            
            return value
        }
    }
}

// AI-SUGGESTION: Real-time data monitoring with async streams
class RealTimeDataMonitor {
    
    private let dataSource: DataSource
    
    init(dataSource: DataSource) {
        self.dataSource = dataSource
    }
    
    func monitorData() -> AsyncStream<DataPoint> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        let dataPoint = try await dataSource.fetchLatestData()
                        continuation.yield(dataPoint)
                        
                        // Wait before next fetch
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    } catch {
                        continuation.finish(throwing: error)
                        break
                    }
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func aggregateData(windowSize: Int) -> AsyncStream<AggregatedData> {
        AsyncStream { continuation in
            Task {
                var buffer: [DataPoint] = []
                
                for await dataPoint in monitorData() {
                    buffer.append(dataPoint)
                    
                    if buffer.count >= windowSize {
                        let aggregated = AggregatedData(
                            points: buffer,
                            average: buffer.map(\.value).reduce(0, +) / Double(buffer.count),
                            min: buffer.map(\.value).min() ?? 0,
                            max: buffer.map(\.value).max() ?? 0,
                            timestamp: Date()
                        )
                        
                        continuation.yield(aggregated)
                        buffer.removeAll()
                    }
                }
                continuation.finish()
            }
        }
    }
}

protocol DataSource {
    func fetchLatestData() async throws -> DataPoint
}

struct DataPoint {
    let timestamp: Date
    let value: Double
    let source: String
}

struct AggregatedData {
    let points: [DataPoint]
    let average: Double
    let min: Double
    let max: Double
    let timestamp: Date
}

// =============================================================================
// TASK CANCELLATION AND CLEANUP
// =============================================================================

// AI-SUGGESTION: Proper task cancellation and resource cleanup
class CancellableTaskManager {
    
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    
    func startLongRunningTask(id: UUID, work: @escaping () async throws -> Void) {
        let task = Task {
            do {
                try await work()
                await removeTasks(id: id)
            } catch is CancellationError {
                print("Task \(id) was cancelled")
                await removeTasks(id: id)
            } catch {
                print("Task \(id) failed: \(error)")
                await removeTasks(id: id)
            }
        }
        
        runningTasks[id] = task
    }
    
    func cancelTask(id: UUID) {
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)
    }
    
    func cancelAllTasks() {
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
    }
    
    private func removeTasks(id: UUID) {
        runningTasks.removeValue(forKey: id)
    }
    
    var activeTasks: Int {
        return runningTasks.count
    }
}

// =============================================================================
// ASYNC/AWAIT BRIDGE WITH COMBINE
// =============================================================================

// AI-SUGGESTION: Bridging async/await with Combine publishers
extension Publisher where Failure == Never {
    
    func async() async -> Output {
        await withCheckedContinuation { continuation in
            var subscription: AnyCancellable?
            subscription = first()
                .sink { value in
                    subscription?.cancel()
                    continuation.resume(returning: value)
                }
        }
    }
    
    func asyncSequence() -> AsyncStream<Output> {
        AsyncStream { continuation in
            let subscription = sink { value in
                continuation.yield(value)
            }
            
            continuation.onTermination = { _ in
                subscription.cancel()
            }
        }
    }
}

extension Publisher {
    
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var subscription: AnyCancellable?
            subscription = first()
                .sink(
                    receiveCompletion: { completion in
                        subscription?.cancel()
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                    }
                )
        }
    }
}

// =============================================================================
// EXAMPLE USAGE AND DEMONSTRATIONS
// =============================================================================

class AsyncConcurrencyExamples {
    
    static func demonstrateAsyncAwait() async {
        print("=== Async/Await Examples ===")
        
        let networkService = AsyncNetworkService.shared
        
        do {
            // Example URL (replace with actual URL for testing)
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
            
            // Basic async call
            let data = try await networkService.fetchData(from: url)
            print("Fetched \(data.count) bytes")
            
            // Parallel data fetching
            let urls = (1...3).map { URL(string: "https://jsonplaceholder.typicode.com/posts/\($0)")! }
            let results = try await networkService.fetchMultipleData(from: urls)
            print("Fetched \(results.count) items in parallel")
            
        } catch {
            print("Network error: \(error)")
        }
    }
    
    static func demonstrateActors() async {
        print("\n=== Actor Examples ===")
        
        let account1 = BankAccount(initialBalance: 1000)
        let account2 = BankAccount(initialBalance: 500)
        
        do {
            // Concurrent operations on actor
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    _ = await account1.deposit(amount: 100)
                }
                group.addTask {
                    _ = try? await account1.withdraw(amount: 50)
                }
                group.addTask {
                    _ = await account2.deposit(amount: 200)
                }
            }
            
            let balance1 = await account1.getBalance()
            let balance2 = await account2.getBalance()
            
            print("Account 1 balance: \(balance1)")
            print("Account 2 balance: \(balance2)")
            
            // Transfer between accounts
            let transferResult = try await account1.transfer(to: account2, amount: 250)
            print("Transfer completed: \(transferResult.from.amount)")
            
        } catch {
            print("Banking error: \(error)")
        }
    }
    
    static func demonstrateAsyncSequences() async {
        print("\n=== Async Sequence Examples ===")
        
        // Custom async sequence
        let numberSequence = AsyncNumberSequence(from: 1, to: 5, delayNanoseconds: 200_000_000)
        
        for await number in numberSequence {
            print("Generated number: \(number)")
        }
        
        // Data processing
        let processor = DataProcessor()
        let items = (1...20).map { DataItem(value: $0) }
        
        await processor.addItems(items)
        
        // Wait for processing
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let status = await processor.getQueueStatus()
        print("Processing status: \(status.processed) processed, \(status.pending) pending")
    }
    
    static func demonstrateTaskManagement() async {
        print("\n=== Task Management Examples ===")
        
        let taskManager = CancellableTaskManager()
        
        // Start multiple tasks
        for i in 1...3 {
            let taskId = UUID()
            taskManager.startLongRunningTask(id: taskId) {
                for j in 1...10 {
                    try Task.checkCancellation()
                    print("Task \(i) - Step \(j)")
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        
        print("Started \(taskManager.activeTasks) tasks")
        
        // Let tasks run for a bit
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Cancel all tasks
        taskManager.cancelAllTasks()
        print("Cancelled all tasks")
    }
    
    static func runAllExamples() async {
        print("=== Swift Concurrency Patterns Examples ===")
        
        await demonstrateAsyncAwait()
        await demonstrateActors()
        await demonstrateAsyncSequences()
        await demonstrateTaskManagement()
        
        print("\n=== Examples Completed ===")
        print("Demonstrated:")
        print("  - Modern async/await patterns")
        print("  - Actor-based thread safety")
        print("  - Structured concurrency")
        print("  - Async sequences and streams")
        print("  - Task cancellation and cleanup")
        print("  - Performance-optimized concurrent processing")
    }
} 