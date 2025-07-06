// AI-Generated Code Header
// **Intent:** Enterprise system demonstrating dependency injection and design patterns
// **Optimization:** Efficient business logic processing and resource management
// **Safety:** Input validation, exception handling, and defensive programming

using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace EnterpriseSystem
{
    // AI-SUGGESTION: Domain models with validation
    public class Customer
    {
        public int Id { get; set; }
        
        [Required(ErrorMessage = "Name is required")]
        [StringLength(100, ErrorMessage = "Name cannot exceed 100 characters")]
        public string Name { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Invalid email format")]
        public string Email { get; set; } = string.Empty;
        
        [Phone(ErrorMessage = "Invalid phone format")]
        public string? Phone { get; set; }
        
        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
        public CustomerType Type { get; set; } = CustomerType.Regular;
        public List<Order> Orders { get; set; } = new();
        
        public decimal GetTotalOrderValue()
        {
            return Orders.Sum(o => o.TotalAmount);
        }
        
        public bool IsVipCustomer()
        {
            return Type == CustomerType.VIP || GetTotalOrderValue() > 10000m;
        }
    }
    
    public class Order
    {
        public int Id { get; set; }
        public int CustomerId { get; set; }
        public DateTime OrderDate { get; set; } = DateTime.UtcNow;
        public OrderStatus Status { get; set; } = OrderStatus.Pending;
        public List<OrderItem> Items { get; set; } = new();
        
        public decimal TotalAmount => Items.Sum(i => i.Price * i.Quantity);
        
        public void AddItem(string productName, decimal price, int quantity = 1)
        {
            Items.Add(new OrderItem
            {
                ProductName = productName,
                Price = price,
                Quantity = quantity
            });
        }
    }
    
    public class OrderItem
    {
        public string ProductName { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public int Quantity { get; set; }
        public decimal Subtotal => Price * Quantity;
    }
    
    public enum CustomerType
    {
        Regular,
        Premium,
        VIP
    }
    
    public enum OrderStatus
    {
        Pending,
        Processing,
        Shipped,
        Delivered,
        Cancelled
    }
    
    // AI-SUGGESTION: Repository interfaces for data access abstraction
    public interface ICustomerRepository
    {
        Task<Customer?> GetByIdAsync(int id);
        Task<IEnumerable<Customer>> GetAllAsync();
        Task<Customer> CreateAsync(Customer customer);
        Task<Customer> UpdateAsync(Customer customer);
        Task<bool> DeleteAsync(int id);
        Task<IEnumerable<Customer>> SearchAsync(string searchTerm);
    }
    
    public interface IOrderRepository
    {
        Task<Order?> GetByIdAsync(int id);
        Task<IEnumerable<Order>> GetByCustomerIdAsync(int customerId);
        Task<Order> CreateAsync(Order order);
        Task<Order> UpdateAsync(Order order);
        Task<IEnumerable<Order>> GetOrdersByStatusAsync(OrderStatus status);
    }
    
    // AI-SUGGESTION: In-memory implementation for demonstration
    public class InMemoryCustomerRepository : ICustomerRepository
    {
        private readonly List<Customer> _customers = new();
        private int _nextId = 1;
        
        public Task<Customer?> GetByIdAsync(int id)
        {
            var customer = _customers.FirstOrDefault(c => c.Id == id);
            return Task.FromResult(customer);
        }
        
        public Task<IEnumerable<Customer>> GetAllAsync()
        {
            return Task.FromResult(_customers.AsEnumerable());
        }
        
        public Task<Customer> CreateAsync(Customer customer)
        {
            customer.Id = _nextId++;
            customer.CreatedDate = DateTime.UtcNow;
            _customers.Add(customer);
            return Task.FromResult(customer);
        }
        
        public Task<Customer> UpdateAsync(Customer customer)
        {
            var existingIndex = _customers.FindIndex(c => c.Id == customer.Id);
            if (existingIndex >= 0)
            {
                _customers[existingIndex] = customer;
            }
            return Task.FromResult(customer);
        }
        
        public Task<bool> DeleteAsync(int id)
        {
            var customer = _customers.FirstOrDefault(c => c.Id == id);
            if (customer != null)
            {
                _customers.Remove(customer);
                return Task.FromResult(true);
            }
            return Task.FromResult(false);
        }
        
        public Task<IEnumerable<Customer>> SearchAsync(string searchTerm)
        {
            var results = _customers.Where(c => 
                c.Name.Contains(searchTerm, StringComparison.OrdinalIgnoreCase) ||
                c.Email.Contains(searchTerm, StringComparison.OrdinalIgnoreCase))
                .ToList();
            return Task.FromResult(results.AsEnumerable());
        }
    }
    
    public class InMemoryOrderRepository : IOrderRepository
    {
        private readonly List<Order> _orders = new();
        private int _nextId = 1;
        
        public Task<Order?> GetByIdAsync(int id)
        {
            var order = _orders.FirstOrDefault(o => o.Id == id);
            return Task.FromResult(order);
        }
        
        public Task<IEnumerable<Order>> GetByCustomerIdAsync(int customerId)
        {
            var orders = _orders.Where(o => o.CustomerId == customerId).ToList();
            return Task.FromResult(orders.AsEnumerable());
        }
        
        public Task<Order> CreateAsync(Order order)
        {
            order.Id = _nextId++;
            order.OrderDate = DateTime.UtcNow;
            _orders.Add(order);
            return Task.FromResult(order);
        }
        
        public Task<Order> UpdateAsync(Order order)
        {
            var existingIndex = _orders.FindIndex(o => o.Id == order.Id);
            if (existingIndex >= 0)
            {
                _orders[existingIndex] = order;
            }
            return Task.FromResult(order);
        }
        
        public Task<IEnumerable<Order>> GetOrdersByStatusAsync(OrderStatus status)
        {
            var orders = _orders.Where(o => o.Status == status).ToList();
            return Task.FromResult(orders.AsEnumerable());
        }
    }
    
    // AI-SUGGESTION: Business service interfaces
    public interface ICustomerService
    {
        Task<Customer> CreateCustomerAsync(Customer customer);
        Task<Customer?> GetCustomerAsync(int id);
        Task<IEnumerable<Customer>> GetAllCustomersAsync();
        Task<Customer> UpdateCustomerAsync(Customer customer);
        Task<bool> DeleteCustomerAsync(int id);
        Task<IEnumerable<Customer>> SearchCustomersAsync(string searchTerm);
        Task<decimal> GetCustomerLifetimeValueAsync(int customerId);
    }
    
    public interface IOrderService
    {
        Task<Order> CreateOrderAsync(int customerId, List<OrderItem> items);
        Task<Order?> GetOrderAsync(int id);
        Task<IEnumerable<Order>> GetCustomerOrdersAsync(int customerId);
        Task<Order> UpdateOrderStatusAsync(int orderId, OrderStatus status);
        Task<IEnumerable<Order>> GetOrdersByStatusAsync(OrderStatus status);
        Task<decimal> CalculateOrderTotalAsync(List<OrderItem> items);
    }
    
    // AI-SUGGESTION: Service implementations with business logic
    public class CustomerService : ICustomerService
    {
        private readonly ICustomerRepository _customerRepository;
        private readonly IOrderRepository _orderRepository;
        
        public CustomerService(ICustomerRepository customerRepository, IOrderRepository orderRepository)
        {
            _customerRepository = customerRepository ?? throw new ArgumentNullException(nameof(customerRepository));
            _orderRepository = orderRepository ?? throw new ArgumentNullException(nameof(orderRepository));
        }
        
        public async Task<Customer> CreateCustomerAsync(Customer customer)
        {
            // AI-SUGGESTION: Validate customer data
            ValidateCustomer(customer);
            
            // AI-SUGGESTION: Check for duplicate email
            var existingCustomers = await _customerRepository.GetAllAsync();
            if (existingCustomers.Any(c => c.Email.Equals(customer.Email, StringComparison.OrdinalIgnoreCase)))
            {
                throw new InvalidOperationException("Customer with this email already exists");
            }
            
            return await _customerRepository.CreateAsync(customer);
        }
        
        public async Task<Customer?> GetCustomerAsync(int id)
        {
            if (id <= 0)
                throw new ArgumentException("Customer ID must be positive", nameof(id));
                
            var customer = await _customerRepository.GetByIdAsync(id);
            if (customer != null)
            {
                customer.Orders = (await _orderRepository.GetByCustomerIdAsync(id)).ToList();
            }
            return customer;
        }
        
        public async Task<IEnumerable<Customer>> GetAllCustomersAsync()
        {
            return await _customerRepository.GetAllAsync();
        }
        
        public async Task<Customer> UpdateCustomerAsync(Customer customer)
        {
            ValidateCustomer(customer);
            
            var existingCustomer = await _customerRepository.GetByIdAsync(customer.Id);
            if (existingCustomer == null)
            {
                throw new InvalidOperationException("Customer not found");
            }
            
            return await _customerRepository.UpdateAsync(customer);
        }
        
        public async Task<bool> DeleteCustomerAsync(int id)
        {
            var customer = await _customerRepository.GetByIdAsync(id);
            if (customer == null)
                return false;
                
            // AI-SUGGESTION: Check if customer has orders
            var orders = await _orderRepository.GetByCustomerIdAsync(id);
            if (orders.Any())
            {
                throw new InvalidOperationException("Cannot delete customer with existing orders");
            }
            
            return await _customerRepository.DeleteAsync(id);
        }
        
        public async Task<IEnumerable<Customer>> SearchCustomersAsync(string searchTerm)
        {
            if (string.IsNullOrWhiteSpace(searchTerm))
                return await GetAllCustomersAsync();
                
            return await _customerRepository.SearchAsync(searchTerm);
        }
        
        public async Task<decimal> GetCustomerLifetimeValueAsync(int customerId)
        {
            var orders = await _orderRepository.GetByCustomerIdAsync(customerId);
            return orders.Where(o => o.Status == OrderStatus.Delivered)
                        .Sum(o => o.TotalAmount);
        }
        
        private static void ValidateCustomer(Customer customer)
        {
            if (string.IsNullOrWhiteSpace(customer.Name))
                throw new ArgumentException("Customer name is required");
                
            if (string.IsNullOrWhiteSpace(customer.Email))
                throw new ArgumentException("Customer email is required");
                
            if (!IsValidEmail(customer.Email))
                throw new ArgumentException("Invalid email format");
        }
        
        private static bool IsValidEmail(string email)
        {
            try
            {
                var addr = new System.Net.Mail.MailAddress(email);
                return addr.Address == email;
            }
            catch
            {
                return false;
            }
        }
    }
    
    public class OrderService : IOrderService
    {
        private readonly IOrderRepository _orderRepository;
        private readonly ICustomerRepository _customerRepository;
        
        public OrderService(IOrderRepository orderRepository, ICustomerRepository customerRepository)
        {
            _orderRepository = orderRepository ?? throw new ArgumentNullException(nameof(orderRepository));
            _customerRepository = customerRepository ?? throw new ArgumentNullException(nameof(customerRepository));
        }
        
        public async Task<Order> CreateOrderAsync(int customerId, List<OrderItem> items)
        {
            // AI-SUGGESTION: Validate customer exists
            var customer = await _customerRepository.GetByIdAsync(customerId);
            if (customer == null)
                throw new InvalidOperationException("Customer not found");
                
            if (items == null || !items.Any())
                throw new ArgumentException("Order must have at least one item");
                
            var order = new Order
            {
                CustomerId = customerId,
                Items = items,
                Status = OrderStatus.Pending
            };
            
            return await _orderRepository.CreateAsync(order);
        }
        
        public async Task<Order?> GetOrderAsync(int id)
        {
            return await _orderRepository.GetByIdAsync(id);
        }
        
        public async Task<IEnumerable<Order>> GetCustomerOrdersAsync(int customerId)
        {
            return await _orderRepository.GetByCustomerIdAsync(customerId);
        }
        
        public async Task<Order> UpdateOrderStatusAsync(int orderId, OrderStatus status)
        {
            var order = await _orderRepository.GetByIdAsync(orderId);
            if (order == null)
                throw new InvalidOperationException("Order not found");
                
            // AI-SUGGESTION: Validate status transition
            if (!IsValidStatusTransition(order.Status, status))
                throw new InvalidOperationException($"Invalid status transition from {order.Status} to {status}");
                
            order.Status = status;
            return await _orderRepository.UpdateAsync(order);
        }
        
        public async Task<IEnumerable<Order>> GetOrdersByStatusAsync(OrderStatus status)
        {
            return await _orderRepository.GetOrdersByStatusAsync(status);
        }
        
        public Task<decimal> CalculateOrderTotalAsync(List<OrderItem> items)
        {
            var total = items?.Sum(i => i.Price * i.Quantity) ?? 0m;
            return Task.FromResult(total);
        }
        
        private static bool IsValidStatusTransition(OrderStatus current, OrderStatus target)
        {
            return current switch
            {
                OrderStatus.Pending => target == OrderStatus.Processing || target == OrderStatus.Cancelled,
                OrderStatus.Processing => target == OrderStatus.Shipped || target == OrderStatus.Cancelled,
                OrderStatus.Shipped => target == OrderStatus.Delivered,
                OrderStatus.Delivered => false,
                OrderStatus.Cancelled => false,
                _ => false
            };
        }
    }
    
    // AI-SUGGESTION: Dependency injection container setup
    public class ServiceContainer
    {
        private readonly Dictionary<Type, object> _services = new();
        
        public void RegisterSingleton<TInterface, TImplementation>(TImplementation implementation)
            where TImplementation : class, TInterface
        {
            _services[typeof(TInterface)] = implementation;
        }
        
        public T GetService<T>()
        {
            if (_services.TryGetValue(typeof(T), out var service))
            {
                return (T)service;
            }
            throw new InvalidOperationException($"Service of type {typeof(T).Name} is not registered");
        }
    }
    
    // AI-SUGGESTION: Application facade
    public class EnterpriseApplication
    {
        private readonly ServiceContainer _container;
        
        public EnterpriseApplication()
        {
            _container = new ServiceContainer();
            ConfigureServices();
        }
        
        private void ConfigureServices()
        {
            // AI-SUGGESTION: Register repositories
            _container.RegisterSingleton<ICustomerRepository, InMemoryCustomerRepository>(new InMemoryCustomerRepository());
            _container.RegisterSingleton<IOrderRepository, InMemoryOrderRepository>(new InMemoryOrderRepository());
            
            // AI-SUGGESTION: Register services
            var customerRepo = _container.GetService<ICustomerRepository>();
            var orderRepo = _container.GetService<IOrderRepository>();
            
            _container.RegisterSingleton<ICustomerService, CustomerService>(
                new CustomerService(customerRepo, orderRepo));
            _container.RegisterSingleton<IOrderService, OrderService>(
                new OrderService(orderRepo, customerRepo));
        }
        
        public async Task RunDemoAsync()
        {
            Console.WriteLine("=== Enterprise System Demo ===");
            
            var customerService = _container.GetService<ICustomerService>();
            var orderService = _container.GetService<IOrderService>();
            
            try
            {
                // AI-SUGGESTION: Create sample customers
                var customer1 = await customerService.CreateCustomerAsync(new Customer
                {
                    Name = "John Doe",
                    Email = "john.doe@example.com",
                    Phone = "+1-555-0123",
                    Type = CustomerType.Premium
                });
                
                var customer2 = await customerService.CreateCustomerAsync(new Customer
                {
                    Name = "Jane Smith",
                    Email = "jane.smith@example.com",
                    Type = CustomerType.VIP
                });
                
                Console.WriteLine($"Created customers: {customer1.Name} (ID: {customer1.Id}), {customer2.Name} (ID: {customer2.Id})");
                
                // AI-SUGGESTION: Create orders
                var order1 = await orderService.CreateOrderAsync(customer1.Id, new List<OrderItem>
                {
                    new() { ProductName = "Laptop", Price = 1299.99m, Quantity = 1 },
                    new() { ProductName = "Mouse", Price = 29.99m, Quantity = 2 }
                });
                
                var order2 = await orderService.CreateOrderAsync(customer2.Id, new List<OrderItem>
                {
                    new() { ProductName = "Monitor", Price = 399.99m, Quantity = 2 },
                    new() { ProductName = "Keyboard", Price = 89.99m, Quantity = 1 }
                });
                
                Console.WriteLine($"Created orders: Order {order1.Id} (${order1.TotalAmount:F2}), Order {order2.Id} (${order2.TotalAmount:F2})");
                
                // AI-SUGGESTION: Update order status
                await orderService.UpdateOrderStatusAsync(order1.Id, OrderStatus.Processing);
                await orderService.UpdateOrderStatusAsync(order1.Id, OrderStatus.Shipped);
                await orderService.UpdateOrderStatusAsync(order1.Id, OrderStatus.Delivered);
                
                Console.WriteLine($"Order {order1.Id} status updated to Delivered");
                
                // AI-SUGGESTION: Calculate customer lifetime value
                var lifetimeValue = await customerService.GetCustomerLifetimeValueAsync(customer1.Id);
                Console.WriteLine($"Customer {customer1.Name} lifetime value: ${lifetimeValue:F2}");
                
                // AI-SUGGESTION: Search customers
                var searchResults = await customerService.SearchCustomersAsync("john");
                Console.WriteLine($"Search results for 'john': {searchResults.Count()} customers found");
                
                // AI-SUGGESTION: Get orders by status
                var pendingOrders = await orderService.GetOrdersByStatusAsync(OrderStatus.Pending);
                Console.WriteLine($"Pending orders: {pendingOrders.Count()}");
                
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }
}

// AI-SUGGESTION: Enterprise system demonstration class (converted from Program)
public static class EnterpriseSystemDemo
{
    public static async Task RunDemoAsync()
    {
        Console.WriteLine("C# Enterprise System Demonstration");
        Console.WriteLine("==================================");
        
        var app = new EnterpriseSystem.EnterpriseApplication();
        await app.RunDemoAsync();
        
        Console.WriteLine("\n=== Enterprise System Demo Complete ===");
    }
} 