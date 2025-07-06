// AI-Generated Code Header
// **Intent:** Demonstrate Kotlin functional programming patterns and utilities
// **Optimization:** Immutable data structures, lazy evaluation, and function composition
// **Safety:** Type safety, null safety, and functional error handling

package com.example.functional

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.contracts.ExperimentalContracts
import kotlin.contracts.InvocationKind
import kotlin.contracts.contract
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

// AI-SUGGESTION: Result monad for functional error handling
sealed class Result<out T, out E> {
    data class Success<T>(val value: T) : Result<T, Nothing>()
    data class Failure<E>(val error: E) : Result<Nothing, E>()
    
    companion object {
        fun <T> success(value: T): Result<T, Nothing> = Success(value)
        fun <E> failure(error: E): Result<Nothing, E> = Failure(error)
        
        fun <T> of(block: () -> T): Result<T, Exception> = try {
            success(block())
        } catch (e: Exception) {
            failure(e)
        }
    }
    
    inline fun <R> map(transform: (T) -> R): Result<R, E> = when (this) {
        is Success -> success(transform(value))
        is Failure -> this
    }
    
    inline fun <R> flatMap(transform: (T) -> Result<R, E>): Result<R, E> = when (this) {
        is Success -> transform(value)
        is Failure -> this
    }
    
    inline fun <R> mapError(transform: (E) -> R): Result<T, R> = when (this) {
        is Success -> this
        is Failure -> failure(transform(error))
    }
    
    inline fun fold(onSuccess: (T) -> Unit, onFailure: (E) -> Unit) = when (this) {
        is Success -> onSuccess(value)
        is Failure -> onFailure(error)
    }
    
    fun getOrNull(): T? = when (this) {
        is Success -> value
        is Failure -> null
    }
    
    fun getOrElse(default: T): T = when (this) {
        is Success -> value
        is Failure -> default
    }
}

// AI-SUGGESTION: Option monad for null-safe operations
sealed class Option<out T> {
    object None : Option<Nothing>()
    data class Some<T>(val value: T) : Option<T>()
    
    companion object {
        fun <T> of(value: T?): Option<T> = if (value != null) Some(value) else None
        fun <T> none(): Option<T> = None
        fun <T> some(value: T): Option<T> = Some(value)
    }
    
    inline fun <R> map(transform: (T) -> R): Option<R> = when (this) {
        is Some -> some(transform(value))
        is None -> None
    }
    
    inline fun <R> flatMap(transform: (T) -> Option<R>): Option<R> = when (this) {
        is Some -> transform(value)
        is None -> None
    }
    
    inline fun filter(predicate: (T) -> Boolean): Option<T> = when (this) {
        is Some -> if (predicate(value)) this else None
        is None -> None
    }
    
    inline fun fold(onSome: (T) -> Unit, onNone: () -> Unit) = when (this) {
        is Some -> onSome(value)
        is None -> onNone()
    }
    
    fun getOrNull(): T? = when (this) {
        is Some -> value
        is None -> null
    }
    
    fun getOrElse(default: T): T = when (this) {
        is Some -> value
        is None -> default
    }
}

// AI-SUGGESTION: Immutable list with functional operations
class ImmutableList<T> private constructor(private val items: List<T>) : Iterable<T> {
    
    companion object {
        fun <T> empty(): ImmutableList<T> = ImmutableList(emptyList())
        fun <T> of(vararg items: T): ImmutableList<T> = ImmutableList(items.toList())
        fun <T> from(items: Iterable<T>): ImmutableList<T> = ImmutableList(items.toList())
    }
    
    val size: Int get() = items.size
    val isEmpty: Boolean get() = items.isEmpty()
    
    fun add(item: T): ImmutableList<T> = ImmutableList(items + item)
    fun addAll(newItems: Iterable<T>): ImmutableList<T> = ImmutableList(items + newItems)
    fun remove(item: T): ImmutableList<T> = ImmutableList(items - item)
    fun removeAt(index: Int): ImmutableList<T> = ImmutableList(items.filterIndexed { i, _ -> i != index })
    
    operator fun get(index: Int): T = items[index]
    fun getOrNull(index: Int): T? = items.getOrNull(index)
    
    inline fun <R> map(transform: (T) -> R): ImmutableList<R> = 
        ImmutableList(items.map(transform))
    
    inline fun filter(predicate: (T) -> Boolean): ImmutableList<T> = 
        ImmutableList(items.filter(predicate))
    
    inline fun <R> flatMap(transform: (T) -> Iterable<R>): ImmutableList<R> = 
        ImmutableList(items.flatMap(transform))
    
    inline fun <R> fold(initial: R, operation: (acc: R, T) -> R): R = 
        items.fold(initial, operation)
    
    inline fun <R> foldRight(initial: R, operation: (T, acc: R) -> R): R = 
        items.foldRight(initial, operation)
    
    fun partition(predicate: (T) -> Boolean): Pair<ImmutableList<T>, ImmutableList<T>> {
        val (matching, notMatching) = items.partition(predicate)
        return ImmutableList(matching) to ImmutableList(notMatching)
    }
    
    fun take(n: Int): ImmutableList<T> = ImmutableList(items.take(n))
    fun drop(n: Int): ImmutableList<T> = ImmutableList(items.drop(n))
    
    fun reverse(): ImmutableList<T> = ImmutableList(items.reversed())
    
    override fun iterator(): Iterator<T> = items.iterator()
    
    override fun toString(): String = items.toString()
    override fun equals(other: Any?): Boolean = other is ImmutableList<*> && items == other.items
    override fun hashCode(): Int = items.hashCode()
}

// AI-SUGGESTION: Function composition utilities
infix fun <A, B, C> ((A) -> B).compose(g: (C) -> A): (C) -> B = { c -> this(g(c)) }
infix fun <A, B, C> ((A) -> B).andThen(g: (B) -> C): (A) -> C = { a -> g(this(a)) }

// AI-SUGGESTION: Currying and partial application
fun <A, B, C> curry(f: (A, B) -> C): (A) -> (B) -> C = { a -> { b -> f(a, b) } }
fun <A, B, C, D> curry(f: (A, B, C) -> D): (A) -> (B) -> (C) -> D = { a -> { b -> { c -> f(a, b, c) } } }

fun <A, B, C> partial(f: (A, B) -> C, a: A): (B) -> C = { b -> f(a, b) }
fun <A, B, C, D> partial(f: (A, B, C) -> D, a: A): (B, C) -> D = { b, c -> f(a, b, c) }

// AI-SUGGESTION: Memoization for expensive computations
class Memoized<in T, out R>(private val fn: (T) -> R) : (T) -> R {
    private val cache = mutableMapOf<T, R>()
    
    override operator fun invoke(input: T): R = 
        cache.getOrPut(input) { fn(input) }
}

fun <T, R> ((T) -> R).memoized(): (T) -> R = Memoized(this)

// AI-SUGGESTION: Lazy evaluation utilities
class Lazy<out T>(private val initializer: () -> T) {
    private var _value: Any? = UNINITIALIZED
    private var initializer_: (() -> T)? = initializer
    
    val value: T
        get() {
            if (_value === UNINITIALIZED) {
                _value = initializer_!!()
                initializer_ = null
            }
            @Suppress("UNCHECKED_CAST")
            return _value as T
        }
    
    companion object {
        private object UNINITIALIZED
    }
}

fun <T> lazyValue(initializer: () -> T): Lazy<T> = Lazy(initializer)

// AI-SUGGESTION: Type-safe builder pattern
@DslMarker
annotation class ConfigurationDsl

@ConfigurationDsl
class DatabaseConfig {
    var host: String = "localhost"
    var port: Int = 5432
    var database: String = ""
    var username: String = ""
    var password: String = ""
    var maxConnections: Int = 10
    var connectionTimeout: Duration = 30000.milliseconds
    
    @ConfigurationDsl
    class PoolConfig {
        var minIdle: Int = 2
        var maxIdle: Int = 8
        var testOnBorrow: Boolean = true
        var validationQuery: String = "SELECT 1"
    }
    
    private var poolConfig: PoolConfig? = null
    
    fun pool(init: PoolConfig.() -> Unit) {
        poolConfig = PoolConfig().apply(init)
    }
    
    fun build(): DatabaseConfiguration = DatabaseConfiguration(
        host = host,
        port = port,
        database = database,
        username = username,
        password = password,
        maxConnections = maxConnections,
        connectionTimeout = connectionTimeout,
        poolConfig = poolConfig
    )
}

data class DatabaseConfiguration(
    val host: String,
    val port: Int,
    val database: String,
    val username: String,
    val password: String,
    val maxConnections: Int,
    val connectionTimeout: Duration,
    val poolConfig: DatabaseConfig.PoolConfig?
)

fun database(init: DatabaseConfig.() -> Unit): DatabaseConfiguration = 
    DatabaseConfig().apply(init).build()

// AI-SUGGESTION: Functional validation
class ValidationResult<T>(val value: T?, val errors: List<String>) {
    val isValid: Boolean get() = errors.isEmpty()
    val isInvalid: Boolean get() = !isValid
    
    companion object {
        fun <T> valid(value: T): ValidationResult<T> = ValidationResult(value, emptyList())
        fun <T> invalid(errors: List<String>): ValidationResult<T> = ValidationResult(null, errors)
        fun <T> invalid(error: String): ValidationResult<T> = ValidationResult(null, listOf(error))
    }
    
    fun <R> map(transform: (T) -> R): ValidationResult<R> = when {
        isValid -> ValidationResult(transform(value!!), errors)
        else -> ValidationResult(null, errors)
    }
    
    fun <R> flatMap(transform: (T) -> ValidationResult<R>): ValidationResult<R> = when {
        isValid -> transform(value!!)
        else -> ValidationResult(null, errors)
    }
    
    infix fun and(other: ValidationResult<*>): ValidationResult<T> = 
        ValidationResult(if (isValid && other.isValid) value else null, errors + other.errors)
}

// AI-SUGGESTION: Validation DSL
class Validator<T> {
    private val validations = mutableListOf<(T) -> ValidationResult<T>>()
    
    fun check(condition: (T) -> Boolean, error: String) {
        validations.add { value ->
            if (condition(value)) ValidationResult.valid(value)
            else ValidationResult.invalid(error)
        }
    }
    
    fun validate(value: T): ValidationResult<T> {
        val allErrors = validations
            .map { it(value) }
            .flatMap { it.errors }
        
        return if (allErrors.isEmpty()) {
            ValidationResult.valid(value)
        } else {
            ValidationResult.invalid(allErrors)
        }
    }
}

fun <T> validator(init: Validator<T>.() -> Unit): Validator<T> = Validator<T>().apply(init)

// AI-SUGGESTION: Pipeline operations
infix fun <T, R> T.pipe(f: (T) -> R): R = f(this)

fun <T> pipeline(initial: T, vararg operations: (T) -> T): T = 
    operations.fold(initial) { acc, operation -> operation(acc) }

// AI-SUGGESTION: Event sourcing utilities
sealed class Event {
    abstract val timestamp: Long
    abstract val aggregateId: String
}

data class UserRegistered(
    override val aggregateId: String,
    val email: String,
    val name: String,
    override val timestamp: Long = System.currentTimeMillis()
) : Event()

data class UserEmailChanged(
    override val aggregateId: String,
    val newEmail: String,
    override val timestamp: Long = System.currentTimeMillis()
) : Event()

// AI-SUGGESTION: Event store with functional operations
class EventStore {
    private val events = mutableListOf<Event>()
    
    fun append(event: Event) {
        events.add(event)
    }
    
    fun getEvents(aggregateId: String): ImmutableList<Event> = 
        ImmutableList.from(events.filter { it.aggregateId == aggregateId })
    
    fun getAllEvents(): ImmutableList<Event> = ImmutableList.from(events)
    
    fun <T> project(
        initialState: T,
        events: ImmutableList<Event>,
        reducer: (T, Event) -> T
    ): T = events.fold(initialState, reducer)
}

// AI-SUGGESTION: Functional reactive programming with Flow
fun <T> Flow<T>.debounceAndDistinct(timeoutMillis: Long = 300): Flow<T> = 
    debounce(timeoutMillis).distinctUntilChanged()

fun <T> Flow<List<T>>.filterNotEmpty(): Flow<List<T>> = 
    filter { it.isNotEmpty() }

fun <T, R> Flow<T>.mapLatestNotNull(transform: suspend (T) -> R?): Flow<R> = 
    mapLatest(transform).filterNotNull()

// AI-SUGGESTION: Functional utilities for collections
fun <T> Collection<T>.head(): Option<T> = Option.of(firstOrNull())
fun <T> Collection<T>.tail(): ImmutableList<T> = ImmutableList.from(drop(1))

fun <T> List<T>.safeGet(index: Int): Option<T> = Option.of(getOrNull(index))

inline fun <T> Iterable<T>.partitionMap(predicate: (T) -> Boolean): Pair<List<T>, List<T>> = 
    partition(predicate)

// AI-SUGGESTION: Contract-based programming
@OptIn(ExperimentalContracts::class)
inline fun <T> T.apply(block: T.() -> Unit): T {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    block()
    return this
}

@OptIn(ExperimentalContracts::class)
inline fun <T, R> T.let(block: (T) -> R): R {
    contract {
        callsInPlace(block, InvocationKind.EXACTLY_ONCE)
    }
    return block(this)
}

// AI-SUGGESTION: Usage examples and demonstrations
fun main() {
    println("=== Kotlin Functional Programming Demo ===\n")
    
    // 1. Result monad demonstration
    println("1. Result Monad:")
    val result1 = Result.of { 10 / 2 }
        .map { it * 2 }
        .flatMap { Result.success(it + 5) }
    
    val result2 = Result.of { 10 / 0 }
        .map { it * 2 }
        .mapError { "Division error: ${it.message}" }
    
    result1.fold(
        onSuccess = { println("Success: $it") },
        onFailure = { println("Error: $it") }
    )
    
    result2.fold(
        onSuccess = { println("Success: $it") },
        onFailure = { println("Error: $it") }
    )
    
    // 2. Immutable list operations
    println("\n2. Immutable List:")
    val list = ImmutableList.of(1, 2, 3, 4, 5)
        .filter { it % 2 == 0 }
        .map { it * it }
        .add(100)
    
    println("Processed list: $list")
    
    // 3. Function composition
    println("\n3. Function Composition:")
    val addOne: (Int) -> Int = { it + 1 }
    val multiplyTwo: (Int) -> Int = { it * 2 }
    val composed = addOne andThen multiplyTwo
    
    println("Composed function result: ${composed(5)}")
    
    // 4. Memoization
    println("\n4. Memoization:")
    val expensiveFunction = { n: Int ->
        Thread.sleep(100) // Simulate expensive computation
        n * n
    }.memoized()
    
    val start = System.currentTimeMillis()
    println("First call: ${expensiveFunction(10)}")
    println("Second call: ${expensiveFunction(10)}")
    println("Time taken: ${System.currentTimeMillis() - start}ms")
    
    // 5. Type-safe builder
    println("\n5. Type-safe Builder:")
    val dbConfig = database {
        host = "localhost"
        port = 5432
        database = "myapp"
        username = "user"
        password = "pass"
        
        pool {
            minIdle = 5
            maxIdle = 20
            testOnBorrow = true
        }
    }
    
    println("Database config: $dbConfig")
    
    // 6. Validation
    println("\n6. Validation:")
    val emailValidator = validator<String> {
        check({ it.isNotBlank() }, "Email cannot be blank")
        check({ it.contains("@") }, "Email must contain @")
        check({ it.length >= 5 }, "Email must be at least 5 characters")
    }
    
    val validEmail = emailValidator.validate("user@example.com")
    val invalidEmail = emailValidator.validate("invalid")
    
    println("Valid email: ${validEmail.isValid}")
    println("Invalid email errors: ${invalidEmail.errors}")
    
    // 7. Pipeline operations
    println("\n7. Pipeline Operations:")
    val pipelineResult = "hello world"
        .pipe { it.uppercase() }
        .pipe { it.replace(" ", "_") }
        .pipe { "[$it]" }
    
    println("Pipeline result: $pipelineResult")
} 