// AI-SUGGESTION: This file demonstrates functional programming patterns in Swift
// including higher-order functions, monads, and advanced Swift features.
// Perfect for learning functional programming concepts in Swift.

import Foundation

// =============================================================================
// FUNCTIONAL UTILITIES
// =============================================================================

// AI-SUGGESTION: Higher-order function utilities
struct FunctionalUtils {
    
    // Function composition
    static func compose<A, B, C>(_ f: @escaping (B) -> C, _ g: @escaping (A) -> B) -> (A) -> C {
        return { a in f(g(a)) }
    }
    
    // Currying
    static func curry<A, B, C>(_ function: @escaping (A, B) -> C) -> (A) -> (B) -> C {
        return { a in { b in function(a, b) } }
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
}

// =============================================================================
// MONADS
// =============================================================================

// AI-SUGGESTION: Maybe monad for optional values
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
    
    var value: T? {
        switch self {
        case .just(let value):
            return value
        case .nothing:
            return nil
        }
    }
}

// AI-SUGGESTION: Either monad for error handling
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
    
    var isLeft: Bool {
        switch self {
        case .left: return true
        case .right: return false
        }
    }
    
    var isRight: Bool { !isLeft }
}

// =============================================================================
// ENHANCED COLLECTIONS
// =============================================================================

// AI-SUGGESTION: Functional collection extensions
extension Array {
    
    // Safe subscripting
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    // Chunking
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
    
    // Group by
    func grouped<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: [Element]] {
        return Dictionary(grouping: self) { $0[keyPath: keyPath] }
    }
    
    // Unique elements
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen: Set<T> = []
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
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
// VALIDATION FRAMEWORK
// =============================================================================

// AI-SUGGESTION: Functional validation system
protocol Validator {
    associatedtype Input
    associatedtype Error: Swift.Error
    
    func validate(_ input: Input) -> Either<Error, Input>
}

struct EmailValidator: Validator {
    enum ValidationError: Error {
        case empty
        case invalidFormat
    }
    
    func validate(_ input: String) -> Either<ValidationError, String> {
        if input.isEmpty {
            return .left(.empty)
        }
        
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if predicate.evaluate(with: input) {
            return .right(input)
        } else {
            return .left(.invalidFormat)
        }
    }
}

struct AgeValidator: Validator {
    enum ValidationError: Error {
        case tooYoung
        case tooOld
        case invalid
    }
    
    func validate(_ input: Int) -> Either<ValidationError, Int> {
        guard input > 0 else { return .left(.invalid) }
        guard input >= 18 else { return .left(.tooYoung) }
        guard input <= 120 else { return .left(.tooOld) }
        
        return .right(input)
    }
}

// =============================================================================
// OBSERVABLE PATTERN
// =============================================================================

// AI-SUGGESTION: Simple reactive observable
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
        
        return Disposable { [weak self] in
            if let self = self,
               let index = self.observers.firstIndex(where: { $0 as AnyObject === observer as AnyObject }) {
                self.observers.remove(at: index)
            }
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
// EXAMPLE MODELS
// =============================================================================

// AI-SUGGESTION: Example data models
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
}

// =============================================================================
// EXAMPLE USAGE
// =============================================================================

class FunctionalPatternsExamples {
    
    static func demonstrateComposition() {
        print("=== Function Composition ===")
        
        let addOne = { $0 + 1 }
        let multiplyByTwo = { $0 * 2 }
        let composed = FunctionalUtils.compose(multiplyByTwo, addOne)
        
        print("Composed function (5 + 1) * 2 = \(composed(5))")
        
        // Currying
        let add = { (a: Int, b: Int) in a + b }
        let curriedAdd = FunctionalUtils.curry(add)
        let addFive = curriedAdd(5)
        
        print("Curried addition 5 + 3 = \(addFive(3))")
    }
    
    static func demonstrateMonads() {
        print("\n=== Monads ===")
        
        // Maybe monad
        let maybeValue = Maybe.just(42)
        let mapped = maybeValue.map { $0 * 2 }
        let chained = maybeValue.flatMap { Maybe.just($0 + 10) }
        
        print("Maybe mapped: \(mapped.value ?? 0)")
        print("Maybe chained: \(chained.value ?? 0)")
        
        // Either monad
        let rightValue: Either<String, Int> = .right(42)
        let leftValue: Either<String, Int> = .left("Error")
        
        let mappedRight = rightValue.map { $0 * 2 }
        let mappedLeft = leftValue.map { $0 * 2 }
        
        print("Either right: \(mappedRight)")
        print("Either left: \(mappedLeft)")
    }
    
    static func demonstrateCollections() {
        print("\n=== Collection Operations ===")
        
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        
        // Basic operations
        let doubled = numbers.map { $0 * 2 }
        let evens = numbers.filter { $0 % 2 == 0 }
        let sum = numbers.reduce(0, +)
        
        print("Doubled: \(doubled)")
        print("Evens: \(evens)")
        print("Sum: \(sum)")
        
        // Advanced operations
        let chunks = numbers.chunked(into: 3)
        print("Chunks: \(chunks)")
        
        let scan = numbers.scan(0, +)
        print("Cumulative sum: \(scan)")
        
        // Working with objects
        let people = [
            Person(name: "Alice", age: 25, email: "alice@example.com", department: "Engineering"),
            Person(name: "Bob", age: 30, email: "bob@example.com", department: "Marketing"),
            Person(name: "Charlie", age: 25, email: "charlie@example.com", department: "Engineering")
        ]
        
        let byDepartment = people.grouped(by: \.department)
        print("By department: \(byDepartment.mapValues { $0.count })")
        
        let uniqueAges = people.unique(by: \.age)
        print("Unique ages: \(uniqueAges.map(\.age))")
    }
    
    static func demonstrateValidation() {
        print("\n=== Validation ===")
        
        let emailValidator = EmailValidator()
        let ageValidator = AgeValidator()
        
        let validEmail = emailValidator.validate("test@example.com")
        let invalidEmail = emailValidator.validate("invalid-email")
        
        let validAge = ageValidator.validate(25)
        let invalidAge = ageValidator.validate(15)
        
        print("Valid email: \(validEmail)")
        print("Invalid email: \(invalidEmail)")
        print("Valid age: \(validAge)")
        print("Invalid age: \(invalidAge)")
    }
    
    static func demonstrateObservable() {
        print("\n=== Observable Pattern ===")
        
        let observable = Observable(10)
        
        let disposable = observable.observe { value in
            print("Observed: \(value)")
        }
        
        observable.value = 20
        observable.value = 30
        
        // Mapped observable
        let doubled = observable.map { $0 * 2 }
        let doubledDisposable = doubled.observe { value in
            print("Doubled: \(value)")
        }
        
        observable.value = 40
        
        disposable.dispose()
        doubledDisposable.dispose()
    }
    
    static func demonstrateMemoization() {
        print("\n=== Memoization ===")
        
        // Fibonacci with memoization
        let fibonacci = FunctionalUtils.memoize { (n: Int) -> Int in
            if n <= 1 { return n }
            return fibonacci(n - 1) + fibonacci(n - 2)
        }
        
        let start = Date()
        let result = fibonacci(35)
        let duration = Date().timeIntervalSince(start)
        
        print("Fibonacci(35) = \(result) in \(duration) seconds")
        
        // Second call should be much faster (cached)
        let start2 = Date()
        let result2 = fibonacci(35)
        let duration2 = Date().timeIntervalSince(start2)
        
        print("Fibonacci(35) = \(result2) in \(duration2) seconds (cached)")
    }
    
    static func runAllExamples() {
        print("=== Functional Programming Patterns ===")
        
        demonstrateComposition()
        demonstrateMonads()
        demonstrateCollections()
        demonstrateValidation()
        demonstrateObservable()
        demonstrateMemoization()
        
        print("\n=== Examples Completed ===")
        print("Demonstrated:")
        print("  - Function composition and currying")
        print("  - Monads (Maybe, Either)")
        print("  - Functional collection operations")
        print("  - Type-safe validation")
        print("  - Observable pattern")
        print("  - Memoization for performance")
        print("  - Higher-order functions")
    }
} 