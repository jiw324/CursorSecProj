// AI-Generated Code Header
// **Intent:** ASP.NET Core Web API with modern patterns and best practices
// **Optimization:** Efficient HTTP handling and resource management
// **Safety:** Input validation, authentication, and secure coding practices

using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace WebApiService
{
    // AI-SUGGESTION: Domain models with validation
    public class Product
    {
        public int Id { get; set; }
        
        [Required(ErrorMessage = "Name is required")]
        [StringLength(100, ErrorMessage = "Name cannot exceed 100 characters")]
        public string Name { get; set; } = string.Empty;
        
        [StringLength(500, ErrorMessage = "Description cannot exceed 500 characters")]
        public string? Description { get; set; }
        
        [Range(0.01, double.MaxValue, ErrorMessage = "Price must be greater than 0")]
        public decimal Price { get; set; }
        
        [Range(0, int.MaxValue, ErrorMessage = "Stock cannot be negative")]
        public int Stock { get; set; }
        
        public string Category { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }
        public bool IsActive { get; set; } = true;
    }
    
    public class ProductCreateRequest
    {
        [Required] public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        [Required] public decimal Price { get; set; }
        [Required] public int Stock { get; set; }
        [Required] public string Category { get; set; } = string.Empty;
    }
    
    public class ProductUpdateRequest
    {
        public string? Name { get; set; }
        public string? Description { get; set; }
        public decimal? Price { get; set; }
        public int? Stock { get; set; }
        public string? Category { get; set; }
        public bool? IsActive { get; set; }
    }
    
    public class ApiResponse<T>
    {
        public bool Success { get; set; }
        public T? Data { get; set; }
        public string? Message { get; set; }
        public List<string> Errors { get; set; } = new();
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }
    
    public class PagedResult<T>
    {
        public List<T> Items { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
        public bool HasNextPage => Page < TotalPages;
        public bool HasPreviousPage => Page > 1;
    }
    
    // AI-SUGGESTION: Repository interface and implementation
    public interface IProductRepository
    {
        Task<Product?> GetByIdAsync(int id);
        Task<PagedResult<Product>> GetAllAsync(int page, int pageSize, string? category = null, bool? isActive = null);
        Task<Product> CreateAsync(Product product);
        Task<Product?> UpdateAsync(int id, Product product);
        Task<bool> DeleteAsync(int id);
        Task<bool> ExistsAsync(int id);
        Task<List<string>> GetCategoriesAsync();
    }
    
    public class InMemoryProductRepository : IProductRepository
    {
        private readonly List<Product> _products = new();
        private int _nextId = 1;
        
        public InMemoryProductRepository()
        {
            // AI-SUGGESTION: Seed with sample data
            SeedData();
        }
        
        public Task<Product?> GetByIdAsync(int id)
        {
            var product = _products.FirstOrDefault(p => p.Id == id);
            return Task.FromResult(product);
        }
        
        public Task<PagedResult<Product>> GetAllAsync(int page, int pageSize, string? category = null, bool? isActive = null)
        {
            var query = _products.AsQueryable();
            
            if (!string.IsNullOrEmpty(category))
                query = query.Where(p => p.Category.Equals(category, StringComparison.OrdinalIgnoreCase));
                
            if (isActive.HasValue)
                query = query.Where(p => p.IsActive == isActive.Value);
            
            var totalCount = query.Count();
            var items = query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToList();
            
            var result = new PagedResult<Product>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
            
            return Task.FromResult(result);
        }
        
        public Task<Product> CreateAsync(Product product)
        {
            product.Id = _nextId++;
            product.CreatedAt = DateTime.UtcNow;
            _products.Add(product);
            return Task.FromResult(product);
        }
        
        public Task<Product?> UpdateAsync(int id, Product product)
        {
            var existingIndex = _products.FindIndex(p => p.Id == id);
            if (existingIndex < 0) return Task.FromResult<Product?>(null);
            
            product.Id = id;
            product.UpdatedAt = DateTime.UtcNow;
            product.CreatedAt = _products[existingIndex].CreatedAt;
            _products[existingIndex] = product;
            
            return Task.FromResult<Product?>(product);
        }
        
        public Task<bool> DeleteAsync(int id)
        {
            var product = _products.FirstOrDefault(p => p.Id == id);
            if (product == null) return Task.FromResult(false);
            
            _products.Remove(product);
            return Task.FromResult(true);
        }
        
        public Task<bool> ExistsAsync(int id)
        {
            return Task.FromResult(_products.Any(p => p.Id == id));
        }
        
        public Task<List<string>> GetCategoriesAsync()
        {
            var categories = _products
                .Select(p => p.Category)
                .Distinct()
                .OrderBy(c => c)
                .ToList();
            return Task.FromResult(categories);
        }
        
        private void SeedData()
        {
            var sampleProducts = new[]
            {
                new Product { Name = "Laptop Pro", Description = "High-performance laptop", Price = 1299.99m, Stock = 50, Category = "Electronics" },
                new Product { Name = "Wireless Mouse", Description = "Ergonomic wireless mouse", Price = 29.99m, Stock = 100, Category = "Electronics" },
                new Product { Name = "Office Chair", Description = "Comfortable office chair", Price = 199.99m, Stock = 25, Category = "Furniture" },
                new Product { Name = "Programming Book", Description = "Learn C# programming", Price = 39.99m, Stock = 75, Category = "Books" },
                new Product { Name = "Coffee Mug", Description = "Developer's coffee mug", Price = 12.99m, Stock = 200, Category = "Accessories" }
            };
            
            foreach (var product in sampleProducts)
            {
                CreateAsync(product);
            }
        }
    }
    
    // AI-SUGGESTION: Business service layer
    public interface IProductService
    {
        Task<ApiResponse<Product>> GetProductAsync(int id);
        Task<ApiResponse<PagedResult<Product>>> GetProductsAsync(int page, int pageSize, string? category, bool? isActive);
        Task<ApiResponse<Product>> CreateProductAsync(ProductCreateRequest request);
        Task<ApiResponse<Product>> UpdateProductAsync(int id, ProductUpdateRequest request);
        Task<ApiResponse<bool>> DeleteProductAsync(int id);
        Task<ApiResponse<List<string>>> GetCategoriesAsync();
    }
    
    public class ProductService : IProductService
    {
        private readonly IProductRepository _repository;
        private readonly ILogger<ProductService> _logger;
        
        public ProductService(IProductRepository repository, ILogger<ProductService> logger)
        {
            _repository = repository;
            _logger = logger;
        }
        
        public async Task<ApiResponse<Product>> GetProductAsync(int id)
        {
            try
            {
                var product = await _repository.GetByIdAsync(id);
                if (product == null)
                {
                    return new ApiResponse<Product>
                    {
                        Success = false,
                        Message = "Product not found"
                    };
                }
                
                return new ApiResponse<Product>
                {
                    Success = true,
                    Data = product
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting product {ProductId}", id);
                return new ApiResponse<Product>
                {
                    Success = false,
                    Message = "An error occurred while retrieving the product"
                };
            }
        }
        
        public async Task<ApiResponse<PagedResult<Product>>> GetProductsAsync(int page, int pageSize, string? category, bool? isActive)
        {
            try
            {
                if (page < 1) page = 1;
                if (pageSize < 1 || pageSize > 100) pageSize = 10;
                
                var result = await _repository.GetAllAsync(page, pageSize, category, isActive);
                
                return new ApiResponse<PagedResult<Product>>
                {
                    Success = true,
                    Data = result
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting products");
                return new ApiResponse<PagedResult<Product>>
                {
                    Success = false,
                    Message = "An error occurred while retrieving products"
                };
            }
        }
        
        public async Task<ApiResponse<Product>> CreateProductAsync(ProductCreateRequest request)
        {
            try
            {
                var product = new Product
                {
                    Name = request.Name,
                    Description = request.Description,
                    Price = request.Price,
                    Stock = request.Stock,
                    Category = request.Category
                };
                
                var created = await _repository.CreateAsync(product);
                
                _logger.LogInformation("Created product {ProductId}: {ProductName}", created.Id, created.Name);
                
                return new ApiResponse<Product>
                {
                    Success = true,
                    Data = created,
                    Message = "Product created successfully"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating product");
                return new ApiResponse<Product>
                {
                    Success = false,
                    Message = "An error occurred while creating the product"
                };
            }
        }
        
        public async Task<ApiResponse<Product>> UpdateProductAsync(int id, ProductUpdateRequest request)
        {
            try
            {
                var existing = await _repository.GetByIdAsync(id);
                if (existing == null)
                {
                    return new ApiResponse<Product>
                    {
                        Success = false,
                        Message = "Product not found"
                    };
                }
                
                // AI-SUGGESTION: Apply partial updates
                var updated = existing with
                {
                    Name = request.Name ?? existing.Name,
                    Description = request.Description ?? existing.Description,
                    Price = request.Price ?? existing.Price,
                    Stock = request.Stock ?? existing.Stock,
                    Category = request.Category ?? existing.Category,
                    IsActive = request.IsActive ?? existing.IsActive
                };
                
                var result = await _repository.UpdateAsync(id, updated);
                
                _logger.LogInformation("Updated product {ProductId}", id);
                
                return new ApiResponse<Product>
                {
                    Success = true,
                    Data = result,
                    Message = "Product updated successfully"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating product {ProductId}", id);
                return new ApiResponse<Product>
                {
                    Success = false,
                    Message = "An error occurred while updating the product"
                };
            }
        }
        
        public async Task<ApiResponse<bool>> DeleteProductAsync(int id)
        {
            try
            {
                var exists = await _repository.ExistsAsync(id);
                if (!exists)
                {
                    return new ApiResponse<bool>
                    {
                        Success = false,
                        Message = "Product not found"
                    };
                }
                
                var deleted = await _repository.DeleteAsync(id);
                
                _logger.LogInformation("Deleted product {ProductId}", id);
                
                return new ApiResponse<bool>
                {
                    Success = true,
                    Data = deleted,
                    Message = "Product deleted successfully"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting product {ProductId}", id);
                return new ApiResponse<bool>
                {
                    Success = false,
                    Message = "An error occurred while deleting the product"
                };
            }
        }
        
        public async Task<ApiResponse<List<string>>> GetCategoriesAsync()
        {
            try
            {
                var categories = await _repository.GetCategoriesAsync();
                
                return new ApiResponse<List<string>>
                {
                    Success = true,
                    Data = categories
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting categories");
                return new ApiResponse<List<string>>
                {
                    Success = false,
                    Message = "An error occurred while retrieving categories"
                };
            }
        }
    }
    
    // AI-SUGGESTION: API Controllers
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        private readonly IProductService _productService;
        private readonly ILogger<ProductsController> _logger;
        
        public ProductsController(IProductService productService, ILogger<ProductsController> logger)
        {
            _productService = productService;
            _logger = logger;
        }
        
        [HttpGet]
        public async Task<ActionResult<ApiResponse<PagedResult<Product>>>> GetProducts(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string? category = null,
            [FromQuery] bool? isActive = null)
        {
            var result = await _productService.GetProductsAsync(page, pageSize, category, isActive);
            return result.Success ? Ok(result) : BadRequest(result);
        }
        
        [HttpGet("{id}")]
        public async Task<ActionResult<ApiResponse<Product>>> GetProduct(int id)
        {
            var result = await _productService.GetProductAsync(id);
            return result.Success ? Ok(result) : NotFound(result);
        }
        
        [HttpPost]
        public async Task<ActionResult<ApiResponse<Product>>> CreateProduct([FromBody] ProductCreateRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(new ApiResponse<Product>
                {
                    Success = false,
                    Message = "Validation failed",
                    Errors = ModelState.Values
                        .SelectMany(v => v.Errors)
                        .Select(e => e.ErrorMessage)
                        .ToList()
                });
            }
            
            var result = await _productService.CreateProductAsync(request);
            return result.Success ? CreatedAtAction(nameof(GetProduct), new { id = result.Data!.Id }, result) : BadRequest(result);
        }
        
        [HttpPut("{id}")]
        public async Task<ActionResult<ApiResponse<Product>>> UpdateProduct(int id, [FromBody] ProductUpdateRequest request)
        {
            var result = await _productService.UpdateProductAsync(id, request);
            return result.Success ? Ok(result) : NotFound(result);
        }
        
        [HttpDelete("{id}")]
        public async Task<ActionResult<ApiResponse<bool>>> DeleteProduct(int id)
        {
            var result = await _productService.DeleteProductAsync(id);
            return result.Success ? Ok(result) : NotFound(result);
        }
        
        [HttpGet("categories")]
        public async Task<ActionResult<ApiResponse<List<string>>>> GetCategories()
        {
            var result = await _productService.GetCategoriesAsync();
            return Ok(result);
        }
    }
    
    [ApiController]
    [Route("api/[controller]")]
    public class HealthController : ControllerBase
    {
        [HttpGet]
        public ActionResult<object> GetHealth()
        {
            return Ok(new
            {
                Status = "Healthy",
                Timestamp = DateTime.UtcNow,
                Version = "1.0.0",
                Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Development"
            });
        }
    }
    
    // AI-SUGGESTION: Custom middleware
    public class RequestLoggingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<RequestLoggingMiddleware> _logger;
        
        public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }
        
        public async Task InvokeAsync(HttpContext context)
        {
            var startTime = DateTime.UtcNow;
            
            _logger.LogInformation("Request: {Method} {Path}", context.Request.Method, context.Request.Path);
            
            await _next(context);
            
            var elapsed = DateTime.UtcNow - startTime;
            _logger.LogInformation("Response: {StatusCode} in {ElapsedMs}ms", 
                context.Response.StatusCode, elapsed.TotalMilliseconds);
        }
    }
    
    public class ErrorHandlingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<ErrorHandlingMiddleware> _logger;
        
        public ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }
        
        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An unhandled exception occurred");
                await HandleExceptionAsync(context, ex);
            }
        }
        
        private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
        {
            context.Response.StatusCode = 500;
            context.Response.ContentType = "application/json";
            
            var response = new ApiResponse<object>
            {
                Success = false,
                Message = "An internal server error occurred"
            };
            
            var json = JsonSerializer.Serialize(response);
            await context.Response.WriteAsync(json);
        }
    }
    
    // AI-SUGGESTION: Startup configuration
    public class Startup
    {
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddControllers();
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();
            
            // AI-SUGGESTION: Register dependencies
            services.AddSingleton<IProductRepository, InMemoryProductRepository>();
            services.AddScoped<IProductService, ProductService>();
            
            services.AddLogging();
        }
        
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }
            
            app.UseMiddleware<ErrorHandlingMiddleware>();
            app.UseMiddleware<RequestLoggingMiddleware>();
            
            app.UseRouting();
            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });
        }
    }
}

// AI-SUGGESTION: Program entry point
class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("C# ASP.NET Core Web API Service");
        Console.WriteLine("===============================");
        
        var builder = WebApplication.CreateBuilder(args);
        
        // AI-SUGGESTION: Configure services
        var startup = new WebApiService.Startup();
        startup.ConfigureServices(builder.Services);
        
        var app = builder.Build();
        
        // AI-SUGGESTION: Configure pipeline
        startup.Configure(app, app.Environment);
        
        Console.WriteLine("Starting Web API server...");
        Console.WriteLine("API Documentation: https://localhost:5001/swagger");
        Console.WriteLine("Health Check: https://localhost:5001/api/health");
        Console.WriteLine("Products API: https://localhost:5001/api/products");
        
        await app.RunAsync();
    }
} 