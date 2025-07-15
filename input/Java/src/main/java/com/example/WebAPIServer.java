package com.webapi.server;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.Headers;

import java.io.*;
import java.net.InetSocketAddress;
import java.net.URI;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;
import java.util.regex.Pattern;

class User {
    private Long id;
    private String username;
    private String email;
    private String firstName;
    private String lastName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private boolean active;

    public User() {}

    public User(String username, String email, String firstName, String lastName) {
        this.username = username;
        this.email = email;
        this.firstName = firstName;
        this.lastName = lastName;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        this.active = true;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { 
        this.username = username;
        this.updatedAt = LocalDateTime.now();
    }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { 
        this.email = email;
        this.updatedAt = LocalDateTime.now();
    }
    
    public String getFirstName() { return firstName; }
    public void setFirstName(String firstName) { 
        this.firstName = firstName;
        this.updatedAt = LocalDateTime.now();
    }
    
    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { 
        this.lastName = lastName;
        this.updatedAt = LocalDateTime.now();
    }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { 
        this.active = active;
        this.updatedAt = LocalDateTime.now();
    }

    public String toJson() {
        return String.format(
            "{\"id\":%d,\"username\":\"%s\",\"email\":\"%s\",\"firstName\":\"%s\",\"lastName\":\"%s\",\"createdAt\":\"%s\",\"updatedAt\":\"%s\",\"active\":%b}",
            id, username, email, firstName, lastName, 
            createdAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
            updatedAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME), 
            active);
    }

    @Override
    public String toString() {
        return String.format("User{id=%d, username='%s', email='%s', active=%s}", 
            id, username, email, active);
    }
}

class APIResponse {
    private boolean success;
    private String message;
    private Object data;
    private String error;
    private LocalDateTime timestamp;

    public APIResponse(boolean success, String message, Object data, String error) {
        this.success = success;
        this.message = message;
        this.data = data;
        this.error = error;
        this.timestamp = LocalDateTime.now();
    }

    public static APIResponse success(String message, Object data) {
        return new APIResponse(true, message, data, null);
    }

    public static APIResponse error(String error) {
        return new APIResponse(false, null, null, error);
    }

    public String toJson() {
        StringBuilder json = new StringBuilder();
        json.append("{");
        json.append("\"success\":").append(success).append(",");
        json.append("\"timestamp\":\"").append(timestamp.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)).append("\"");
        
        if (message != null) {
            json.append(",\"message\":\"").append(escapeJson(message)).append("\"");
        }
        
        if (data != null) {
            if (data instanceof String) {
                json.append(",\"data\":\"").append(escapeJson((String) data)).append("\"");
            } else if (data instanceof Collection) {
                json.append(",\"data\":[");
                Collection<?> collection = (Collection<?>) data;
                json.append(collection.stream()
                    .map(item -> item instanceof User ? ((User) item).toJson() : "\"" + escapeJson(item.toString()) + "\"")
                    .collect(Collectors.joining(",")));
                json.append("]");
            } else {
                json.append(",\"data\":").append(data.toString());
            }
        }
        
        if (error != null) {
            json.append(",\"error\":\"").append(escapeJson(error)).append("\"");
        }
        
        json.append("}");
        return json.toString();
    }

    private String escapeJson(String str) {
        return str.replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t");
    }
}

class SimpleJsonParser {
    public static Map<String, Object> parse(String json) {
        Map<String, Object> result = new HashMap<>();
        
        if (json == null || json.trim().isEmpty()) {
            return result;
        }
        
        json = json.trim();
        if (!json.startsWith("{") || !json.endsWith("}")) {
            throw new IllegalArgumentException("Invalid JSON format");
        }
        
        json = json.substring(1, json.length() - 1);
        
        String[] pairs = json.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
        
        for (String pair : pairs) {
            String[] keyValue = pair.split(":", 2);
            if (keyValue.length == 2) {
                String key = keyValue[0].trim().replaceAll("^\"|\"$", "");
                String value = keyValue[1].trim().replaceAll("^\"|\"$", "");
                result.put(key, value);
            }
        }
        
        return result;
    }
}

class UserRepository {
    private final Map<Long, User> users = new ConcurrentHashMap<>();
    private final AtomicLong nextId = new AtomicLong(1);

    public User save(User user) {
        if (user.getId() == null) {
            user.setId(nextId.getAndIncrement());
        }
        users.put(user.getId(), user);
        return user;
    }

    public Optional<User> findById(Long id) {
        return Optional.ofNullable(users.get(id));
    }

    public Optional<User> findByUsername(String username) {
        return users.values().stream()
            .filter(user -> user.getUsername().equals(username))
            .findFirst();
    }

    public Optional<User> findByEmail(String email) {
        return users.values().stream()
            .filter(user -> user.getEmail().equals(email))
            .findFirst();
    }

    public List<User> findAll() {
        return new ArrayList<>(users.values());
    }

    public List<User> findByActive(boolean active) {
        return users.values().stream()
            .filter(user -> user.isActive() == active)
            .collect(Collectors.toList());
    }

    public boolean deleteById(Long id) {
        return users.remove(id) != null;
    }

    public long count() {
        return users.size();
    }

    public void clear() {
        users.clear();
        nextId.set(1);
    }
}

abstract class BaseHandler implements HttpHandler {
    protected final UserRepository userRepository;

    public BaseHandler(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        try {
            Headers headers = exchange.getResponseHeaders();
            headers.add("Access-Control-Allow-Origin", "*");
            headers.add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
            headers.add("Access-Control-Allow-Headers", "Content-Type, Authorization");
            headers.add("Content-Type", "application/json");

            String method = exchange.getRequestMethod();
            
            if ("OPTIONS".equals(method)) {
                sendResponse(exchange, 200, "");
                return;
            }

            handleRequest(exchange);
            
        } catch (Exception e) {
            System.err.println("Handler error: " + e.getMessage());
            e.printStackTrace();
            sendErrorResponse(exchange, 500, "Internal server error: " + e.getMessage());
        }
    }

    protected abstract void handleRequest(HttpExchange exchange) throws IOException;

    protected void sendResponse(HttpExchange exchange, int statusCode, String response) throws IOException {
        byte[] responseBytes = response.getBytes();
        exchange.sendResponseHeaders(statusCode, responseBytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(responseBytes);
        }
    }

    protected void sendJsonResponse(HttpExchange exchange, int statusCode, APIResponse response) throws IOException {
        sendResponse(exchange, statusCode, response.toJson());
    }

    protected void sendErrorResponse(HttpExchange exchange, int statusCode, String error) throws IOException {
        sendJsonResponse(exchange, statusCode, APIResponse.error(error));
    }

    protected String readRequestBody(HttpExchange exchange) throws IOException {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(exchange.getRequestBody()))) {
            return reader.lines().collect(Collectors.joining("\n"));
        }
    }

    protected Map<String, String> parseQueryParams(URI uri) {
        Map<String, String> params = new HashMap<>();
        String query = uri.getQuery();
        
        if (query != null) {
            String[] pairs = query.split("&");
            for (String pair : pairs) {
                String[] keyValue = pair.split("=", 2);
                if (keyValue.length == 2) {
                    params.put(keyValue[0], keyValue[1]);
                }
            }
        }
        
        return params;
    }

    protected Long extractIdFromPath(String path) {
        String[] segments = path.split("/");
        if (segments.length > 0) {
            try {
                return Long.parseLong(segments[segments.length - 1]);
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return null;
    }
}

class UsersHandler extends BaseHandler {
    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        "^[A-Za-z0-9+_.-]+@([A-Za-z0-9.-]+\\.[A-Za-z]{2,})$");

    public UsersHandler(UserRepository userRepository) {
        super(userRepository);
    }

    @Override
    protected void handleRequest(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();

        switch (method) {
            case "GET":
                if (path.matches(".*/users/\\d+$")) {
                    handleGetUser(exchange);
                } else {
                    handleGetUsers(exchange);
                }
                break;
            case "POST":
                handleCreateUser(exchange);
                break;
            case "PUT":
                handleUpdateUser(exchange);
                break;
            case "DELETE":
                handleDeleteUser(exchange);
                break;
            default:
                sendErrorResponse(exchange, 405, "Method not allowed: " + method);
        }
    }

    private void handleGetUsers(HttpExchange exchange) throws IOException {
        Map<String, String> params = parseQueryParams(exchange.getRequestURI());
        List<User> users;

        if (params.containsKey("active")) {
            boolean active = Boolean.parseBoolean(params.get("active"));
            users = userRepository.findByActive(active);
        } else {
            users = userRepository.findAll();
        }

        sendJsonResponse(exchange, 200, APIResponse.success("Users retrieved successfully", users));
    }

    private void handleGetUser(HttpExchange exchange) throws IOException {
        Long id = extractIdFromPath(exchange.getRequestURI().getPath());
        
        if (id == null) {
            sendErrorResponse(exchange, 400, "Invalid user ID");
            return;
        }

        Optional<User> user = userRepository.findById(id);
        if (user.isPresent()) {
            sendJsonResponse(exchange, 200, APIResponse.success("User found", user.get()));
        } else {
            sendErrorResponse(exchange, 404, "User not found");
        }
    }

    private void handleCreateUser(HttpExchange exchange) throws IOException {
        try {
            String requestBody = readRequestBody(exchange);
            Map<String, Object> userData = SimpleJsonParser.parse(requestBody);

            String username = (String) userData.get("username");
            String email = (String) userData.get("email");
            String firstName = (String) userData.get("firstName");
            String lastName = (String) userData.get("lastName");

            if (username == null || username.trim().isEmpty()) {
                sendErrorResponse(exchange, 400, "Username is required");
                return;
            }

            if (email == null || !EMAIL_PATTERN.matcher(email).matches()) {
                sendErrorResponse(exchange, 400, "Valid email is required");
                return;
            }

            if (userRepository.findByUsername(username).isPresent()) {
                sendErrorResponse(exchange, 409, "Username already exists");
                return;
            }

            if (userRepository.findByEmail(email).isPresent()) {
                sendErrorResponse(exchange, 409, "Email already exists");
                return;
            }

            User user = new User(username.trim(), email.trim(), 
                               firstName != null ? firstName.trim() : "", 
                               lastName != null ? lastName.trim() : "");
            
            User savedUser = userRepository.save(user);
            sendJsonResponse(exchange, 201, APIResponse.success("User created successfully", savedUser));

        } catch (IllegalArgumentException e) {
            sendErrorResponse(exchange, 400, "Invalid JSON: " + e.getMessage());
        }
    }

    private void handleUpdateUser(HttpExchange exchange) throws IOException {
        Long id = extractIdFromPath(exchange.getRequestURI().getPath());
        
        if (id == null) {
            sendErrorResponse(exchange, 400, "Invalid user ID");
            return;
        }

        Optional<User> existingUser = userRepository.findById(id);
        if (!existingUser.isPresent()) {
            sendErrorResponse(exchange, 404, "User not found");
            return;
        }

        try {
            String requestBody = readRequestBody(exchange);
            Map<String, Object> updates = SimpleJsonParser.parse(requestBody);
            User user = existingUser.get();

            if (updates.containsKey("username")) {
                String newUsername = (String) updates.get("username");
                if (newUsername != null && !newUsername.trim().isEmpty()) {
                    Optional<User> userWithUsername = userRepository.findByUsername(newUsername.trim());
                    if (userWithUsername.isPresent() && !userWithUsername.get().getId().equals(id)) {
                        sendErrorResponse(exchange, 409, "Username already exists");
                        return;
                    }
                    user.setUsername(newUsername.trim());
                }
            }

            if (updates.containsKey("email")) {
                String newEmail = (String) updates.get("email");
                if (newEmail != null && EMAIL_PATTERN.matcher(newEmail).matches()) {
                    Optional<User> userWithEmail = userRepository.findByEmail(newEmail.trim());
                    if (userWithEmail.isPresent() && !userWithEmail.get().getId().equals(id)) {
                        sendErrorResponse(exchange, 409, "Email already exists");
                        return;
                    }
                    user.setEmail(newEmail.trim());
                }
            }

            if (updates.containsKey("firstName")) {
                user.setFirstName((String) updates.get("firstName"));
            }

            if (updates.containsKey("lastName")) {
                user.setLastName((String) updates.get("lastName"));
            }

            if (updates.containsKey("active")) {
                user.setActive(Boolean.parseBoolean((String) updates.get("active")));
            }

            User updatedUser = userRepository.save(user);
            sendJsonResponse(exchange, 200, APIResponse.success("User updated successfully", updatedUser));

        } catch (IllegalArgumentException e) {
            sendErrorResponse(exchange, 400, "Invalid JSON: " + e.getMessage());
        }
    }

    private void handleDeleteUser(HttpExchange exchange) throws IOException {
        Long id = extractIdFromPath(exchange.getRequestURI().getPath());
        
        if (id == null) {
            sendErrorResponse(exchange, 400, "Invalid user ID");
            return;
        }

        boolean deleted = userRepository.deleteById(id);
        if (deleted) {
            sendJsonResponse(exchange, 200, APIResponse.success("User deleted successfully", null));
        } else {
            sendErrorResponse(exchange, 404, "User not found");
        }
    }
}

class HealthHandler extends BaseHandler {
    private final LocalDateTime startTime = LocalDateTime.now();

    public HealthHandler(UserRepository userRepository) {
        super(userRepository);
    }

    @Override
    protected void handleRequest(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            sendErrorResponse(exchange, 405, "Method not allowed");
            return;
        }

        Map<String, Object> health = new HashMap<>();
        health.put("status", "healthy");
        health.put("timestamp", LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        health.put("uptime", java.time.Duration.between(startTime, LocalDateTime.now()).toString());
        health.put("totalUsers", userRepository.count());
        health.put("activeUsers", userRepository.findByActive(true).size());
        health.put("version", "1.0.0");

        String healthJson = String.format(
            "{\"status\":\"%s\",\"timestamp\":\"%s\",\"uptime\":\"%s\",\"totalUsers\":%d,\"activeUsers\":%d,\"version\":\"%s\"}",
            health.get("status"), health.get("timestamp"), health.get("uptime"),
            (Long) health.get("totalUsers"), health.get("activeUsers"), health.get("version")
        );

        sendJsonResponse(exchange, 200, APIResponse.success("Health check", healthJson));
    }
}

public class WebAPIServer {
    private final HttpServer server;
    private final UserRepository userRepository;
    private final int port;

    public WebAPIServer(int port) throws IOException {
        this.port = port;
        this.userRepository = new UserRepository();
        this.server = HttpServer.create(new InetSocketAddress(port), 0);
        
        setupRoutes();
        setupThreadPool();
        seedData();
    }

    private void setupRoutes() {
        server.createContext("/api/users", new UsersHandler(userRepository));
        server.createContext("/health", new HealthHandler(userRepository));
        
        server.createContext("/", exchange -> {
            String response = "{\n" +
                "  \"service\": \"Java Web API Server\",\n" +
                "  \"version\": \"1.0.0\",\n" +
                "  \"endpoints\": {\n" +
                "    \"GET /health\": \"Health check\",\n" +
                "    \"GET /api/users\": \"Get all users\",\n" +
                "    \"POST /api/users\": \"Create user\",\n" +
                "    \"GET /api/users/{id}\": \"Get user by ID\",\n" +
                "    \"PUT /api/users/{id}\": \"Update user\",\n" +
                "    \"DELETE /api/users/{id}\": \"Delete user\"\n" +
                "  }\n" +
                "}";
            
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.getBytes().length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(response.getBytes());
            }
        });
    }

    private void setupThreadPool() {
        server.setExecutor(Executors.newFixedThreadPool(10));
    }

    private void seedData() {
        userRepository.save(new User("johndoe", "john@example.com", "John", "Doe"));
        userRepository.save(new User("janedoe", "jane@example.com", "Jane", "Doe"));
        userRepository.save(new User("bobsmith", "bob@example.com", "Bob", "Smith"));
        
        System.out.println("Seeded database with " + userRepository.count() + " users");
    }

    public void start() {
        server.start();
        System.out.println("Java Web API Server started on port " + port);
        System.out.println("API Documentation available at: http://localhost:" + port);
        System.out.println("Health check available at: http://localhost:" + port + "/health");
        System.out.println("Users endpoint: http://localhost:" + port + "/api/users");
    }

    public void stop() {
        server.stop(0);
        System.out.println("Server stopped");
    }

    public static void main(String[] args) {
        System.out.println("Java Web API Server Demo");
        System.out.println("========================");

        try {
            int port = args.length > 0 ? Integer.parseInt(args[0]) : 8080;
            WebAPIServer apiServer = new WebAPIServer(port);
            
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                System.out.println("\nShutting down server...");
                apiServer.stop();
            }));

            apiServer.start();

            System.out.println("\n--- Demo API Usage ---");
            System.out.println("Try these endpoints:");
            System.out.println("GET http://localhost:" + port + "/health");
            System.out.println("GET http://localhost:" + port + "/api/users");
            System.out.println("POST http://localhost:" + port + "/api/users");
            System.out.println("  Body: {\"username\":\"testuser\",\"email\":\"test@example.com\",\"firstName\":\"Test\",\"lastName\":\"User\"}");
            System.out.println("PUT http://localhost:" + port + "/api/users/1");
            System.out.println("  Body: {\"firstName\":\"Updated\",\"active\":\"false\"}");
            System.out.println("DELETE http://localhost:" + port + "/api/users/1");

            System.out.println("\nServer is running. Press Ctrl+C to stop.");
            Thread.currentThread().join();

        } catch (Exception e) {
            System.err.println("Server error: " + e.getMessage());
            e.printStackTrace();
        }

        System.out.println("\n=== Web API Server Demo Complete ===");
    }
} 