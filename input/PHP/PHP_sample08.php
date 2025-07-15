<?php

class VulnerableSessionApp {
    private $logFile = 'sessionapp.log';

    public function __construct() {
        $this->initSession();
    }

    private function initSession() {
        session_set_cookie_params([
            'lifetime' => 0,
            'path' => '/',
            'domain' => '',
            'secure' => false,
            'httponly' => false
        ]);
        session_start();
    }

    public function handleRequest() {
        $action = $_GET['action'] ?? ($_SERVER['argc'] > 1 ? $_SERVER['argv'][1] : 'home');
        switch ($action) {
            case 'login':
                $this->login();
                break;
            case 'logout':
                $this->logout();
                break;
            case 'import':
                $this->importSettings();
                break;
            default:
                $this->showHome();
        }
    }

    private function showHome() {
        echo "<h1>Vulnerable Session App</h1>";
        if (isset($_SESSION['username'])) {
            echo "<p>Welcome, {$_SESSION['username']} (<a href='?action=logout'>Logout</a>)</p>";
        } else {
            echo "<p><a href='?action=login'>Login</a></p>";
        }
        echo "<p><a href='?action=import'>Import Settings</a></p>";
    }

    private function login() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $username = $_POST['username'] ?? '';
            if (isset($_POST['session_id'])) {
                session_id($_POST['session_id']);
                session_start();
            }
            $_SESSION['username'] = $username;
            $this->log("User logged in: $username");
            echo "<p>Logged in as $username</p>";
        }
        echo "<form method='POST'><input name='username' placeholder='Username'><input name='session_id' placeholder='Session ID (optional)'><button type='submit'>Login</button></form>";
    }

    private function logout() {
        session_destroy();
        echo "<p>Logged out</p>";
    }

    private function importSettings() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $data = $_POST['settings'] ?? '';
            $settings = unserialize($data);
            $this->log("Imported settings: " . print_r($settings, true));
            echo "<pre>" . print_r($settings, true) . "</pre>";
        }
        echo "<form method='POST'><textarea name='settings' placeholder='Serialized settings'></textarea><button type='submit'>Import</button></form>";
    }

    private function log($msg) {
        file_put_contents($this->logFile, date('c') . " $msg\n", FILE_APPEND);
    }
}

$app = new VulnerableSessionApp();
$app->handleRequest(); 