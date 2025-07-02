// AI-SUGGESTION: This file demonstrates modern Swift concurrency patterns
// including async/await, actors, tasks, and structured concurrency.
// Perfect for learning Swift 5.5+ concurrency features.

import Foundation

// =============================================================================
// ASYNC/AWAIT PATTERNS
// =============================================================================

// AI-SUGGESTION: Modern async networking with error handling
class AsyncNetworkService {
    static let shared = AsyncNetworkService()
    private let session = URLSession.shared
    
    func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        return data
    }
    
    func fetchMultipleURLs(_ urls: [URL]) async throws -> [Data] {
        try await withThrowingTaskGroup(of: Data.self) { group in
            for url in urls {
                group.addTask {
                    try await self.fetchData(from: url)
                }
            }
            
            var results: [Data] = []
            for try await data in group {
                results.append(data)
            }
            return results
        }
    }
    
    func fetchWithTimeout(url: URL, timeout: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await self.fetchData(from: url)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NetworkError.timeout
            }
            
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

enum NetworkError: Error {
    case invalidResponse
    case timeout
}

// =============================================================================
// ACTORS FOR THREAD SAFETY
// =============================================================================

// AI-SUGGESTION: Actor for thread-safe counter
actor Counter {
    private var value = 0
    
    func increment() -> Int {
        value += 1
        return value
    }
    
    func decrement() -> Int {
        value -= 1
        return value
    }
    
    func getValue() -> Int {
        return value
    }
    
    func reset() {
        value = 0
    }
}

// AI-SUGGESTION: Bank account actor with transfer operations
actor BankAccount {
    private var balance: Decimal
    private var transactions: [Transaction] = []
    
    init(balance: Decimal) {
        self.balance = balance
    }
    
    func getBalance() -> Decimal {
        return balance
    }
    
    func deposit(_ amount: Decimal) {
        balance += amount
        transactions.append(Transaction(type: .deposit, amount: amount))
    }
    
    func withdraw(_ amount: Decimal) throws {
        guard balance >= amount else {
            throw BankError.insufficientFunds
        }
        balance -= amount
        transactions.append(Transaction(type: .withdrawal, amount: amount))
    }
    
    func transfer(to account: BankAccount, amount: Decimal) async throws {
        try withdraw(amount)
        await account.deposit(amount)
    }
    
    func getTransactions() -> [Transaction] {
        return transactions
    }
}

struct Transaction {
    let type: TransactionType
    let amount: Decimal
    let timestamp = Date()
}

enum TransactionType {
    case deposit, withdrawal
}

enum BankError: Error {
    case insufficientFunds
}

// =============================================================================
// ASYNC SEQUENCES
// =============================================================================

// AI-SUGGESTION: Custom async sequence for number generation
struct AsyncNumberSequence: AsyncSequence {
    typealias Element = Int
    
    let range: ClosedRange<Int>
    let delay: UInt64
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(range: range, delay: delay)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        var current: Int
        let end: Int
        let delay: UInt64
        
        init(range: ClosedRange<Int>, delay: UInt64) {
            self.current = range.lowerBound
            self.end = range.upperBound
            self.delay = delay
        }
        
        mutating func next() async -> Int? {
            guard current <= end else { return nil }
            
            let value = current
            current += 1
            
            try? await Task.sleep(nanoseconds: delay)
            return value
        }
    }
}

// AI-SUGGESTION: Data stream processor
class DataStreamProcessor {
    
    func processStream<T>(_ stream: AsyncSequence) async where T == stream.Element {
        do {
            for try await item in stream {
                await processItem(item)
            }
        } catch {
            print("Stream processing error: \(error)")
        }
    }
    
    private func processItem<T>(_ item: T) async {
        // Simulate processing
        try? await Task.sleep(nanoseconds: 100_000_000)
        print("Processed: \(item)")
    }
}

// =============================================================================
// TASK GROUPS AND STRUCTURED CONCURRENCY
// =============================================================================

// AI-SUGGESTION: Parallel task execution with results collection
class ParallelTaskRunner {
    
    func runParallelTasks<T>(_ tasks: [() async throws -> T]) async throws -> [T] {
        try await withThrowingTaskGroup(of: T.self) { group in
            for task in tasks {
                group.addTask {
                    try await task()
                }
            }
            
            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    func runTasksWithProgress<T>(_ tasks: [() async throws -> T], 
                                progress: @escaping (Int, Int) -> Void) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, task) in tasks.enumerated() {
                group.addTask {
                    let result = try await task()
                    return (index, result)
                }
            }
            
            var results: [T?] = Array(repeating: nil, count: tasks.count)
            var completed = 0
            
            for try await (index, result) in group {
                results[index] = result
                completed += 1
                progress(completed, tasks.count)
            }
            
            return results.compactMap { $0 }
        }
    }
}

// =============================================================================
// EXAMPLE USAGE
// =============================================================================

class AsyncConcurrencyExamples {
    
    static func demonstrateCounter() async {
        print("=== Counter Actor Example ===")
        
        let counter = Counter()
        
        // Concurrent increments
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...10 {
                group.addTask {
                    let value = await counter.increment()
                    print("Counter value: \(value)")
                }
            }
        }
        
        let finalValue = await counter.getValue()
        print("Final counter value: \(finalValue)")
    }
    
    static func demonstrateBanking() async {
        print("\n=== Banking Actor Example ===")
        
        let account1 = BankAccount(balance: 1000)
        let account2 = BankAccount(balance: 500)
        
        do {
            // Concurrent operations
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await account1.deposit(100)
                }
                group.addTask {
                    try? await account1.withdraw(50)
                }
                group.addTask {
                    await account2.deposit(200)
                }
            }
            
            let balance1 = await account1.getBalance()
            let balance2 = await account2.getBalance()
            
            print("Account 1: \(balance1)")
            print("Account 2: \(balance2)")
            
            // Transfer
            try await account1.transfer(to: account2, amount: 250)
            
            let newBalance1 = await account1.getBalance()
            let newBalance2 = await account2.getBalance()
            
            print("After transfer - Account 1: \(newBalance1), Account 2: \(newBalance2)")
            
        } catch {
            print("Banking error: \(error)")
        }
    }
    
    static func demonstrateAsyncSequence() async {
        print("\n=== Async Sequence Example ===")
        
        let sequence = AsyncNumberSequence(range: 1...5, delay: 200_000_000)
        
        for await number in sequence {
            print("Generated: \(number)")
        }
    }
    
    static func demonstrateParallelTasks() async {
        print("\n=== Parallel Tasks Example ===")
        
        let runner = ParallelTaskRunner()
        
        let tasks: [() async throws -> String] = [
            { () async throws -> String in
                try await Task.sleep(nanoseconds: 500_000_000)
                return "Task 1 completed"
            },
            { () async throws -> String in
                try await Task.sleep(nanoseconds: 300_000_000)
                return "Task 2 completed"
            },
            { () async throws -> String in
                try await Task.sleep(nanoseconds: 700_000_000)
                return "Task 3 completed"
            }
        ]
        
        do {
            let results = try await runner.runTasksWithProgress(tasks) { completed, total in
                print("Progress: \(completed)/\(total)")
            }
            
            for result in results {
                print(result)
            }
        } catch {
            print("Task execution error: \(error)")
        }
    }
    
    static func runAllExamples() async {
        print("=== Swift Async Concurrency Examples ===")
        
        await demonstrateCounter()
        await demonstrateBanking()
        await demonstrateAsyncSequence()
        await demonstrateParallelTasks()
        
        print("\n=== Examples Completed ===")
        print("Demonstrated:")
        print("  - Actor-based thread safety")
        print("  - Async/await patterns")
        print("  - Structured concurrency")
        print("  - Async sequences")
        print("  - Parallel task execution")
    }
} 