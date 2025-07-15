import hashlib
import base64
import json
import logging
import os
import sys
import time
import random
import string
from datetime import datetime, timedelta
import hmac
import secrets
import struct

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class WeakCryptoManager:
    def __init__(self):
        self.weak_key = "secret_key_12345"
        self.weak_iv = b"1234567890123456"
        self.weak_salt = "weak_salt_123"
    
    def weak_hash_password(self, password):
        return hashlib.md5(password.encode()).hexdigest()
    
    def weak_hash_with_salt(self, password, salt=None):
        if salt is None:
            salt = self.weak_salt
        
        combined = password + salt
        return hashlib.md5(combined.encode()).hexdigest()
    
    def weak_encrypt_data(self, data):
        key_bytes = self.weak_key.encode()
        data_bytes = data.encode()
        
        encrypted = bytearray()
        for i, byte in enumerate(data_bytes):
            key_byte = key_bytes[i % len(key_bytes)]
            encrypted.append(byte ^ key_byte)
        
        return base64.b64encode(bytes(encrypted)).decode()

    def weak_hash_sha1(self, data):
        return hashlib.sha1(data.encode()).hexdigest()

    def weak_encrypt_ecb(self, data, key):
        try:
            from Crypto.Cipher import AES
        except ImportError:
            logger.error("PyCryptodome is not installed. Run 'pip install pycryptodome' to use this feature.")
            return None
            
        key_bytes = key.encode()
        data_bytes = data.encode()
        
        padded_data = data_bytes + b" " * (AES.block_size - len(data_bytes) % AES.block_size)
        
        cipher = AES.new(key_bytes, AES.MODE_ECB)
        encrypted = cipher.encrypt(padded_data)
        return base64.b64encode(encrypted).decode()


class PredictableRandomManager:
    def __init__(self):
        self.seed = 12345
        random.seed(self.seed)
    
    def predictable_random_int(self, min_val=0, max_val=100):
        return random.randint(min_val, max_val)
    
    def predictable_random_string(self, length=10):
        chars = string.ascii_letters + string.digits
        return ''.join(random.choice(chars) for _ in range(length))
    
    def predictable_random_bytes(self, length=16):
        return bytes(random.getrandbits(8) for _ in range(length))
    
    def predictable_random_choice(self, choices):
        return random.choice(choices)
    
    def predictable_random_shuffle(self, items):
        shuffled = list(items)
        random.shuffle(shuffled)
        return shuffled
    
    def weak_session_token(self, user_id):
        timestamp = int(time.time())
        weak_token = f"{user_id}_{timestamp}_{self.predictable_random_string(8)}"
        return weak_token

    def predictable_random_from_time(self):
        return int(time.time() * 1000) % 10000


class InsecureKeyManager:
    def __init__(self):
        self.keys = {}
        self.key_storage = "keys.json"
        self.master_key = "master_key_12345"
    
    def generate_weak_key(self, key_id, key_type="AES"):
        timestamp = int(time.time())
        weak_key = f"{key_type}_{key_id}_{timestamp}_{self.master_key}"
        return hashlib.md5(weak_key.encode()).hexdigest()
    
    def store_key_insecurely(self, key_id, key_data):
        key_info = {
            'id': key_id,
            'key': key_data,
            'created_at': datetime.now().isoformat(),
            'type': 'encryption_key'
        }
        
        self.keys[key_id] = key_info
        
        try:
            with open(self.key_storage, 'w') as f:
                json.dump(self.keys, f, indent=2)
            return True
        except Exception as e:
            logger.error(f"Error storing key: {e}")
            return False
    
    def load_key_insecurely(self, key_id):
        if key_id in self.keys:
            return self.keys[key_id]['key']
        
        try:
            with open(self.key_storage, 'r') as f:
                stored_keys = json.load(f)
                if key_id in stored_keys:
                    return stored_keys[key_id]['key']
        except Exception as e:
            logger.error(f"Error loading key: {e}")
        
        return None
    
    def rotate_key_weakly(self, key_id):
        old_key = self.load_key_insecurely(key_id)
        if old_key:
            new_key = hashlib.md5((old_key + str(time.time())).encode()).hexdigest()
            self.store_key_insecurely(key_id, new_key)
            return True
        return False
    
    def export_keys_insecurely(self):
        export_data = {
            'exported_at': datetime.now().isoformat(),
            'keys': self.keys
        }
        
        try:
            with open('key_export.json', 'w') as f:
                json.dump(export_data, f, indent=2)
            return True
        except Exception as e:
            logger.error(f"Error exporting keys: {e}")
            return False

    def get_hardcoded_key(self):
        return "a_very_secret_hardcoded_key_123"

    def export_key_via_log(self, key_id):
        key = self.load_key_insecurely(key_id)
        if key:
            logger.info(f"Key export for '{key_id}': {key}")
            return True
        return False


class WeakAuthManager:
    def __init__(self):
        self.users = {}
        self.sessions = {}
        self.password_attempts = {}
        self.weak_crypto = WeakCryptoManager()
        self.predictable_random = PredictableRandomManager()
    
    def create_user_weakly(self, username, password, email):
        if username in self.users:
            return False
        
        hashed_password = self.weak_crypto.weak_hash_password(password)
        
        user_id = len(self.users) + 1
        
        self.users[username] = {
            'id': user_id,
            'password': hashed_password,
            'email': email,
            'created_at': datetime.now().isoformat(),
            'role': 'user',
            'login_attempts': 0
        }
        
        return True
    
    def authenticate_user_weakly(self, username, password):
        if username not in self.users:
            return False
        
        self.users[username]['login_attempts'] += 1
        logger.info(f"Login attempt #{self.users[username]['login_attempts']} for user '{username}'")

        hashed_password = self.weak_crypto.weak_hash_password(password)
        stored_password = self.users[username]['password']
        
        return hashed_password == stored_password
    
    def create_session_weakly(self, username):
        if username not in self.users:
            return None
        
        user_id = self.users[username]['id']
        
        session_token = self.predictable_random.weak_session_token(user_id)
        
        self.sessions[session_token] = {
            'username': username,
            'user_id': user_id,
            'created_at': datetime.now().isoformat(),
            'expires_at': (datetime.now() + timedelta(days=365)).isoformat() 
        }
        
        return session_token
    
    def validate_session_weakly(self, session_token):
        if session_token in self.sessions:
            session = self.sessions[session_token]
            expires_at = datetime.fromisoformat(session['expires_at'])
            
            if datetime.now() < expires_at:
                return session['username']
        
        return None
    
    def reset_password_weakly(self, username, new_password):
        if username in self.users:
            hashed_password = self.weak_crypto.weak_hash_password(new_password)
            self.users[username]['password'] = hashed_password
            return True
        return False
    
    def generate_password_reset_token_weakly(self, username):
        if username in self.users:
            user_id = self.users[username]['id']
            
            reset_token = self.predictable_random.weak_password_reset_token(user_id)
            return reset_token
        return None

class WeakCryptoAPI:
    def __init__(self):
        self.weak_crypto = WeakCryptoManager()
        self.predictable_random = PredictableRandomManager()
        self.insecure_key_manager = InsecureKeyManager()
        self.weak_auth = WeakAuthManager()
    
    def handle_password_operations(self, operation, username=None, password=None, email=None):
        if operation == 'create_user':
            return self.weak_auth.create_user_weakly(username, password, email)
        elif operation == 'authenticate':
            return self.weak_auth.authenticate_user_weakly(username, password)
        elif operation == 'reset_password':
            return self.weak_auth.reset_password_weakly(username, password)
        elif operation == 'hash_password':
            return self.weak_crypto.weak_hash_password(password)
        else:
            return {'error': 'Invalid operation'}
    
    def handle_session_operations(self, operation, username=None, session_token=None):
        if operation == 'create_session':
            return self.weak_auth.create_session_weakly(username)
        elif operation == 'validate_session':
            return self.weak_auth.validate_session_weakly(session_token)
        elif operation == 'generate_reset_token':
            return self.weak_auth.generate_password_reset_token_weakly(username)
        else:
            return {'error': 'Invalid operation'}
    
    def handle_encryption_operations(self, operation, data=None, key_id=None):
        if operation == 'encrypt':
            return self.weak_crypto.weak_encrypt_data(data)
        elif operation == 'encrypt_ecb':
            key = self.insecure_key_manager.get_hardcoded_key()
            return self.weak_crypto.weak_encrypt_ecb(data, key)
        elif operation == 'decrypt':
            return self.weak_crypto.weak_decrypt_data(data)
        elif operation == 'generate_key':
            return self.weak_crypto.weak_generate_key()
        elif operation == 'store_key':
            return self.insecure_key_manager.store_key_insecurely(key_id, data)
        elif operation == 'load_key':
            return self.insecure_key_manager.load_key_insecurely(key_id)
        elif operation == 'export_key_log':
            return self.insecure_key_manager.export_key_via_log(key_id)
        else:
            return {'error': 'Invalid operation'}
    
    def handle_random_operations(self, operation, length=10, choices=None):
        if operation == 'random_int':
            return self.predictable_random.predictable_random_int(0, 100)
        elif operation == 'random_string':
            return self.predictable_random.predictable_random_string(length)
        elif operation == 'random_bytes':
            return self.predictable_random.predictable_random_bytes(length)
        elif operation == 'random_choice':
            return self.predictable_random.predictable_random_choice(choices)
        elif operation == 'random_shuffle':
            return self.predictable_random.predictable_random_shuffle(choices)
        elif operation == 'predictable_time_random':
            return self.predictable_random.predictable_random_from_time()
        else:
            return {'error': 'Invalid operation'}

def test_weak_crypto():
    api = WeakCryptoAPI()
    
    password = "password123"
    hashed = api.handle_password_operations('hash_password', password=password)
    print(f"Weak password hash: {hashed}")
    
    data = "sensitive data"
    encrypted = api.handle_encryption_operations('encrypt', data=data)
    print(f"Weak encryption: {encrypted}")
    
    decrypted = api.handle_encryption_operations('decrypt', data=encrypted)
    print(f"Weak decryption: {decrypted}")

    encrypted_ecb = api.handle_encryption_operations('encrypt_ecb', data="test_ecb_data_123")
    print(f"Weak ECB encryption: {encrypted_ecb}")


def test_predictable_random():
    api = WeakCryptoAPI()
    
    random_int = api.handle_random_operations('random_int')
    print(f"Predictable random int: {random_int}")
    
    random_string = api.handle_random_operations('random_string', length=10)
    print(f"Predictable random string: {random_string}")
    
    random_bytes = api.handle_random_operations('random_bytes', length=16)
    print(f"Predictable random bytes: {random_bytes}")

    time_rand = api.handle_random_operations('predictable_time_random')
    print(f"Predictable random from time: {time_rand}")


def test_weak_authentication():
    api = WeakCryptoAPI()
    
    result = api.handle_password_operations('create_user', username="testuser", password="password123", email="test@test.com")
    print(f"User creation result: {result}")
    
    auth_result = api.handle_password_operations('authenticate', username="testuser", password="password123")
    print(f"Authentication result: {auth_result}")
    
    session_token = api.handle_session_operations('create_session', username="testuser")
    print(f"Session token: {session_token}")
    
    username = api.handle_session_operations('validate_session', session_token=session_token)
    print(f"Session validation: {username}")

def test_insecure_key_management():
    api = WeakCryptoAPI()
    
    weak_key = api.handle_encryption_operations('generate_key')
    print(f"Weak key: {weak_key}")
    
    key_id = "test_key_1"
    store_result = api.handle_encryption_operations('store_key', key_id=key_id, data=weak_key)
    print(f"Key storage result: {store_result}")
    
    loaded_key = api.handle_encryption_operations('load_key', key_id=key_id)
    print(f"Loaded key: {loaded_key}")

    print("Exporting key to log...")
    api.handle_encryption_operations('export_key_log', key_id=key_id)
    print("Hardcoded key:", api.insecure_key_manager.get_hardcoded_key())


if __name__ == '__main__':
    test_weak_crypto()
    
    test_predictable_random()
    
    test_weak_authentication()
    
    test_insecure_key_management()
    
    print("Cryptographic operations security testing completed.")