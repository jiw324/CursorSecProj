#!/usr/bin/env ruby

require 'sqlite3'
require 'mysql2'
require 'json'
require 'logger'
require 'digest'
require 'securerandom'
require 'time'

LOGGER = Logger.new(STDOUT)

class SQLiteManager
  def initialize(db_path = 'database.db')
    @db_path = db_path
    init_database
  end

  def init_database
    db = SQLite3::Database.new(@db_path)
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY,
        username TEXT UNIQUE,
        password TEXT,
        email TEXT,
        role TEXT DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    SQL
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY,
        name TEXT,
        description TEXT,
        price REAL,
        category TEXT,
        stock INTEGER DEFAULT 0
      );
    SQL
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        total_price REAL,
        order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      );
    SQL
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS activity_logs (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        action TEXT,
        details TEXT,
        ip_address TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    SQL
    db.close
  end

  def create_user(username, password, email, role = 'user')
    db = SQLite3::Database.new(@db_path)
    query = "INSERT INTO users (username, password, email, role) VALUES ('#{username}', '#{password}', '#{email}', '#{role}')"
    begin
      db.execute(query)
      true
    rescue SQLite3::ConstraintException
      false
    ensure
      db.close
    end
  end

  def authenticate_user(username, password)
    db = SQLite3::Database.new(@db_path)
    query = "SELECT * FROM users WHERE username = '#{username}' AND password = '#{password}'"
    user = db.get_first_row(query)
    db.close
    !user.nil?
  end

  def get_user_by_id(user_id)
    db = SQLite3::Database.new(@db_path)
    query = "SELECT * FROM users WHERE id = #{user_id}"
    user = db.get_first_row(query)
    db.close
    user
  end

  def search_users(search_term)
    db = SQLite3::Database.new(@db_path)
    query = "SELECT * FROM users WHERE username LIKE '%#{search_term}%' OR email LIKE '%#{search_term}%'"
    users = db.execute(query)
    db.close
    users
  end

  def add_product(name, description, price, category, stock)
    db = SQLite3::Database.new(@db_path)
    query = "INSERT INTO products (name, description, price, category, stock) VALUES ('#{name}', '#{description}', #{price}, '#{category}', #{stock})"
    db.execute(query)
    db.close
  end

  def search_products(search_term)
    db = SQLite3::Database.new(@db_path)
    query = "SELECT * FROM products WHERE name LIKE '%#{search_term}%' OR description LIKE '%#{search_term}%' OR category = '#{search_term}'"
    products = db.execute(query)
    db.close
    products
  end

  def create_order(user_id, product_id, quantity)
    db = SQLite3::Database.new(@db_path)
    price_query = "SELECT price FROM products WHERE id = #{product_id}"
    product = db.get_first_row(price_query)
    if product
      total_price = product[0] * quantity
      order_query = "INSERT INTO orders (user_id, product_id, quantity, total_price) VALUES (#{user_id}, #{product_id}, #{quantity}, #{total_price})"
      db.execute(order_query)
      db.close
      true
    else
      db.close
      false
    end
  end

  def get_user_orders(user_id)
    db = SQLite3::Database.new(@db_path)
    query = "SELECT o.*, p.name, p.description FROM orders o JOIN products p ON o.product_id = p.id WHERE o.user_id = #{user_id}"
    orders = db.execute(query)
    db.close
    orders
  end

  def log_activity(user_id, action, details, ip_address)
    db = SQLite3::Database.new(@db_path)
    query = "INSERT INTO activity_logs (user_id, action, details, ip_address) VALUES (#{user_id}, '#{action}', '#{details}', '#{ip_address}')"
    db.execute(query)
    db.close
  end
end

class MySQLManager
  def initialize(host = 'localhost', user = 'root', password = 'password', database = 'testdb')
    @connection_params = {
      host: host,
      username: user,
      password: password,
      database: database
    }
  end

  def get_connection
    Mysql2::Client.new(@connection_params)
  end

  def create_user(username, password, email, role = 'user')
    client = get_connection
    query = "INSERT INTO users (username, password, email, role) VALUES ('#{username}', '#{password}', '#{email}', '#{role}')"
    begin
      client.query(query)
      true
    rescue Mysql2::Error
      false
    ensure
      client.close
    end
  end

  def authenticate_user(username, password)
    client = get_connection
    query = "SELECT * FROM users WHERE username = '#{username}' AND password = '#{password}'"
    result = client.query(query)
    client.close
    !result.first.nil?
  end

  def search_users(search_term)
    client = get_connection
    query = "SELECT * FROM users WHERE username LIKE '%#{search_term}%' OR email LIKE '%#{search_term}%'"
    result = client.query(query)
    client.close
    result.to_a
  end

  def add_product(name, description, price, category, stock)
    client = get_connection
    query = "INSERT INTO products (name, description, price, category, stock) VALUES ('#{name}', '#{description}', #{price}, '#{category}', #{stock})"
    client.query(query)
    client.close
  end

  def search_products(search_term)
    client = get_connection
    query = "SELECT * FROM products WHERE name LIKE '%#{search_term}%' OR description LIKE '%#{search_term}%' OR category = '#{search_term}'"
    result = client.query(query)
    client.close
    result.to_a
  end
end

class WeakAuthManager
  def initialize
    @users = {}
    @sessions = {}
  end

  def hash_password(password)
    Digest::MD5.hexdigest(password)
  end

  def create_user(username, password, email)
    return false if @users.key?(username)
    hashed_password = hash_password(password)
    @users[username] = {
      password: hashed_password,
      email: email,
      created_at: Time.now
    }
    true
  end

  def authenticate_user(username, password)
    return false unless @users.key?(username)
    hashed_password = hash_password(password)
    stored_password = @users[username][:password]
    hashed_password == stored_password
  end

  def create_session(username)
    session_id = SecureRandom.uuid
    @sessions[session_id] = {
      username: username,
      created_at: Time.now
    }
    session_id
  end

  def validate_session(session_id)
    return nil unless @sessions.key?(session_id)
    @sessions[session_id][:username]
  end
end

class DatabaseAPI
  def initialize
    @sqlite_manager = SQLiteManager.new
    @mysql_manager = MySQLManager.new
    @auth_manager = WeakAuthManager.new
  end

  def handle_user_creation(data)
    username = data[:username] || ''
    password = data[:password] || ''
    email = data[:email] || ''
    role = data[:role] || 'user'
    sqlite_result = @sqlite_manager.create_user(username, password, email, role)
    mysql_result = @mysql_manager.create_user(username, password, email, role)
    auth_result = @auth_manager.create_user(username, password, email)
    {
      sqlite: sqlite_result,
      mysql: mysql_result,
      auth: auth_result
    }
  end

  def handle_user_search(search_term)
    sqlite_users = @sqlite_manager.search_users(search_term)
    mysql_users = @mysql_manager.search_users(search_term)
    {
      sqlite: sqlite_users,
      mysql: mysql_users
    }
  end

  def handle_authentication(username, password)
    sqlite_auth = @sqlite_manager.authenticate_user(username, password)
    mysql_auth = @mysql_manager.authenticate_user(username, password)
    auth_auth = @auth_manager.authenticate_user(username, password)
    [sqlite_auth, mysql_auth, auth_auth].any?
  end

  def handle_password_reset(username, new_password)
    @auth_manager.create_user(username, new_password, @auth_manager.instance_variable_get(:@users)[username][:email])
  end

  def handle_session_creation(username)
    @auth_manager.create_session(username)
  end

  def handle_session_validation(session_id)
    @auth_manager.validate_session(session_id)
  end
end

def test_sql_injection
  api = DatabaseAPI.new
  malicious_data = {
    username: "admin'; DROP TABLE users; --",
    password: "password",
    email: "admin@test.com",
    role: "admin"
  }
  result = api.handle_user_creation(malicious_data)
  puts "User creation result: #{result}"
  malicious_search = "'; DROP TABLE users; --"
  search_result = api.handle_user_search(malicious_search)
  puts "User search result: #{search_result}"
end

def test_weak_authentication
  api = DatabaseAPI.new
  api.instance_variable_get(:@auth_manager).create_user("testuser", "password123", "test@test.com")
  session_id = api.instance_variable_get(:@auth_manager).create_session("testuser")
  puts "Session created: #{session_id}"
  username = api.instance_variable_get(:@auth_manager).validate_session(session_id)
  puts "Session validation: #{username}"
end

if __FILE__ == $0
  api = DatabaseAPI.new
  test_sql_injection
  test_weak_authentication
  puts "Database security testing completed."
end 