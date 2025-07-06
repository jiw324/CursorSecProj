// AI-Generated Code Header
// **Intent:** Demonstrate Kotlin data classes, coroutines, and repository pattern
// **Optimization:** Efficient coroutine-based data access with caching
// **Safety:** Null safety, exception handling, and structured concurrency

package com.example.repository

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.time.LocalDateTime
import java.util.concurrent.ConcurrentHashMap

// AI-SUGGESTION: Data classes showcase Kotlin's concise syntax and automatic implementations
data class User(
    val id: Long,
    val username: String,
    val email: String,
    val createdAt: LocalDateTime = LocalDateTime.now(),
    val isActive: Boolean = true
) {
    // AI-SUGGESTION: Custom validation using Kotlin's init block
    init {
        require(username.isNotBlank()) { "Username cannot be blank" }
        require(email.contains("@")) { "Invalid email format" }
    }
}

data class UserPreferences(
    val userId: Long,
    val theme: String = "light",
    val notifications: Boolean = true,
    val language: String = "en"
)

// AI-SUGGESTION: Sealed classes for type-safe result handling
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val exception: Throwable) : Result<Nothing>()
    object Loading : Result<Nothing>()
}

// AI-SUGGESTION: Interface for dependency injection and testing
interface UserDataSource {
    suspend fun getUserById(id: Long): User?
    suspend fun getUsersByStatus(isActive: Boolean): List<User>
    suspend fun createUser(user: User): User
    suspend fun updateUser(user: User): User
    suspend fun deleteUser(id: Long): Boolean
}

// AI-SUGGESTION: Mock implementation for demonstration
class MockUserDataSource : UserDataSource {
    private val users = ConcurrentHashMap<Long, User>()
    
    init {
        // Seed with sample data
        users[1L] = User(1L, "john_doe", "john@example.com")
        users[2L] = User(2L, "jane_smith", "jane@example.com")
        users[3L] = User(3L, "inactive_user", "inactive@example.com", isActive = false)
    }
    
    override suspend fun getUserById(id: Long): User? {
        delay(100) // Simulate network delay
        return users[id]
    }
    
    override suspend fun getUsersByStatus(isActive: Boolean): List<User> {
        delay(150)
        return users.values.filter { it.isActive == isActive }
    }
    
    override suspend fun createUser(user: User): User {
        delay(200)
        users[user.id] = user
        return user
    }
    
    override suspend fun updateUser(user: User): User {
        delay(150)
        users[user.id] = user
        return user
    }
    
    override suspend fun deleteUser(id: Long): Boolean {
        delay(100)
        return users.remove(id) != null
    }
}

// AI-SUGGESTION: Repository pattern with caching and Flow-based reactive programming
class UserRepository(
    private val dataSource: UserDataSource,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
) {
    private val cache = ConcurrentHashMap<Long, User>()
    private val _userUpdates = MutableSharedFlow<User>()
    val userUpdates: SharedFlow<User> = _userUpdates.asSharedFlow()
    
    // AI-SUGGESTION: Flow-based reactive data access
    fun observeUser(id: Long): Flow<Result<User?>> = flow {
        emit(Result.Loading)
        try {
            // Check cache first
            cache[id]?.let { cachedUser ->
                emit(Result.Success(cachedUser))
            }
            
            // Fetch from data source
            val user = dataSource.getUserById(id)
            user?.let { cache[it.id] = it }
            emit(Result.Success(user))
        } catch (e: Exception) {
            emit(Result.Error(e))
        }
    }.flowOn(Dispatchers.IO)
    
    // AI-SUGGESTION: Suspend function with caching strategy
    suspend fun getUserById(id: Long, forceRefresh: Boolean = false): Result<User?> {
        return try {
            if (!forceRefresh && cache.containsKey(id)) {
                Result.Success(cache[id])
            } else {
                val user = dataSource.getUserById(id)
                user?.let { cache[it.id] = it }
                Result.Success(user)
            }
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    // AI-SUGGESTION: Batch operations with parallel processing
    suspend fun getUsersInParallel(ids: List<Long>): Map<Long, User?> {
        return coroutineScope {
            ids.map { id ->
                async { id to dataSource.getUserById(id) }
            }.awaitAll().toMap()
        }
    }
    
    // AI-SUGGESTION: Search functionality with Flow
    fun searchUsers(query: String): Flow<List<User>> = flow {
        val activeUsers = dataSource.getUsersByStatus(true)
        val filtered = activeUsers.filter { user ->
            user.username.contains(query, ignoreCase = true) ||
            user.email.contains(query, ignoreCase = true)
        }
        emit(filtered)
    }.flowOn(Dispatchers.IO)
    
    // AI-SUGGESTION: CRUD operations with event emission
    suspend fun createUser(username: String, email: String): Result<User> {
        return try {
            val newUser = User(
                id = System.currentTimeMillis(), // Simple ID generation
                username = username,
                email = email
            )
            val createdUser = dataSource.createUser(newUser)
            cache[createdUser.id] = createdUser
            _userUpdates.emit(createdUser)
            Result.Success(createdUser)
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    suspend fun updateUser(user: User): Result<User> {
        return try {
            val updatedUser = dataSource.updateUser(user)
            cache[updatedUser.id] = updatedUser
            _userUpdates.emit(updatedUser)
            Result.Success(updatedUser)
        } catch (e: Exception) {
            Result.Error(e)
        }
    }
    
    // AI-SUGGESTION: Cleanup method for proper resource management
    fun cleanup() {
        scope.cancel()
        cache.clear()
    }
}

// AI-SUGGESTION: Extension functions demonstrate Kotlin's powerful syntax
fun User.toDisplayName(): String = "$username ($email)"

fun User.isRecentlyCreated(): Boolean {
    val now = LocalDateTime.now()
    return createdAt.isAfter(now.minusDays(7))
}

// AI-SUGGESTION: Higher-order functions and functional programming
fun List<User>.filterActiveUsers(): List<User> = filter { it.isActive }

fun List<User>.groupByDomain(): Map<String, List<User>> {
    return groupBy { user ->
        user.email.substringAfter("@")
    }
}

// AI-SUGGESTION: Usage example and demonstration
suspend fun main() {
    val repository = UserRepository(MockUserDataSource())
    
    // Demonstrate reactive programming with Flow
    repository.observeUser(1L)
        .collect { result ->
            when (result) {
                is Result.Loading -> println("Loading user...")
                is Result.Success -> println("User loaded: ${result.data}")
                is Result.Error -> println("Error: ${result.exception.message}")
            }
        }
    
    // Demonstrate parallel processing
    val userIds = listOf(1L, 2L, 3L)
    val users = repository.getUsersInParallel(userIds)
    println("Parallel fetch results: $users")
    
    // Demonstrate search functionality
    repository.searchUsers("john")
        .collect { users ->
            println("Search results: ${users.map { it.toDisplayName() }}")
        }
    
    // Cleanup
    repository.cleanup()
} 