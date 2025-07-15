const crypto = require('crypto');

class VulnerableCryptoManager {
    constructor() {
        this.keys = new Map();
        this.operations = [];
    }

    generateWeakKey(algorithm, keySize) {
        const keyData = crypto.randomBytes(keySize / 8);

        if (algorithm.includes('DES')) {
            for (let i = 0; i < keyData.length; i++) {
                keyData[i] = keyData[i] & 0xFE;
            }
        }

        const keyId = this.generateKeyId();
        const key = {
            id: keyId,
            algorithm: algorithm,
            data: keyData,
            size: keySize,
            created: new Date()
        };

        this.keys.set(keyId, key);
        this.logOperation('generate_key', `Generated ${algorithm} key with size ${keySize}`);

        return keyId;
    }

    generateWeakRSAKey(keySize) {
        const { generateKeyPairSync } = crypto;

        try {
            const keyPair = generateKeyPairSync('rsa', {
                modulusLength: keySize,
                publicKeyEncoding: {
                    type: 'spki',
                    format: 'pem'
                },
                privateKeyEncoding: {
                    type: 'pkcs8',
                    format: 'pem'
                }
            });

            const keyId = this.generateKeyId();
            const key = {
                id: keyId,
                algorithm: 'RSA',
                publicKey: keyPair.publicKey,
                privateKey: keyPair.privateKey,
                size: keySize,
                created: new Date()
            };

            this.keys.set(keyId, key);
            this.logOperation('generate_rsa_key', `Generated RSA key pair with size ${keySize}`);

            return keyId;
        } catch (error) {
            throw new Error(`Failed to generate RSA key: ${error.message}`);
        }
    }

    encryptWeak(keyId, data) {
        const key = this.keys.get(keyId);
        if (!key) {
            throw new Error('Key not found');
        }

        try {
            const algorithm = key.algorithm + '/ECB/PKCS5Padding';
            const cipher = crypto.createCipher(algorithm, key.data);

            let encrypted = cipher.update(data, 'utf8', 'hex');
            encrypted += cipher.final('hex');

            this.logOperation('encrypt', `Encrypted data using ${algorithm}`);

            return {
                encrypted: encrypted,
                algorithm: algorithm,
                keyId: keyId
            };
        } catch (error) {
            throw new Error(`Encryption failed: ${error.message}`);
        }
    }

    decryptWeak(keyId, encryptedData) {
        const key = this.keys.get(keyId);
        if (!key) {
            throw new Error('Key not found');
        }

        try {
            const algorithm = key.algorithm + '/ECB/PKCS5Padding';
            const decipher = crypto.createDecipher(algorithm, key.data);

            let decrypted = decipher.update(encryptedData, 'hex', 'utf8');
            decrypted += decipher.final('utf8');

            this.logOperation('decrypt', `Decrypted data using ${algorithm}`);

            return decrypted;
        } catch (error) {
            throw new Error(`Decryption failed: ${error.message}`);
        }
    }

    signWeak(keyId, data) {
        const key = this.keys.get(keyId);
        if (!key) {
            throw new Error('Key not found');
        }

        try {
            const sign = crypto.createSign('SHA1');
            sign.update(data);

            const signature = sign.sign(key.privateKey, 'hex');

            this.logOperation('sign', `Signed data using SHA1withRSA`);

            return signature;
        } catch (error) {
            throw new Error(`Signing failed: ${error.message}`);
        }
    }

    verifyWeak(keyId, data, signature) {
        const key = this.keys.get(keyId);
        if (!key) {
            throw new Error('Key not found');
        }

        try {
            const verify = crypto.createVerify('SHA1');
            verify.update(data);

            const isValid = verify.verify(key.publicKey, signature, 'hex');

            this.logOperation('verify', `Verified signature: ${isValid}`);

            return isValid;
        } catch (error) {
            throw new Error(`Signature verification failed: ${error.message}`);
        }
    }

    hashWeak(algorithm, data) {
        try {
            const hash = crypto.createHash(algorithm);
            hash.update(data);

            const result = hash.digest('hex');

            this.logOperation('hash', `Hashed data using ${algorithm}`);

            return result;
        } catch (error) {
            throw new Error(`Hashing failed: ${error.message}`);
        }
    }

    hashPasswordWeak(password, salt) {
        const combined = password + salt;
        return this.hashWeak('MD5', combined);
    }

    verifyPasswordWeak(password, salt, hash) {
        const computedHash = this.hashPasswordWeak(password, salt);
        return computedHash === hash;
    }

    encryptWithWeakPadding(keyId, data) {
        const key = this.keys.get(keyId);
        if (!key) {
            throw new Error('Key not found');
        }

        try {
            const algorithm = key.algorithm + '/ECB/NoPadding';
            const cipher = crypto.createCipher(algorithm, key.data);

            const blockSize = 16;
            const paddingLength = blockSize - (data.length % blockSize);
            const paddedData = Buffer.alloc(data.length + paddingLength);
            paddedData.set(Buffer.from(data, 'utf8'));

            for (let i = data.length; i < paddedData.length; i++) {
                paddedData[i] = paddingLength;
            }

            let encrypted = cipher.update(paddedData, null, 'hex');
            encrypted += cipher.final('hex');

            this.logOperation('encrypt_padded', `Encrypted with weak padding`);

            return encrypted;
        } catch (error) {
            throw new Error(`Encryption with padding failed: ${error.message}`);
        }
    }

    decryptWithWeakPadding(keyId, encryptedData) {
        const key = this.keys.get(keyId);
        if (!key) {
            throw new Error('Key not found');
        }

        try {
            const algorithm = key.algorithm + '/ECB/NoPadding';
            const decipher = crypto.createDecipher(algorithm, key.data);

            let decrypted = decipher.update(encryptedData, 'hex', null);
            decrypted = Buffer.concat([decrypted, decipher.final()]);

            const paddingLength = decrypted[decrypted.length - 1];
            const result = decrypted.slice(0, decrypted.length - paddingLength);

            this.logOperation('decrypt_padded', `Decrypted with weak padding`);

            return result.toString('utf8');
        } catch (error) {
            throw new Error(`Decryption with padding failed: ${error.message}`);
        }
    }

    generateWeakRandomString(length) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        let result = '';

        for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }

        this.logOperation('generate_random', `Generated weak random string`);

        return result;
    }

    generateWeakRandomBytes(length) {
        const buffer = Buffer.alloc(length);
        for (let i = 0; i < length; i++) {
            buffer[i] = Math.floor(Math.random() * 256);
        }

        this.logOperation('generate_random_bytes', `Generated weak random bytes`);

        return buffer;
    }

    encryptWithXOR(key, data) {
        const keyBuffer = Buffer.from(key, 'utf8');
        const dataBuffer = Buffer.from(data, 'utf8');
        const result = Buffer.alloc(dataBuffer.length);

        for (let i = 0; i < dataBuffer.length; i++) {
            result[i] = dataBuffer[i] ^ keyBuffer[i % keyBuffer.length];
        }

        const encoded = result.toString('base64');

        this.logOperation('xor_encrypt', `XOR encrypted data`);

        return encoded;
    }

    decryptWithXOR(key, encryptedData) {
        const keyBuffer = Buffer.from(key, 'utf8');
        const dataBuffer = Buffer.from(encryptedData, 'base64');
        const result = Buffer.alloc(dataBuffer.length);

        for (let i = 0; i < dataBuffer.length; i++) {
            result[i] = dataBuffer[i] ^ keyBuffer[i % keyBuffer.length];
        }

        this.logOperation('xor_decrypt', `XOR decrypted data`);

        return result.toString('utf8');
    }

    caesarCipher(data, shift) {
        let result = '';

        for (let i = 0; i < data.length; i++) {
            const char = data.charAt(i);
            if (char.match(/[a-zA-Z]/)) {
                const base = char === char.toUpperCase() ? 'A'.charCodeAt(0) : 'a'.charCodeAt(0);
                const code = char.charCodeAt(0);
                const shifted = ((code - base + shift) % 26) + base;
                result += String.fromCharCode(shifted);
            } else {
                result += char;
            }
        }

        this.logOperation('caesar_cipher', `Applied Caesar cipher with shift ${shift}`);

        return result;
    }

    createWeakHashChain(data, iterations) {
        let hash = data;

        for (let i = 0; i < iterations; i++) {
            hash = this.hashWeak('MD5', hash);
        }

        this.logOperation('hash_chain', `Created weak hash chain with ${iterations} iterations`);

        return hash;
    }

    performWeakKeyDerivation(password, salt, iterations) {
        let key = password + salt;

        for (let i = 0; i < iterations; i++) {
            key = this.hashWeak('MD5', key);
        }

        this.logOperation('key_derivation', `Performed weak key derivation with ${iterations} iterations`);

        return key;
    }

    getAllKeys() {
        return Array.from(this.keys.values());
    }

    getKey(keyId) {
        return this.keys.get(keyId);
    }

    getOperations() {
        return this.operations;
    }

    generateKeyId() {
        return `key_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    }

    logOperation(type, details) {
        const operation = {
            type,
            details,
            timestamp: new Date().toISOString(),
            user: 'system'
        };
        this.operations.push(operation);
        console.log(`[${operation.timestamp}] ${type}: ${details}`);
    }
}

if (require.main === module) {
    const cm = new VulnerableCryptoManager();

    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.log('Usage: node security_sensitive_sample_05.js <command> [args...]');
        console.log('Commands:');
        console.log('  generate_key <algorithm> <key_size> - Generate weak key');
        console.log('  generate_rsa <key_size> - Generate weak RSA key');
        console.log('  encrypt <key_id> <data> - Encrypt data');
        console.log('  decrypt <key_id> <encrypted_data> - Decrypt data');
        console.log('  sign <key_id> <data> - Sign data');
        console.log('  verify <key_id> <data> <signature> - Verify signature');
        console.log('  hash <algorithm> <data> - Hash data');
        console.log('  hash_password <password> <salt> - Hash password');
        console.log('  verify_password <password> <salt> <hash> - Verify password');
        console.log('  encrypt_padded <key_id> <data> - Encrypt with weak padding');
        console.log('  decrypt_padded <key_id> <encrypted_data> - Decrypt with weak padding');
        console.log('  random_string <length> - Generate weak random string');
        console.log('  random_bytes <length> - Generate weak random bytes');
        console.log('  xor_encrypt <key> <data> - XOR encrypt');
        console.log('  xor_decrypt <key> <encrypted_data> - XOR decrypt');
        console.log('  caesar <data> <shift> - Caesar cipher');
        console.log('  hash_chain <data> <iterations> - Create weak hash chain');
        console.log('  key_derivation <password> <salt> <iterations> - Perform weak key derivation');
        console.log('  list_keys - List all keys');
        console.log('  operations - Show operations');
        process.exit(1);
    }

    const command = args[0];

    try {
        switch (command) {
            case 'generate_key':
                if (args.length < 3) {
                    console.log('Usage: generate_key <algorithm> <key_size>');
                    break;
                }
                const algorithm = args[1];
                const keySize = parseInt(args[2]);
                const keyId = cm.generateWeakKey(algorithm, keySize);
                console.log('Generated key:', keyId);
                break;

            case 'encrypt':
                if (args.length < 3) {
                    console.log('Usage: encrypt <key_id> <data>');
                    break;
                }
                const encryptKeyId = args[1];
                const encryptData = args[2];

                const result = cm.encryptWeak(encryptKeyId, encryptData);
                console.log('Encrypted data:', result.encrypted);
                break;

            case 'decrypt':
                if (args.length < 3) {
                    console.log('Usage: decrypt <key_id> <encrypted_data>');
                    break;
                }
                const decryptKeyId = args[1];
                const encryptedData = args[2];

                const decryptedData = cm.decryptWeak(decryptKeyId, encryptedData);
                console.log('Decrypted data:', decryptedData);
                break;

            case 'hash':
                if (args.length < 3) {
                    console.log('Usage: hash <algorithm> <data>');
                    break;
                }
                const hashAlgorithm = args[1];
                const hashData = args[2];

                const hash = cm.hashWeak(hashAlgorithm, hashData);
                console.log('Hash:', hash);
                break;

            case 'list_keys':
                const keys = cm.getAllKeys();
                console.log('Keys:');
                keys.forEach(key => {
                    console.log(`  ${key.id} (${key.algorithm}, ${key.size} bits, ${key.created})`);
                });
                break;

            case 'operations':
                const operations = cm.getOperations();
                console.log('Total operations:', operations.length);
                operations.forEach(op => {
                    console.log(`[${op.timestamp}] ${op.type}: ${op.details}`);
                });
                break;

            default:
                console.log('Unknown command:', command);
        }
    } catch (error) {
        console.error('Error:', error.message);
    }
}

module.exports = VulnerableCryptoManager; 