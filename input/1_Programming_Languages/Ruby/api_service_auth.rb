#!/usr/bin/env ruby

=begin
AI-Generated Code Header
Intent: Demonstrate Ruby API service with JWT authentication and modern patterns
Optimization: Efficient request handling, connection pooling, and caching strategies
Safety: Secure authentication, input validation, and comprehensive error handling
=end

require 'sinatra/base'
require 'sinatra/json'
require 'rack/cors'
require 'jwt'
require 'bcrypt'
require 'redis'
require 'json'
require 'logger'
require 'digest'
require 'securerandom'
require 'time'

# AI-SUGGESTION: Authentication and JWT service
class AuthenticationService
  include BCrypt
  
  SECRET_KEY = ENV['JWT_SECRET_KEY'] || 'your-super-secret-key-change-in-production'
  ALGORITHM = 'HS256'
  TOKEN_EXPIRY = 24 * 60 * 60 # 24 hours
  REFRESH_TOKEN_EXPIRY = 7 * 24 * 60 * 60 # 7 days
  
  def self.generate_token_pair(user_id, permissions = [])
    current_time = Time.now.to_i
    
    # Access token payload
    access_payload = {
      user_id: user_id,
      permissions: permissions,
      type: 'access',
      iat: current_time,
      exp: current_time + TOKEN_EXPIRY
    }
    
    # Refresh token payload
    refresh_payload = {
      user_id: user_id,
      type: 'refresh',
      iat: current_time,
      exp: current_time + REFRESH_TOKEN_EXPIRY,
      jti: SecureRandom.uuid # Unique identifier for refresh token
    }
    
    access_token = JWT.encode(access_payload, SECRET_KEY, ALGORITHM)
    refresh_token = JWT.encode(refresh_payload, SECRET_KEY, ALGORITHM)
    
    {
      access_token: access_token,
      refresh_token: refresh_token,
      expires_in: TOKEN_EXPIRY,
      token_type: 'Bearer'
    }
  end
  
  def self.decode_token(token)
    JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })
  rescue JWT::ExpiredSignature
    { error: 'Token expired' }
  rescue JWT::InvalidSignature
    { error: 'Invalid token signature' }
  rescue JWT::DecodeError => e
    { error: "Token decode error: #{e.message}" }
  end
  
  def self.verify_access_token(token)
    decoded = decode_token(token)
    return decoded if decoded.is_a?(Hash) && decoded[:error]
    
    payload = decoded[0]
    return { error: 'Invalid token type' } unless payload['type'] == 'access'
    
    { valid: true, payload: payload }
  end
  
  def self.hash_password(password)
    Password.create(password)
  end
  
  def self.verify_password(password, hash)
    Password.new(hash) == password
  end
end

# AI-SUGGESTION: User model and data store
class User
  attr_accessor :id, :username, :email, :password_hash, :permissions, :created_at, :active
  
  def initialize(attributes = {})
    @id = attributes[:id] || SecureRandom.uuid
    @username = attributes[:username]
    @email = attributes[:email]
    @password_hash = attributes[:password_hash]
    @permissions = attributes[:permissions] || []
    @created_at = attributes[:created_at] || Time.now
    @active = attributes.fetch(:active, true)
  end
  
  def to_h
    {
      id: @id,
      username: @username,
      email: @email,
      permissions: @permissions,
      created_at: @created_at.iso8601,
      active: @active
    }
  end
  
  def self.create(attributes)
    password = attributes.delete(:password)
    user = new(attributes)
    user.password_hash = AuthenticationService.hash_password(password) if password
    UserStore.save(user)
    user
  end
  
  def self.find_by_username(username)
    UserStore.find_by_username(username)
  end
  
  def self.find_by_id(id)
    UserStore.find_by_id(id)
  end
  
  def authenticate(password)
    AuthenticationService.verify_password(password, @password_hash)
  end
  
  def has_permission?(permission)
    @permissions.include?(permission) || @permissions.include?('admin')
  end
end

# AI-SUGGESTION: Simple in-memory user store with Redis backing
class UserStore
  @users = {}
  @redis = nil
  
  begin
    @redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
    @redis.ping
  rescue Redis::CannotConnectError
    puts "Warning: Redis not available, using in-memory storage only"
  end
  
  def self.save(user)
    @users[user.id] = user
    
    if @redis
      @redis.hset('users', user.id, user.to_h.to_json)
      @redis.hset('users_by_username', user.username, user.id)
    end
    
    user
  end
  
  def self.find_by_id(id)
    # Try memory first
    return @users[id] if @users[id]
    
    # Try Redis
    if @redis
      user_data = @redis.hget('users', id)
      if user_data
        attributes = JSON.parse(user_data, symbolize_names: true)
        attributes[:created_at] = Time.parse(attributes[:created_at])
        user = User.new(attributes)
        @users[id] = user
        return user
      end
    end
    
    nil
  end
  
  def self.find_by_username(username)
    # Try memory first
    user = @users.values.find { |u| u.username == username }
    return user if user
    
    # Try Redis
    if @redis
      user_id = @redis.hget('users_by_username', username)
      return find_by_id(user_id) if user_id
    end
    
    nil
  end
  
  def self.all
    @users.values
  end
end

# AI-SUGGESTION: Rate limiting service
class RateLimitService
  def initialize(redis = nil)
    @redis = redis
    @in_memory_store = {}
  end
  
  def check_rate_limit(identifier, limit = 100, window = 3600)
    current_time = Time.now.to_i
    window_start = current_time - window
    
    if @redis
      check_redis_rate_limit(identifier, limit, window, current_time, window_start)
    else
      check_memory_rate_limit(identifier, limit, window, current_time, window_start)
    end
  end
  
  private
  
  def check_redis_rate_limit(identifier, limit, window, current_time, window_start)
    key = "rate_limit:#{identifier}"
    
    # Remove old entries
    @redis.zremrangebyscore(key, 0, window_start)
    
    # Count current requests
    current_count = @redis.zcard(key)
    
    if current_count >= limit
      { allowed: false, remaining: 0, reset_time: window_start + window }
    else
      # Add current request
      @redis.zadd(key, current_time, "#{current_time}:#{SecureRandom.uuid}")
      @redis.expire(key, window)
      
      { allowed: true, remaining: limit - current_count - 1, reset_time: window_start + window }
    end
  end
  
  def check_memory_rate_limit(identifier, limit, window, current_time, window_start)
    @in_memory_store[identifier] ||= []
    
    # Remove old entries
    @in_memory_store[identifier].reject! { |timestamp| timestamp < window_start }
    
    current_count = @in_memory_store[identifier].size
    
    if current_count >= limit
      { allowed: false, remaining: 0, reset_time: window_start + window }
    else
      @in_memory_store[identifier] << current_time
      { allowed: true, remaining: limit - current_count - 1, reset_time: window_start + window }
    end
  end
end

# AI-SUGGESTION: API response helper
module ApiResponse
  def success_response(data = {}, status = 200)
    content_type :json
    status status
    {
      success: true,
      data: data,
      timestamp: Time.now.iso8601
    }.to_json
  end
  
  def error_response(message, status = 400, details = {})
    content_type :json
    status status
    {
      success: false,
      error: {
        message: message,
        details: details
      },
      timestamp: Time.now.iso8601
    }.to_json
  end
  
  def paginated_response(items, page, per_page, total_count)
    total_pages = (total_count.to_f / per_page).ceil
    
    success_response({
      items: items,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_items: total_count,
        total_pages: total_pages,
        has_next: page < total_pages,
        has_prev: page > 1
      }
    })
  end
end

# AI-SUGGESTION: Input validation module
module InputValidator
  def validate_required_fields(data, required_fields)
    missing_fields = required_fields.select { |field| data[field].nil? || data[field].to_s.strip.empty? }
    
    unless missing_fields.empty?
      halt 422, error_response(
        "Missing required fields: #{missing_fields.join(', ')}", 
        422,
        { missing_fields: missing_fields }
      )
    end
  end
  
  def validate_email(email)
    email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    unless email.match?(email_regex)
      halt 422, error_response("Invalid email format", 422)
    end
  end
  
  def validate_password_strength(password)
    errors = []
    
    errors << "Password must be at least 8 characters long" if password.length < 8
    errors << "Password must contain at least one uppercase letter" unless password.match?(/[A-Z]/)
    errors << "Password must contain at least one lowercase letter" unless password.match?(/[a-z]/)
    errors << "Password must contain at least one digit" unless password.match?(/\d/)
    
    unless errors.empty?
      halt 422, error_response("Password validation failed", 422, { validation_errors: errors })
    end
  end
  
  def sanitize_input(input)
    return nil if input.nil?
    input.to_s.strip
  end
end

# AI-SUGGESTION: Main API service class
class ApiService < Sinatra::Base
  include ApiResponse
  include InputValidator
  
  configure do
    set :environment, ENV['RACK_ENV'] || 'development'
    set :show_exceptions, false
    set :raise_errors, false
    
    # CORS configuration
    use Rack::Cors do
      allow do
        origins '*'
        resource '*', 
          headers: :any, 
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: true
      end
    end
    
    # Initialize services
    @@rate_limiter = RateLimitService.new
    @@logger = Logger.new(STDOUT)
    @@logger.level = development? ? Logger::DEBUG : Logger::INFO
  end
  
  # AI-SUGGESTION: Middleware and helpers
  before do
    content_type :json
    
    # Rate limiting
    rate_limit_result = @@rate_limiter.check_rate_limit(request.ip, 100, 3600)
    
    unless rate_limit_result[:allowed]
      response.headers['X-RateLimit-Remaining'] = '0'
      response.headers['X-RateLimit-Reset'] = rate_limit_result[:reset_time].to_s
      halt 429, error_response("Rate limit exceeded", 429)
    end
    
    response.headers['X-RateLimit-Remaining'] = rate_limit_result[:remaining].to_s
    response.headers['X-RateLimit-Reset'] = rate_limit_result[:reset_time].to_s
    
    # Logging
    @@logger.info("#{request.request_method} #{request.path_info} - IP: #{request.ip}")
  end
  
  helpers do
    def current_user
      @current_user ||= begin
        auth_header = request.env['HTTP_AUTHORIZATION']
        return nil unless auth_header
        
        token = auth_header.split(' ').last
        verification = AuthenticationService.verify_access_token(token)
        
        if verification[:valid]
          User.find_by_id(verification[:payload]['user_id'])
        else
          nil
        end
      end
    end
    
    def require_authentication!
      halt 401, error_response("Authentication required", 401) unless current_user
    end
    
    def require_permission!(permission)
      require_authentication!
      
      unless current_user.has_permission?(permission)
        halt 403, error_response("Insufficient permissions", 403)
      end
    end
    
    def parse_json_body
      return {} if request.body.nil?
      
      request.body.rewind
      body = request.body.read
      return {} if body.empty?
      
      JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError
      halt 400, error_response("Invalid JSON format", 400)
    end
  end
  
  # AI-SUGGESTION: Error handlers
  error 400 do
    error_response("Bad Request", 400)
  end
  
  error 401 do
    error_response("Unauthorized", 401)
  end
  
  error 403 do
    error_response("Forbidden", 403)
  end
  
  error 404 do
    error_response("Not Found", 404)
  end
  
  error 422 do
    error_response("Unprocessable Entity", 422)
  end
  
  error 500 do
    @@logger.error("Internal server error: #{env['sinatra.error']}")
    error_response("Internal Server Error", 500)
  end
  
  # AI-SUGGESTION: Health check endpoints
  get '/health' do
    success_response({
      status: 'healthy',
      version: '1.0.0',
      environment: settings.environment
    })
  end
  
  get '/health/detailed' do
    redis_status = begin
      Redis.new.ping
      'healthy'
    rescue
      'unavailable'
    end
    
    success_response({
      status: 'healthy',
      version: '1.0.0',
      environment: settings.environment,
      services: {
        redis: redis_status,
        users_count: UserStore.all.size
      }
    })
  end
  
  # AI-SUGGESTION: Authentication endpoints
  post '/auth/register' do
    data = parse_json_body
    
    validate_required_fields(data, [:username, :email, :password])
    
    username = sanitize_input(data[:username])
    email = sanitize_input(data[:email]).downcase
    password = data[:password]
    
    validate_email(email)
    validate_password_strength(password)
    
    # Check if user already exists
    if User.find_by_username(username)
      halt 409, error_response("Username already exists", 409)
    end
    
    if User.find_by_email(email)
      halt 409, error_response("Email already exists", 409)
    end
    
    # Create user
    user = User.create(
      username: username,
      email: email,
      password: password,
      permissions: ['user'] # Default permission
    )
    
    # Generate tokens
    tokens = AuthenticationService.generate_token_pair(user.id, user.permissions)
    
    @@logger.info("User registered: #{username}")
    
    success_response({
      user: user.to_h,
      **tokens
    }, 201)
  end
  
  post '/auth/login' do
    data = parse_json_body
    
    validate_required_fields(data, [:username, :password])
    
    username = sanitize_input(data[:username])
    password = data[:password]
    
    user = User.find_by_username(username)
    
    unless user && user.authenticate(password)
      halt 401, error_response("Invalid credentials", 401)
    end
    
    unless user.active
      halt 401, error_response("Account is disabled", 401)
    end
    
    # Generate tokens
    tokens = AuthenticationService.generate_token_pair(user.id, user.permissions)
    
    @@logger.info("User logged in: #{username}")
    
    success_response({
      user: user.to_h,
      **tokens
    })
  end
  
  post '/auth/refresh' do
    data = parse_json_body
    
    validate_required_fields(data, [:refresh_token])
    
    verification = AuthenticationService.decode_token(data[:refresh_token])
    
    if verification.is_a?(Hash) && verification[:error]
      halt 401, error_response("Invalid refresh token", 401)
    end
    
    payload = verification[0]
    
    unless payload['type'] == 'refresh'
      halt 401, error_response("Invalid token type", 401)
    end
    
    user = User.find_by_id(payload['user_id'])
    
    unless user
      halt 401, error_response("User not found", 401)
    end
    
    # Generate new tokens
    tokens = AuthenticationService.generate_token_pair(user.id, user.permissions)
    
    success_response(tokens)
  end
  
  get '/auth/me' do
    require_authentication!
    
    success_response({ user: current_user.to_h })
  end
  
  # AI-SUGGESTION: User management endpoints
  get '/users' do
    require_permission!('admin')
    
    page = [params['page'].to_i, 1].max
    per_page = [[params['per_page'].to_i, 10].max, 100].min
    
    all_users = UserStore.all
    total_count = all_users.size
    
    start_index = (page - 1) * per_page
    end_index = start_index + per_page - 1
    
    users = all_users[start_index..end_index] || []
    user_data = users.map(&:to_h)
    
    paginated_response(user_data, page, per_page, total_count)
  end
  
  get '/users/:id' do
    require_authentication!
    
    user = User.find_by_id(params[:id])
    
    unless user
      halt 404, error_response("User not found", 404)
    end
    
    # Users can only see their own profile unless they're admin
    unless current_user.id == user.id || current_user.has_permission?('admin')
      halt 403, error_response("Access denied", 403)
    end
    
    success_response({ user: user.to_h })
  end
  
  put '/users/:id' do
    require_authentication!
    
    user = User.find_by_id(params[:id])
    
    unless user
      halt 404, error_response("User not found", 404)
    end
    
    # Users can only update their own profile unless they're admin
    unless current_user.id == user.id || current_user.has_permission?('admin')
      halt 403, error_response("Access denied", 403)
    end
    
    data = parse_json_body
    
    # Update allowed fields
    user.email = sanitize_input(data[:email]).downcase if data[:email]
    
    # Only admins can update permissions and active status
    if current_user.has_permission?('admin')
      user.permissions = data[:permissions] if data[:permissions]
      user.active = data[:active] if data.key?(:active)
    end
    
    # Validate email if updated
    validate_email(user.email) if data[:email]
    
    UserStore.save(user)
    
    success_response({ user: user.to_h })
  end
  
  # AI-SUGGESTION: API metrics endpoint
  get '/metrics' do
    require_permission!('admin')
    
    success_response({
      users: {
        total: UserStore.all.size,
        active: UserStore.all.count(&:active)
      },
      environment: settings.environment,
      uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC),
      timestamp: Time.now.iso8601
    })
  end
  
  # AI-SUGGESTION: API documentation endpoint
  get '/docs' do
    content_type :html
    
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>API Documentation</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .endpoint { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
          .method { font-weight: bold; color: #007cba; }
          .path { font-family: monospace; background: #f5f5f5; padding: 2px 4px; }
        </style>
      </head>
      <body>
        <h1>API Documentation</h1>
        
        <div class="endpoint">
          <div class="method">POST</div>
          <div class="path">/auth/register</div>
          <p>Register a new user account</p>
        </div>
        
        <div class="endpoint">
          <div class="method">POST</div>
          <div class="path">/auth/login</div>
          <p>Authenticate user and receive access tokens</p>
        </div>
        
        <div class="endpoint">
          <div class="method">POST</div>
          <div class="path">/auth/refresh</div>
          <p>Refresh access token using refresh token</p>
        </div>
        
        <div class="endpoint">
          <div class="method">GET</div>
          <div class="path">/auth/me</div>
          <p>Get current user information (requires authentication)</p>
        </div>
        
        <div class="endpoint">
          <div class="method">GET</div>
          <div class="path">/users</div>
          <p>List all users (admin only)</p>
        </div>
        
        <div class="endpoint">
          <div class="method">GET</div>
          <div class="path">/health</div>
          <p>Basic health check</p>
        </div>
      </body>
      </html>
    HTML
  end
end

# AI-SUGGESTION: Data seeding for demo
class DataSeeder
  def self.seed!
    return if UserStore.all.any?
    
    puts "Seeding demo data..."
    
    # Create admin user
    admin = User.create(
      username: 'admin',
      email: 'admin@example.com',
      password: 'AdminPass123',
      permissions: ['admin', 'user']
    )
    
    # Create regular user
    user = User.create(
      username: 'testuser',
      email: 'user@example.com',
      password: 'UserPass123',
      permissions: ['user']
    )
    
    puts "Created demo users:"
    puts "  Admin: admin / AdminPass123"
    puts "  User: testuser / UserPass123"
  end
end

# AI-SUGGESTION: Application runner
if __FILE__ == $0
  puts "=== Ruby API Service with Authentication Demo ==="
  puts "Initializing service..."
  
  # Seed demo data
  DataSeeder.seed!
  
  puts "\nStarting API server..."
  puts "API Endpoints:"
  puts "  Health: GET http://localhost:4567/health"
  puts "  Docs: GET http://localhost:4567/docs"
  puts "  Register: POST http://localhost:4567/auth/register"
  puts "  Login: POST http://localhost:4567/auth/login"
  puts ""
  puts "Demo accounts available (see above)"
  
  ApiService.run! host: '0.0.0.0', port: 4567
end 