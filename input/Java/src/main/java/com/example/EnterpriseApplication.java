package com.enterprise.application;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import java.math.BigDecimal;

class Customer {
    private Long id;
    private String firstName;
    private String lastName;
    private String email;
    private String phoneNumber;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private CustomerStatus status;
    private List<Order> orders;

    public enum CustomerStatus {
        ACTIVE, INACTIVE, SUSPENDED, VIP
    }

    public Customer(String firstName, String lastName, String email) {
        this.firstName = validateName(firstName);
        this.lastName = validateName(lastName);
        this.email = validateEmail(email);
        this.phoneNumber = "";
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        this.status = CustomerStatus.ACTIVE;
        this.orders = new ArrayList<>();
    }

    private String validateName(String name) {
        if (name == null || name.trim().isEmpty()) {
            throw new IllegalArgumentException("Name cannot be null or empty");
        }
        return name.trim();
    }

    private String validateEmail(String email) {
        if (email == null || !email.contains("@") || !email.contains(".")) {
            throw new IllegalArgumentException("Invalid email format");
        }
        return email.toLowerCase().trim();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getFirstName() { return firstName; }
    public void setFirstName(String firstName) { 
        this.firstName = validateName(firstName);
        this.updatedAt = LocalDateTime.now();
    }
    
    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { 
        this.lastName = validateName(lastName);
        this.updatedAt = LocalDateTime.now();
    }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { 
        this.email = validateEmail(email);
        this.updatedAt = LocalDateTime.now();
    }
    
    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { 
        this.phoneNumber = phoneNumber != null ? phoneNumber.trim() : "";
        this.updatedAt = LocalDateTime.now();
    }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public CustomerStatus getStatus() { return status; }
    public void setStatus(CustomerStatus status) { 
        this.status = status;
        this.updatedAt = LocalDateTime.now();
    }
    
    public List<Order> getOrders() { return new ArrayList<>(orders); }
    public void addOrder(Order order) { 
        this.orders.add(order);
        this.updatedAt = LocalDateTime.now();
    }

    public String getFullName() {
        return firstName + " " + lastName;
    }

    @Override
    public String toString() {
        return String.format("Customer{id=%d, name='%s', email='%s', status=%s}", 
            id, getFullName(), email, status);
    }
}

class Order {
    private Long id;
    private Long customerId;
    private List<OrderItem> items;
    private BigDecimal totalAmount;
    private OrderStatus status;
    private LocalDateTime orderDate;
    private LocalDateTime deliveryDate;

    public enum OrderStatus {
        PENDING, CONFIRMED, PROCESSING, SHIPPED, DELIVERED, CANCELLED
    }

    public Order(Long customerId) {
        this.customerId = customerId;
        this.items = new ArrayList<>();
        this.totalAmount = BigDecimal.ZERO;
        this.status = OrderStatus.PENDING;
        this.orderDate = LocalDateTime.now();
    }

    public void addItem(String productName, BigDecimal price, Integer quantity) {
        OrderItem item = new OrderItem(productName, price, quantity);
        items.add(item);
        calculateTotal();
    }

    private void calculateTotal() {
        this.totalAmount = items.stream()
            .map(OrderItem::getSubtotal)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getCustomerId() { return customerId; }
    public List<OrderItem> getItems() { return new ArrayList<>(items); }
    public BigDecimal getTotalAmount() { return totalAmount; }
    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { this.status = status; }
    public LocalDateTime getOrderDate() { return orderDate; }
    public LocalDateTime getDeliveryDate() { return deliveryDate; }
    public void setDeliveryDate(LocalDateTime deliveryDate) { this.deliveryDate = deliveryDate; }

    @Override
    public String toString() {
        return String.format("Order{id=%d, customerId=%d, total=%s, status=%s}", 
            id, customerId, totalAmount, status);
    }
}

class OrderItem {
    private String productName;
    private BigDecimal price;
    private Integer quantity;
    private BigDecimal subtotal;

    public OrderItem(String productName, BigDecimal price, Integer quantity) {
        this.productName = productName;
        this.price = price;
        this.quantity = quantity;
        this.subtotal = price.multiply(BigDecimal.valueOf(quantity));
    }

    public String getProductName() { return productName; }
    public BigDecimal getPrice() { return price; }
    public Integer getQuantity() { return quantity; }
    public BigDecimal getSubtotal() { return subtotal; }
}

interface CustomerRepository {
    Customer save(Customer customer);
    Optional<Customer> findById(Long id);
    Optional<Customer> findByEmail(String email);
    List<Customer> findAll();
    List<Customer> findByStatus(Customer.CustomerStatus status);
    void deleteById(Long id);
    long count();
}

interface OrderRepository {
    Order save(Order order);
    Optional<Order> findById(Long id);
    List<Order> findByCustomerId(Long customerId);
    List<Order> findByStatus(Order.OrderStatus status);
    List<Order> findOrdersInDateRange(LocalDateTime start, LocalDateTime end);
    void deleteById(Long id);
}

class InMemoryCustomerRepository implements CustomerRepository {
    private final Map<Long, Customer> customers = new ConcurrentHashMap<>();
    private Long nextId = 1L;

    @Override
    public Customer save(Customer customer) {
        if (customer.getId() == null) {
            customer.setId(nextId++);
        }
        customers.put(customer.getId(), customer);
        return customer;
    }

    @Override
    public Optional<Customer> findById(Long id) {
        return Optional.ofNullable(customers.get(id));
    }

    @Override
    public Optional<Customer> findByEmail(String email) {
        return customers.values().stream()
            .filter(customer -> customer.getEmail().equals(email))
            .findFirst();
    }

    @Override
    public List<Customer> findAll() {
        return new ArrayList<>(customers.values());
    }

    @Override
    public List<Customer> findByStatus(Customer.CustomerStatus status) {
        return customers.values().stream()
            .filter(customer -> customer.getStatus() == status)
            .collect(Collectors.toList());
    }

    @Override
    public void deleteById(Long id) {
        customers.remove(id);
    }

    @Override
    public long count() {
        return customers.size();
    }
}

class InMemoryOrderRepository implements OrderRepository {
    private final Map<Long, Order> orders = new ConcurrentHashMap<>();
    private Long nextId = 1L;

    @Override
    public Order save(Order order) {
        if (order.getId() == null) {
            order.setId(nextId++);
        }
        orders.put(order.getId(), order);
        return order;
    }

    @Override
    public Optional<Order> findById(Long id) {
        return Optional.ofNullable(orders.get(id));
    }

    @Override
    public List<Order> findByCustomerId(Long customerId) {
        return orders.values().stream()
            .filter(order -> order.getCustomerId().equals(customerId))
            .collect(Collectors.toList());
    }

    @Override
    public List<Order> findByStatus(Order.OrderStatus status) {
        return orders.values().stream()
            .filter(order -> order.getStatus() == status)
            .collect(Collectors.toList());
    }

    @Override
    public List<Order> findOrdersInDateRange(LocalDateTime start, LocalDateTime end) {
        return orders.values().stream()
            .filter(order -> order.getOrderDate().isAfter(start) && order.getOrderDate().isBefore(end))
            .collect(Collectors.toList());
    }

    @Override
    public void deleteById(Long id) {
        orders.remove(id);
    }
}

class CustomerService {
    private final CustomerRepository customerRepository;
    private final OrderRepository orderRepository;

    public CustomerService(CustomerRepository customerRepository, OrderRepository orderRepository) {
        this.customerRepository = customerRepository;
        this.orderRepository = orderRepository;
    }

    public Customer createCustomer(String firstName, String lastName, String email) {
        if (customerRepository.findByEmail(email).isPresent()) {
            throw new BusinessException("Customer with email already exists: " + email);
        }

        Customer customer = new Customer(firstName, lastName, email);
        return customerRepository.save(customer);
    }

    public Customer updateCustomer(Long id, String firstName, String lastName, String phoneNumber) {
        Customer customer = customerRepository.findById(id)
            .orElseThrow(() -> new CustomerNotFoundException("Customer not found: " + id));

        if (firstName != null) customer.setFirstName(firstName);
        if (lastName != null) customer.setLastName(lastName);
        if (phoneNumber != null) customer.setPhoneNumber(phoneNumber);

        return customerRepository.save(customer);
    }

    public void upgradeToVip(Long customerId) {
        Customer customer = getCustomerById(customerId);
        
        BigDecimal totalSpent = calculateCustomerTotalSpent(customerId);
        if (totalSpent.compareTo(BigDecimal.valueOf(1000)) >= 0) {
            customer.setStatus(Customer.CustomerStatus.VIP);
            customerRepository.save(customer);
        } else {
            throw new BusinessException("Customer does not meet VIP criteria");
        }
    }

    public Customer getCustomerById(Long id) {
        return customerRepository.findById(id)
            .orElseThrow(() -> new CustomerNotFoundException("Customer not found: " + id));
    }

    public List<Customer> getAllCustomers() {
        return customerRepository.findAll();
    }

    public List<Customer> getCustomersByStatus(Customer.CustomerStatus status) {
        return customerRepository.findByStatus(status);
    }

    private BigDecimal calculateCustomerTotalSpent(Long customerId) {
        return orderRepository.findByCustomerId(customerId).stream()
            .filter(order -> order.getStatus() == Order.OrderStatus.DELIVERED)
            .map(Order::getTotalAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}

class OrderService {
    private final OrderRepository orderRepository;
    private final CustomerRepository customerRepository;

    public OrderService(OrderRepository orderRepository, CustomerRepository customerRepository) {
        this.orderRepository = orderRepository;
        this.customerRepository = customerRepository;
    }

    public Order createOrder(Long customerId) {
        customerRepository.findById(customerId)
            .orElseThrow(() -> new CustomerNotFoundException("Customer not found: " + customerId));

        Order order = new Order(customerId);
        return orderRepository.save(order);
    }

    public void addItemToOrder(Long orderId, String productName, BigDecimal price, Integer quantity) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException("Order not found: " + orderId));

        if (order.getStatus() != Order.OrderStatus.PENDING) {
            throw new BusinessException("Cannot modify order with status: " + order.getStatus());
        }

        order.addItem(productName, price, quantity);
        orderRepository.save(order);
    }

    public Order confirmOrder(Long orderId) {
        Order order = getOrderById(orderId);
        
        if (order.getItems().isEmpty()) {
            throw new BusinessException("Cannot confirm empty order");
        }

        order.setStatus(Order.OrderStatus.CONFIRMED);
        return orderRepository.save(order);
    }

    public Order shipOrder(Long orderId) {
        Order order = getOrderById(orderId);
        
        if (order.getStatus() != Order.OrderStatus.PROCESSING) {
            throw new BusinessException("Order must be in PROCESSING status to ship");
        }

        order.setStatus(Order.OrderStatus.SHIPPED);
        return orderRepository.save(order);
    }

    public Order deliverOrder(Long orderId) {
        Order order = getOrderById(orderId);
        
        if (order.getStatus() != Order.OrderStatus.SHIPPED) {
            throw new BusinessException("Order must be SHIPPED to mark as delivered");
        }

        order.setStatus(Order.OrderStatus.DELIVERED);
        order.setDeliveryDate(LocalDateTime.now());
        return orderRepository.save(order);
    }

    public Order getOrderById(Long id) {
        return orderRepository.findById(id)
            .orElseThrow(() -> new OrderNotFoundException("Order not found: " + id));
    }

    public List<Order> getOrdersByCustomer(Long customerId) {
        return orderRepository.findByCustomerId(customerId);
    }

    public List<Order> getOrdersByStatus(Order.OrderStatus status) {
        return orderRepository.findByStatus(status);
    }
}

class BusinessException extends RuntimeException {
    public BusinessException(String message) {
        super(message);
    }
}

class CustomerNotFoundException extends RuntimeException {
    public CustomerNotFoundException(String message) {
        super(message);
    }
}

class OrderNotFoundException extends RuntimeException {
    public OrderNotFoundException(String message) {
        super(message);
    }
}

class ApplicationContext {
    private final CustomerRepository customerRepository;
    private final OrderRepository orderRepository;
    private final CustomerService customerService;
    private final OrderService orderService;

    public ApplicationContext() {
        this.customerRepository = new InMemoryCustomerRepository();
        this.orderRepository = new InMemoryOrderRepository();
        this.customerService = new CustomerService(customerRepository, orderRepository);
        this.orderService = new OrderService(orderRepository, customerRepository);
    }

    public CustomerService getCustomerService() { return customerService; }
    public OrderService getOrderService() { return orderService; }
}

public class EnterpriseApplication {
    private final ApplicationContext context;

    public EnterpriseApplication() {
        this.context = new ApplicationContext();
    }

    public void runDemo() {
        System.out.println("Enterprise Application Demo");
        System.out.println("===========================");

        CustomerService customerService = context.getCustomerService();
        OrderService orderService = context.getOrderService();

        try {
            System.out.println("\n--- Creating Customers ---");
            Customer customer1 = customerService.createCustomer("John", "Doe", "john@example.com");
            Customer customer2 = customerService.createCustomer("Jane", "Smith", "jane@example.com");
            Customer customer3 = customerService.createCustomer("Bob", "Johnson", "bob@example.com");

            System.out.println("Created customers:");
            customerService.getAllCustomers().forEach(System.out::println);

            System.out.println("\n--- Creating Orders ---");
            Order order1 = orderService.createOrder(customer1.getId());
            orderService.addItemToOrder(order1.getId(), "Laptop", BigDecimal.valueOf(999.99), 1);
            orderService.addItemToOrder(order1.getId(), "Mouse", BigDecimal.valueOf(29.99), 2);
            orderService.confirmOrder(order1.getId());

            Order order2 = orderService.createOrder(customer2.getId());
            orderService.addItemToOrder(order2.getId(), "Smartphone", BigDecimal.valueOf(699.99), 1);
            orderService.confirmOrder(order2.getId());

            System.out.println("Created orders:");
            orderService.getOrdersByStatus(Order.OrderStatus.CONFIRMED).forEach(System.out::println);

            System.out.println("\n--- Processing Orders ---");
            order1.setStatus(Order.OrderStatus.PROCESSING);
            orderService.shipOrder(order1.getId());
            orderService.deliverOrder(order1.getId());

            System.out.println("Order 1 delivered: " + orderService.getOrderById(order1.getId()));

            System.out.println("\n--- VIP Upgrade Attempt ---");
            try {
                customerService.upgradeToVip(customer1.getId());
                System.out.println("Customer 1 upgraded to VIP: " + customerService.getCustomerById(customer1.getId()));
            } catch (BusinessException e) {
                System.out.println("VIP upgrade failed: " + e.getMessage());
            }

            System.out.println("\n--- Statistics ---");
            System.out.println("Total customers: " + customerService.getAllCustomers().size());
            System.out.println("VIP customers: " + customerService.getCustomersByStatus(Customer.CustomerStatus.VIP).size());
            System.out.println("Delivered orders: " + orderService.getOrdersByStatus(Order.OrderStatus.DELIVERED).size());

        } catch (Exception e) {
            System.err.println("Application error: " + e.getMessage());
            e.printStackTrace();
        }

        System.out.println("\n=== Enterprise Application Demo Complete ===");
    }

    public static void main(String[] args) {
        EnterpriseApplication app = new EnterpriseApplication();
        app.runDemo();
    }
} 