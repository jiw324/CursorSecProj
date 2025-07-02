// AI-SUGGESTION: This file demonstrates functional programming patterns in Swift
// including monads, higher-order functions, generics, and advanced Swift features.
// Perfect for learning functional programming concepts and advanced Swift techniques.

import Foundation
import Combine

// =============================================================================
// FUNCTIONAL PROGRAMMING FUNDAMENTALS
// =============================================================================

// AI-SUGGESTION: Result monad for error handling
enum Result<Value, Error: Swift.Error> {
    case success(Value)
    case failure(Error)
    
    func map<T>(_ transform: (Value) -> T) -> Result<T, Error> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func flatMap<T>(_ transform: (Value) -> Result<T, Error>) -> Result<T, Error> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func get() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

// AI-SUGGESTION: Optional monad extensions
extension Optional {
    func flatMap<U>(_ transform: (Wrapped) -> U?) -> U? {
        switch self {
        case .some(let value):
            return transform(value)
        case .none:
            return nil
        }
    }
    
    func filter(_ predicate: (Wrapped) -> Bool) -> Optional {
        switch self {
        case .some(let value):
            return predicate(value) ? self : nil
        case .none:
            return nil
        }
    }
    
    func or(_ alternative: @autoclosure () -> Optional) -> Optional {
        return self ?? alternative()
    }
    
    func apply<U>(_ transform: ((Wrapped) -> U)?) -> U? {
        guard let transform = transform else { return nil }
        return map(transform)
    }
}

// =============================================================================
// HIGHER-ORDER FUNCTIONS
// =============================================================================

// AI-SUGGESTION: Collection of higher-order function utilities
struct FunctionalUtils {
    
    // Curry functions
    static func curry<A, B, C>(_ function: @escaping (A, B) -> C) -> (A) -> (B) -> C {
        return { a in { b in function(a, b) } }
    }
    
    static func curry<A, B, C, D>(_ function: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
        return { a in { b in { c in function(a, b, c) } } }
    }
    
    // Function composition
    static func compose<A, B, C>(_ f: @escaping (B) -> C, _ g: @escaping (A) -> B) -> (A) -> C {
        return { a in f(g(a)) }
    }
    
    // Partial application
    static func partial<A, B, C>(_ function: @escaping (A, B) -> C, _ a: A) -> (B) -> C {
        return { b in function(a, b) }
    }
    
    // Memoization
    static func memoize<Input: Hashable, Output>(_ function: @escaping (Input) -> Output) -> (Input) -> Output {
        var cache: [Input: Output] = [:]
        return { input in
            if let cached = cache[input] {
                return cached
            }
            let result = function(input)
            cache[input] = result
            return result
        }
    }
    
    // Debounce
    static func debounce<T>(_ function: @escaping (T) -> Void, delay: TimeInterval) -> (T) -> Void {
        var workItem: DispatchWorkItem?
        return { value in
            workItem?.cancel()
            workItem = DispatchWorkItem { function(value) }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
        }
    }
    
    // Throttle
    static func throttle<T>(_ function: @escaping (T) -> Void, interval: TimeInterval) -> (T) -> Void {
        var lastExecutionTime: TimeInterval = 0
        return { value in
            let currentTime = Date().timeIntervalSince1970
            if currentTime - lastExecutionTime >= interval {
                function(value)
                lastExecutionTime = currentTime
            }
        }
    }
}

// =============================================================================
// MONADS AND FUNCTORS
// =============================================================================

// AI-SUGGESTION: Maybe monad (similar to Optional but more explicit)
enum Maybe<T> {
    case just(T)
    case nothing
    
    func map<U>(_ transform: (T) -> U) -> Maybe<U> {
        switch self {
        case .just(let value):
            return .just(transform(value))
        case .nothing:
            return .nothing
        }
    }
    
    func flatMap<U>(_ transform: (T) -> Maybe<U>) -> Maybe<U> {
        switch self {
        case .just(let value):
            return transform(value)
        case .nothing:
            return .nothing
        }
    }
    
    func filter(_ predicate: (T) -> Bool) -> Maybe<T> {
        switch self {
        case .just(let value):
            return predicate(value) ? self : .nothing
        case .nothing:
            return .nothing
        }
    }
    
    var value: T? {
        switch self {
        case .just(let value):
            return value
        case .nothing:
            return nil
        }
    }
}

// AI-SUGGESTION: Either monad for representing two possible values
enum Either<Left, Right> {
    case left(Left)
    case right(Right)
    
    func map<T>(_ transform: (Right) -> T) -> Either<Left, T> {
        switch self {
        case .left(let value):
            return .left(value)
        case .right(let value):
            return .right(transform(value))
        }
    }
    
    func flatMap<T>(_ transform: (Right) -> Either<Left, T>) -> Either<Left, T> {
        switch self {
        case .left(let value):
            return .left(value)
        case .right(let value):
            return transform(value)
        }
    }
    
    func mapLeft<T>(_ transform: (Left) -> T) -> Either<T, Right> {
        switch self {
        case .left(let value):
            return .left(transform(value))
        case .right(let value):
            return .right(value)
        }
    }
    
    var isLeft: Bool {
        switch self {
        case .left: return true
        case .right: return false
        }
    }
    
    var isRight: Bool {
        return !isLeft
    }
}

// =============================================================================
// ADVANCED GENERICS
// =============================================================================

// AI-SUGGESTION: Type-safe builder pattern with generics
protocol Builder {
    associatedtype Product
    func build() -> Product
}

class ConfigurationBuilder<T>: Builder {
    private var properties: [String: Any] = [:]
    
    func set<U>(_ keyPath: WritableKeyPath<T, U>, value: U) -> Self {
        // In a real implementation, this would use reflection or codegen
        return self
    }
    
    func build() -> T {
        // This would construct T using the properties
        fatalError("Implementation needed")
    }
}

// AI-SUGGESTION: Generic data validation
protocol Validator {
    associatedtype Input
    associatedtype Error: Swift.Error
    
    func validate(_ input: Input) -> Result<Input, Error>
}

struct EmailValidator: Validator {
    typealias Input = String
    
    enum ValidationError: Error {
        case empty
        case invalidFormat
    }
    
    func validate(_ input: String) -> Result<String, ValidationError> {
        if input.isEmpty {
            return .failure(.empty)
        }
        
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if predicate.evaluate(with: input) {
            return .success(input)
        } else {
            return .failure(.invalidFormat)
        }
    }
}

// AI-SUGGESTION: Generic repository pattern
protocol Repository {
    associatedtype Entity
    associatedtype Identifier
    
    func save(_ entity: Entity) -> Result<Entity, RepositoryError>
    func find(by id: Identifier) -> Maybe<Entity>
    func findAll() -> [Entity]
    func delete(by id: Identifier) -> Result<Void, RepositoryError>
}

enum RepositoryError: Error {
    case notFound
    case saveFailed
    case deleteFailed
}

class InMemoryRepository<T: Identifiable>: Repository {
    typealias Entity = T
    typealias Identifier = T.ID
    
    private var storage: [T.ID: T] = [:]
    
    func save(_ entity: T) -> Result<T, RepositoryError> {
        storage[entity.id] = entity
        return .success(entity)
    }
    
    func find(by id: T.ID) -> Maybe<T> {
        if let entity = storage[id] {
            return .just(entity)
        } else {
            return .nothing
        }
    }
    
    func findAll() -> [T] {
        return Array(storage.values)
    }
    
    func delete(by id: T.ID) -> Result<Void, RepositoryError> {
        if storage.removeValue(forKey: id) != nil {
            return .success(())
        } else {
            return .failure(.notFound)
        }
    }
}

// =============================================================================
// FUNCTIONAL COLLECTION OPERATIONS
// =============================================================================

// AI-SUGGESTION: Enhanced collection operations
extension Array {
    
    // Chunking
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
    
    // Safe subscripting
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    // Unique elements (for Hashable elements)
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen: Set<T> = []
        return filter { seen.insert(self[keyPath: keyPath]).inserted }
    }
    
    // Group by
    func grouped<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: [Element]] {
        return Dictionary(grouping: self) { $0[keyPath: keyPath] }
    }
    
    // Parallel map (using concurrent queue)
    func parallelMap<T>(_ transform: @escaping (Element) -> T) -> [T] {
        var result = Array<T?>(repeating: nil, count: count)
        let queue = DispatchQueue(label: "parallel-map", attributes: .concurrent)
        let group = DispatchGroup()
        
        for (index, element) in enumerated() {
            queue.async(group: group) {
                result[index] = transform(element)
            }
        }
        
        group.wait()
        return result.compactMap { $0 }
    }
    
    // Scan (accumulate with history)
    func scan<T>(_ initial: T, _ combine: (T, Element) -> T) -> [T] {
        var result = [initial]
        var accumulator = initial
        
        for element in self {
            accumulator = combine(accumulator, element)
            result.append(accumulator)
        }
        
        return result
    }
}

// =============================================================================
// REACTIVE PROGRAMMING PATTERNS
// =============================================================================

// AI-SUGGESTION: Simple observable pattern
class Observable<T> {
    private var observers: [(T) -> Void] = []
    private var _value: T
    
    var value: T {
        get { return _value }
        set {
            _value = newValue
            notifyObservers()
        }
    }
    
    init(_ value: T) {
        self._value = value
    }
    
    func observe(_ observer: @escaping (T) -> Void) -> Disposable {
        observers.append(observer)
        observer(value) // Emit current value
        
        let index = observers.count - 1
        return Disposable { [weak self] in
            self?.observers.remove(at: index)
        }
    }
    
    func map<U>(_ transform: @escaping (T) -> U) -> Observable<U> {
        let mapped = Observable<U>(transform(value))
        
        let _ = observe { newValue in
            mapped.value = transform(newValue)
        }
        
        return mapped
    }
    
    private func notifyObservers() {
        observers.forEach { $0(value) }
    }
}

class Disposable {
    private let dispose: () -> Void
    
    init(_ dispose: @escaping () -> Void) {
        self.dispose = dispose
    }
    
    func dispose() {
        dispose()
    }
}

// =============================================================================
// FUNCTIONAL ERROR HANDLING
// =============================================================================

// AI-SUGGESTION: Functional error handling utilities
struct Try<T> {
    private let computation: () throws -> T
    
    init(_ computation: @escaping () throws -> T) {
        self.computation = computation
    }
    
    func execute() -> Result<T, Error> {
        do {
            let value = try computation()
            return .success(value)
        } catch {
            return .failure(error)
        }
    }
    
    func map<U>(_ transform: @escaping (T) throws -> U) -> Try<U> {
        return Try<U> {
            let value = try self.computation()
            return try transform(value)
        }
    }
    
    func flatMap<U>(_ transform: @escaping (T) throws -> Try<U>) -> Try<U> {
        return Try<U> {
            let value = try self.computation()
            return try transform(value).computation()
        }
    }
    
    func recover(_ recovery: @escaping (Error) throws -> T) -> Try<T> {
        return Try {
            do {
                return try self.computation()
            } catch {
                return try recovery(error)
            }
        }
    }
}

// =============================================================================
// EXAMPLE DOMAIN MODELS
// =============================================================================

// AI-SUGGESTION: Example models for functional programming demonstration
struct Person: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let age: Int
    let email: String
    let department: String
}

struct Product: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let price: Double
    let category: String
    let inStock: Bool
}

struct Order: Identifiable {
    let id = UUID()
    let personId: UUID
    let products: [Product]
    let total: Double
    let date: Date
}

// =============================================================================
// FUNCTIONAL PROGRAMMING EXAMPLES
// =============================================================================

class FunctionalProgrammingExamples {
    
    static func demonstrateHigherOrderFunctions() {
        print("=== Higher-Order Functions ===")
        
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        
        // Map, filter, reduce
        let doubled = numbers.map { $0 * 2 }
        let evens = numbers.filter { $0 % 2 == 0 }
        let sum = numbers.reduce(0, +)
        
        print("Doubled: \(doubled)")
        print("Evens: \(evens)")
        print("Sum: \(sum)")
        
        // Function composition
        let addOne = { $0 + 1 }
        let multiplyByTwo = { $0 * 2 }
        let composed = FunctionalUtils.compose(multiplyByTwo, addOne)
        
        let result = composed(5) // (5 + 1) * 2 = 12
        print("Composed function result: \(result)")
        
        // Currying
        let add = { (a: Int, b: Int) in a + b }
        let curriedAdd = FunctionalUtils.curry(add)
        let addFive = curriedAdd(5)
        
        print("Curried addition: \(addFive(3))") // 8
        
        // Memoization
        let fibonacci = FunctionalUtils.memoize { (n: Int) -> Int in
            if n <= 1 { return n }
            return fibonacci(n - 1) + fibonacci(n - 2)
        }
        
        print("Fibonacci(10): \(fibonacci(10))")
    }
    
    static func demonstrateMonads() {
        print("\n=== Monads ===")
        
        // Maybe monad
        let maybeValue = Maybe.just(42)
        let mapped = maybeValue.map { $0 * 2 }
        let flatMapped = maybeValue.flatMap { Maybe.just($0 + 10) }
        
        print("Maybe mapped: \(mapped.value ?? 0)")
        print("Maybe flatMapped: \(flatMapped.value ?? 0)")
        
        // Either monad
        let rightValue: Either<String, Int> = .right(42)
        let leftValue: Either<String, Int> = .left("Error")
        
        let mappedRight = rightValue.map { $0 * 2 }
        let mappedLeft = leftValue.map { $0 * 2 }
        
        print("Either right mapped: \(mappedRight)")
        print("Either left mapped: \(mappedLeft)")
        
        // Result monad
        let successResult: Result<Int, NSError> = .success(100)
        let failureResult: Result<Int, NSError> = .failure(NSError(domain: "Test", code: 1))
        
        let mappedSuccess = successResult.map { $0 / 2 }
        let mappedFailure = failureResult.map { $0 / 2 }
        
        print("Result success: \(try? mappedSuccess.get())")
        print("Result failure: \(try? mappedFailure.get())")
    }
    
    static func demonstrateGenericRepository() {
        print("\n=== Generic Repository ===")
        
        let personRepo = InMemoryRepository<Person>()
        
        let person = Person(name: "John Doe", age: 30, email: "john@example.com", department: "Engineering")
        
        let saveResult = personRepo.save(person)
        print("Save result: \(saveResult)")
        
        let foundPerson = personRepo.find(by: person.id)
        print("Found person: \(foundPerson.value?.name ?? "Not found")")
        
        let allPeople = personRepo.findAll()
        print("All people count: \(allPeople.count)")
    }
    
    static func demonstrateValidation() {
        print("\n=== Validation ===")
        
        let emailValidator = EmailValidator()
        
        let validEmail = emailValidator.validate("test@example.com")
        let invalidEmail = emailValidator.validate("invalid-email")
        let emptyEmail = emailValidator.validate("")
        
        print("Valid email: \(try? validEmail.get())")
        print("Invalid email: \(try? invalidEmail.get())")
        print("Empty email: \(try? emptyEmail.get())")
    }
    
    static func demonstrateCollectionOperations() {
        print("\n=== Collection Operations ===")
        
        let people = [
            Person(name: "Alice", age: 25, email: "alice@example.com", department: "Engineering"),
            Person(name: "Bob", age: 30, email: "bob@example.com", department: "Marketing"),
            Person(name: "Charlie", age: 25, email: "charlie@example.com", department: "Engineering"),
            Person(name: "Diana", age: 35, email: "diana@example.com", department: "Sales")
        ]
        
        // Group by department
        let byDepartment = people.grouped(by: \.department)
        print("People by department: \(byDepartment.mapValues { $0.count })")
        
        // Unique ages
        let uniqueAges = people.unique(by: \.age)
        print("Unique ages: \(uniqueAges.map(\.age))")
        
        // Chunking
        let numbers = Array(1...10)
        let chunks = numbers.chunked(into: 3)
        print("Chunked numbers: \(chunks)")
        
        // Scanning
        let scanned = numbers.scan(0, +)
        print("Scanned sum: \(scanned)")
    }
    
    static func demonstrateObservable() {
        print("\n=== Observable Pattern ===")
        
        let observable = Observable(10)
        
        let disposable = observable.observe { value in
            print("Observed value: \(value)")
        }
        
        observable.value = 20
        observable.value = 30
        
        // Map observable
        let mapped = observable.map { $0 * 2 }
        let mappedDisposable = mapped.observe { value in
            print("Mapped value: \(value)")
        }
        
        observable.value = 40
        
        // Clean up
        disposable.dispose()
        mappedDisposable.dispose()
    }
    
    static func demonstrateTryMonad() {
        print("\n=== Try Monad ===")
        
        let safeDivision = Try {
            let result = 10 / 2
            return result
        }
        
        let unsafeDivision = Try {
            let result = 10 / 0
            return result
        }
        
        let safeResult = safeDivision.execute()
        let unsafeResult = unsafeDivision.execute()
        
        print("Safe division: \(try? safeResult.get())")
        print("Unsafe division: \(try? unsafeResult.get())")
        
        // Recovery
        let recovered = Try { () -> Int in
            throw NSError(domain: "Test", code: 1)
        }.recover { _ in 42 }
        
        let recoveredResult = recovered.execute()
        print("Recovered result: \(try? recoveredResult.get())")
    }
    
    static func runAllExamples() {
        print("=== Functional Programming Examples ===")
        
        demonstrateHigherOrderFunctions()
        demonstrateMonads()
        demonstrateGenericRepository()
        demonstrateValidation()
        demonstrateCollectionOperations()
        demonstrateObservable()
        demonstrateTryMonad()
        
        print("\n=== Examples Completed ===")
        print("Demonstrated:")
        print("  - Higher-order functions and composition")
        print("  - Monads (Maybe, Either, Result)")
        print("  - Advanced generics and protocols")
        print("  - Functional collection operations")
        print("  - Reactive programming patterns")
        print("  - Type-safe validation")
        print("  - Error handling with monads")
        print("  - Repository pattern with generics")
    }
} 