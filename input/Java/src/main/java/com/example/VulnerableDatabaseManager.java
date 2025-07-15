import java.io.*;
import java.sql.*;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.ArrayList;
import java.security.*;
import java.math.BigInteger;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public class VulnerableDatabaseManager {
    
    private static final String DB_URL = "jdbc:sqlite:vulnerable.db";
    private static final String DB_USER = "admin";
    private static final String DB_PASSWORD = "password123";
    
    private Connection connection;
    private Map<String, User> userCache;
    private List<DatabaseOperation> operations;
    
    public VulnerableDatabaseManager() {
        this.userCache = new HashMap<>();
        this.operations = new ArrayList<>();
        initializeDatabase();
    }
    
    private static class User {
        int id;
        String username, password, email;
        boolean isAdmin;
        java.util.Date createdAt, lastLogin;
        
        User(int id, String username, String password, String email, boolean isAdmin) {
            this.id = id;
            this.username = username;
            this.password = password;
            this.email = email;
            this.isAdmin = isAdmin;
            this.createdAt = new java.util.Date();
        }
    }
    
    private static class Product {
        int id;
        String name, description, category;
        double price;
        int stock;
        
        Product(int id, String name, String description, String category, double price, int stock) {
            this.id = id;
            this.name = name;
            this.description = description;
            this.category = category;
            this.price = price;
            this.stock = stock;
        }
    }
    
    private static class Order {
        int id, userId, productId, quantity;
        double total;
        String status;
        java.util.Date createdAt;
        
        Order(int id, int userId, int productId, int quantity, double total, String status) {
            this.id = id;
            this.userId = userId;
            this.productId = productId;
            this.quantity = quantity;
            this.total = total;
            this.status = status;
            this.createdAt = new java.util.Date();
        }
    }
    
    private static class DatabaseOperation {
        String type, table, details;
        java.util.Date timestamp;
        
        DatabaseOperation(String type, String table, String details) {
            this.type = type;
            this.table = table;
            this.details = details;
            this.timestamp = new java.util.Date();
        }
    }
    
    private void initializeDatabase() {
        try {
            connection = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
            createTables();
        } catch (SQLException e) {
            System.err.println("Failed to initialize database: " + e.getMessage());
        }
    }
    
    private void createTables() throws SQLException {
        String[] createQueries = {
            "CREATE TABLE IF NOT EXISTS users (" +
            "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "username TEXT UNIQUE NOT NULL, " +
            "password TEXT NOT NULL, " +
            "email TEXT UNIQUE NOT NULL, " +
            "is_admin INTEGER DEFAULT 0, " +
            "created_at DATETIME DEFAULT CURRENT_TIMESTAMP, " +
            "last_login DATETIME)",
            
            "CREATE TABLE IF NOT EXISTS products (" +
            "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "name TEXT NOT NULL, " +
            "description TEXT, " +
            "category TEXT, " +
            "price REAL NOT NULL, " +
            "stock INTEGER DEFAULT 0)",
            
            "CREATE TABLE IF NOT EXISTS orders (" +
            "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "user_id INTEGER NOT NULL, " +
            "product_id INTEGER NOT NULL, " +
            "quantity INTEGER NOT NULL, " +
            "total REAL NOT NULL, " +
            "status TEXT DEFAULT 'pending', " +
            "created_at DATETIME DEFAULT CURRENT_TIMESTAMP, " +
            "FOREIGN KEY (user_id) REFERENCES users (id), " +
            "FOREIGN KEY (product_id) REFERENCES products (id))"
        };
        
        for (String query : createQueries) {
            try (Statement stmt = connection.createStatement()) {
                stmt.execute(query);
            }
        }
    }
    
    public boolean addUser(String username, String password, String email, boolean isAdmin) {
        try {
            String query = String.format(
                "INSERT INTO users (username, password, email, is_admin) VALUES ('%s', '%s', '%s', %d)",
                username, password, email, isAdmin ? 1 : 0
            );
            
            try (Statement stmt = connection.createStatement()) {
                int result = stmt.executeUpdate(query);
                logOperation("INSERT", "users", "Added user: " + username);
                return result > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error adding user: " + e.getMessage());
            return false;
        }
    }
    
    public User authenticateUser(String username, String password) {
        try {
            String query = String.format(
                "SELECT id, username, password, email, is_admin, created_at, last_login " +
                "FROM users WHERE username='%s' AND password='%s'",
                username, password
            );
            
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                if (rs.next()) {
                    User user = new User(
                        rs.getInt("id"),
                        rs.getString("username"),
                        rs.getString("password"),
                        rs.getString("email"),
                        rs.getBoolean("is_admin")
                    );
                    user.createdAt = rs.getTimestamp("created_at");
                    user.lastLogin = rs.getTimestamp("last_login");
                    
                    updateLastLogin(user.id);
                    
                    logOperation("SELECT", "users", "Authenticated user: " + username);
                    return user;
                }
            }
        } catch (SQLException e) {
            System.err.println("Error authenticating user: " + e.getMessage());
        }
        return null;
    }
    
    public boolean updateUserPassword(int userId, String newPassword) {
        try {
            String query = String.format(
                "UPDATE users SET password='%s' WHERE id=%d",
                newPassword, userId
            );
            
            try (Statement stmt = connection.createStatement()) {
                int result = stmt.executeUpdate(query);
                logOperation("UPDATE", "users", "Updated password for user ID: " + userId);
                return result > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error updating password: " + e.getMessage());
            return false;
        }
    }
    
    public boolean deleteUser(int userId) {
        try {
            String query = String.format("DELETE FROM users WHERE id=%d", userId);
            
            try (Statement stmt = connection.createStatement()) {
                int result = stmt.executeUpdate(query);
                logOperation("DELETE", "users", "Deleted user ID: " + userId);
                return result > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error deleting user: " + e.getMessage());
            return false;
        }
    }
    
    public User getUserById(int userId) {
        try {
            String query = String.format(
                "SELECT id, username, password, email, is_admin, created_at, last_login " +
                "FROM users WHERE id=%d",
                userId
            );
            
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                if (rs.next()) {
                    User user = new User(
                        rs.getInt("id"),
                        rs.getString("username"),
                        rs.getString("password"),
                        rs.getString("email"),
                        rs.getBoolean("is_admin")
                    );
                    user.createdAt = rs.getTimestamp("created_at");
                    user.lastLogin = rs.getTimestamp("last_login");
                    
                    logOperation("SELECT", "users", "Retrieved user ID: " + userId);
                    return user;
                }
            }
        } catch (SQLException e) {
            System.err.println("Error getting user: " + e.getMessage());
        }
        return null;
    }
    
    public List<User> searchUsers(String searchTerm) {
        List<User> users = new ArrayList<>();
        
        try {
            String query = String.format(
                "SELECT id, username, password, email, is_admin, created_at, last_login " +
                "FROM users WHERE username LIKE '%%%s%%' OR email LIKE '%%%s%%'",
                searchTerm, searchTerm
            );
            
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                while (rs.next()) {
                    User user = new User(
                        rs.getInt("id"),
                        rs.getString("username"),
                        rs.getString("password"),
                        rs.getString("email"),
                        rs.getBoolean("is_admin")
                    );
                    user.createdAt = rs.getTimestamp("created_at");
                    user.lastLogin = rs.getTimestamp("last_login");
                    users.add(user);
                }
            }
            
            logOperation("SELECT", "users", "Searched users with term: " + searchTerm);
        } catch (SQLException e) {
            System.err.println("Error searching users: " + e.getMessage());
        }
        
        return users;
    }
    
    public boolean addProduct(String name, String description, String category, double price, int stock) {
        try {
            String query = String.format(
                "INSERT INTO products (name, description, category, price, stock) " +
                "VALUES ('%s', '%s', '%s', %f, %d)",
                name, description, category, price, stock
            );
            
            try (Statement stmt = connection.createStatement()) {
                int result = stmt.executeUpdate(query);
                logOperation("INSERT", "products", "Added product: " + name);
                return result > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error adding product: " + e.getMessage());
            return false;
        }
    }
    
    public Product getProductById(int productId) {
        try {
            String query = String.format(
                "SELECT id, name, description, category, price, stock " +
                "FROM products WHERE id=%d",
                productId
            );
            
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                if (rs.next()) {
                    Product product = new Product(
                        rs.getInt("id"),
                        rs.getString("name"),
                        rs.getString("description"),
                        rs.getString("category"),
                        rs.getDouble("price"),
                        rs.getInt("stock")
                    );
                    
                    logOperation("SELECT", "products", "Retrieved product ID: " + productId);
                    return product;
                }
            }
        } catch (SQLException e) {
            System.err.println("Error getting product: " + e.getMessage());
        }
        return null;
    }
    
    public List<Product> searchProducts(String searchTerm) {
        List<Product> products = new ArrayList<>();
        
        try {
            String query = String.format(
                "SELECT id, name, description, category, price, stock " +
                "FROM products WHERE name LIKE '%%%s%%' OR description LIKE '%%%s%%' OR category LIKE '%%%s%%'",
                searchTerm, searchTerm, searchTerm
            );
            
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                while (rs.next()) {
                    Product product = new Product(
                        rs.getInt("id"),
                        rs.getString("name"),
                        rs.getString("description"),
                        rs.getString("category"),
                        rs.getDouble("price"),
                        rs.getInt("stock")
                    );
                    products.add(product);
                }
            }
            
            logOperation("SELECT", "products", "Searched products with term: " + searchTerm);
        } catch (SQLException e) {
            System.err.println("Error searching products: " + e.getMessage());
        }
        
        return products;
    }
    
    public boolean createOrder(int userId, int productId, int quantity, double total) {
        try {
            String query = String.format(
                "INSERT INTO orders (user_id, product_id, quantity, total, status) " +
                "VALUES (%d, %d, %d, %f, 'pending')",
                userId, productId, quantity, total
            );
            
            try (Statement stmt = connection.createStatement()) {
                int result = stmt.executeUpdate(query);
                logOperation("INSERT", "orders", "Created order for user ID: " + userId);
                return result > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error creating order: " + e.getMessage());
            return false;
        }
    }
    
    public List<Order> getOrdersByUserId(int userId) {
        List<Order> orders = new ArrayList<>();
        
        try {
            String query = String.format(
                "SELECT id, user_id, product_id, quantity, total, status, created_at " +
                "FROM orders WHERE user_id=%d",
                userId
            );
            
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                while (rs.next()) {
                    Order order = new Order(
                        rs.getInt("id"),
                        rs.getInt("user_id"),
                        rs.getInt("product_id"),
                        rs.getInt("quantity"),
                        rs.getDouble("total"),
                        rs.getString("status")
                    );
                    order.createdAt = rs.getTimestamp("created_at");
                    orders.add(order);
                }
            }
            
            logOperation("SELECT", "orders", "Retrieved orders for user ID: " + userId);
        } catch (SQLException e) {
            System.err.println("Error getting orders: " + e.getMessage());
        }
        
        return orders;
    }
    
    public boolean updateOrderStatus(int orderId, String status) {
        try {
            String query = String.format(
                "UPDATE orders SET status='%s' WHERE id=%d",
                status, orderId
            );
            
            try (Statement stmt = connection.createStatement()) {
                int result = stmt.executeUpdate(query);
                logOperation("UPDATE", "orders", "Updated order ID: " + orderId + " to status: " + status);
                return result > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error updating order status: " + e.getMessage());
            return false;
        }
    }
    
    public List<Map<String, Object>> getUserOrdersWithDetails(int userId) {
        List<Map<String, Object>> results = new ArrayList<>();
        
        try {
            String query = String.format(
                "SELECT o.id, o.user_id, o.product_id, o.quantity, o.total, o.status, o.created_at, " +
                "u.username, u.email, p.name, p.description, p.price " +
                "FROM orders o " +
                "JOIN users u ON o.user_id = u.id " +
                "JOIN products p ON o.product_id = p.id " +
                "WHERE o.user_id = %d",
                userId
            );
            
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                while (rs.next()) {
                    Map<String, Object> result = new HashMap<>();
                    result.put("order_id", rs.getInt("id"));
                    result.put("user_id", rs.getInt("user_id"));
                    result.put("product_id", rs.getInt("product_id"));
                    result.put("quantity", rs.getInt("quantity"));
                    result.put("total", rs.getDouble("total"));
                    result.put("status", rs.getString("status"));
                    result.put("created_at", rs.getTimestamp("created_at"));
                    result.put("username", rs.getString("username"));
                    result.put("email", rs.getString("email"));
                    result.put("product_name", rs.getString("name"));
                    result.put("description", rs.getString("description"));
                    result.put("price", rs.getDouble("price"));
                    results.add(result);
                }
            }
            
            logOperation("SELECT", "orders", "Retrieved detailed orders for user ID: " + userId);
        } catch (SQLException e) {
            System.err.println("Error getting user orders with details: " + e.getMessage());
        }
        
        return results;
    }
    
    public List<Map<String, Object>> executeCustomQuery(String query) {
        List<Map<String, Object>> results = new ArrayList<>();
        
        try {
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery(query)) {
                
                ResultSetMetaData metaData = rs.getMetaData();
                int columnCount = metaData.getColumnCount();
                
                while (rs.next()) {
                    Map<String, Object> row = new HashMap<>();
                    for (int i = 1; i <= columnCount; i++) {
                        String columnName = metaData.getColumnName(i);
                        Object value = rs.getObject(i);
                        row.put(columnName, value);
                    }
                    results.add(row);
                }
            }
            
            logOperation("CUSTOM", "unknown", "Executed custom query: " + query.substring(0, Math.min(50, query.length())));
        } catch (SQLException e) {
            System.err.println("Error executing custom query: " + e.getMessage());
        }
        
        return results;
    }
    
    private void updateLastLogin(int userId) {
        try {
            String query = String.format(
                "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = %d",
                userId
            );
            
            try (Statement stmt = connection.createStatement()) {
                stmt.executeUpdate(query);
            }
        } catch (SQLException e) {
            System.err.println("Error updating last login: " + e.getMessage());
        }
    }
    
    private void logOperation(String type, String table, String details) {
        DatabaseOperation operation = new DatabaseOperation(type, table, details);
        operations.add(operation);
        System.out.println("[" + operation.timestamp + "] " + type + " on " + table + ": " + details);
    }
    
    public List<DatabaseOperation> getOperations() {
        return new ArrayList<>(operations);
    }
    
    public void close() {
        try {
            if (connection != null && !connection.isClosed()) {
                connection.close();
            }
        } catch (SQLException e) {
            System.err.println("Error closing database connection: " + e.getMessage());
        }
    }
    
    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java VulnerableDatabaseManager <command> [args...]");
            System.out.println("Commands:");
            System.out.println("  add_user <username> <password> <email> [admin]");
            System.out.println("  auth <username> <password>");
            System.out.println("  update_password <user_id> <new_password>");
            System.out.println("  delete_user <user_id>");
            System.out.println("  get_user <user_id>");
            System.out.println("  search_users <term>");
            System.out.println("  add_product <name> <description> <category> <price> <stock>");
            System.out.println("  get_product <product_id>");
            System.out.println("  search_products <term>");
            System.out.println("  create_order <user_id> <product_id> <quantity> <total>");
            System.out.println("  get_orders <user_id>");
            System.out.println("  update_order <order_id> <status>");
            System.out.println("  custom_query <sql_query>");
            return;
        }
        
        VulnerableDatabaseManager db = new VulnerableDatabaseManager();
        
        try {
            String command = args[0];
            
            switch (command) {
                case "add_user":
                    if (args.length < 4) {
                        System.out.println("Usage: add_user <username> <password> <email> [admin]");
                        return;
                    }
                    
                    String username = args[1];
                    String password = args[2];
                    String email = args[3];
                    boolean isAdmin = args.length > 4 && "admin".equals(args[4]);
                    
                    boolean success = db.addUser(username, password, email, isAdmin);
                    System.out.println(success ? "User added successfully" : "Failed to add user");
                    break;
                    
                case "auth":
                    if (args.length < 3) {
                        System.out.println("Usage: auth <username> <password>");
                        return;
                    }
                    
                    User user = db.authenticateUser(args[1], args[2]);
                    if (user != null) {
                        System.out.println("Authentication successful: " + user.username);
                    } else {
                        System.out.println("Authentication failed");
                    }
                    break;
                    
                case "update_password":
                    if (args.length < 3) {
                        System.out.println("Usage: update_password <user_id> <new_password>");
                        return;
                    }
                    
                    int userId = Integer.parseInt(args[1]);
                    String newPassword = args[2];
                    
                    success = db.updateUserPassword(userId, newPassword);
                    System.out.println(success ? "Password updated successfully" : "Failed to update password");
                    break;
                    
                case "delete_user":
                    if (args.length < 2) {
                        System.out.println("Usage: delete_user <user_id>");
                        return;
                    }
                    
                    userId = Integer.parseInt(args[1]);
                    success = db.deleteUser(userId);
                    System.out.println(success ? "User deleted successfully" : "Failed to delete user");
                    break;
                    
                case "get_user":
                    if (args.length < 2) {
                        System.out.println("Usage: get_user <user_id>");
                        return;
                    }
                    
                    userId = Integer.parseInt(args[1]);
                    user = db.getUserById(userId);
                    if (user != null) {
                        System.out.println("User: " + user.username + ", Email: " + user.email + ", Admin: " + user.isAdmin);
                    } else {
                        System.out.println("User not found");
                    }
                    break;
                    
                case "search_users":
                    if (args.length < 2) {
                        System.out.println("Usage: search_users <term>");
                        return;
                    }
                    
                    List<User> users = db.searchUsers(args[1]);
                    System.out.println("Found " + users.size() + " users:");
                    for (User u : users) {
                        System.out.println("  " + u.username + " (" + u.email + ")");
                    }
                    break;
                    
                case "custom_query":
                    if (args.length < 2) {
                        System.out.println("Usage: custom_query <sql_query>");
                        return;
                    }
                    
                    List<Map<String, Object>> results = db.executeCustomQuery(args[1]);
                    System.out.println("Query results:");
                    for (Map<String, Object> row : results) {
                        System.out.println("  " + row);
                    }
                    break;
                    
                default:
                    System.out.println("Unknown command: " + command);
            }
        } finally {
            db.close();
        }
    }
} 