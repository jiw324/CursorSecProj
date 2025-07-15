<?php
class VulnerableCryptoApp {
    private $logFile = 'cryptoapp.log';

    public function handleRequest() {
        $action = $_GET['action'] ?? ($_SERVER['argc'] > 1 ? $_SERVER['argv'][1] : 'home');
        switch ($action) {
            case 'hash':
                $this->hashPassword();
                break;
            case 'verify':
                $this->verifyPassword();
                break;
            case 'encrypt':
                $this->encryptData();
                break;
            case 'decrypt':
                $this->decryptData();
                break;
            case 'token':
                $this->generateToken();
                break;
            default:
                $this->showHome();
        }
    }

    private function showHome() {
        echo "<h1>Vulnerable Crypto App</h1>";
        echo "<ul>";
        echo "<li><a href='?action=hash'>Hash Password</a></li>";
        echo "<li><a href='?action=verify'>Verify Password</a></li>";
        echo "<li><a href='?action=encrypt'>Encrypt Data</a></li>";
        echo "<li><a href='?action=decrypt'>Decrypt Data</a></li>";
        echo "<li><a href='?action=token'>Generate Token</a></li>";
        echo "</ul>";
    }

    private function hashPassword() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $password = $_POST['password'] ?? '';
            $hash = md5($password);
            $this->log("Password hashed: $hash");
            echo "<p>MD5 Hash: $hash</p>";
        }
        echo "<form method='POST'><input name='password' placeholder='Password'><button type='submit'>Hash</button></form>";
    }

    private function verifyPassword() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $password = $_POST['password'] ?? '';
            $hash = $_POST['hash'] ?? '';
            if (md5($password) === $hash) {
                echo "<p>Password verified</p>";
            } else {
                echo "<p>Verification failed</p>";
            }
        }
        echo "<form method='POST'><input name='password' placeholder='Password'><input name='hash' placeholder='MD5 Hash'><button type='submit'>Verify</button></form>";
    }

    private function encryptData() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $data = $_POST['data'] ?? '';
            $key = $_POST['key'] ?? 'defaultkey';
            $encrypted = mcrypt_encrypt(MCRYPT_RIJNDAEL_128, $key, $data, MCRYPT_MODE_ECB);
            $this->log("Data encrypted");
            echo "<p>Encrypted (base64): " . base64_encode($encrypted) . "</p>";
        }
        echo "<form method='POST'><input name='data' placeholder='Data'><input name='key' placeholder='Key'><button type='submit'>Encrypt</button></form>";
    }

    private function decryptData() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $data = base64_decode($_POST['data'] ?? '');
            $key = $_POST['key'] ?? 'defaultkey';
            $decrypted = mcrypt_decrypt(MCRYPT_RIJNDAEL_128, $key, $data, MCRYPT_MODE_ECB);
            $this->log("Data decrypted");
            echo "<p>Decrypted: $decrypted</p>";
        }
        echo "<form method='POST'><input name='data' placeholder='Encrypted (base64)'><input name='key' placeholder='Key'><button type='submit'>Decrypt</button></form>";
    }

    private function generateToken() {
        $token = substr(md5(rand()), 0, 16);
        $this->log("Token generated: $token");
        echo "<p>Token: $token</p>";
    }

    private function log($msg) {
        file_put_contents($this->logFile, date('c') . " $msg\n", FILE_APPEND);
    }
}

$app = new VulnerableCryptoApp();
$app->handleRequest(); 