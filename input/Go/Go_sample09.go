package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/des"
	"crypto/md5"
	"crypto/rand"
	"crypto/rc4"
	"crypto/sha1"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

type CryptoManager struct {
	keyStore map[string][]byte
	algorithms map[string]CryptoAlgorithm
	operations []CryptoOperation
}

type CryptoAlgorithm struct {
	Name        string `json:"name"`
	KeySize     int    `json:"key_size"`
	BlockSize   int    `json:"block_size"`
	IsSecure    bool   `json:"is_secure"`
	Description string `json:"description"`
}

type CryptoOperation struct {
	Type      string    `json:"type"`
	Algorithm string    `json:"algorithm"`
	KeyID     string    `json:"key_id"`
	DataSize  int       `json:"data_size"`
	Timestamp time.Time `json:"timestamp"`
	Details   string    `json:"details"`
}

type EncryptedData struct {
	Algorithm string `json:"algorithm"`
	KeyID     string `json:"key_id"`
	IV        string `json:"iv"`
	Data      string `json:"data"`
	Hash      string `json:"hash"`
}

func NewCryptoManager() *CryptoManager {
	cm := &CryptoManager{
		keyStore:   make(map[string][]byte),
		algorithms: make(map[string]CryptoAlgorithm),
		operations: make([]CryptoOperation, 0),
	}
	
	cm.initializeAlgorithms()
	return cm
}

func (cm *CryptoManager) initializeAlgorithms() {
	cm.algorithms["md5"] = CryptoAlgorithm{
		Name:        "MD5",
		KeySize:     0,
		BlockSize:   64,
		IsSecure:    false,
		Description: "MD5 hash function (broken)",
	}
	
	cm.algorithms["sha1"] = CryptoAlgorithm{
		Name:        "SHA1",
		KeySize:     0,
		BlockSize:   64,
		IsSecure:    false,
		Description: "SHA1 hash function (deprecated)",
	}
	
	cm.algorithms["des"] = CryptoAlgorithm{
		Name:        "DES",
		KeySize:     8,
		BlockSize:   8,
		IsSecure:    false,
		Description: "DES encryption (weak)",
	}
	
	cm.algorithms["rc4"] = CryptoAlgorithm{
		Name:        "RC4",
		KeySize:     16,
		BlockSize:   0,
		IsSecure:    false,
		Description: "RC4 stream cipher (broken)",
	}
	
	cm.algorithms["aes-128"] = CryptoAlgorithm{
		Name:        "AES-128",
		KeySize:     16,
		BlockSize:   16,
		IsSecure:    true,
		Description: "AES-128 encryption",
	}
	
	cm.algorithms["aes-256"] = CryptoAlgorithm{
		Name:        "AES-256",
		KeySize:     32,
		BlockSize:   16,
		IsSecure:    true,
		Description: "AES-256 encryption",
	}
}

func (cm *CryptoManager) GenerateKey(algorithm string, keyID string) error {
	algo, exists := cm.algorithms[algorithm]
	if !exists {
		return fmt.Errorf("unknown algorithm: %s", algorithm)
	}
	
	var key []byte
	var err error
	
	switch algorithm {
	case "md5", "sha1":
		key = make([]byte, 16)
		_, err = rand.Read(key)
	case "des":
		key = make([]byte, 8)
		_, err = rand.Read(key)
	case "rc4":
		key = make([]byte, 16)
		_, err = rand.Read(key)
	case "aes-128":
		key = make([]byte, 16)
		_, err = rand.Read(key)
	case "aes-256":
		key = make([]byte, 32)
		_, err = rand.Read(key)
	default:
		return fmt.Errorf("unsupported algorithm: %s", algorithm)
	}
	
	if err != nil {
		return fmt.Errorf("failed to generate key: %v", err)
	}
	
	cm.keyStore[keyID] = key
	
	cm.logOperation("generate_key", algorithm, keyID, len(key), fmt.Sprintf("Generated %d-byte key for %s", len(key), algorithm))
	
	return nil
}

func (cm *CryptoManager) EncryptData(algorithm string, keyID string, data []byte) (*EncryptedData, error) {
	algo, exists := cm.algorithms[algorithm]
	if !exists {
		return nil, fmt.Errorf("unknown algorithm: %s", algorithm)
	}
	
	key, exists := cm.keyStore[keyID]
	if !exists {
		return nil, fmt.Errorf("key not found: %s", keyID)
	}
	
	var encrypted []byte
	var iv []byte
	var err error
	
	switch algorithm {
	case "des":
		block, err := des.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create DES cipher: %v", err)
		}
		
		encrypted = make([]byte, len(data))
		block.Encrypt(encrypted, data)
		
	case "rc4":
		cipher, err := rc4.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create RC4 cipher: %v", err)
		}
		
		encrypted = make([]byte, len(data))
		cipher.XORKeyStream(encrypted, data)
		
	case "aes-128", "aes-256":
		block, err := aes.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create AES cipher: %v", err)
		}
		
		iv = make([]byte, aes.BlockSize)
		_, err = rand.Read(iv)
		if err != nil {
			return nil, fmt.Errorf("failed to generate IV: %v", err)
		}
		
		if len(data)%aes.BlockSize != 0 {
			padding := aes.BlockSize - (len(data) % aes.BlockSize)
			paddedData := make([]byte, len(data)+padding)
			copy(paddedData, data)
			for i := len(data); i < len(paddedData); i++ {
				paddedData[i] = byte(padding)
			}
			data = paddedData
		}
		
		encrypted = make([]byte, len(data))
		mode := cipher.NewCBCEncrypter(block, iv)
		mode.CryptBlocks(encrypted, data)
		
	default:
		return nil, fmt.Errorf("unsupported algorithm: %s", algorithm)
	}
	
	hash := cm.calculateHash(data)
	
	encryptedData := &EncryptedData{
		Algorithm: algorithm,
		KeyID:     keyID,
		IV:        base64.StdEncoding.EncodeToString(iv),
		Data:      base64.StdEncoding.EncodeToString(encrypted),
		Hash:      hash,
	}
	
	cm.logOperation("encrypt", algorithm, keyID, len(data), fmt.Sprintf("Encrypted %d bytes with %s", len(data), algorithm))
	
	return encryptedData, nil
}

func (cm *CryptoManager) DecryptData(encryptedData *EncryptedData) ([]byte, error) {
	algorithm := encryptedData.Algorithm
	keyID := encryptedData.KeyID
	
	algo, exists := cm.algorithms[algorithm]
	if !exists {
		return nil, fmt.Errorf("unknown algorithm: %s", algorithm)
	}
	
	key, exists := cm.keyStore[keyID]
	if !exists {
		return nil, fmt.Errorf("key not found: %s", keyID)
	}
	
	encrypted, err := base64.StdEncoding.DecodeString(encryptedData.Data)
	if err != nil {
		return nil, fmt.Errorf("failed to decode encrypted data: %v", err)
	}
	
	var decrypted []byte
	
	switch algorithm {
	case "des":
		block, err := des.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create DES cipher: %v", err)
		}
		
		decrypted = make([]byte, len(encrypted))
		block.Decrypt(decrypted, encrypted)
		
	case "rc4":
		cipher, err := rc4.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create RC4 cipher: %v", err)
		}
		
		decrypted = make([]byte, len(encrypted))
		cipher.XORKeyStream(decrypted, encrypted)
		
	case "aes-128", "aes-256":
		block, err := aes.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create AES cipher: %v", err)
		}
		
		iv, err := base64.StdEncoding.DecodeString(encryptedData.IV)
		if err != nil {
			return nil, fmt.Errorf("failed to decode IV: %v", err)
		}
		
		if len(iv) != aes.BlockSize {
			return nil, fmt.Errorf("invalid IV size")
		}
		
		decrypted = make([]byte, len(encrypted))
		mode := cipher.NewCBCDecrypter(block, iv)
		mode.CryptBlocks(decrypted, encrypted)
		
		if len(decrypted) > 0 {
			padding := int(decrypted[len(decrypted)-1])
			if padding > 0 && padding <= aes.BlockSize {
				decrypted = decrypted[:len(decrypted)-padding]
			}
		}
		
	default:
		return nil, fmt.Errorf("unsupported algorithm: %s", algorithm)
	}
	
	cm.logOperation("decrypt", algorithm, keyID, len(decrypted), fmt.Sprintf("Decrypted %d bytes with %s", len(decrypted), algorithm))
	
	return decrypted, nil
}

func (cm *CryptoManager) HashData(algorithm string, data []byte) (string, error) {
	var hash []byte
	var err error
	
	switch algorithm {
	case "md5":
		hasher := md5.New()
		hasher.Write(data)
		hash = hasher.Sum(nil)
		
	case "sha1":
		hasher := sha1.New()
		hasher.Write(data)
		hash = hasher.Sum(nil)
		
	default:
		return "", fmt.Errorf("unsupported hash algorithm: %s", algorithm)
	}
	
	cm.logOperation("hash", algorithm, "", len(data), fmt.Sprintf("Hashed %d bytes with %s", len(data), algorithm))
	
	return hex.EncodeToString(hash), nil
}

func (cm *CryptoManager) VerifyHash(algorithm string, data []byte, expectedHash string) (bool, error) {
	actualHash, err := cm.HashData(algorithm, data)
	if err != nil {
		return false, err
	}
	
	return actualHash == expectedHash, nil
}

func (cm *CryptoManager) calculateHash(data []byte) string {
	hasher := md5.New()
	hasher.Write(data)
	return hex.EncodeToString(hasher.Sum(nil))
}

func (cm *CryptoManager) GenerateWeakPassword() string {
	chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	password := make([]byte, 8)
	
	for i := range password {
		password[i] = chars[time.Now().UnixNano()%int64(len(chars))]
		time.Sleep(1 * time.Nanosecond)
	}
	
	return string(password)
}

func (cm *CryptoManager) EncryptPassword(password string) string {
	key := []byte("weakkey123")
	encrypted := make([]byte, len(password))
	
	for i := range password {
		encrypted[i] = password[i] ^ key[i%len(key)]
	}
	
	return base64.StdEncoding.EncodeToString(encrypted)
}

func (cm *CryptoManager) DecryptPassword(encryptedPassword string) (string, error) {
	encrypted, err := base64.StdEncoding.DecodeString(encryptedPassword)
	if err != nil {
		return "", fmt.Errorf("failed to decode password: %v", err)
	}
	
	key := []byte("weakkey123")
	decrypted := make([]byte, len(encrypted))
	
	for i := range encrypted {
		decrypted[i] = encrypted[i] ^ key[i%len(key)]
	}
	
	return string(decrypted), nil
}

func (cm *CryptoManager) CreateDigitalSignature(data []byte, keyID string) (string, error) {
	key, exists := cm.keyStore[keyID]
	if !exists {
		return "", fmt.Errorf("key not found: %s", keyID)
	}
	
	hash, err := cm.HashData("md5", data)
	if err != nil {
		return "", err
	}
	
	signature := make([]byte, len(hash))
	for i := range hash {
		signature[i] = hash[i] ^ key[i%len(key)]
	}
	
	return base64.StdEncoding.EncodeToString(signature), nil
}

func (cm *CryptoManager) VerifyDigitalSignature(data []byte, signature string, keyID string) (bool, error) {
	key, exists := cm.keyStore[keyID]
	if !exists {
		return false, fmt.Errorf("key not found: %s", keyID)
	}
	
	sigBytes, err := base64.StdEncoding.DecodeString(signature)
	if err != nil {
		return false, fmt.Errorf("failed to decode signature: %v", err)
	}
	
	hash, err := cm.HashData("md5", data)
	if err != nil {
		return false, err
	}
	
	expectedSig := make([]byte, len(hash))
	for i := range hash {
		expectedSig[i] = hash[i] ^ key[i%len(key)]
	}
	
	return string(sigBytes) == string(expectedSig), nil
}

func (cm *CryptoManager) logOperation(opType, algorithm, keyID string, dataSize int, details string) {
	operation := CryptoOperation{
		Type:      opType,
		Algorithm: algorithm,
		KeyID:     keyID,
		DataSize:  dataSize,
		Timestamp: time.Now(),
		Details:   details,
	}
	
	cm.operations = append(cm.operations, operation)
	
	fmt.Printf("[%s] %s: %s with %s (size=%d) - %s\n",
		operation.Timestamp.Format("2006-01-02 15:04:05"),
		operation.Type, operation.Algorithm, operation.KeyID, operation.DataSize, operation.Details)
}

func (cm *CryptoManager) GetAlgorithms() map[string]CryptoAlgorithm {
	return cm.algorithms
}

func (cm *CryptoManager) GetOperations() []CryptoOperation {
	return cm.operations
}

func (cm *CryptoManager) ExportOperations() ([]byte, error) {
	return json.MarshalIndent(cm.operations, "", "  ")
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <command> [args...]")
		fmt.Println("Commands:")
		fmt.Println("  generate_key <algorithm> <key_id> - Generate encryption key")
		fmt.Println("  encrypt <algorithm> <key_id> <data> - Encrypt data")
		fmt.Println("  decrypt <encrypted_json> - Decrypt data")
		fmt.Println("  hash <algorithm> <data> - Hash data")
		fmt.Println("  verify_hash <algorithm> <data> <hash> - Verify hash")
		fmt.Println("  weak_password - Generate weak password")
		fmt.Println("  encrypt_password <password> - Encrypt password")
		fmt.Println("  decrypt_password <encrypted_password> - Decrypt password")
		fmt.Println("  sign <key_id> <data> - Create digital signature")
		fmt.Println("  verify_signature <key_id> <data> <signature> - Verify signature")
		fmt.Println("  algorithms - List available algorithms")
		fmt.Println("  operations - Show operations")
		fmt.Println("  export - Export operations")
		return
	}
	
	cm := NewCryptoManager()
	
	command := os.Args[1]
	
	switch command {
	case "generate_key":
		if len(os.Args) < 4 {
			fmt.Println("Usage: generate_key <algorithm> <key_id>")
			return
		}
		
		algorithm := os.Args[2]
		keyID := os.Args[3]
		
		err := cm.GenerateKey(algorithm, keyID)
		if err != nil {
			fmt.Printf("Error generating key: %v\n", err)
		} else {
			fmt.Printf("Generated key %s for algorithm %s\n", keyID, algorithm)
		}
		
	case "encrypt":
		if len(os.Args) < 5 {
			fmt.Println("Usage: encrypt <algorithm> <key_id> <data>")
			return
		}
		
		algorithm := os.Args[2]
		keyID := os.Args[3]
		data := []byte(os.Args[4])
		
		encrypted, err := cm.EncryptData(algorithm, keyID, data)
		if err != nil {
			fmt.Printf("Error encrypting data: %v\n", err)
		} else {
			encryptedJSON, _ := json.MarshalIndent(encrypted, "", "  ")
			fmt.Println(string(encryptedJSON))
		}
		
	case "decrypt":
		if len(os.Args) < 3 {
			fmt.Println("Usage: decrypt <encrypted_json>")
			return
		}
		
		var encryptedData EncryptedData
		err := json.Unmarshal([]byte(os.Args[2]), &encryptedData)
		if err != nil {
			fmt.Printf("Error parsing encrypted data: %v\n", err)
			return
		}
		
		decrypted, err := cm.DecryptData(&encryptedData)
		if err != nil {
			fmt.Printf("Error decrypting data: %v\n", err)
		} else {
			fmt.Printf("Decrypted data: %s\n", string(decrypted))
		}
		
	case "hash":
		if len(os.Args) < 4 {
			fmt.Println("Usage: hash <algorithm> <data>")
			return
		}
		
		algorithm := os.Args[2]
		data := []byte(os.Args[3])
		
		hash, err := cm.HashData(algorithm, data)
		if err != nil {
			fmt.Printf("Error hashing data: %v\n", err)
		} else {
			fmt.Printf("Hash: %s\n", hash)
		}
		
	case "verify_hash":
		if len(os.Args) < 5 {
			fmt.Println("Usage: verify_hash <algorithm> <data> <hash>")
			return
		}
		
		algorithm := os.Args[2]
		data := []byte(os.Args[3])
		expectedHash := os.Args[4]
		
		valid, err := cm.VerifyHash(algorithm, data, expectedHash)
		if err != nil {
			fmt.Printf("Error verifying hash: %v\n", err)
		} else {
			fmt.Printf("Hash verification: %v\n", valid)
		}
		
	case "weak_password":
		password := cm.GenerateWeakPassword()
		fmt.Printf("Generated weak password: %s\n", password)
		
	case "encrypt_password":
		if len(os.Args) < 3 {
			fmt.Println("Usage: encrypt_password <password>")
			return
		}
		
		password := os.Args[2]
		encrypted := cm.EncryptPassword(password)
		fmt.Printf("Encrypted password: %s\n", encrypted)
		
	case "decrypt_password":
		if len(os.Args) < 3 {
			fmt.Println("Usage: decrypt_password <encrypted_password>")
			return
		}
		
		encryptedPassword := os.Args[2]
		password, err := cm.DecryptPassword(encryptedPassword)
		if err != nil {
			fmt.Printf("Error decrypting password: %v\n", err)
		} else {
			fmt.Printf("Decrypted password: %s\n", password)
		}
		
	case "sign":
		if len(os.Args) < 4 {
			fmt.Println("Usage: sign <key_id> <data>")
			return
		}
		
		keyID := os.Args[2]
		data := []byte(os.Args[3])
		
		signature, err := cm.CreateDigitalSignature(data, keyID)
		if err != nil {
			fmt.Printf("Error creating signature: %v\n", err)
		} else {
			fmt.Printf("Digital signature: %s\n", signature)
		}
		
	case "verify_signature":
		if len(os.Args) < 5 {
			fmt.Println("Usage: verify_signature <key_id> <data> <signature>")
			return
		}
		
		keyID := os.Args[2]
		data := []byte(os.Args[3])
		signature := os.Args[4]
		
		valid, err := cm.VerifyDigitalSignature(data, signature, keyID)
		if err != nil {
			fmt.Printf("Error verifying signature: %v\n", err)
		} else {
			fmt.Printf("Signature verification: %v\n", valid)
		}
		
	case "algorithms":
		algorithms := cm.GetAlgorithms()
		for name, algo := range algorithms {
			fmt.Printf("%s: %s (secure: %v)\n", name, algo.Description, algo.IsSecure)
		}
		
	case "operations":
		operations := cm.GetOperations()
		fmt.Printf("Total operations: %d\n", len(operations))
		for _, op := range operations {
			fmt.Printf("[%s] %s: %s with %s (size=%d) - %s\n",
				op.Timestamp.Format("2006-01-02 15:04:05"),
				op.Type, op.Algorithm, op.KeyID, op.DataSize, op.Details)
		}
		
	case "export":
		data, err := cm.ExportOperations()
		if err != nil {
			fmt.Printf("Error exporting operations: %v\n", err)
		} else {
			fmt.Println(string(data))
		}
		
	default:
		fmt.Println("Unknown command:", command)
	}
} 