#!/usr/bin/env ruby

require 'digest'
require 'base64'
require 'json'
require 'logger'
require 'securerandom'
require 'time'
require 'openssl'
require 'yaml'

LOGGER = Logger.new(STDOUT)

class WeakCryptoManager
  def initialize
    @weak_key = "secret_key_12345"
    @weak_iv = "1234567890123456"
    @weak_salt = "weak_salt_123"
  end

  def weak_hash_password(password)
    Digest::MD5.hexdigest(password)
  end

  def weak_hash_with_salt(password, salt = nil)
    salt ||= @weak_salt
    
    combined = password + salt
    Digest::MD5.hexdigest(combined)
  end

  def weak_encrypt_data(data)
    key_bytes = @weak_key.bytes
    data_bytes = data.bytes
    
    encrypted = []
    data_bytes.each_with_index do |byte, i|
      key_byte = key_bytes[i % key_bytes.length]
      encrypted << (byte ^ key_byte)
    end
    
    Base64.encode64(encrypted.pack('C*'))
  end

  def weak_decrypt_data(encrypted_data)
    encrypted_bytes = Base64.decode64(encrypted_data).bytes
    key_bytes = @weak_key.bytes
    
    decrypted = []
    encrypted_bytes.each_with_index do |byte, i|
      key_byte = key_bytes[i % key_bytes.length]
      decrypted << (byte ^ key_byte)
    end
    
    decrypted.pack('C*')
  end

  def weak_generate_key(length = 32)
    key = ""
    length.times do |i|
      key += (65 + (i % 26)).chr
    end
    key
  end

  def weak_generate_iv(length = 16)
    iv = ""
    length.times do |i|
      iv += (48 + (i % 10)).chr
    end
    iv
  end
end

class PredictableRandomManager
  def initialize
    @seed = 12345
    srand(@seed)
  end

  def predictable_random_int(min_val = 0, max_val = 100)
    rand(min_val..max_val)
  end

  def predictable_random_string(length = 10)
    chars = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a
    length.times.map { chars[rand(chars.length)] }.join
  end

  def predictable_random_bytes(length = 16)
    length.times.map { rand(256) }.pack('C*')
  end

  def predictable_random_choice(choices)
    choices[rand(choices.length)]
  end

  def predictable_random_shuffle(items)
    items.shuffle
  end

  def weak_session_token(user_id)
    timestamp = Time.now.to_i
    weak_token = "#{user_id}_#{timestamp}_#{predictable_random_string(8)}"
    weak_token
  end

  def weak_password_reset_token(user_id)
    timestamp = Time.now.to_i
    weak_token = "reset_#{user_id}_#{timestamp}_#{predictable_random_string(6)}"
    weak_token
  end
end

class InsecureKeyManager
  def initialize
    @keys = {}
    @key_storage = "keys.json"
    @master_key = "master_key_12345"
  end

  def generate_weak_key(key_id, key_type = "AES")
    timestamp = Time.now.to_i
    weak_key = "#{key_type}_#{key_id}_#{timestamp}_#{@master_key}"
    Digest::MD5.hexdigest(weak_key)
  end

  def store_key_insecurely(key_id, key_data)
    key_info = {
      id: key_id,
      key: key_data,
      created_at: Time.now.iso8601,
      type: 'encryption_key'
    }
    
    @keys[key_id] = key_info
    
    begin
      File.write(@key_storage, JSON.pretty_generate(@keys))
      true
    rescue => e
      LOGGER.error("Error storing key: #{e}")
      false
    end
  end

  def load_key_insecurely(key_id)
    return @keys[key_id][:key] if @keys.key?(key_id)
    
    begin
      stored_keys = JSON.parse(File.read(@key_storage))
      stored_keys[key_id]['key'] if stored_keys.key?(key_id)
    rescue => e
      LOGGER.error("Error loading key: #{e}")
      nil
    end
  end

  def rotate_key_weakly(key_id)
    old_key = load_key_insecurely(key_id)
    if old_key
      new_key = Digest::MD5.hexdigest(old_key + Time.now.to_i.to_s)
      store_key_insecurely(key_id, new_key)
      true
    else
      false
    end
  end

  def export_keys_insecurely
    export_data = {
      exported_at: Time.now.iso8601,
      keys: @keys
    }
    
    begin
      File.write('key_export.json', JSON.pretty_generate(export_data))
      true
    rescue => e
      LOGGER.error("Error exporting keys: #{e}")
      false
    end
  end
end

class WeakAuthManager
  def initialize
    @users = {}
    @sessions = {}
    @password_attempts = {}
    @weak_crypto = WeakCryptoManager.new
    @predictable_random = PredictableRandomManager.new
  end

  def create_user_weakly(username, password, email)
    return false if @users.key?(username)
    
    hashed_password = @weak_crypto.weak_hash_password(password)
    
    user_id = @users.length + 1
    
    @users[username] = {
      id: user_id,
      password: hashed_password,
      email: email,
      created_at: Time.now.iso8601,
      role: 'user'
    }
    
    true
  end

  def authenticate_user_weakly(username, password)
    return false unless @users.key?(username)
    
    hashed_password = @weak_crypto.weak_hash_password(password)
    stored_password = @users[username][:password]
    
    hashed_password == stored_password
  end

  def create_session_weakly(username)
    return nil unless @users.key?(username)
    
    user_id = @users[username][:id]
    
    session_token = @predictable_random.weak_session_token(user_id)
    
    @sessions[session_token] = {
      username: username,
      user_id: user_id,
      created_at: Time.now.iso8601,
      expires_at: (Time.now + 24 * 60 * 60).iso8601
    }
    
    session_token
  end

  def validate_session_weakly(session_token)
    return nil unless @sessions.key?(session_token)
    
    session = @sessions[session_token]
    expires_at = Time.parse(session[:expires_at])
    
    if Time.now < expires_at
      session[:username]
    else
      nil
    end
  end

  def reset_password_weakly(username, new_password)
    if @users.key?(username)
      hashed_password = @weak_crypto.weak_hash_password(new_password)
      @users[username][:password] = hashed_password
      true
    else
      false
    end
  end

  def generate_password_reset_token_weakly(username)
    return nil unless @users.key?(username)
    
    user_id = @users[username][:id]
    
    reset_token = @predictable_random.weak_password_reset_token(user_id)
    reset_token
  end
end

class WeakCryptoAPI
  def initialize
    @weak_crypto = WeakCryptoManager.new
    @predictable_random = PredictableRandomManager.new
    @insecure_key_manager = InsecureKeyManager.new
    @weak_auth = WeakAuthManager.new
  end

  def handle_password_operations(operation, username = nil, password = nil, email = nil)
    case operation
    when 'create_user'
      @weak_auth.create_user_weakly(username, password, email)
    when 'authenticate'
      @weak_auth.authenticate_user_weakly(username, password)
    when 'reset_password'
      @weak_auth.reset_password_weakly(username, password)
    when 'hash_password'
      @weak_crypto.weak_hash_password(password)
    else
      { error: 'Invalid operation' }
    end
  end

  def handle_session_operations(operation, username = nil, session_token = nil)
    case operation
    when 'create_session'
      @weak_auth.create_session_weakly(username)
    when 'validate_session'
      @weak_auth.validate_session_weakly(session_token)
    when 'generate_reset_token'
      @weak_auth.generate_password_reset_token_weakly(username)
    else
      { error: 'Invalid operation' }
    end
  end

  def handle_encryption_operations(operation, data = nil, key_id = nil)
    case operation
    when 'encrypt'
      @weak_crypto.weak_encrypt_data(data)
    when 'decrypt'
      @weak_crypto.weak_decrypt_data(data)
    when 'generate_key'
      @weak_crypto.weak_generate_key
    when 'store_key'
      @insecure_key_manager.store_key_insecurely(key_id, data)
    when 'load_key'
      @insecure_key_manager.load_key_insecurely(key_id)
    else
      { error: 'Invalid operation' }
    end
  end

  def handle_random_operations(operation, length = 10, choices = nil)
    case operation
    when 'random_int'
      @predictable_random.predictable_random_int(0, 100)
    when 'random_string'
      @predictable_random.predictable_random_string(length)
    when 'random_bytes'
      @predictable_random.predictable_random_bytes(length)
    when 'random_choice'
      @predictable_random.predictable_random_choice(choices)
    when 'random_shuffle'
      @predictable_random.predictable_random_shuffle(choices)
    else
      { error: 'Invalid operation' }
    end
  end
end

class WeakCryptoFunctions
  def self.weak_rsa_encryption(data, key_size = 512)
    key = OpenSSL::PKey::RSA.generate(key_size)
    encrypted = key.public_encrypt(data)
    Base64.encode64(encrypted)
  end

  def self.weak_rsa_decryption(encrypted_data, private_key)
    encrypted = Base64.decode64(encrypted_data)
    private_key.private_decrypt(encrypted)
  end

  def self.weak_aes_encryption(data, key = nil)
    key ||= "weak_key_1234567890123456"
    cipher = OpenSSL::Cipher.new('AES-128-ECB')
    cipher.encrypt
    cipher.key = key
    encrypted = cipher.update(data) + cipher.final
    Base64.encode64(encrypted)
  end

  def self.weak_aes_decryption(encrypted_data, key = nil)
    key ||= "weak_key_1234567890123456"
    encrypted = Base64.decode64(encrypted_data)
    cipher = OpenSSL::Cipher.new('AES-128-ECB')
    cipher.decrypt
    cipher.key = key
    cipher.update(encrypted) + cipher.final
  end

  def self.weak_hmac(data, key = nil)
    key ||= "weak_hmac_key"
    OpenSSL::HMAC.hexdigest('MD5', key, data)
  end

  def self.weak_pbkdf2(password, salt = nil, iterations = 1000)
    salt ||= "weak_salt"
    OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations, 32, 'MD5')
  end
end

def test_weak_crypto
  api = WeakCryptoAPI.new
  
  password = "password123"
  hashed = api.handle_password_operations('hash_password', password: password)
  puts "Weak password hash: #{hashed}"
  
  data = "sensitive data"
  encrypted = api.handle_encryption_operations('encrypt', data: data)
  puts "Weak encryption: #{encrypted}"
  
  decrypted = api.handle_encryption_operations('decrypt', data: encrypted)
  puts "Weak decryption: #{decrypted}"
end

def test_predictable_random
  api = WeakCryptoAPI.new
  
  random_int = api.handle_random_operations('random_int')
  puts "Predictable random int: #{random_int}"
  
  random_string = api.handle_random_operations('random_string', 10)
  puts "Predictable random string: #{random_string}"
  
  random_bytes = api.handle_random_operations('random_bytes', 16)
  puts "Predictable random bytes: #{random_bytes}"
end

def test_weak_authentication
  api = WeakCryptoAPI.new
  
  result = api.handle_password_operations('create_user', username: "testuser", password: "password123", email: "test@test.com")
  puts "User creation result: #{result}"
  
  auth_result = api.handle_password_operations('authenticate', username: "testuser", password: "password123")
  puts "Authentication result: #{auth_result}"
  
  session_token = api.handle_session_operations('create_session', username: "testuser")
  puts "Session token: #{session_token}"
  
  username = api.handle_session_operations('validate_session', session_token: session_token)
  puts "Session validation: #{username}"
end

def test_insecure_key_management
  api = WeakCryptoAPI.new
  
  weak_key = api.handle_encryption_operations('generate_key')
  puts "Weak key: #{weak_key}"
  
  key_id = "test_key_1"
  store_result = api.handle_encryption_operations('store_key', key_id: key_id, data: weak_key)
  puts "Key storage result: #{store_result}"
  
  loaded_key = api.handle_encryption_operations('load_key', key_id: key_id)
  puts "Loaded key: #{loaded_key}"
end

def test_additional_weak_crypto
  data = "secret message"
  encrypted_rsa = WeakCryptoFunctions.weak_rsa_encryption(data)
  puts "Weak RSA encryption: #{encrypted_rsa}"
  
  encrypted_aes = WeakCryptoFunctions.weak_aes_encryption(data)
  puts "Weak AES encryption: #{encrypted_aes}"
  
  hmac = WeakCryptoFunctions.weak_hmac(data)
  puts "Weak HMAC: #{hmac}"
  
  pbkdf2 = WeakCryptoFunctions.weak_pbkdf2("password", "salt")
  puts "Weak PBKDF2: #{Base64.encode64(pbkdf2)}"
end

if __FILE__ == $0
  test_weak_crypto
  
  test_predictable_random
  
  test_weak_authentication
  
  test_insecure_key_management
  
  test_additional_weak_crypto
  
  puts "Cryptographic operations security testing completed."
end 