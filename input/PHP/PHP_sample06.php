<?php
session_start();

class VulnerableDBApp {
    private $db;
    private $logFile = 'dbapp.log';

    public function __construct() {
        $this->initDatabase();
    }

    private function initDatabase() {
        $this->db = new mysqli('localhost', 'root', '', 'vulnerable_db');
        if ($this->db->connect_error) {
            die('Database connection failed: ' . $this->db->connect_error);
        }
    }

    public function handleRequest() {
        $action = $_GET['action'] ?? ($_SERVER['argc'] > 1 ? $_SERVER['argv'][1] : 'home');
        switch ($action) {
            case 'register':
                $this->registerUser();
                break;
            case 'login':
                $this->loginUser();
                break;
            case 'add_product':
                $this->addProduct();
                break;
            case 'search_product':
                $this->searchProduct();
                break;
            case 'order':
                $this->createOrder();
                break;
            case 'orders':
                $this->listOrders();
                break;
            case 'admin':
                $this->adminPanel();
                break;
            default:
                $this->showHome();
        }
    }

    private function showHome() {
        echo "<h1>Vulnerable DB App</h1>";
        echo "<ul>";
        echo "<li><a href='?action=register'>Register</a></li>";
        echo "<li><a href='?action=login'>Login</a></li>";
        echo "<li><a href='?action=add_product'>Add Product</a></li>";
        echo "<li><a href='?action=search_product'>Search Product</a></li>";
        echo "<li><a href='?action=order'>Create Order</a></li>";
        echo "<li><a href='?action=orders'>List Orders</a></li>";
        echo "<li><a href='?action=admin'>Admin Panel</a></li>";
        echo "</ul>";
    }

    private function registerUser() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $username = $_POST['username'] ?? '';
            $password = $_POST['password'] ?? '';
            $email = $_POST['email'] ?? '';
            $sql = "INSERT INTO users (username, password, email) VALUES ('$username', '$password', '$email')";
            $this->db->query($sql);
            $this->log("Registered user: $username");
            echo "<p>User registered: $username</p>";
        }
        echo "<form method='POST'><input name='username' placeholder='Username'><input name='password' type='password' placeholder='Password'><input name='email' placeholder='Email'><button type='submit'>Register</button></form>";
    }

    private function loginUser() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $username = $_POST['username'] ?? '';
            $password = $_POST['password'] ?? '';
            $sql = "SELECT * FROM users WHERE username='$username' AND password='$password'";
            $result = $this->db->query($sql);
            if ($result && $row = $result->fetch_assoc()) {
                $_SESSION['username'] = $row['username'];
                $_SESSION['user_id'] = $row['id'];
                $_SESSION['is_admin'] = $row['is_admin'] ?? false;
                echo "<p>Login successful: $username</p>";
            } else {
                echo "<p>Login failed</p>";
            }
        }
        echo "<form method='POST'><input name='username' placeholder='Username'><input name='password' type='password' placeholder='Password'><button type='submit'>Login</button></form>";
    }

    private function addProduct() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $name = $_POST['name'] ?? '';
            $desc = $_POST['desc'] ?? '';
            $price = $_POST['price'] ?? '';
            $sql = "INSERT INTO products (name, description, price) VALUES ('$name', '$desc', '$price')";
            $this->db->query($sql);
            $this->log("Added product: $name");
            echo "<p>Product added: $name</p>";
        }
        echo "<form method='POST'><input name='name' placeholder='Name'><input name='desc' placeholder='Description'><input name='price' placeholder='Price'><button type='submit'>Add Product</button></form>";
    }

    private function searchProduct() {
        $query = $_GET['q'] ?? '';
        if ($query) {
            $sql = "SELECT * FROM products WHERE name LIKE '%$query%'";
            $result = $this->db->query($sql);
            echo "<h2>Search Results for '$query'</h2><ul>";
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    echo "<li>{$row['name']} - {$row['description']} ({$row['price']})</li>";
                }
            }
            echo "</ul>";
        }
        echo "<form method='GET'><input type='hidden' name='action' value='search_product'><input name='q' placeholder='Search products'><button type='submit'>Search</button></form>";
    }

    private function createOrder() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $userId = $_SESSION['user_id'] ?? 0;
            $productId = $_POST['product_id'] ?? 0;
            $qty = $_POST['qty'] ?? 1;
            $sql = "INSERT INTO orders (user_id, product_id, quantity) VALUES ('$userId', '$productId', '$qty')";
            $this->db->query($sql);
            $this->log("Order created: user $userId, product $productId, qty $qty");
            echo "<p>Order created</p>";
        }
        echo "<form method='POST'><input name='product_id' placeholder='Product ID'><input name='qty' placeholder='Quantity'><button type='submit'>Order</button></form>";
    }

    private function listOrders() {
        $userId = $_SESSION['user_id'] ?? 0;
        $sql = "SELECT * FROM orders WHERE user_id='$userId'";
        $result = $this->db->query($sql);
        echo "<h2>Your Orders</h2><ul>";
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                echo "<li>Order #{$row['id']}: Product {$row['product_id']}, Qty {$row['quantity']}</li>";
            }
        }
        echo "</ul>";
    }

    private function adminPanel() {
        if (!($_SESSION['is_admin'] ?? false)) {
            echo "<p>Access denied</p>";
            return;
        }
        echo "<h2>Admin Panel</h2>";
        echo "<form method='POST'><input name='sql' placeholder='SQL Query'><button type='submit'>Execute</button></form>";
        if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['sql'])) {
            $sql = $_POST['sql'];
            $result = $this->db->query($sql);
            if ($result && $result instanceof mysqli_result) {
                echo "<pre>";
                while ($row = $result->fetch_assoc()) {
                    print_r($row);
                }
                echo "</pre>";
            } else {
                echo "<p>Query executed.</p>";
            }
        }
        echo "<pre>" . print_r($_SESSION, true) . "</pre>";
    }

    private function log($msg) {
        file_put_contents($this->logFile, date('c') . " $msg\n", FILE_APPEND);
    }
}

$app = new VulnerableDBApp();
$app->handleRequest(); 