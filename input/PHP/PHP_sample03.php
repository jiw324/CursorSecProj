<?php
declare(strict_types=1);

namespace App;

use Exception;
use PDO;
use PDOException;

class Router
{
    private array $routes = [];
    private array $middleware = [];
    private string $basePath = '';
    
    public function __construct(string $basePath = '')
    {
        $this->basePath = rtrim($basePath, '/');
    }
    
    public function get(string $pattern, callable|string $handler, array $middleware = []): void
    {
        $this->addRoute('GET', $pattern, $handler, $middleware);
    }
    
    public function post(string $pattern, callable|string $handler, array $middleware = []): void
    {
        $this->addRoute('POST', $pattern, $handler, $middleware);
    }
    
    public function put(string $pattern, callable|string $handler, array $middleware = []): void
    {
        $this->addRoute('PUT', $pattern, $handler, $middleware);
    }
    
    public function delete(string $pattern, callable|string $handler, array $middleware = []): void
    {
        $this->addRoute('DELETE', $pattern, $handler, $middleware);
    }
    
    private function addRoute(string $method, string $pattern, callable|string $handler, array $middleware): void
    {
        $this->routes[] = [
            'method' => $method,
            'pattern' => $this->basePath . $pattern,
            'handler' => $handler,
            'middleware' => $middleware
        ];
    }
    
    public function addMiddleware(string $name, callable $middleware): void
    {
        $this->middleware[$name] = $middleware;
    }
    
    public function dispatch(): void
    {
        $method = $_SERVER['REQUEST_METHOD'];
        $uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
        
        foreach ($this->routes as $route) {
            if ($route['method'] !== $method) {
                continue;
            }
            
            $params = $this->matchRoute($route['pattern'], $uri);
            if ($params !== false) {
                try {
                    foreach ($route['middleware'] as $middlewareName) {
                        if (isset($this->middleware[$middlewareName])) {
                            $this->middleware[$middlewareName]();
                        }
                    }
                    
                    if (is_string($route['handler'])) {
                        $this->handleControllerAction($route['handler'], $params);
                    } else {
                        call_user_func($route['handler'], $params);
                    }
                    return;
                } catch (Exception $e) {
                    $this->handleError($e);
                    return;
                }
            }
        }
        
        $this->handle404();
    }
    
    private function matchRoute(string $pattern, string $uri): array|false
    {
        $regex = preg_replace('/\{([^}]+)\}/', '(?P<$1>[^/]+)', $pattern);
        $regex = '#^' . $regex . '$#';
        
        if (preg_match($regex, $uri, $matches)) {
            return array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
        }
        
        return false;
    }
    
    private function handleControllerAction(string $handler, array $params): void
    {
        [$controllerName, $action] = explode('@', $handler);
        $controllerClass = "App\\Controllers\\{$controllerName}";
        
        if (!class_exists($controllerClass)) {
            throw new Exception("Controller {$controllerClass} not found");
        }
        
        $controller = new $controllerClass();
        
        if (!method_exists($controller, $action)) {
            throw new Exception("Action {$action} not found in {$controllerClass}");
        }
        
        $controller->$action($params);
    }
    
    private function handleError(Exception $e): void
    {
        http_response_code(500);
        echo "Error: " . $e->getMessage();
    }
    
    private function handle404(): void
    {
        http_response_code(404);
        echo "404 - Page Not Found";
    }
}

abstract class BaseController
{
    protected View $view;
    protected Database $db;
    
    public function __construct()
    {
        $this->view = new View();
        $this->db = Database::getInstance();
    }
    
    protected function json(array $data, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json');
        echo json_encode($data);
    }
    
    protected function redirect(string $url): void
    {
        header("Location: {$url}");
        exit;
    }
    
    protected function validate(array $data, array $rules): array
    {
        $validator = new Validator();
        return $validator->validate($data, $rules);
    }
}

class View
{
    private string $templatePath = 'templates/';
    private array $data = [];
    
    public function render(string $template, array $data = []): void
    {
        $this->data = array_merge($this->data, $data);
        
        $templateFile = $this->templatePath . $template . '.php';
        
        if (!file_exists($templateFile)) {
            throw new Exception("Template {$template} not found");
        }
        
        extract($this->data, EXTR_SKIP);
        
        ob_start();
        include $templateFile;
        $content = ob_get_clean();
        
        echo $content;
    }
    
    public function assign(string $key, mixed $value): void
    {
        $this->data[$key] = $value;
    }
    
    public function escape(string $string): string
    {
        return htmlspecialchars($string, ENT_QUOTES, 'UTF-8');
    }
}

class Database
{
    private static ?Database $instance = null;
    private PDO $connection;
    
    private function __construct()
    {
        $config = [
            'host' => $_ENV['DB_HOST'] ?? 'localhost',
            'dbname' => $_ENV['DB_NAME'] ?? 'app_db',
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
    
    public static function getInstance(): Database
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function getConnection(): PDO
    {
        return $this->connection;
    }
    
    public function query(string $sql, array $params = []): array
    {
        $stmt = $this->connection->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }
    
    public function execute(string $sql, array $params = []): bool
    {
        $stmt = $this->connection->prepare($sql);
        return $stmt->execute($params);
    }
    
    public function lastInsertId(): string
    {
        return $this->connection->lastInsertId();
    }
}

abstract class Model
{
    protected static string $table = '';
    protected static array $fillable = [];
    protected Database $db;
    protected array $attributes = [];
    
    public function __construct(array $attributes = [])
    {
        $this->db = Database::getInstance();
        $this->fill($attributes);
    }
    
    public function fill(array $attributes): void
    {
        foreach ($attributes as $key => $value) {
            if (in_array($key, static::$fillable)) {
                $this->attributes[$key] = $value;
            }
        }
    }
    
    public function __get(string $key): mixed
    {
        return $this->attributes[$key] ?? null;
    }
    
    public function __set(string $key, mixed $value): void
    {
        if (in_array($key, static::$fillable)) {
            $this->attributes[$key] = $value;
        }
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
        $fields = array_keys($this->attributes);
        $placeholders = ':' . implode(', :', $fields);
        $fieldsList = implode(', ', $fields);
        
        $sql = "INSERT INTO " . static::$table . " ({$fieldsList}) VALUES ({$placeholders})";
        
        if ($this->db->execute($sql, $this->attributes)) {
            $this->attributes['id'] = (int)$this->db->lastInsertId();
            return true;
        }
        
        return false;
    }
    
    private function update(): bool
    {
        $fields = [];
        foreach (array_keys($this->attributes) as $field) {
            if ($field !== 'id') {
                $fields[] = "{$field} = :{$field}";
            }
        }
        
        $sql = "UPDATE " . static::$table . " SET " . implode(', ', $fields) . " WHERE id = :id";
        return $this->db->execute($sql, $this->attributes);
    }
    
    public static function find(int $id): ?static
    {
        $db = Database::getInstance();
        $result = $db->query("SELECT * FROM " . static::$table . " WHERE id = ?", [$id]);
        
        return $result ? new static($result[0]) : null;
    }
    
    public static function all(): array
    {
        $db = Database::getInstance();
        $results = $db->query("SELECT * FROM " . static::$table);
        
        return array_map(fn($row) => new static($row), $results);
    }
    
    public static function where(string $column, mixed $value): array
    {
        $db = Database::getInstance();
        $results = $db->query("SELECT * FROM " . static::$table . " WHERE {$column} = ?", [$value]);
        
        return array_map(fn($row) => new static($row), $results);
    }
    
    public function delete(): bool
    {
        if (!isset($this->attributes['id'])) {
            return false;
        }
        
        return $this->db->execute("DELETE FROM " . static::$table . " WHERE id = ?", [$this->attributes['id']]);
    }
}

class User extends Model
{
    protected static string $table = 'users';
    protected static array $fillable = ['name', 'email', 'password', 'created_at', 'updated_at'];
    
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
    
    public static function findByEmail(string $email): ?User
    {
        $users = static::where('email', $email);
        return $users[0] ?? null;
    }
    
    public function posts(): array
    {
        return Post::where('user_id', $this->id);
    }
}

class Post extends Model
{
    protected static string $table = 'posts';
    protected static array $fillable = ['title', 'content', 'user_id', 'status', 'created_at', 'updated_at'];
    
    public function user(): ?User
    {
        return User::find($this->user_id);
    }
    
    public function getExcerpt(int $length = 150): string
    {
        $content = strip_tags($this->content ?? '');
        return strlen($content) > $length ? substr($content, 0, $length) . '...' : $content;
    }
    
    public static function published(): array
    {
        return static::where('status', 'published');
    }
}

class Validator
{
    public function validate(array $data, array $rules): array
    {
        $errors = [];
        
        foreach ($rules as $field => $ruleString) {
            $fieldRules = explode('|', $ruleString);
            
            foreach ($fieldRules as $rule) {
                $ruleParts = explode(':', $rule);
                $ruleName = $ruleParts[0];
                $ruleValue = $ruleParts[1] ?? null;
                
                $error = $this->validateField($data[$field] ?? null, $ruleName, $ruleValue, $field);
                if ($error) {
                    $errors[$field][] = $error;
                }
            }
        }
        
        return $errors;
    }
    
    private function validateField(mixed $value, string $rule, ?string $ruleValue, string $fieldName): ?string
    {
        switch ($rule) {
            case 'required':
                return empty($value) ? "{$fieldName} is required" : null;
                
            case 'email':
                return !filter_var($value, FILTER_VALIDATE_EMAIL) ? "{$fieldName} must be a valid email" : null;
                
            case 'min':
                return strlen($value ?? '') < (int)$ruleValue ? "{$fieldName} must be at least {$ruleValue} characters" : null;
                
            case 'max':
                return strlen($value ?? '') > (int)$ruleValue ? "{$fieldName} must not exceed {$ruleValue} characters" : null;
                
            case 'unique':
                [$table, $column] = explode(',', $ruleValue);
                $db = Database::getInstance();
                $result = $db->query("SELECT COUNT(*) as count FROM {$table} WHERE {$column} = ?", [$value]);
                return $result[0]['count'] > 0 ? "{$fieldName} already exists" : null;
                
            default:
                return null;
        }
    }
}

class Session
{
    public static function start(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
    }
    
    public static function set(string $key, mixed $value): void
    {
        $_SESSION[$key] = $value;
    }
    
    public static function get(string $key, mixed $default = null): mixed
    {
        return $_SESSION[$key] ?? $default;
    }
    
    public static function has(string $key): bool
    {
        return isset($_SESSION[$key]);
    }
    
    public static function remove(string $key): void
    {
        unset($_SESSION[$key]);
    }
    
    public static function destroy(): void
    {
        session_destroy();
    }
    
    public static function regenerateId(): void
    {
        session_regenerate_id(true);
    }
    
    public static function flash(string $key, mixed $value = null): mixed
    {
        if ($value !== null) {
            $_SESSION['flash'][$key] = $value;
            return $value;
        }
        
        $flashValue = $_SESSION['flash'][$key] ?? null;
        unset($_SESSION['flash'][$key]);
        return $flashValue;
    }
}

class CSRFMiddleware
{
    public static function generateToken(): string
    {
        if (!Session::has('csrf_token')) {
            Session::set('csrf_token', bin2hex(random_bytes(32)));
        }
        return Session::get('csrf_token');
    }
    
    public static function validateToken(string $token): bool
    {
        return hash_equals(Session::get('csrf_token', ''), $token);
    }
    
    public static function middleware(): void
    {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $token = $_POST['csrf_token'] ?? $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
            
            if (!self::validateToken($token)) {
                http_response_code(403);
                die('CSRF token validation failed');
            }
        }
    }
}

namespace App\Controllers;

use App\BaseController;
use App\User;
use App\Post;
use App\Session;
use App\CSRFMiddleware;

class HomeController extends BaseController
{
    public function index(): void
    {
        $posts = Post::published();
        $this->view->render('home', [
            'posts' => $posts,
            'title' => 'Welcome to Our Blog'
        ]);
    }
    
    public function about(): void
    {
        $this->view->render('about', [
            'title' => 'About Us'
        ]);
    }
}

class AuthController extends BaseController
{
    public function showLogin(): void
    {
        $this->view->render('auth/login', [
            'title' => 'Login',
            'csrf_token' => CSRFMiddleware::generateToken()
        ]);
    }
    
    public function login(): void
    {
        $errors = $this->validate($_POST, [
            'email' => 'required|email',
            'password' => 'required'
        ]);
        
        if (!empty($errors)) {
            $this->view->render('auth/login', [
                'errors' => $errors,
                'title' => 'Login',
                'csrf_token' => CSRFMiddleware::generateToken()
            ]);
            return;
        }
        
        $user = User::findByEmail($_POST['email']);
        
        if ($user && $user->verifyPassword($_POST['password'])) {
            Session::set('user_id', $user->id);
            Session::regenerateId();
            Session::flash('success', 'Login successful');
            $this->redirect('/dashboard');
        } else {
            Session::flash('error', 'Invalid credentials');
            $this->redirect('/login');
        }
    }
    
    public function showRegister(): void
    {
        $this->view->render('auth/register', [
            'title' => 'Register',
            'csrf_token' => CSRFMiddleware::generateToken()
        ]);
    }
    
    public function register(): void
    {
        $errors = $this->validate($_POST, [
            'name' => 'required|min:2|max:50',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|min:8'
        ]);
        
        if (!empty($errors)) {
            $this->view->render('auth/register', [
                'errors' => $errors,
                'title' => 'Register',
                'csrf_token' => CSRFMiddleware::generateToken()
            ]);
            return;
        }
        
        $user = new User([
            'name' => $_POST['name'],
            'email' => $_POST['email'],
            'password' => $_POST['password'],
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s')
        ]);
        
        $user->hashPassword();
        
        if ($user->save()) {
            Session::flash('success', 'Registration successful');
            $this->redirect('/login');
        } else {
            Session::flash('error', 'Registration failed');
            $this->redirect('/register');
        }
    }
    
    public function logout(): void
    {
        Session::destroy();
        $this->redirect('/');
    }
}

class BlogController extends BaseController
{
    public function index(): void
    {
        $posts = Post::all();
        $this->view->render('blog/index', [
            'posts' => $posts,
            'title' => 'All Posts'
        ]);
    }
    
    public function show(array $params): void
    {
        $post = Post::find((int)$params['id']);
        
        if (!$post) {
            http_response_code(404);
            $this->view->render('errors/404');
            return;
        }
        
        $this->view->render('blog/show', [
            'post' => $post,
            'title' => $post->title
        ]);
    }
    
    public function create(): void
    {
        if (!Session::has('user_id')) {
            $this->redirect('/login');
            return;
        }
        
        $this->view->render('blog/create', [
            'title' => 'Create Post',
            'csrf_token' => CSRFMiddleware::generateToken()
        ]);
    }
    
    public function store(): void
    {
        if (!Session::has('user_id')) {
            $this->redirect('/login');
            return;
        }
        
        $errors = $this->validate($_POST, [
            'title' => 'required|min:5|max:255',
            'content' => 'required|min:10'
        ]);
        
        if (!empty($errors)) {
            $this->view->render('blog/create', [
                'errors' => $errors,
                'title' => 'Create Post',
                'csrf_token' => CSRFMiddleware::generateToken()
            ]);
            return;
        }
        
        $post = new Post([
            'title' => $_POST['title'],
            'content' => $_POST['content'],
            'user_id' => Session::get('user_id'),
            'status' => 'published',
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s')
        ]);
        
        if ($post->save()) {
            Session::flash('success', 'Post created successfully');
            $this->redirect('/blog/' . $post->id);
        } else {
            Session::flash('error', 'Failed to create post');
            $this->redirect('/blog/create');
        }
    }
}

namespace App;

Session::start();

if (file_exists('.env')) {
    $lines = file('.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos($line, '=') !== false && strpos($line, '#') !== 0) {
            [$key, $value] = explode('=', $line, 2);
            $_ENV[trim($key)] = trim($value);
        }
    }
}

$router = new Router();

$router->addMiddleware('csrf', [CSRFMiddleware::class, 'middleware']);

$router->get('/', 'HomeController@index');
$router->get('/about', 'HomeController@about');

$router->get('/login', 'AuthController@showLogin');
$router->post('/login', 'AuthController@login', ['csrf']);
$router->get('/register', 'AuthController@showRegister');
$router->post('/register', 'AuthController@register', ['csrf']);
$router->post('/logout', 'AuthController@logout', ['csrf']);

$router->get('/blog', 'BlogController@index');
$router->get('/blog/{id}', 'BlogController@show');
$router->get('/blog/create', 'BlogController@create');
$router->post('/blog', 'BlogController@store', ['csrf']);

$router->get('/api/posts', function() {
    header('Content-Type: application/json');
    echo json_encode(Post::all());
});

$router->get('/api/posts/{id}', function($params) {
    $post = Post::find((int)$params['id']);
    header('Content-Type: application/json');
    echo json_encode($post ? $post : ['error' => 'Post not found']);
});

if (php_sapi_name() !== 'cli') {
    $router->dispatch();
}

function setupDatabase(): void
{
    $db = Database::getInstance();
    
    $db->execute("
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ");
    
    $db->execute("
        CREATE TABLE IF NOT EXISTS posts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            content TEXT NOT NULL,
            user_id INT NOT NULL,
            status ENUM('draft', 'published') DEFAULT 'draft',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ");
}
