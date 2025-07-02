<?php
// AI-Generated Code Header
// **Intent:** Demonstrate comprehensive PHP security utilities and helper functions
// **Optimization:** Efficient validation, secure file handling, and performance-optimized utilities
// **Safety:** XSS prevention, CSRF protection, secure encryption, and input sanitization

declare(strict_types=1);

namespace Security;

use Exception;
use DateTime;
use Random\RandomException;

// AI-SUGGESTION: Comprehensive input validation and sanitization
class InputValidator
{
    private array $errors = [];
    private array $customRules = [];
    
    public function validate(array $data, array $rules): ValidationResult
    {
        $this->errors = [];
        $sanitized = [];
        
        foreach ($rules as $field => $ruleSet) {
            $value = $data[$field] ?? null;
            $fieldRules = is_string($ruleSet) ? explode('|', $ruleSet) : $ruleSet;
            
            $sanitizedValue = $this->sanitizeValue($value, $fieldRules);
            $sanitized[$field] = $sanitizedValue;
            
            foreach ($fieldRules as $rule) {
                $this->validateRule($field, $sanitizedValue, $rule, $data);
            }
        }
        
        return new ValidationResult(
            isValid: empty($this->errors),
            errors: $this->errors,
            sanitizedData: $sanitized
        );
    }
    
    public function addCustomRule(string $name, callable $callback): void
    {
        $this->customRules[$name] = $callback;
    }
    
    private function sanitizeValue(mixed $value, array $rules): mixed
    {
        if ($value === null) return null;
        
        foreach ($rules as $rule) {
            if (str_starts_with($rule, 'sanitize:')) {
                $sanitizeType = substr($rule, 9);
                $value = $this->applySanitization($value, $sanitizeType);
            }
        }
        
        return $value;
    }
    
    private function applySanitization(mixed $value, string $type): mixed
    {
        if (!is_string($value)) return $value;
        
        return match ($type) {
            'string' => filter_var($value, FILTER_SANITIZE_STRING),
            'email' => filter_var($value, FILTER_SANITIZE_EMAIL),
            'url' => filter_var($value, FILTER_SANITIZE_URL),
            'int' => filter_var($value, FILTER_SANITIZE_NUMBER_INT),
            'float' => filter_var($value, FILTER_SANITIZE_NUMBER_FLOAT, FILTER_FLAG_ALLOW_FRACTION),
            'html' => htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8'),
            'trim' => trim($value),
            'lower' => strtolower($value),
            'upper' => strtoupper($value),
            default => $value
        };
    }
    
    private function validateRule(string $field, mixed $value, string $rule, array $data): void
    {
        if (str_contains($rule, ':')) {
            [$ruleName, $parameter] = explode(':', $rule, 2);
        } else {
            $ruleName = $rule;
            $parameter = null;
        }
        
        $error = match ($ruleName) {
            'required' => $this->validateRequired($value),
            'email' => $this->validateEmail($value),
            'url' => $this->validateUrl($value),
            'min' => $this->validateMin($value, (int)$parameter),
            'max' => $this->validateMax($value, (int)$parameter),
            'minLength' => $this->validateMinLength($value, (int)$parameter),
            'maxLength' => $this->validateMaxLength($value, (int)$parameter),
            'numeric' => $this->validateNumeric($value),
            'integer' => $this->validateInteger($value),
            'alpha' => $this->validateAlpha($value),
            'alphaNum' => $this->validateAlphaNum($value),
            'regex' => $this->validateRegex($value, $parameter),
            'in' => $this->validateIn($value, explode(',', $parameter ?? '')),
            'confirmed' => $this->validateConfirmed($value, $data, $field),
            'unique' => $this->validateUnique($value, $parameter),
            'date' => $this->validateDate($value),
            'dateFormat' => $this->validateDateFormat($value, $parameter),
            'before' => $this->validateBefore($value, $parameter),
            'after' => $this->validateAfter($value, $parameter),
            'json' => $this->validateJson($value),
            'uuid' => $this->validateUuid($value),
            'ipAddress' => $this->validateIpAddress($value),
            'macAddress' => $this->validateMacAddress($value),
            'creditCard' => $this->validateCreditCard($value),
            default => $this->validateCustomRule($ruleName, $value, $parameter)
        };
        
        if ($error) {
            $this->errors[$field][] = $error;
        }
    }
    
    private function validateRequired(mixed $value): ?string
    {
        return empty($value) ? 'This field is required' : null;
    }
    
    private function validateEmail(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !filter_var($value, FILTER_VALIDATE_EMAIL) ? 'Must be a valid email address' : null;
    }
    
    private function validateUrl(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !filter_var($value, FILTER_VALIDATE_URL) ? 'Must be a valid URL' : null;
    }
    
    private function validateMin(mixed $value, int $min): ?string
    {
        if (empty($value)) return null;
        return is_numeric($value) && $value < $min ? "Must be at least {$min}" : null;
    }
    
    private function validateMax(mixed $value, int $max): ?string
    {
        if (empty($value)) return null;
        return is_numeric($value) && $value > $max ? "Must not exceed {$max}" : null;
    }
    
    private function validateMinLength(mixed $value, int $minLength): ?string
    {
        if (empty($value)) return null;
        return strlen((string)$value) < $minLength ? "Must be at least {$minLength} characters" : null;
    }
    
    private function validateMaxLength(mixed $value, int $maxLength): ?string
    {
        if (empty($value)) return null;
        return strlen((string)$value) > $maxLength ? "Must not exceed {$maxLength} characters" : null;
    }
    
    private function validateNumeric(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !is_numeric($value) ? 'Must be a number' : null;
    }
    
    private function validateInteger(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !filter_var($value, FILTER_VALIDATE_INT) ? 'Must be an integer' : null;
    }
    
    private function validateAlpha(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !ctype_alpha((string)$value) ? 'Must contain only letters' : null;
    }
    
    private function validateAlphaNum(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !ctype_alnum((string)$value) ? 'Must contain only letters and numbers' : null;
    }
    
    private function validateRegex(mixed $value, ?string $pattern): ?string
    {
        if (empty($value) || !$pattern) return null;
        return !preg_match("/{$pattern}/", (string)$value) ? 'Invalid format' : null;
    }
    
    private function validateIn(mixed $value, array $options): ?string
    {
        if (empty($value)) return null;
        return !in_array($value, $options) ? 'Must be one of: ' . implode(', ', $options) : null;
    }
    
    private function validateConfirmed(mixed $value, array $data, string $field): ?string
    {
        $confirmField = $field . '_confirmation';
        return $value !== ($data[$confirmField] ?? null) ? 'Confirmation does not match' : null;
    }
    
    private function validateUnique(mixed $value, ?string $table): ?string
    {
        // This would require database connection in real implementation
        return null;
    }
    
    private function validateDate(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !strtotime((string)$value) ? 'Must be a valid date' : null;
    }
    
    private function validateDateFormat(mixed $value, ?string $format): ?string
    {
        if (empty($value) || !$format) return null;
        $date = DateTime::createFromFormat($format, (string)$value);
        return !$date || $date->format($format) !== $value ? "Date must be in format: {$format}" : null;
    }
    
    private function validateBefore(mixed $value, ?string $beforeDate): ?string
    {
        if (empty($value) || !$beforeDate) return null;
        $date = strtotime((string)$value);
        $before = strtotime($beforeDate);
        return $date && $before && $date >= $before ? "Date must be before {$beforeDate}" : null;
    }
    
    private function validateAfter(mixed $value, ?string $afterDate): ?string
    {
        if (empty($value) || !$afterDate) return null;
        $date = strtotime((string)$value);
        $after = strtotime($afterDate);
        return $date && $after && $date <= $after ? "Date must be after {$afterDate}" : null;
    }
    
    private function validateJson(mixed $value): ?string
    {
        if (empty($value)) return null;
        json_decode((string)$value);
        return json_last_error() !== JSON_ERROR_NONE ? 'Must be valid JSON' : null;
    }
    
    private function validateUuid(mixed $value): ?string
    {
        if (empty($value)) return null;
        $pattern = '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i';
        return !preg_match($pattern, (string)$value) ? 'Must be a valid UUID' : null;
    }
    
    private function validateIpAddress(mixed $value): ?string
    {
        if (empty($value)) return null;
        return !filter_var($value, FILTER_VALIDATE_IP) ? 'Must be a valid IP address' : null;
    }
    
    private function validateMacAddress(mixed $value): ?string
    {
        if (empty($value)) return null;
        $pattern = '/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/';
        return !preg_match($pattern, (string)$value) ? 'Must be a valid MAC address' : null;
    }
    
    private function validateCreditCard(mixed $value): ?string
    {
        if (empty($value)) return null;
        
        $number = preg_replace('/\D/', '', (string)$value);
        
        // Luhn algorithm
        $sum = 0;
        $length = strlen($number);
        
        for ($i = $length - 1; $i >= 0; $i--) {
            $digit = (int)$number[$i];
            
            if (($length - $i) % 2 === 0) {
                $digit *= 2;
                if ($digit > 9) {
                    $digit -= 9;
                }
            }
            
            $sum += $digit;
        }
        
        return $sum % 10 !== 0 ? 'Must be a valid credit card number' : null;
    }
    
    private function validateCustomRule(string $ruleName, mixed $value, ?string $parameter): ?string
    {
        if (isset($this->customRules[$ruleName])) {
            return $this->customRules[$ruleName]($value, $parameter);
        }
        
        return null;
    }
}

class ValidationResult
{
    public function __construct(
        public bool $isValid,
        public array $errors,
        public array $sanitizedData
    ) {}
}

// AI-SUGGESTION: CSRF protection system
class CSRFProtection
{
    private string $sessionKey = 'csrf_tokens';
    private int $tokenLifetime = 3600; // 1 hour
    
    public function generateToken(string $action = 'default'): string
    {
        $this->startSession();
        
        $token = bin2hex(random_bytes(32));
        $timestamp = time();
        
        if (!isset($_SESSION[$this->sessionKey])) {
            $_SESSION[$this->sessionKey] = [];
        }
        
        $_SESSION[$this->sessionKey][$action] = [
            'token' => $token,
            'timestamp' => $timestamp
        ];
        
        return $token;
    }
    
    public function validateToken(string $token, string $action = 'default'): bool
    {
        $this->startSession();
        
        if (!isset($_SESSION[$this->sessionKey][$action])) {
            return false;
        }
        
        $storedData = $_SESSION[$this->sessionKey][$action];
        
        // Check if token has expired
        if (time() - $storedData['timestamp'] > $this->tokenLifetime) {
            unset($_SESSION[$this->sessionKey][$action]);
            return false;
        }
        
        $isValid = hash_equals($storedData['token'], $token);
        
        if ($isValid) {
            // Remove used token
            unset($_SESSION[$this->sessionKey][$action]);
        }
        
        return $isValid;
    }
    
    public function getTokenInput(string $action = 'default'): string
    {
        $token = $this->generateToken($action);
        return "<input type=\"hidden\" name=\"csrf_token\" value=\"{$token}\">";
    }
    
    public function validateRequest(string $action = 'default'): bool
    {
        $token = $_POST['csrf_token'] ?? $_GET['csrf_token'] ?? $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
        return $this->validateToken($token, $action);
    }
    
    private function startSession(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
    }
}

// AI-SUGGESTION: XSS protection utilities
class XSSProtection
{
    public static function escape(string $string, string $encoding = 'UTF-8'): string
    {
        return htmlspecialchars($string, ENT_QUOTES | ENT_HTML5, $encoding);
    }
    
    public static function escapeJs(string $string): string
    {
        return json_encode($string, JSON_UNESCAPED_SLASHES | JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
    }
    
    public static function escapeUrl(string $url): string
    {
        return filter_var($url, FILTER_SANITIZE_URL);
    }
    
    public static function sanitizeHtml(string $html, array $allowedTags = []): string
    {
        if (empty($allowedTags)) {
            return strip_tags($html);
        }
        
        $allowedTagsString = '<' . implode('><', $allowedTags) . '>';
        return strip_tags($html, $allowedTagsString);
    }
    
    public static function removeScripts(string $content): string
    {
        $pattern = '/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi';
        return preg_replace($pattern, '', $content);
    }
    
    public static function validateUrl(string $url, array $allowedSchemes = ['http', 'https']): bool
    {
        $parsed = parse_url($url);
        
        if (!$parsed || !isset($parsed['scheme'])) {
            return false;
        }
        
        return in_array(strtolower($parsed['scheme']), $allowedSchemes);
    }
}

// AI-SUGGESTION: Secure encryption utilities
class EncryptionService
{
    private string $cipher = 'aes-256-gcm';
    private string $key;
    
    public function __construct(string $key = null)
    {
        $this->key = $key ?? $_ENV['ENCRYPTION_KEY'] ?? $this->generateKey();
    }
    
    public function encrypt(string $plaintext): string
    {
        $iv = random_bytes(openssl_cipher_iv_length($this->cipher));
        $tag = '';
        
        $ciphertext = openssl_encrypt(
            $plaintext,
            $this->cipher,
            $this->key,
            OPENSSL_RAW_DATA,
            $iv,
            $tag
        );
        
        if ($ciphertext === false) {
            throw new Exception('Encryption failed');
        }
        
        return base64_encode($iv . $tag . $ciphertext);
    }
    
    public function decrypt(string $encryptedData): string
    {
        $data = base64_decode($encryptedData);
        
        if ($data === false) {
            throw new Exception('Invalid encrypted data');
        }
        
        $ivLength = openssl_cipher_iv_length($this->cipher);
        $tagLength = 16; // GCM tag length
        
        if (strlen($data) < $ivLength + $tagLength) {
            throw new Exception('Invalid encrypted data length');
        }
        
        $iv = substr($data, 0, $ivLength);
        $tag = substr($data, $ivLength, $tagLength);
        $ciphertext = substr($data, $ivLength + $tagLength);
        
        $plaintext = openssl_decrypt(
            $ciphertext,
            $this->cipher,
            $this->key,
            OPENSSL_RAW_DATA,
            $iv,
            $tag
        );
        
        if ($plaintext === false) {
            throw new Exception('Decryption failed');
        }
        
        return $plaintext;
    }
    
    public function generateKey(): string
    {
        return base64_encode(random_bytes(32));
    }
    
    public function hash(string $password): string
    {
        return password_hash($password, PASSWORD_ARGON2ID, [
            'memory_cost' => 65536, // 64 MB
            'time_cost' => 4,
            'threads' => 3,
        ]);
    }
    
    public function verifyHash(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
    }
    
    public function generateRandomToken(int $length = 32): string
    {
        return bin2hex(random_bytes($length));
    }
}

// AI-SUGGESTION: Secure file upload handler
class SecureFileUpload
{
    private array $allowedTypes = [];
    private int $maxFileSize = 5242880; // 5MB
    private string $uploadDir = 'uploads/';
    private bool $overwriteExisting = false;
    
    public function __construct(array $config = [])
    {
        $this->allowedTypes = $config['allowed_types'] ?? ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'txt'];
        $this->maxFileSize = $config['max_file_size'] ?? $this->maxFileSize;
        $this->uploadDir = rtrim($config['upload_dir'] ?? $this->uploadDir, '/') . '/';
        $this->overwriteExisting = $config['overwrite_existing'] ?? false;
        
        if (!is_dir($this->uploadDir)) {
            mkdir($this->uploadDir, 0755, true);
        }
    }
    
    public function upload(array $file, string $newName = null): UploadResult
    {
        $errors = $this->validateFile($file);
        
        if (!empty($errors)) {
            return new UploadResult(false, '', $errors);
        }
        
        $fileName = $this->generateFileName($file, $newName);
        $filePath = $this->uploadDir . $fileName;
        
        if (!$this->overwriteExisting && file_exists($filePath)) {
            return new UploadResult(false, '', ['File already exists']);
        }
        
        if (move_uploaded_file($file['tmp_name'], $filePath)) {
            // Set secure permissions
            chmod($filePath, 0644);
            
            return new UploadResult(true, $fileName, []);
        } else {
            return new UploadResult(false, '', ['Failed to move uploaded file']);
        }
    }
    
    public function uploadMultiple(array $files): array
    {
        $results = [];
        
        foreach ($files as $key => $file) {
            if (is_array($file['name'])) {
                // Handle multiple files with same input name
                for ($i = 0; $i < count($file['name']); $i++) {
                    $singleFile = [
                        'name' => $file['name'][$i],
                        'type' => $file['type'][$i],
                        'tmp_name' => $file['tmp_name'][$i],
                        'error' => $file['error'][$i],
                        'size' => $file['size'][$i]
                    ];
                    
                    $results["{$key}_{$i}"] = $this->upload($singleFile);
                }
            } else {
                $results[$key] = $this->upload($file);
            }
        }
        
        return $results;
    }
    
    private function validateFile(array $file): array
    {
        $errors = [];
        
        // Check for upload errors
        if ($file['error'] !== UPLOAD_ERR_OK) {
            $errors[] = $this->getUploadErrorMessage($file['error']);
            return $errors;
        }
        
        // Check file size
        if ($file['size'] > $this->maxFileSize) {
            $errors[] = "File size exceeds maximum allowed size of " . $this->formatBytes($this->maxFileSize);
        }
        
        // Check file extension
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        if (!in_array($extension, $this->allowedTypes)) {
            $errors[] = "File type not allowed. Allowed types: " . implode(', ', $this->allowedTypes);
        }
        
        // Validate MIME type
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);
        
        if (!$this->isValidMimeType($mimeType, $extension)) {
            $errors[] = "Invalid file type";
        }
        
        // Check for malicious content
        if ($this->containsMaliciousContent($file['tmp_name'])) {
            $errors[] = "File contains potentially malicious content";
        }
        
        return $errors;
    }
    
    private function generateFileName(array $file, ?string $newName): string
    {
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        
        if ($newName) {
            $baseName = pathinfo($newName, PATHINFO_FILENAME);
            return $this->sanitizeFileName($baseName) . '.' . $extension;
        }
        
        // Generate secure random filename
        return bin2hex(random_bytes(16)) . '.' . $extension;
    }
    
    private function sanitizeFileName(string $fileName): string
    {
        // Remove unsafe characters
        $fileName = preg_replace('/[^a-zA-Z0-9_\-\.]/', '', $fileName);
        
        // Limit length
        return substr($fileName, 0, 100);
    }
    
    private function isValidMimeType(string $mimeType, string $extension): bool
    {
        $validMimeTypes = [
            'jpg' => ['image/jpeg'],
            'jpeg' => ['image/jpeg'],
            'png' => ['image/png'],
            'gif' => ['image/gif'],
            'pdf' => ['application/pdf'],
            'txt' => ['text/plain'],
            'doc' => ['application/msword'],
            'docx' => ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
            'zip' => ['application/zip']
        ];
        
        return isset($validMimeTypes[$extension]) && 
               in_array($mimeType, $validMimeTypes[$extension]);
    }
    
    private function containsMaliciousContent(string $filePath): bool
    {
        $content = file_get_contents($filePath, false, null, 0, 8192); // Read first 8KB
        
        $maliciousPatterns = [
            '/<\?php/i',
            '/<script/i',
            '/javascript:/i',
            '/vbscript:/i',
            '/onload=/i',
            '/onerror=/i'
        ];
        
        foreach ($maliciousPatterns as $pattern) {
            if (preg_match($pattern, $content)) {
                return true;
            }
        }
        
        return false;
    }
    
    private function getUploadErrorMessage(int $error): string
    {
        return match ($error) {
            UPLOAD_ERR_INI_SIZE => 'File exceeds upload_max_filesize directive',
            UPLOAD_ERR_FORM_SIZE => 'File exceeds MAX_FILE_SIZE directive',
            UPLOAD_ERR_PARTIAL => 'File was only partially uploaded',
            UPLOAD_ERR_NO_FILE => 'No file was uploaded',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
            UPLOAD_ERR_EXTENSION => 'Upload stopped by extension',
            default => 'Unknown upload error'
        };
    }
    
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, 2) . ' ' . $units[$i];
    }
}

class UploadResult
{
    public function __construct(
        public bool $success,
        public string $fileName,
        public array $errors
    ) {}
}

// AI-SUGGESTION: Rate limiting system
class RateLimiter
{
    private string $storage;
    private array $config;
    
    public function __construct(string $storage = 'file', array $config = [])
    {
        $this->storage = $storage;
        $this->config = array_merge([
            'max_attempts' => 60,
            'window' => 3600, // 1 hour
            'storage_path' => sys_get_temp_dir() . '/rate_limits'
        ], $config);
        
        if ($this->storage === 'file' && !is_dir($this->config['storage_path'])) {
            mkdir($this->config['storage_path'], 0755, true);
        }
    }
    
    public function attempt(string $key, int $maxAttempts = null, int $window = null): bool
    {
        $maxAttempts = $maxAttempts ?? $this->config['max_attempts'];
        $window = $window ?? $this->config['window'];
        
        $data = $this->getData($key);
        $currentTime = time();
        
        // Reset if window has passed
        if ($data && ($currentTime - $data['first_attempt']) > $window) {
            $data = null;
        }
        
        if (!$data) {
            $data = [
                'attempts' => 1,
                'first_attempt' => $currentTime,
                'last_attempt' => $currentTime
            ];
        } else {
            $data['attempts']++;
            $data['last_attempt'] = $currentTime;
        }
        
        $this->setData($key, $data);
        
        return $data['attempts'] <= $maxAttempts;
    }
    
    public function getRemainingAttempts(string $key, int $maxAttempts = null): int
    {
        $maxAttempts = $maxAttempts ?? $this->config['max_attempts'];
        $data = $this->getData($key);
        
        if (!$data) {
            return $maxAttempts;
        }
        
        return max(0, $maxAttempts - $data['attempts']);
    }
    
    public function getTimeUntilReset(string $key, int $window = null): int
    {
        $window = $window ?? $this->config['window'];
        $data = $this->getData($key);
        
        if (!$data) {
            return 0;
        }
        
        $elapsed = time() - $data['first_attempt'];
        return max(0, $window - $elapsed);
    }
    
    public function reset(string $key): void
    {
        $this->deleteData($key);
    }
    
    private function getData(string $key): ?array
    {
        if ($this->storage === 'file') {
            $file = $this->config['storage_path'] . '/' . md5($key) . '.json';
            
            if (file_exists($file)) {
                $content = file_get_contents($file);
                return json_decode($content, true);
            }
        }
        
        return null;
    }
    
    private function setData(string $key, array $data): void
    {
        if ($this->storage === 'file') {
            $file = $this->config['storage_path'] . '/' . md5($key) . '.json';
            file_put_contents($file, json_encode($data));
        }
    }
    
    private function deleteData(string $key): void
    {
        if ($this->storage === 'file') {
            $file = $this->config['storage_path'] . '/' . md5($key) . '.json';
            
            if (file_exists($file)) {
                unlink($file);
            }
        }
    }
}

// AI-SUGGESTION: Security headers manager
class SecurityHeaders
{
    public static function setSecurityHeaders(): void
    {
        // Prevent XSS attacks
        header('X-XSS-Protection: 1; mode=block');
        
        // Prevent content sniffing
        header('X-Content-Type-Options: nosniff');
        
        // Prevent clickjacking
        header('X-Frame-Options: DENY');
        
        // HSTS (only over HTTPS)
        if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') {
            header('Strict-Transport-Security: max-age=31536000; includeSubDomains; preload');
        }
        
        // Content Security Policy
        $cspPolicy = implode('; ', [
            "default-src 'self'",
            "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
            "style-src 'self' 'unsafe-inline'",
            "img-src 'self' data: https:",
            "font-src 'self'",
            "connect-src 'self'",
            "frame-ancestors 'none'"
        ]);
        
        header("Content-Security-Policy: {$cspPolicy}");
        
        // Referrer Policy
        header('Referrer-Policy: strict-origin-when-cross-origin');
        
        // Permissions Policy
        header('Permissions-Policy: geolocation=(), microphone=(), camera=()');
    }
}

// AI-SUGGESTION: Utility helper functions
class Utils
{
    public static function generateUuid(): string
    {
        return sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff)
        );
    }
    
    public static function slugify(string $text): string
    {
        $text = preg_replace('~[^\pL\d]+~u', '-', $text);
        $text = iconv('utf-8', 'us-ascii//TRANSLIT', $text);
        $text = preg_replace('~[^-\w]+~', '', $text);
        $text = trim($text, '-');
        $text = preg_replace('~-+~', '-', $text);
        
        return strtolower($text);
    }
    
    public static function truncate(string $text, int $length, string $suffix = '...'): string
    {
        if (strlen($text) <= $length) {
            return $text;
        }
        
        return substr($text, 0, $length - strlen($suffix)) . $suffix;
    }
    
    public static function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, 2) . ' ' . $units[$i];
    }
    
    public static function timeAgo(DateTime $datetime): string
    {
        $now = new DateTime();
        $diff = $now->diff($datetime);
        
        if ($diff->y > 0) {
            return $diff->y . ' year' . ($diff->y > 1 ? 's' : '') . ' ago';
        } elseif ($diff->m > 0) {
            return $diff->m . ' month' . ($diff->m > 1 ? 's' : '') . ' ago';
        } elseif ($diff->d > 0) {
            return $diff->d . ' day' . ($diff->d > 1 ? 's' : '') . ' ago';
        } elseif ($diff->h > 0) {
            return $diff->h . ' hour' . ($diff->h > 1 ? 's' : '') . ' ago';
        } elseif ($diff->i > 0) {
            return $diff->i . ' minute' . ($diff->i > 1 ? 's' : '') . ' ago';
        } else {
            return 'Just now';
        }
    }
    
    public static function arrayFlatten(array $array): array
    {
        $result = [];
        
        foreach ($array as $value) {
            if (is_array($value)) {
                $result = array_merge($result, self::arrayFlatten($value));
            } else {
                $result[] = $value;
            }
        }
        
        return $result;
    }
    
    public static function isEmail(string $email): bool
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }
    
    public static function isUrl(string $url): bool
    {
        return filter_var($url, FILTER_VALIDATE_URL) !== false;
    }
    
    public static function randomString(int $length = 32): string
    {
        $characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
        $string = '';
        
        for ($i = 0; $i < $length; $i++) {
            $string .= $characters[random_int(0, strlen($characters) - 1)];
        }
        
        return $string;
    }
    
    public static function maskEmail(string $email): string
    {
        $parts = explode('@', $email);
        
        if (count($parts) !== 2) {
            return $email;
        }
        
        $username = $parts[0];
        $domain = $parts[1];
        
        if (strlen($username) <= 2) {
            $maskedUsername = str_repeat('*', strlen($username));
        } else {
            $maskedUsername = substr($username, 0, 1) . 
                             str_repeat('*', strlen($username) - 2) . 
                             substr($username, -1);
        }
        
        return $maskedUsername . '@' . $domain;
    }
}

// AI-SUGGESTION: Usage example and demonstration
function demonstrateSecurityUtilities(): void
{
    echo "=== Security Utilities Demo ===\n";
    
    // Input validation
    $validator = new InputValidator();
    
    $validator->addCustomRule('strong_password', function($value) {
        if (strlen($value) < 8) return 'Password must be at least 8 characters';
        if (!preg_match('/[A-Z]/', $value)) return 'Password must contain uppercase letter';
        if (!preg_match('/[a-z]/', $value)) return 'Password must contain lowercase letter';
        if (!preg_match('/[0-9]/', $value)) return 'Password must contain number';
        if (!preg_match('/[^A-Za-z0-9]/', $value)) return 'Password must contain special character';
        return null;
    });
    
    $data = [
        'email' => 'user@example.com',
        'password' => 'SecurePass123!',
        'password_confirmation' => 'SecurePass123!',
        'age' => '25'
    ];
    
    $rules = [
        'email' => 'required|email|sanitize:email',
        'password' => 'required|strong_password',
        'password_confirmation' => 'required|confirmed',
        'age' => 'required|integer|min:18|max:120'
    ];
    
    $result = $validator->validate($data, $rules);
    
    if ($result->isValid) {
        echo "Validation passed!\n";
        echo "Sanitized email: " . $result->sanitizedData['email'] . "\n";
    } else {
        echo "Validation errors: " . json_encode($result->errors) . "\n";
    }
    
    // CSRF protection
    $csrf = new CSRFProtection();
    $token = $csrf->generateToken('login');
    echo "CSRF Token: " . substr($token, 0, 10) . "...\n";
    
    // XSS protection
    $userInput = '<script>alert("XSS")</script>Hello World';
    $safeOutput = XSSProtection::escape($userInput);
    echo "Safe output: " . $safeOutput . "\n";
    
    // Encryption
    $encryption = new EncryptionService();
    $plaintext = "Sensitive data";
    $encrypted = $encryption->encrypt($plaintext);
    $decrypted = $encryption->decrypt($encrypted);
    
    echo "Original: {$plaintext}\n";
    echo "Encrypted: " . substr($encrypted, 0, 20) . "...\n";
    echo "Decrypted: {$decrypted}\n";
    
    // Rate limiting
    $rateLimiter = new RateLimiter();
    $clientIp = '192.168.1.1';
    
    if ($rateLimiter->attempt($clientIp, 5, 300)) { // 5 attempts per 5 minutes
        echo "Request allowed\n";
    } else {
        $timeUntilReset = $rateLimiter->getTimeUntilReset($clientIp, 300);
        echo "Rate limit exceeded. Try again in {$timeUntilReset} seconds\n";
    }
    
    // Utilities
    echo "UUID: " . Utils::generateUuid() . "\n";
    echo "Slug: " . Utils::slugify("Hello World! This is a test.") . "\n";
    echo "Masked email: " . Utils::maskEmail("john.doe@example.com") . "\n";
    
    // Set security headers
    SecurityHeaders::setSecurityHeaders();
    echo "Security headers set\n";
    
    echo "Security utilities demo completed\n";
} 