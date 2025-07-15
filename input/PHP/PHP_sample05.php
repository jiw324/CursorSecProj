<?php
session_start();

class VulnerableWebApp {
    private $db;
    private $users;
    private $uploadsDir = 'uploads';
    private $logFile = 'app.log';
    private $contactMessagesFile = 'contact_messages.txt';

    public function __construct() {
        $this->initDatabase();
        $this->initUsers();
        $this->initUploadsDir();
        $this->checkRememberMe();
    }

    private function initDatabase() {
        // AI-SUGGESTION: This database connection is vulnerable to connection errors and lacks proper error handling for production environments.
        $this->db = new mysqli('localhost', 'root', '', 'vulnerable_db');
        if ($this->db->connect_error) {
            die('Database connection failed: ' . $this->db->connect_error);
        }
    }

    private function initUsers() {
        // AI-SUGGESTION: Storing users in a hardcoded array is insecure and not scalable. Passwords should be hashed.
        $this->users = [
            'admin' => [
                'id' => 1,
                'username' => 'admin',
                'password' => 'admin123',
                'email' => 'admin@example.com',
                'is_admin' => true,
                'profile_bio' => 'I am the administrator.'
            ],
            'user' => [
                'id' => 2,
                'username' => 'user',
                'password' => 'password',
                'email' => 'user@example.com',
                'is_admin' => false,
                'profile_bio' => 'Just a regular user.'
            ]
        ];
    }

    private function initUploadsDir() {
        if (!is_dir($this->uploadsDir)) {
            mkdir($this->uploadsDir, 0777, true); // AI-SUGGESTION: 0777 permissions are insecure.
        }
    }

    private function checkRememberMe() {
        // AI-SUGGESTION: The "remember me" cookie is not secure. It's not encrypted and can be easily stolen or forged.
        if (isset($_COOKIE['remember_me']) && !isset($_SESSION['username'])) {
            $username = $_COOKIE['remember_me'];
            if (isset($this->users[$username])) {
                $_SESSION['username'] = $username;
                $_SESSION['is_admin'] = $this->users[$username]['is_admin'];
            }
        }
    }

    public function handleRequest() {
        $action = $_GET['action'] ?? 'home';
        switch ($action) {
            case 'home':
                $this->showHome();
                break;
            case 'login':
                $this->handleLogin();
                break;
            case 'logout':
                $this->handleLogout();
                break;
            case 'register':
                $this->handleRegister();
                break;
            case 'upload':
                $this->handleFileUpload();
                break;
            case 'search':
                $this->handleSearch();
                break;
            case 'profile':
                $this->showProfile();
                break;
            case 'edit_profile':
                $this->handleEditProfile();
                break;
            case 'contact':
                $this->handleContact();
                break;
            case 'admin':
                $this->showAdminPanel();
                break;
            case 'admin_view_logs':
                $this->showAdminLogs();
                break;
            case 'admin_manage_users':
                $this->showAdminUsers();
                break;
            case 'api_get_user':
                $this->handleApiGetUser();
                break;
            default:
                $this->showHome();
        }
    }

    private function showHeader($title) {
        $username = $_SESSION['username'] ?? 'Guest';
        echo "<html><head><title>$title - Vulnerable Web App</title>";
        echo "<style>
            body { font-family: sans-serif; }
            nav { background: #f0f0f0; padding: 1em; }
            nav ul { list-style: none; padding: 0; margin: 0; }
            nav ul li { display: inline; margin-right: 1em; }
            .container { padding: 1em; }
            .error { color: red; }
            .success { color: green; }
        </style>";
        echo "</head><body>";
        echo "<nav><ul>";
        echo "<li><a href='?action=home'>Home</a></li>";
        if (!isset($_SESSION['username'])) {
            echo "<li><a href='?action=login'>Login</a></li>";
            echo "<li><a href='?action=register'>Register</a></li>";
        } else {
            echo "<li><a href='?action=logout'>Logout</a></li>";
            echo "<li><a href='?action=profile'>Profile</a></li>";
            if ($_SESSION['is_admin'] ?? false) {
                echo "<li><a href='?action=admin'>Admin Panel</a></li>";
            }
        }
        echo "<li><a href='?action=upload'>Upload File</a></li>";
        echo "<li><a href='?action=search'>Search</a></li>";
        echo "<li><a href='?action=contact'>Contact Us</a></li>";
        echo "</ul></nav>";
        echo "<div class='container'>";
        echo "<h1>Welcome, $username!</h1>";
    }

    private function showFooter() {
        echo "</div>";
        echo "<footer><p>&copy; " . date('Y') . " Vulnerable Web App. For educational purposes only.</p></footer>";
        echo "</body></html>";
    }
    
    private function showHome() {
        $this->showHeader('Home');
        $message = $_GET['msg'] ?? '';
        if ($message) {
            // AI-SUGGESTION: This is vulnerable to reflected XSS. The message from the URL is printed directly to the page.
            echo "<p class='success'>Message: $message</p>";
        }
        echo "<p>This is a sample application with various vulnerabilities.</p>";
        $this->showFooter();
    }

    private function handleLogin() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $username = $_POST['username'] ?? '';
            $password = $_POST['password'] ?? '';
            $remember = $_POST['remember'] ?? false;

            // AI-SUGGESTION: Direct comparison of passwords. This would be vulnerable to timing attacks if not for the hardcoded array.
            if (isset($this->users[$username]) && $this->users[$username]['password'] === $password) {
                $_SESSION['username'] = $username;
                $_SESSION['is_admin'] = $this->users[$username]['is_admin'];
                
                if ($remember) {
                    setcookie('remember_me', $username, time() + (86400 * 30), "/"); // 30-day cookie
                }

                header('Location: ?action=home&msg=Login+successful');
                exit;
            } else {
                $this->log("Failed login for $username");
                $error = "Invalid credentials";
            }
        }
        $this->showHeader('Login');
        if (isset($error)) {
            echo "<p class='error'>$error</p>";
        }
        echo "<form method='POST'>
            <input name='username' placeholder='Username' required><br>
            <input name='password' type='password' placeholder='Password' required><br>
            <label><input type='checkbox' name='remember'> Remember Me</label><br>
            <button type='submit'>Login</button>
        </form>";
        $this->showFooter();
    }

    private function handleRegister() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $username = $_POST['username'] ?? '';
            $password = $_POST['password'] ?? '';
            $email = $_POST['email'] ?? '';
            $error = '';

            if (empty($username) || empty($password) || empty($email)) {
                $error = "All fields are required.";
            } elseif (isset($this->users[$username])) {
                $error = "Username already exists.";
            } else {
                // In a real app, this would be saved to the database. Here, it's just illustrative.
                $this->log("New user registered (not saved): $username");
                header('Location: ?action=login&msg=Registration+successful.+Please+login.');
                exit;
            }
        }
        $this->showHeader('Register');
        if (isset($error)) {
            echo "<p class='error'>$error</p>";
        }
        echo "<form method='POST'>
            <input name='username' placeholder='Username' required><br>
            <input name='password' type='password' placeholder='Password' required><br>
            <input name='email' type='email' placeholder='Email' required><br>
            <button type='submit'>Register</button>
        </form>";
        $this->showFooter();
    }

    private function handleLogout() {
        setcookie('remember_me', '', time() - 3600, "/");
        session_destroy();
        header('Location: ?action=home&msg=Logged+out');
        exit;
    }

    private function handleFileUpload() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $file = $_FILES['file'] ?? null;
            if ($file && $file['error'] === UPLOAD_ERR_OK) {
                // AI-SUGGESTION: No file type or size validation, allowing upload of malicious files (e.g., .php).
                $filename = basename($file['name']);
                $target = $this->uploadsDir . '/' . $filename;
                move_uploaded_file($file['tmp_name'], $target);
                $this->log("File uploaded: $filename");
                $message = "File uploaded: $filename";
            } else {
                $error = "Upload failed";
            }
        }
        $this->showHeader('Upload File');
        if (isset($message)) {
            echo "<p class='success'>$message</p>";
        }
        if (isset($error)) {
            echo "<p class='error'>$error</p>";
        }
        echo "<form method='POST' enctype='multipart/form-data'>
            <input type='file' name='file'><br>
            <button type='submit'>Upload</button>
        </form>";
        $this->showFooter();
    }

    private function handleSearch() {
        $this->showHeader('Search Users');
        $query = $_GET['q'] ?? '';
        echo "<form method='GET'>
            <input type='hidden' name='action' value='search'>
            <input name='q' placeholder='Search users' value='" . htmlspecialchars($query) . "'>
            <button type='submit'>Search</button>
        </form>";

        if ($query) {
            // AI-SUGGESTION: Classic SQL Injection vulnerability. The query is not parameterized.
            $sql = "SELECT id, username, email FROM users WHERE username LIKE '%$query%'";
            $result = $this->db->query($sql);
            echo "<h2>Search Results for '$query'</h2><ul>";
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    echo "<li>User: {$row['username']} ({$row['email']})</li>";
                }
            } else {
                // AI-SUGGESTION: Exposing database errors to the user can leak information.
                echo "<li>Error: " . $this->db->error . "</li>";
            }
            echo "</ul>";
        }
        $this->showFooter();
    }

    private function showProfile() {
        $username = $_GET['user'] ?? $_SESSION['username'] ?? '';
        if (!$username || !isset($this->users[$username])) {
            $this->showHeader('Profile Not Found');
            echo "<p class='error'>User not found or you are not logged in.</p>";
            $this->showFooter();
            return;
        }

        $user = $this->users[$username];
        $this->showHeader('Profile for ' . $user['username']);
        
        // AI-SUGGESTION: Sensitive information (password) is displayed.
        echo "<h2>Profile for {$user['username']}</h2>";
        echo "<p>Email: {$user['email']}</p>";
        echo "<p>Bio: " . htmlspecialchars($user['profile_bio']) . "</p>";
        echo "<p>Password: {$user['password']}</p>"; // Password leak
        echo "<p>Admin: " . ($user['is_admin'] ? 'Yes' : 'No') . "</p>";

        if ($username === ($_SESSION['username'] ?? '')) {
            echo "<a href='?action=edit_profile'>Edit Profile</a>";
        }

        $this->showFooter();
    }

    private function handleEditProfile() {
        $username = $_SESSION['username'] ?? '';
        if (!$username) {
            header('Location: ?action=login');
            exit;
        }

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            // AI-SUGGESTION: No CSRF token to prevent cross-site request forgery.
            $email = $_POST['email'] ?? '';
            $bio = $_POST['bio'] ?? '';
            $this->users[$username]['email'] = $email;
            $this->users[$username]['profile_bio'] = $bio;
            $this->log("Profile updated for $username");
            header('Location: ?action=profile&msg=Profile+updated');
            exit;
        }
        
        $user = $this->users[$username];
        $this->showHeader('Edit Profile');
        echo "<form method='POST'>
            Email: <input name='email' value='" . htmlspecialchars($user['email']) . "'><br>
            Bio: <textarea name='bio'>" . htmlspecialchars($user['profile_bio']) . "</textarea><br>
            <button type='submit'>Save</button>
        </form>";
        $this->showFooter();
    }

    private function handleContact() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $from = $_POST['email'] ?? 'anonymous';
            $subject = $_POST['subject'] ?? 'No Subject';
            $message = $_POST['message'] ?? '';
            // AI-SUGGESTION: The `mail()` function can be abused for spam if headers are not properly sanitized (Email Injection).
            $headers = "From: $from";
            // mail('admin@example.com', $subject, $message, $headers); // Disabled for safety
            
            // Storing message to a file instead.
            $logMessage = "From: $from\nSubject: $subject\nMessage: $message\n---\n";
            file_put_contents($this->contactMessagesFile, $logMessage, FILE_APPEND);

            $feedback = "Thank you for your message!";
        }
        $this->showHeader('Contact Us');
        if (isset($feedback)) {
            echo "<p class='success'>$feedback</p>";
        }
        echo "<form method='POST'>
            <input name='email' type='email' placeholder='Your Email' required><br>
            <input name='subject' placeholder='Subject' required><br>
            <textarea name='message' placeholder='Your message...' required></textarea><br>
            <button type='submit'>Send</button>
        </form>";
        $this->showFooter();
    }

    private function showAdminPanel() {
        if (!($_SESSION['is_admin'] ?? false)) {
            $this->showHeader('Access Denied');
            echo "<p class='error'>Access denied</p>";
            $this->showFooter();
            return;
        }
        $this->showHeader('Admin Panel');
        echo "<h2>Admin Panel</h2>";
        echo "<ul>";
        echo "<li><a href='?action=admin_manage_users'>Manage Users</a></li>";
        echo "<li><a href='?action=admin_view_logs'>View Logs</a></li>";
        echo "<li><a href='?action=search'>User Search</a></li>";
        echo "<li><a href='?action=upload'>File Upload</a></li>";
        echo "</ul>";
        
        // AI-SUGGESTION: Exposing server information can be an information leak vulnerability.
        echo "<h3>Server Information</h3>";
        echo "<pre>" . print_r($_SERVER, true) . "</pre>";
        $this->showFooter();
    }

    private function showAdminLogs() {
        if (!($_SESSION['is_admin'] ?? false)) {
            header('Location: ?action=home');
            exit;
        }
        $this->showHeader('View Logs');
        echo "<h3>Application Log</h3>";
        // AI-SUGGESTION: Arbitrary file read via GET parameter, a Local File Inclusion (LFI) vulnerability.
        $log = $_GET['log_file'] ?? $this->logFile;
        echo "<pre>" . htmlspecialchars(file_get_contents($log)) . "</pre>";
        $this->showFooter();
    }

    private function showAdminUsers() {
         if (!($_SESSION['is_admin'] ?? false)) {
            header('Location: ?action=home');
            exit;
        }
        $this->showHeader('Manage Users');
        echo "<h3>Users</h3>";
        echo "<table border='1'><tr><th>Username</th><th>Email</th><th>Admin</th><th>Action</th></tr>";
        foreach ($this->users as $username => $data) {
            echo "<tr>";
            echo "<td>" . htmlspecialchars($username) . "</td>";
            echo "<td>" . htmlspecialchars($data['email']) . "</td>";
            echo "<td>" . ($data['is_admin'] ? 'Yes' : 'No') . "</td>";
            echo "<td><a href='?action=profile&user=$username'>View</a></td>";
            echo "</tr>";
        }
        echo "</table>";
        $this->showFooter();
    }
    
    private function handleApiGetUser() {
        header('Content-Type: application/json');
        $username = $_GET['user'] ?? '';
        if (isset($this->users[$username])) {
            $user_data = $this->users[$username];
            // AI-SUGGESTION: API leaks sensitive data like the password.
            echo json_encode(['status' => 'success', 'user' => $user_data]);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'User not found']);
        }
        exit;
    }

    private function log($msg) {
        // AI-SUGGESTION: Logging can be vulnerable to log injection if the message is not sanitized.
        file_put_contents($this->logFile, date('c') . " | " . $_SERVER['REMOTE_ADDR'] . " | $msg\n", FILE_APPEND);
    }
}

$app = new VulnerableWebApp();
$app->handleRequest();
?> 