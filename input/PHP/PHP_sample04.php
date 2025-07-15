<?php
declare(strict_types=1);

namespace Api;

use Exception;
use PDO;
use PDOException;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

class ApiResponse
{
    public static function success(mixed $data = null, string $message = 'Success', int $code = 200): void
    {
        self::json([
            'success' => true,
            'message' => $message,
            'data' => $data,
            'timestamp' => time()
        ], $code);
    }
    
    public static function error(string $message = 'Error', int $code = 400, mixed $errors = null): void
    {
        self::json([
            'success' => false,
            'message' => $message,
            'errors' => $errors,
            'timestamp' => time()
        ], $code);
    }
    
    public static function paginated(array $data, int $total, int $page, int $limit): void
    {
        self::success([
            'items' => $data,
            'pagination' => [
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'pages' => ceil($total / $limit),
                'hasNext' => $page * $limit < $total,
                'hasPrev' => $page > 1
            ]
        ]);
    }
    
    private static function json(array $data, int $code): void
    {
        http_response_code($code);
        header('Content-Type: application/json; charset=utf-8');
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
        
        if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
            exit;
        }
        
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
}

class JWTAuth
{
    private string $secretKey;
    private string $algorithm = 'HS256';
    private int $expiration = 3600;
    
    public function __construct(string $secretKey = null)
    {
        $this->secretKey = $secretKey ?? $_ENV['JWT_SECRET'] ?? 'your-secret-key-change-in-production';
    }
    
    public function generateToken(array $payload): string
    {
        $payload['iat'] = time();
        $payload['exp'] = time() + $this->expiration;
        $payload['iss'] = $_SERVER['HTTP_HOST'] ?? 'api.example.com';
        
        return JWT::encode($payload, $this->secretKey, $this->algorithm);
    }
    
    public function validateToken(string $token): ?array
    {
        try {
            $decoded = JWT::decode($token, new Key($this->secretKey, $this->algorithm));
            return (array) $decoded;
        } catch (Exception $e) {
            return null;
        }
    }
    
    public function extractTokenFromHeader(): ?string
    {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $matches[1];
        }
        
        return null;
    }
    
    public function getCurrentUser(): ?array
    {
        $token = $this->extractTokenFromHeader();
        
        if (!$token) {
            return null;
        }
        
        return $this->validateToken($token);
    }
}

class RateLimit
{
    private array $limits = [];
    private string $storage = 'file'; 
    
    public function __construct(array $config = [])
    {
        $this->limits = $config['limits'] ?? [
            'default' => ['requests' => 100, 'window' => 3600],
            'auth' => ['requests' => 5, 'window' => 300],
            'api' => ['requests' => 1000, 'window' => 3600]
        ];
    }
    
    public function check(string $identifier, string $type = 'default'): bool
    {
        $limit = $this->limits[$type] ?? $this->limits['default'];
        $key = "rate_limit_{$type}_{$identifier}";
        
        $current = $this->getCount($key);
        $window = $this->getWindow($key);
        
        if ($window && (time() - $window) > $limit['window']) {
            $this->resetCount($key);
            $current = 0;
        }
        
        if ($current >= $limit['requests']) {
            return false;
        }
        
        $this->incrementCount($key);
        return true;
    }
    
    private function getCount(string $key): int
    {
        $data = $this->getData($key);
        return $data['count'] ?? 0;
    }
    
    private function getWindow(string $key): ?int
    {
        $data = $this->getData($key);
        return $data['window'] ?? null;
    }
    
    private function incrementCount(string $key): void
    {
        $data = $this->getData($key);
        $data['count'] = ($data['count'] ?? 0) + 1;
        $data['window'] = $data['window'] ?? time();
        $this->setData($key, $data);
    }
    
    private function resetCount(string $key): void
    {
        $this->setData($key, ['count' => 0, 'window' => time()]);
    }
    
    private function getData(string $key): array
    {
        $file = sys_get_temp_dir() . "/{$key}.json";
        
        if (file_exists($file)) {
            $content = file_get_contents($file);
            return json_decode($content, true) ?: [];
        }
        
        return [];
    }
    
    private function setData(string $key, array $data): void
    {
        $file = sys_get_temp_dir() . "/{$key}.json";
        file_put_contents($file, json_encode($data));
    }
}

class ApiValidator
{
    private array $rules = [];
    private array $messages = [];
    
    public function validate(array $data, array $rules): array
    {
        $errors = [];
        
        foreach ($rules as $field => $ruleString) {
            $fieldRules = is_array($ruleString) ? $ruleString : explode('|', $ruleString);
            
            foreach ($fieldRules as $rule) {
                $error = $this->validateRule($data[$field] ?? null, $rule, $field, $data);
                if ($error) {
                    $errors[$field][] = $error;
                }
            }
        }
        
        return $errors;
    }
    
    private function validateRule(mixed $value, string $rule, string $field, array $data): ?string
    {
        if (str_contains($rule, ':')) {
            [$ruleName, $parameter] = explode(':', $rule, 2);
        } else {
            $ruleName = $rule;
            $parameter = null;
        }
        
        return match ($ruleName) {
            'required' => empty($value) ? "{$field} is required" : null,
            'email' => !filter_var($value, FILTER_VALIDATE_EMAIL) ? "{$field} must be valid email" : null,
            'min' => strlen($value ?? '') < (int)$parameter ? "{$field} must be at least {$parameter} characters" : null,
            'max' => strlen($value ?? '') > (int)$parameter ? "{$field} cannot exceed {$parameter} characters" : null,
            'numeric' => !is_numeric($value) ? "{$field} must be numeric" : null,
            'integer' => !filter_var($value, FILTER_VALIDATE_INT) ? "{$field} must be integer" : null,
            'url' => !filter_var($value, FILTER_VALIDATE_URL) ? "{$field} must be valid URL" : null,
            'json' => !$this->isValidJson($value) ? "{$field} must be valid JSON" : null,
            'confirmed' => $value !== ($data["{$field}_confirmation"] ?? null) ? "{$field} confirmation does not match" : null,
            'in' => !in_array($value, explode(',', $parameter)) ? "{$field} must be one of: {$parameter}" : null,
            'date' => !strtotime($value) ? "{$field} must be valid date" : null,
            'regex' => !preg_match("/{$parameter}/", $value ?? '') ? "{$field} format is invalid" : null,
            default => null
        };
    }
    
    private function isValidJson(mixed $value): bool
    {
        if (!is_string($value)) return false;
        json_decode($value);
        return json_last_error() === JSON_ERROR_NONE;
    }
}

class ApiDatabase
{
    private static ?ApiDatabase $instance = null;
    private PDO $connection;
    private array $queryLog = [];
    
    private function __construct()
    {
        $config = [
            'host' => $_ENV['DB_HOST'] ?? 'localhost',
            'dbname' => $_ENV['DB_NAME'] ?? 'api_db',
            'username' => $_ENV['DB_USER'] ?? 'root',
            'password' => $_ENV['DB_PASS'] ?? '',
            'charset' => 'utf8mb4'
        ];
        
        try {
            $dsn = "mysql:host={$config['host']};dbname={$config['dbname']};charset={$config['charset']}";
            $this->connection = new PDO($dsn, $config['username'], $config['password'], [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false
            ]);
        } catch (PDOException $e) {
            throw new Exception("Database connection failed: " . $e->getMessage());
        }
    }
    
    public static function getInstance(): ApiDatabase
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function query(string $sql, array $params = []): array
    {
        $start = microtime(true);
        
        try {
            $stmt = $this->connection->prepare($sql);
            $stmt->execute($params);
            $result = $stmt->fetchAll();
            
            $this->logQuery($sql, $params, microtime(true) - $start);
            return $result;
            
        } catch (PDOException $e) {
            throw new Exception("Database query failed: " . $e->getMessage());
        }
    }
    
    public function execute(string $sql, array $params = []): bool
    {
        $start = microtime(true);
        
        try {
            $stmt = $this->connection->prepare($sql);
            $result = $stmt->execute($params);
            
            $this->logQuery($sql, $params, microtime(true) - $start);
            return $result;
            
        } catch (PDOException $e) {
            throw new Exception("Database execution failed: " . $e->getMessage());
        }
    }
    
    public function lastInsertId(): string
    {
        return $this->connection->lastInsertId();
    }
    
    public function beginTransaction(): bool
    {
        return $this->connection->beginTransaction();
    }
    
    public function commit(): bool
    {
        return $this->connection->commit();
    }
    
    public function rollback(): bool
    {
        return $this->connection->rollback();
    }
    
    private function logQuery(string $sql, array $params, float $time): void
    {
        if ($_ENV['DB_LOG_QUERIES'] ?? false) {
            $this->queryLog[] = [
                'sql' => $sql,
                'params' => $params,
                'time' => $time,
                'timestamp' => microtime(true)
            ];
        }
    }
    
    public function getQueryLog(): array
    {
        return $this->queryLog;
    }
}

abstract class ApiModel
{
    protected static string $table = '';
    protected static array $fillable = [];
    protected static array $hidden = [];
    protected ApiDatabase $db;
    protected array $attributes = [];
    
    public function __construct(array $attributes = [])
    {
        $this->db = ApiDatabase::getInstance();
        $this->fill($attributes);
    }
    
    public function fill(array $attributes): void
    {
        foreach ($attributes as $key => $value) {
            if (in_array($key, static::$fillable) || empty(static::$fillable)) {
                $this->attributes[$key] = $value;
            }
        }
    }
    
    public function toArray(): array
    {
        $array = $this->attributes;
        
        foreach (static::$hidden as $field) {
            unset($array[$field]);
        }
        
        return $array;
    }
    
    public function toJson(): string
    {
        return json_encode($this->toArray());
    }
    
    public function __get(string $key): mixed
    {
        return $this->attributes[$key] ?? null;
    }
    
    public function __set(string $key, mixed $value): void
    {
        $this->attributes[$key] = $value;
    }
    
    public function save(): bool
    {
        if (isset($this->attributes['id'])) {
            return $this->update();
        } else {
            return $this->insert();
        }
    }
    
    private function insert(): bool
    {
        $fillableAttributes = array_intersect_key(
            $this->attributes, 
            array_flip(static::$fillable)
        );
        
        if (empty($fillableAttributes)) {
            $fillableAttributes = $this->attributes;
        }
        
        $fields = array_keys($fillableAttributes);
        $placeholders = ':' . implode(', :', $fields);
        $fieldsList = implode(', ', $fields);
        
        $sql = "INSERT INTO " . static::$table . " ({$fieldsList}) VALUES ({$placeholders})";
        
        if ($this->db->execute($sql, $fillableAttributes)) {
            $this->attributes['id'] = (int)$this->db->lastInsertId();
            return true;
        }
        
        return false;
    }
    
    private function update(): bool
    {
        $fillableAttributes = array_intersect_key(
            $this->attributes, 
            array_flip(static::$fillable)
        );
        
        if (empty($fillableAttributes)) {
            $fillableAttributes = array_filter($this->attributes, fn($key) => $key !== 'id', ARRAY_FILTER_USE_KEY);
        }
        
        $fields = [];
        foreach (array_keys($fillableAttributes) as $field) {
            $fields[] = "{$field} = :{$field}";
        }
        
        $fillableAttributes['id'] = $this->attributes['id'];
        
        $sql = "UPDATE " . static::$table . " SET " . implode(', ', $fields) . " WHERE id = :id";
        return $this->db->execute($sql, $fillableAttributes);
    }
    
    public static function find(int $id): ?static
    {
        $db = ApiDatabase::getInstance();
        $result = $db->query("SELECT * FROM " . static::$table . " WHERE id = ?", [$id]);
        
        return $result ? new static($result[0]) : null;
    }
    
    public static function all(int $limit = 100, int $offset = 0): array
    {
        $db = ApiDatabase::getInstance();
        $results = $db->query("SELECT * FROM " . static::$table . " LIMIT ? OFFSET ?", [$limit, $offset]);
        
        return array_map(fn($row) => new static($row), $results);
    }
    
    public static function where(string $column, mixed $value, string $operator = '='): array
    {
        $db = ApiDatabase::getInstance();
        $results = $db->query("SELECT * FROM " . static::$table . " WHERE {$column} {$operator} ?", [$value]);
        
        return array_map(fn($row) => new static($row), $results);
    }
    
    public static function count(array $conditions = []): int
    {
        $db = ApiDatabase::getInstance();
        
        if (empty($conditions)) {
            $result = $db->query("SELECT COUNT(*) as count FROM " . static::$table);
        } else {
            $whereClause = [];
            $params = [];
            
            foreach ($conditions as $column => $value) {
                $whereClause[] = "{$column} = ?";
                $params[] = $value;
            }
            
            $sql = "SELECT COUNT(*) as count FROM " . static::$table . " WHERE " . implode(' AND ', $whereClause);
            $result = $db->query($sql, $params);
        }
        
        return (int)$result[0]['count'];
    }
    
    public function delete(): bool
    {
        if (!isset($this->attributes['id'])) {
            return false;
        }
        
        return $this->db->execute("DELETE FROM " . static::$table . " WHERE id = ?", [$this->attributes['id']]);
    }
}

class ApiUser extends ApiModel
{
    protected static string $table = 'users';
    protected static array $fillable = ['name', 'email', 'password', 'role', 'created_at', 'updated_at'];
    protected static array $hidden = ['password'];
    
    public function hashPassword(): void
    {
        if (isset($this->attributes['password'])) {
            $this->attributes['password'] = password_hash($this->attributes['password'], PASSWORD_DEFAULT);
        }
    }
    
    public function verifyPassword(string $password): bool
    {
        return password_verify($password, $this->attributes['password'] ?? '');
    }
    
    public static function findByEmail(string $email): ?ApiUser
    {
        $users = static::where('email', $email);
        return $users[0] ?? null;
    }
    
    public function generateApiKey(): string
    {
        $apiKey = bin2hex(random_bytes(32));
        $this->attributes['api_key'] = $apiKey;
        $this->save();
        return $apiKey;
    }
}

class Product extends ApiModel
{
    protected static string $table = 'products';
    protected static array $fillable = ['name', 'description', 'price', 'stock', 'category_id', 'sku', 'status', 'created_at', 'updated_at'];
    
    public function category(): ?Category
    {
        return Category::find($this->category_id);
    }
    
    public function isInStock(): bool
    {
        return $this->stock > 0 && $this->status === 'active';
    }
    
    public function updateStock(int $quantity): bool
    {
        $this->attributes['stock'] = max(0, $this->stock - $quantity);
        return $this->save();
    }
}

class Category extends ApiModel
{
    protected static string $table = 'categories';
    protected static array $fillable = ['name', 'description', 'parent_id', 'created_at'];
    
    public function products(): array
    {
        return Product::where('category_id', $this->id);
    }
    
    public function parent(): ?Category
    {
        return $this->parent_id ? Category::find($this->parent_id) : null;
    }
}

namespace Api\Controllers;

use Api\ApiResponse;
use Api\ApiValidator;
use Api\JWTAuth;
use Api\RateLimit;
use Api\ApiUser;
use Api\Product;
use Api\Category;

class AuthController
{
    private JWTAuth $jwt;
    private ApiValidator $validator;
    private RateLimit $rateLimit;
    
    public function __construct()
    {
        $this->jwt = new JWTAuth();
        $this->validator = new ApiValidator();
        $this->rateLimit = new RateLimit();
    }
    
    public function login(): void
    {
        $clientIp = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        
        if (!$this->rateLimit->check($clientIp, 'auth')) {
            ApiResponse::error('Too many login attempts. Please try again later.', 429);
        }
        
        $input = json_decode(file_get_contents('php://input'), true) ?? [];
        
        $errors = $this->validator->validate($input, [
            'email' => 'required|email',
            'password' => 'required'
        ]);
        
        if (!empty($errors)) {
            ApiResponse::error('Validation failed', 422, $errors);
        }
        
        $user = ApiUser::findByEmail($input['email']);
        
        if (!$user || !$user->verifyPassword($input['password'])) {
            ApiResponse::error('Invalid credentials', 401);
        }
        
        $token = $this->jwt->generateToken([
            'user_id' => $user->id,
            'email' => $user->email,
            'role' => $user->role
        ]);
        
        ApiResponse::success([
            'token' => $token,
            'user' => $user->toArray()
        ], 'Login successful');
    }
    
    public function register(): void
    {
        $input = json_decode(file_get_contents('php://input'), true) ?? [];
        
        $errors = $this->validator->validate($input, [
            'name' => 'required|min:2|max:100',
            'email' => 'required|email',
            'password' => 'required|min:8',
            'password_confirmation' => 'required|confirmed'
        ]);
        
        if (!empty($errors)) {
            ApiResponse::error('Validation failed', 422, $errors);
        }
        
        if (ApiUser::findByEmail($input['email'])) {
            ApiResponse::error('Email already registered', 409);
        }
        
        $user = new ApiUser([
            'name' => $input['name'],
            'email' => $input['email'],
            'password' => $input['password'],
            'role' => 'user',
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s')
        ]);
        
        $user->hashPassword();
        
        if ($user->save()) {
            $token = $this->jwt->generateToken([
                'user_id' => $user->id,
                'email' => $user->email,
                'role' => $user->role
            ]);
            
            ApiResponse::success([
                'token' => $token,
                'user' => $user->toArray()
            ], 'Registration successful', 201);
        } else {
            ApiResponse::error('Registration failed', 500);
        }
    }
    
    public function me(): void
    {
        $user = $this->getCurrentUser();
        
        if (!$user) {
            ApiResponse::error('Unauthorized', 401);
        }
        
        ApiResponse::success($user->toArray());
    }
    
    private function getCurrentUser(): ?ApiUser
    {
        $userData = $this->jwt->getCurrentUser();
        
        if (!$userData) {
            return null;
        }
        
        return ApiUser::find($userData['user_id']);
    }
}

class ProductController
{
    private ApiValidator $validator;
    private JWTAuth $jwt;
    
    public function __construct()
    {
        $this->validator = new ApiValidator();
        $this->jwt = new JWTAuth();
    }
    
    public function index(): void
    {
        $page = (int)($_GET['page'] ?? 1);
        $limit = min((int)($_GET['limit'] ?? 20), 100);
        $offset = ($page - 1) * $limit;
        
        $category = $_GET['category'] ?? null;
        $search = $_GET['search'] ?? null;
        
        if ($category || $search) {
            $products = $this->filterProducts($category, $search, $limit, $offset);
            $total = $this->countFilteredProducts($category, $search);
        } else {
            $products = Product::all($limit, $offset);
            $total = Product::count();
        }
        
        ApiResponse::paginated(
            array_map(fn($product) => $product->toArray(), $products),
            $total,
            $page,
            $limit
        );
    }
    
    public function show(int $id): void
    {
        $product = Product::find($id);
        
        if (!$product) {
            ApiResponse::error('Product not found', 404);
        }
        
        $productData = $product->toArray();
        $productData['category'] = $product->category()?->toArray();
        
        ApiResponse::success($productData);
    }
    
    public function store(): void
    {
        $this->requireAuth();
        
        $input = json_decode(file_get_contents('php://input'), true) ?? [];
        
        $errors = $this->validator->validate($input, [
            'name' => 'required|min:2|max:255',
            'description' => 'required',
            'price' => 'required|numeric',
            'stock' => 'required|integer',
            'category_id' => 'required|integer',
            'sku' => 'required|max:100'
        ]);
        
        if (!empty($errors)) {
            ApiResponse::error('Validation failed', 422, $errors);
        }
        
        if (!Category::find($input['category_id'])) {
            ApiResponse::error('Category not found', 400);
        }
        
        $product = new Product([
            'name' => $input['name'],
            'description' => $input['description'],
            'price' => $input['price'],
            'stock' => $input['stock'],
            'category_id' => $input['category_id'],
            'sku' => $input['sku'],
            'status' => 'active',
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s')
        ]);
        
        if ($product->save()) {
            ApiResponse::success($product->toArray(), 'Product created successfully', 201);
        } else {
            ApiResponse::error('Failed to create product', 500);
        }
    }
    
    public function update(int $id): void
    {
        $this->requireAuth();
        
        $product = Product::find($id);
        
        if (!$product) {
            ApiResponse::error('Product not found', 404);
        }
        
        $input = json_decode(file_get_contents('php://input'), true) ?? [];
        
        $errors = $this->validator->validate($input, [
            'name' => 'min:2|max:255',
            'price' => 'numeric',
            'stock' => 'integer',
            'category_id' => 'integer'
        ]);
        
        if (!empty($errors)) {
            ApiResponse::error('Validation failed', 422, $errors);
        }
        
        if (isset($input['category_id']) && !Category::find($input['category_id'])) {
            ApiResponse::error('Category not found', 400);
        }
        
        $product->fill($input);
        $product->updated_at = date('Y-m-d H:i:s');
        
        if ($product->save()) {
            ApiResponse::success($product->toArray(), 'Product updated successfully');
        } else {
            ApiResponse::error('Failed to update product', 500);
        }
    }
    
    public function destroy(int $id): void
    {
        $this->requireAuth();
        
        $product = Product::find($id);
        
        if (!$product) {
            ApiResponse::error('Product not found', 404);
        }
        
        if ($product->delete()) {
            ApiResponse::success(null, 'Product deleted successfully');
        } else {
            ApiResponse::error('Failed to delete product', 500);
        }
    }
    
    private function filterProducts(?string $category, ?string $search, int $limit, int $offset): array
    {
        $conditions = [];
        $params = [];
        
        if ($category) {
            $conditions[] = "category_id = ?";
            $params[] = $category;
        }
        
        if ($search) {
            $conditions[] = "(name LIKE ? OR description LIKE ?)";
            $params[] = "%{$search}%";
            $params[] = "%{$search}%";
        }
        
        $whereClause = !empty($conditions) ? "WHERE " . implode(" AND ", $conditions) : "";
        $sql = "SELECT * FROM products {$whereClause} LIMIT ? OFFSET ?";
        
        $params[] = $limit;
        $params[] = $offset;
        
        $db = \Api\ApiDatabase::getInstance();
        $results = $db->query($sql, $params);
        
        return array_map(fn($row) => new Product($row), $results);
    }
    
    private function countFilteredProducts(?string $category, ?string $search): int
    {
        $conditions = [];
        $params = [];
        
        if ($category) {
            $conditions[] = "category_id = ?";
            $params[] = $category;
        }
        
        if ($search) {
            $conditions[] = "(name LIKE ? OR description LIKE ?)";
            $params[] = "%{$search}%";
            $params[] = "%{$search}%";
        }
        
        $whereClause = !empty($conditions) ? "WHERE " . implode(" AND ", $conditions) : "";
        $sql = "SELECT COUNT(*) as count FROM products {$whereClause}";
        
        $db = \Api\ApiDatabase::getInstance();
        $result = $db->query($sql, $params);
        
        return (int)$result[0]['count'];
    }
    
    private function requireAuth(): void
    {
        $user = $this->jwt->getCurrentUser();
        
        if (!$user) {
            ApiResponse::error('Authentication required', 401);
        }
    }
}

class ApiRouter
{
    private array $routes = [];
    
    public function addRoute(string $method, string $pattern, callable $handler): void
    {
        $this->routes[] = [
            'method' => strtoupper($method),
            'pattern' => $pattern,
            'handler' => $handler
        ];
    }
    
    public function dispatch(): void
    {
        $method = $_SERVER['REQUEST_METHOD'];
        $uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

        $uri = preg_replace('#^/api/v1#', '', $uri);
        
        foreach ($this->routes as $route) {
            if ($route['method'] !== $method) {
                continue;
            }
            
            $params = $this->matchRoute($route['pattern'], $uri);
            if ($params !== false) {
                try {
                    call_user_func($route['handler'], ...$params);
                    return;
                } catch (Exception $e) {
                    ApiResponse::error('Internal server error: ' . $e->getMessage(), 500);
                }
            }
        }
        
        ApiResponse::error('Endpoint not found', 404);
    }
    
    private function matchRoute(string $pattern, string $uri): array|false
    {
        $regex = preg_replace('/\{([^}]+)\}/', '([^/]+)', $pattern);
        $regex = '#^' . $regex . '$#';
        
        if (preg_match($regex, $uri, $matches)) {
            array_shift($matches);
            return $matches;
        }
        
        return false;
    }
}

$router = new ApiRouter();

$router->addRoute('POST', '/auth/login', function() {
    $controller = new Controllers\AuthController();
    $controller->login();
});

$router->addRoute('POST', '/auth/register', function() {
    $controller = new Controllers\AuthController();
    $controller->register();
});

$router->addRoute('GET', '/auth/me', function() {
    $controller = new Controllers\AuthController();
    $controller->me();
});

$router->addRoute('GET', '/products', function() {
    $controller = new Controllers\ProductController();
    $controller->index();
});

$router->addRoute('GET', '/products/{id}', function($id) {
    $controller = new Controllers\ProductController();
    $controller->show((int)$id);
});

$router->addRoute('POST', '/products', function() {
    $controller = new Controllers\ProductController();
    $controller->store();
});

$router->addRoute('PUT', '/products/{id}', function($id) {
    $controller = new Controllers\ProductController();
    $controller->update((int)$id);
});

$router->addRoute('DELETE', '/products/{id}', function($id) {
    $controller = new Controllers\ProductController();
    $controller->destroy((int)$id);
});

$router->addRoute('GET', '/health', function() {
    ApiResponse::success([
        'status' => 'OK',
        'timestamp' => time(),
        'version' => '1.0.0'
    ]);
});

if (php_sapi_name() !== 'cli') {
    $router->dispatch();
} 