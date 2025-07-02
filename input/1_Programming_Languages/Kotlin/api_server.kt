// AI-Generated Code Header
// **Intent:** Demonstrate Kotlin REST API server using Ktor framework
// **Optimization:** Efficient routing, serialization, and middleware patterns
// **Safety:** Input validation, error handling, and security features

package com.example.api

import io.ktor.application.*
import io.ktor.features.*
import io.ktor.gson.*
import io.ktor.http.*
import io.ktor.request.*
import io.ktor.response.*
import io.ktor.routing.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.LocalDateTime
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlin.time.Duration.Companion.seconds

// AI-SUGGESTION: Data models with validation
data class Product(
    val id: Long,
    val name: String,
    val description: String,
    val price: Double,
    val category: ProductCategory,
    val inStock: Boolean = true,
    val createdAt: LocalDateTime = LocalDateTime.now(),
    val updatedAt: LocalDateTime = LocalDateTime.now()
) {
    init {
        require(name.isNotBlank()) { "Product name cannot be blank" }
        require(price >= 0) { "Product price cannot be negative" }
        require(description.isNotBlank()) { "Product description cannot be blank" }
    }
}

enum class ProductCategory {
    ELECTRONICS, CLOTHING, BOOKS, HOME, SPORTS, OTHER
}

data class CreateProductRequest(
    val name: String,
    val description: String,
    val price: Double,
    val category: ProductCategory
)

data class UpdateProductRequest(
    val name: String? = null,
    val description: String? = null,
    val price: Double? = null,
    val category: ProductCategory? = null,
    val inStock: Boolean? = null
)

data class ProductSearchRequest(
    val query: String? = null,
    val category: ProductCategory? = null,
    val minPrice: Double? = null,
    val maxPrice: Double? = null,
    val inStockOnly: Boolean = true,
    val page: Int = 1,
    val pageSize: Int = 20
)

data class ProductResponse(
    val products: List<Product>,
    val totalCount: Int,
    val page: Int,
    val pageSize: Int,
    val hasMore: Boolean
)

data class ApiResponse<T>(
    val success: Boolean,
    val data: T? = null,
    val error: String? = null,
    val timestamp: LocalDateTime = LocalDateTime.now()
)

data class ErrorResponse(
    val code: String,
    val message: String,
    val details: Map<String, Any>? = null
)

// AI-SUGGESTION: Repository interface for data access
interface ProductRepository {
    suspend fun findById(id: Long): Product?
    suspend fun findAll(searchRequest: ProductSearchRequest): ProductResponse
    suspend fun create(product: Product): Product
    suspend fun update(id: Long, updates: UpdateProductRequest): Product?
    suspend fun delete(id: Long): Boolean
    suspend fun getCategories(): List<ProductCategory>
}

// AI-SUGGESTION: In-memory repository implementation
class InMemoryProductRepository : ProductRepository {
    private val products = ConcurrentHashMap<Long, Product>()
    private val idGenerator = AtomicLong(1)
    private val mutex = Mutex()
    
    init {
        // Seed with sample data
        runBlocking {
            create(Product(
                id = idGenerator.getAndIncrement(),
                name = "Laptop Computer",
                description = "High-performance laptop for development",
                price = 1299.99,
                category = ProductCategory.ELECTRONICS
            ))
            
            create(Product(
                id = idGenerator.getAndIncrement(),
                name = "Programming Book",
                description = "Kotlin programming guide",
                price = 49.99,
                category = ProductCategory.BOOKS
            ))
            
            create(Product(
                id = idGenerator.getAndIncrement(),
                name = "Wireless Headphones",
                description = "Noise-cancelling bluetooth headphones",
                price = 199.99,
                category = ProductCategory.ELECTRONICS
            ))
        }
    }
    
    override suspend fun findById(id: Long): Product? = products[id]
    
    override suspend fun findAll(searchRequest: ProductSearchRequest): ProductResponse {
        mutex.withLock {
            var filtered = products.values.toList()
            
            // Apply filters
            searchRequest.query?.let { query ->
                filtered = filtered.filter { product ->
                    product.name.contains(query, ignoreCase = true) ||
                    product.description.contains(query, ignoreCase = true)
                }
            }
            
            searchRequest.category?.let { category ->
                filtered = filtered.filter { it.category == category }
            }
            
            searchRequest.minPrice?.let { minPrice ->
                filtered = filtered.filter { it.price >= minPrice }
            }
            
            searchRequest.maxPrice?.let { maxPrice ->
                filtered = filtered.filter { it.price <= maxPrice }
            }
            
            if (searchRequest.inStockOnly) {
                filtered = filtered.filter { it.inStock }
            }
            
            // Apply pagination
            val totalCount = filtered.size
            val startIndex = (searchRequest.page - 1) * searchRequest.pageSize
            val endIndex = minOf(startIndex + searchRequest.pageSize, totalCount)
            
            val paginatedProducts = if (startIndex < totalCount) {
                filtered.subList(startIndex, endIndex)
            } else {
                emptyList()
            }
            
            return ProductResponse(
                products = paginatedProducts,
                totalCount = totalCount,
                page = searchRequest.page,
                pageSize = searchRequest.pageSize,
                hasMore = endIndex < totalCount
            )
        }
    }
    
    override suspend fun create(product: Product): Product {
        val newProduct = product.copy(id = idGenerator.getAndIncrement())
        products[newProduct.id] = newProduct
        return newProduct
    }
    
    override suspend fun update(id: Long, updates: UpdateProductRequest): Product? {
        return mutex.withLock {
            products[id]?.let { existing ->
                val updated = existing.copy(
                    name = updates.name ?: existing.name,
                    description = updates.description ?: existing.description,
                    price = updates.price ?: existing.price,
                    category = updates.category ?: existing.category,
                    inStock = updates.inStock ?: existing.inStock,
                    updatedAt = LocalDateTime.now()
                )
                products[id] = updated
                updated
            }
        }
    }
    
    override suspend fun delete(id: Long): Boolean {
        return products.remove(id) != null
    }
    
    override suspend fun getCategories(): List<ProductCategory> {
        return ProductCategory.values().toList()
    }
}

// AI-SUGGESTION: Service layer with business logic
class ProductService(private val repository: ProductRepository) {
    
    suspend fun getProduct(id: Long): ApiResponse<Product> {
        return try {
            val product = repository.findById(id)
            if (product != null) {
                ApiResponse(success = true, data = product)
            } else {
                ApiResponse(success = false, error = "Product not found")
            }
        } catch (e: Exception) {
            ApiResponse(success = false, error = "Internal server error: ${e.message}")
        }
    }
    
    suspend fun searchProducts(searchRequest: ProductSearchRequest): ApiResponse<ProductResponse> {
        return try {
            // Validate pagination parameters
            if (searchRequest.page < 1 || searchRequest.pageSize < 1 || searchRequest.pageSize > 100) {
                return ApiResponse(success = false, error = "Invalid pagination parameters")
            }
            
            // Validate price range
            if (searchRequest.minPrice != null && searchRequest.maxPrice != null 
                && searchRequest.minPrice > searchRequest.maxPrice) {
                return ApiResponse(success = false, error = "Invalid price range")
            }
            
            val result = repository.findAll(searchRequest)
            ApiResponse(success = true, data = result)
        } catch (e: Exception) {
            ApiResponse(success = false, error = "Search failed: ${e.message}")
        }
    }
    
    suspend fun createProduct(request: CreateProductRequest): ApiResponse<Product> {
        return try {
            val product = Product(
                id = 0, // Will be assigned by repository
                name = request.name,
                description = request.description,
                price = request.price,
                category = request.category
            )
            val created = repository.create(product)
            ApiResponse(success = true, data = created)
        } catch (e: IllegalArgumentException) {
            ApiResponse(success = false, error = "Validation error: ${e.message}")
        } catch (e: Exception) {
            ApiResponse(success = false, error = "Failed to create product: ${e.message}")
        }
    }
    
    suspend fun updateProduct(id: Long, request: UpdateProductRequest): ApiResponse<Product> {
        return try {
            // Validate update request
            request.price?.let { price ->
                if (price < 0) {
                    return ApiResponse(success = false, error = "Price cannot be negative")
                }
            }
            
            val updated = repository.update(id, request)
            if (updated != null) {
                ApiResponse(success = true, data = updated)
            } else {
                ApiResponse(success = false, error = "Product not found")
            }
        } catch (e: Exception) {
            ApiResponse(success = false, error = "Failed to update product: ${e.message}")
        }
    }
    
    suspend fun deleteProduct(id: Long): ApiResponse<Boolean> {
        return try {
            val deleted = repository.delete(id)
            if (deleted) {
                ApiResponse(success = true, data = true)
            } else {
                ApiResponse(success = false, error = "Product not found")
            }
        } catch (e: Exception) {
            ApiResponse(success = false, error = "Failed to delete product: ${e.message}")
        }
    }
    
    suspend fun getCategories(): ApiResponse<List<ProductCategory>> {
        return try {
            val categories = repository.getCategories()
            ApiResponse(success = true, data = categories)
        } catch (e: Exception) {
            ApiResponse(success = false, error = "Failed to get categories: ${e.message}")
        }
    }
}

// AI-SUGGESTION: Request rate limiting middleware
class RateLimitFeature {
    class Configuration {
        var maxRequestsPerMinute: Int = 60
        var cleanupIntervalSeconds: Long = 60
    }
    
    companion object Feature : ApplicationFeature<ApplicationCallPipeline, Configuration, RateLimitFeature> {
        override val key = AttributeKey<RateLimitFeature>("RateLimit")
        
        override fun install(pipeline: ApplicationCallPipeline, configure: Configuration.() -> Unit): RateLimitFeature {
            val configuration = Configuration().apply(configure)
            val feature = RateLimitFeature()
            
            val requestCounts = ConcurrentHashMap<String, Pair<Long, Int>>()
            
            // Cleanup old entries periodically
            GlobalScope.launch {
                while (true) {
                    delay(configuration.cleanupIntervalSeconds.seconds)
                    val now = System.currentTimeMillis()
                    requestCounts.entries.removeAll { (_, value) ->
                        now - value.first > 60_000 // Remove entries older than 1 minute
                    }
                }
            }
            
            pipeline.intercept(ApplicationCallPipeline.Call) {
                val clientIp = call.request.origin.remoteHost
                val now = System.currentTimeMillis()
                
                val (lastReset, count) = requestCounts.getOrDefault(clientIp, now to 0)
                
                val newCount = if (now - lastReset > 60_000) {
                    requestCounts[clientIp] = now to 1
                    1
                } else {
                    val incremented = count + 1
                    requestCounts[clientIp] = lastReset to incremented
                    incremented
                }
                
                if (newCount > configuration.maxRequestsPerMinute) {
                    call.respond(HttpStatusCode.TooManyRequests, ErrorResponse(
                        code = "RATE_LIMIT_EXCEEDED",
                        message = "Too many requests. Limit: ${configuration.maxRequestsPerMinute} per minute"
                    ))
                    finish()
                }
            }
            
            return feature
        }
    }
}

// AI-SUGGESTION: Main application configuration
fun Application.productApiModule() {
    install(ContentNegotiation) {
        gson {
            setPrettyPrinting()
            setDateFormat("yyyy-MM-dd'T'HH:mm:ss")
        }
    }
    
    install(CORS) {
        method(HttpMethod.Options)
        method(HttpMethod.Get)
        method(HttpMethod.Post)
        method(HttpMethod.Put)
        method(HttpMethod.Delete)
        header(HttpHeaders.ContentType)
        header(HttpHeaders.Authorization)
        anyHost()
    }
    
    install(CallLogging)
    
    install(RateLimitFeature) {
        maxRequestsPerMinute = 100
    }
    
    install(StatusPages) {
        exception<Throwable> { cause ->
            call.respond(HttpStatusCode.InternalServerError, ErrorResponse(
                code = "INTERNAL_ERROR",
                message = "Internal server error",
                details = mapOf("error" to (cause.message ?: "Unknown error"))
            ))
        }
        
        status(HttpStatusCode.NotFound) {
            call.respond(HttpStatusCode.NotFound, ErrorResponse(
                code = "NOT_FOUND",
                message = "Endpoint not found"
            ))
        }
    }
    
    // AI-SUGGESTION: Dependency injection setup
    val productRepository = InMemoryProductRepository()
    val productService = ProductService(productRepository)
    
    routing {
        route("/api/v1") {
            
            // Health check endpoint
            get("/health") {
                call.respond(mapOf(
                    "status" to "healthy",
                    "timestamp" to LocalDateTime.now(),
                    "version" to "1.0.0"
                ))
            }
            
            route("/products") {
                // Get all products with search and pagination
                get {
                    val searchRequest = ProductSearchRequest(
                        query = call.request.queryParameters["query"],
                        category = call.request.queryParameters["category"]?.let { 
                            try { ProductCategory.valueOf(it.uppercase()) } catch (e: Exception) { null }
                        },
                        minPrice = call.request.queryParameters["minPrice"]?.toDoubleOrNull(),
                        maxPrice = call.request.queryParameters["maxPrice"]?.toDoubleOrNull(),
                        inStockOnly = call.request.queryParameters["inStockOnly"]?.toBooleanStrictOrNull() ?: true,
                        page = call.request.queryParameters["page"]?.toIntOrNull() ?: 1,
                        pageSize = call.request.queryParameters["pageSize"]?.toIntOrNull() ?: 20
                    )
                    
                    val response = productService.searchProducts(searchRequest)
                    call.respond(if (response.success) HttpStatusCode.OK else HttpStatusCode.BadRequest, response)
                }
                
                // Get product by ID
                get("/{id}") {
                    val id = call.parameters["id"]?.toLongOrNull()
                    if (id == null) {
                        call.respond(HttpStatusCode.BadRequest, ErrorResponse(
                            code = "INVALID_ID",
                            message = "Invalid product ID"
                        ))
                        return@get
                    }
                    
                    val response = productService.getProduct(id)
                    call.respond(if (response.success) HttpStatusCode.OK else HttpStatusCode.NotFound, response)
                }
                
                // Create new product
                post {
                    try {
                        val request = call.receive<CreateProductRequest>()
                        val response = productService.createProduct(request)
                        call.respond(if (response.success) HttpStatusCode.Created else HttpStatusCode.BadRequest, response)
                    } catch (e: Exception) {
                        call.respond(HttpStatusCode.BadRequest, ErrorResponse(
                            code = "INVALID_REQUEST",
                            message = "Invalid request body"
                        ))
                    }
                }
                
                // Update product
                put("/{id}") {
                    val id = call.parameters["id"]?.toLongOrNull()
                    if (id == null) {
                        call.respond(HttpStatusCode.BadRequest, ErrorResponse(
                            code = "INVALID_ID",
                            message = "Invalid product ID"
                        ))
                        return@put
                    }
                    
                    try {
                        val request = call.receive<UpdateProductRequest>()
                        val response = productService.updateProduct(id, request)
                        call.respond(if (response.success) HttpStatusCode.OK else HttpStatusCode.NotFound, response)
                    } catch (e: Exception) {
                        call.respond(HttpStatusCode.BadRequest, ErrorResponse(
                            code = "INVALID_REQUEST",
                            message = "Invalid request body"
                        ))
                    }
                }
                
                // Delete product
                delete("/{id}") {
                    val id = call.parameters["id"]?.toLongOrNull()
                    if (id == null) {
                        call.respond(HttpStatusCode.BadRequest, ErrorResponse(
                            code = "INVALID_ID",
                            message = "Invalid product ID"
                        ))
                        return@delete
                    }
                    
                    val response = productService.deleteProduct(id)
                    call.respond(if (response.success) HttpStatusCode.OK else HttpStatusCode.NotFound, response)
                }
            }
            
            // Categories endpoint
            get("/categories") {
                val response = productService.getCategories()
                call.respond(HttpStatusCode.OK, response)
            }
        }
    }
}

// AI-SUGGESTION: Server startup function
fun main() {
    embeddedServer(Netty, port = 8080, host = "0.0.0.0") {
        productApiModule()
    }.start(wait = true)
} 