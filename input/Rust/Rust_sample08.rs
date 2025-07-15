use std::collections::HashMap;
use std::fs;
use std::io::{self, Read, Write};
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use std::fmt;
use std::num::ParseIntError;
use std::string::FromUtf8Error;

#[derive(Debug)]
enum Algorithm {
    Xor,
    Caesar(u8),
    Vigenere,
}

#[derive(Debug)]
enum CryptoError {
    Io(io::Error),
    KeyNotFound(String),
    HexDecode(ParseIntError),
    Utf8(FromUtf8Error),
    WeakKey,
}

impl fmt::Display for CryptoError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            CryptoError::Io(err) => write!(f, "IO Error: {}", err),
            CryptoError::KeyNotFound(user) => write!(f, "Key not found for user: {}", user),
            CryptoError::HexDecode(err) => write!(f, "Hex decoding error: {}", err),
            CryptoError::Utf8(err) => write!(f, "UTF-8 conversion error: {}", err),
            CryptoError::WeakKey => write!(f, "The provided key is too weak"),
        }
    }
}

impl From<io::Error> for CryptoError {
    fn from(err: io::Error) -> CryptoError {
        CryptoError::Io(err)
    }
}

impl From<ParseIntError> for CryptoError {
    fn from(err: ParseIntError) -> CryptoError {
        CryptoError::HexDecode(err)
    }
}

impl From<FromUtf8Error> for CryptoError {
    fn from(err: FromUtf8Error) -> CryptoError {
        CryptoError::Utf8(err)
    }
}


struct CryptoManager {
    keys: HashMap<String, Vec<u8>>,
    key_file: String,
    history: Vec<String>,
}

impl CryptoManager {
    fn new(key_file: &str) -> CryptoManager {
        let mut manager = CryptoManager {
            keys: HashMap::new(),
            key_file: key_file.to_string(),
            history: Vec::new(),
        };
        manager.log_action("CryptoManager created".to_string());
        if let Err(e) = manager.load_keys() {
            manager.log_action(format!("Failed to load keys: {}", e));
        }
        manager
    }

    fn log_action(&mut self, action: String) {
        if let Ok(duration) = SystemTime::now().duration_since(UNIX_EPOCH) {
            let timestamp = duration.as_millis();
            self.history.push(format!("[{}] {}", timestamp, action));
        }
    }

    fn load_keys(&mut self) -> Result<(), CryptoError> {
        if Path::new(&self.key_file).exists() {
            let mut file = fs::File::open(&self.key_file)?;
            let mut contents = String::new();
            file.read_to_string(&mut contents)?;
            for line in contents.lines() {
                let parts: Vec<&str> = line.split(':').collect();
                if parts.len() == 2 {
                    self.keys.insert(parts[0].to_string(), hex_decode(parts[1])?);
                }
            }
            self.log_action(format!("Loaded keys from {}", self.key_file));
        }
        Ok(())
    }

    fn generate_key(&mut self, user: &str) -> Vec<u8> {
        let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        let key_data = format!("{}_{}", user, timestamp);
        let key = xor_encrypt(key_data.as_bytes(), b"master_secret");
        self.keys.insert(user.to_string(), key.clone());
        self.log_action(format!("Generated key for user '{}'", user));
        if let Err(e) = self.save_keys() {
            self.log_action(format!("Failed to save keys: {}", e));
        }
        key
    }

    fn rotate_key(&mut self, user: &str) -> Result<Vec<u8>, CryptoError> {
        if !self.keys.contains_key(user) {
            return Err(CryptoError::KeyNotFound(user.to_string()));
        }
        let new_key = self.generate_key(user);
        self.log_action(format!("Rotated key for user '{}'", user));
        Ok(new_key)
    }

    fn delete_key(&mut self, user: &str) -> Option<Vec<u8>> {
        let result = self.keys.remove(user);
        if result.is_some() {
            self.log_action(format!("Deleted key for user '{}'", user));
            if let Err(e) = self.save_keys() {
                self.log_action(format!("Failed to save keys: {}", e));
            }
        }
        result
    }

    fn save_keys(&self) -> Result<(), CryptoError> {
        let mut file = fs::File::create(&self.key_file)?;
        for (user, key) in &self.keys {
            writeln!(file, "{}:{}", user, hex_encode(key))?;
        }
        Ok(())
    }
    
    fn is_key_weak(&self, key: &[u8]) -> bool {
        key.len() < 8 || key.iter().all(|&b| b == key[0])
    }

    fn encrypt(&self, user: &str, plaintext: &str, algorithm: &Algorithm) -> Result<Vec<u8>, CryptoError> {
        let key = self.keys.get(user).ok_or_else(|| CryptoError::KeyNotFound(user.to_string()))?;
        if self.is_key_weak(key) {
            return Err(CryptoError::WeakKey);
        }
        
        let ciphertext = match algorithm {
            Algorithm::Xor => xor_encrypt(plaintext.as_bytes(), key),
            Algorithm::Caesar(shift) => caesar_encrypt(plaintext.as_bytes(), *shift),
            Algorithm::Vigenere => vigenere_encrypt(plaintext.as_bytes(), key),
        };
        Ok(ciphertext)
    }

    fn decrypt(&self, user: &str, ciphertext: &[u8], algorithm: &Algorithm) -> Result<String, CryptoError> {
        let key = self.keys.get(user).ok_or_else(|| CryptoError::KeyNotFound(user.to_string()))?;
        if self.is_key_weak(key) {
            return Err(CryptoError::WeakKey);
        }

        let decrypted = match algorithm {
            Algorithm::Xor => xor_encrypt(ciphertext, key),
            Algorithm::Caesar(shift) => caesar_decrypt(ciphertext, *shift),
            Algorithm::Vigenere => vigenere_decrypt(ciphertext, key),
        };

        Ok(String::from_utf8(decrypted)?)
    }

    fn generate_token(&self, user: &str) -> Result<String, CryptoError> {
        let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        let key = self.keys.get(user).ok_or_else(|| CryptoError::KeyNotFound(user.to_string()))?;
        let message = format!("{}_{}", user, timestamp);
        let signature = xor_encrypt(message.as_bytes(), &key);
        Ok(format!("{}.{}", message, hex_encode(&signature)))
    }

    fn list_users(&self) -> Vec<String> {
        self.keys.keys().cloned().collect()
    }

    fn print_history(&self) {
        println!("\n--- Action History ---");
        for entry in &self.history {
            println!("{}", entry);
        }
        println!("--- End History ---");
    }
}

fn xor_encrypt(data: &[u8], key: &[u8]) -> Vec<u8> {
    if key.is_empty() { return data.to_vec(); }
    data.iter().enumerate().map(|(i, &b)| b ^ key[i % key.len()]).collect()
}

fn caesar_encrypt(data: &[u8], shift: u8) -> Vec<u8> {
    data.iter().map(|&b| b.wrapping_add(shift)).collect()
}

fn caesar_decrypt(data: &[u8], shift: u8) -> Vec<u8> {
    data.iter().map(|&b| b.wrapping_sub(shift)).collect()
}

fn vigenere_encrypt(data: &[u8], key: &[u8]) -> Vec<u8> {
    if key.is_empty() { return data.to_vec(); }
    data.iter().enumerate().map(|(i, &b)| b.wrapping_add(key[i % key.len()])).collect()
}

fn vigenere_decrypt(data: &[u8], key: &[u8]) -> Vec<u8> {
    if key.is_empty() { return data.to_vec(); }
    data.iter().enumerate().map(|(i, &b)| b.wrapping_sub(key[i % key.len()])).collect()
}

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

fn hex_decode(s: &str) -> Result<Vec<u8>, ParseIntError> {
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16))
        .collect()
}

fn main() {
    let mut crypto = CryptoManager::new("/tmp/rust_sample08_keys_v2.txt");
    let user1 = "alice";
    crypto.generate_key(user1);
    println!("Generated key for {}", user1);

    let user2 = "bob";
    crypto.generate_key(user2);
    println!("Generated key for {}", user2);
    
    let user3 = "carol";
    crypto.generate_key(user3);
    println!("Generated key for {}", user3);

    println!("\nCurrent users: {:?}", crypto.list_users());

    let plaintext = "This is a longer piece of sensitive data to encrypt for testing purposes.";
    println!("\nOriginal plaintext: {}", plaintext);

    let ciphertext_vigenere = crypto.encrypt(user3, plaintext, &Algorithm::Vigenere).unwrap();
    println!("Encrypted with Vigenere for {}: {}", user3, hex_encode(&ciphertext_vigenere));
    let decrypted_vigenere = crypto.decrypt(user3, &ciphertext_vigenere, &Algorithm::Vigenere).unwrap();
    println!("Decrypted with Vigenere for {}: {}", user3, decrypted_vigenere);

    crypto.rotate_key(user1).unwrap();
    println!("\nRotated key for {}", user1);

    let token = crypto.generate_token(user1).unwrap();
    println!("Generated token for {}: {}", user1, token);

    crypto.delete_key(user2);
    println!("\nDeleted key for {}", user2);
    println!("Current users: {:?}", crypto.list_users());

    match crypto.encrypt(user2, plaintext, &Algorithm::Xor) {
        Ok(_) => println!("Encryption should have failed but succeeded."),
        Err(e) => println!("Correctly failed to encrypt for deleted user {}: {}", user2, e),
    }

    crypto.print_history();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn get_test_manager(filename: &str) -> CryptoManager {
        let path = format!("/tmp/{}", filename);
        if Path::new(&path).exists() {
            fs::remove_file(&path).unwrap();
        }
        CryptoManager::new(&path)
    }

    #[test]
    fn test_xor_encryption() {
        let data = b"hello world";
        let key = b"key";
        let encrypted = xor_encrypt(data, key);
        let decrypted = xor_encrypt(&encrypted, key);
        assert_eq!(data.to_vec(), decrypted);
    }
    
    #[test]
    fn test_caesar_cipher() {
        let data = b"hello";
        let shift = 5;
        let encrypted = caesar_encrypt(data, shift);
        let decrypted = caesar_decrypt(&encrypted, shift);
        assert_eq!(data.to_vec(), decrypted);
        assert_ne!(data.to_vec(), encrypted);
    }

    #[test]
    fn test_vigenere_cipher() {
        let data = b"attack at dawn";
        let key = b"LEMON";
        let encrypted = vigenere_encrypt(data, key);
        let decrypted = vigenere_decrypt(&encrypted, key);
        assert_eq!(data.to_vec(), decrypted);
        assert_ne!(data.to_vec(), encrypted);
    }

    #[test]
    fn test_crypto_manager() {
        let mut crypto = get_test_manager("test_keys_manager.txt");
        let user = "bob";
        crypto.generate_key(user);
        let plaintext = "test123";
        let ciphertext = crypto.encrypt(user, plaintext, &Algorithm::Xor).unwrap();
        let decrypted = crypto.decrypt(user, &ciphertext, &Algorithm::Xor).unwrap();
        assert_eq!(plaintext, decrypted);
    }

    #[test]
    fn test_key_rotation() {
        let mut crypto = get_test_manager("test_key_rotation.txt");
        let user = "george";
        let old_key = crypto.generate_key(user);
        let new_key = crypto.rotate_key(user).unwrap();
        assert_ne!(old_key, new_key);
        assert!(crypto.keys.contains_key(user));
    }

    #[test]
    fn test_rotate_nonexistent_key() {
        let mut crypto = get_test_manager("test_key_rotation_nonexistent.txt");
        assert!(crypto.rotate_key("nosuchuser").is_err());
    }

    #[test]
    fn test_key_deletion() {
        let mut crypto = get_test_manager("test_key_deletion.txt");
        let user = "charlie";
        crypto.generate_key(user);
        assert!(crypto.keys.contains_key(user));
        crypto.delete_key(user);
        assert!(!crypto.keys.contains_key(user));
    }

    #[test]
    fn test_list_users() {
        let mut crypto = get_test_manager("test_list_users.txt");
        crypto.generate_key("dave");
        crypto.generate_key("eve");
        let mut users = crypto.list_users();
        users.sort();
        assert_eq!(users, vec!["dave".to_string(), "eve".to_string()]);
    }
    
    #[test]
    fn test_encryption_for_nonexistent_user() {
        let crypto = get_test_manager("test_nonexistent.txt");
        let result = crypto.encrypt("nonexistent", "data", &Algorithm::Xor);
        assert!(result.is_err());
        if let Err(CryptoError::KeyNotFound(user)) = result {
            assert_eq!(user, "nonexistent");
        } else {
            panic!("Expected KeyNotFound error");
        }
    }
    
    #[test]
    fn test_weak_key_encryption_fails() {
        let mut crypto = get_test_manager("test_weak_key.txt");
        let user = "weakuser";
        crypto.keys.insert(user.to_string(), vec![1, 2, 3]);
        let result = crypto.encrypt(user, "some data", &Algorithm::Xor);
        assert!(result.is_err());
        if let Err(CryptoError::WeakKey) = result {
        } else {
            panic!("Expected WeakKey error");
        }
    }

    #[test]
    fn test_token_generation() {
        let mut crypto = get_test_manager("test_token.txt");
        let user = "frank";
        crypto.generate_key(user);
        let token = crypto.generate_token(user).unwrap();
        assert!(token.starts_with(user));
        assert!(token.contains("."));
    }
    
    #[test]
    fn test_hex_coding() {
        let data = vec![10, 20, 30, 40, 255];
        let encoded = hex_encode(&data);
        assert_eq!(encoded, "0a141e28ff");
        let decoded = hex_decode(&encoded).unwrap();
        assert_eq!(data, decoded);
    }
} 