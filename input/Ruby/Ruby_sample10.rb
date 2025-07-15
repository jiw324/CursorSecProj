#!/usr/bin/env ruby

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/flash'
require 'rack/csrf'
require 'sequel'
require 'bcrypt'
require 'jwt'
require 'redis'
require 'json'
require 'logger'
require 'digest'
require 'securerandom'

class AppLogger
  def self.instance
    @logger ||= Logger.new(STDOUT).tap do |log|
      log.level = Logger::INFO
      log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end
    end
  end
end

DB = Sequel.connect('sqlite://app.db')

DB.create_table? :users do
  primary_key :id
  String :username, unique: true, null: false
  String :email, unique: true, null: false
  String :password_hash, null: false
  String :full_name
  Boolean :active, default: true
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

DB.create_table? :posts do
  primary_key :id
  foreign_key :user_id, :users, null: false
  String :title, null: false
  Text :content
  String :slug, unique: true
  String :status, default: 'draft'
  Integer :view_count, default: 0
  DateTime :published_at
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

DB.create_table? :comments do
  primary_key :id
  foreign_key :post_id, :posts, null: false
  foreign_key :user_id, :users, null: false
  Text :content, null: false
  String :status, default: 'pending'
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
end

class User < Sequel::Model
  include BCrypt
  
  plugin :validation_helpers
  plugin :timestamps, update_on_create: true
  
  one_to_many :posts
  one_to_many :comments
  
  def validate
    super
    validates_presence [:username, :email, :password_hash]
    validates_unique [:username, :email]
    validates_format /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i, :email
    validates_min_length 3, :username
  end
  
  def password
    @password ||= Password.new(password_hash)
  end
  
  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end
  
  def authenticate(password)
    self.password == password
  end
  
  def full_display_name
    full_name.nil? || full_name.empty? ? username : full_name
  end
  
  def to_hash
    {
      id: id,
      username: username,
      email: email,
      full_name: full_name,
      active: active,
      created_at: created_at
    }
  end
end

class Post < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps, update_on_create: true
  
  many_to_one :user
  one_to_many :comments
  
  def validate
    super
    validates_presence [:title, :user_id]
    validates_min_length 3, :title
    validates_includes %w[draft published archived], :status
  end
  
  def before_create
    super
    self.slug = generate_slug unless slug
  end
  
  def before_update
    super
    self.updated_at = Time.now
  end
  
  def published?
    status == 'published' && published_at
  end
  
  def excerpt(length = 150)
    return '' unless content
    content.length > length ? "#{content[0...length]}..." : content
  end
  
  def reading_time
    return 0 unless content
    word_count = content.split.length
    (word_count / 200.0).ceil
  end
  
  def to_hash
    {
      id: id,
      title: title,
      content: content,
      slug: slug,
      status: status,
      view_count: view_count,
      reading_time: reading_time,
      published_at: published_at,
      created_at: created_at,
      updated_at: updated_at,
      author: user&.to_hash
    }
  end
  
  private
  
  def generate_slug
    base_slug = title.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '-')
    slug_candidate = base_slug
    counter = 1
    
    while Post.where(slug: slug_candidate).first
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end
    
    slug_candidate
  end
end

class Comment < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps, update_on_create: true
  
  many_to_one :post
  many_to_one :user
  
  def validate
    super
    validates_presence [:content, :post_id, :user_id]
    validates_min_length 10, :content
    validates_includes %w[pending approved spam rejected], :status
  end
  
  def approved?
    status == 'approved'
  end
  
  def to_hash
    {
      id: id,
      content: content,
      status: status,
      created_at: created_at,
      author: user&.to_hash
    }
  end
end

class AuthService
  SECRET_KEY = ENV['JWT_SECRET'] || 'your-secret-key-change-in-production'
  
  def self.generate_token(user_id)
    payload = {
      user_id: user_id,
      exp: Time.now.to_i + (24 * 60 * 60)
    }
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end
  
  def self.decode_token(token)
    JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
  rescue JWT::DecodeError => e
    AppLogger.instance.error("JWT decode error: #{e.message}")
    nil
  end
  
  def self.current_user(request)
    auth_header = request.env['HTTP_AUTHORIZATION']
    return nil unless auth_header
    
    token = auth_header.split(' ').last
    payload = decode_token(token)
    return nil unless payload
    
    User[payload[0]['user_id']]
  rescue => e
    AppLogger.instance.error("Auth error: #{e.message}")
    nil
  end
end

class CacheService
  def initialize
    @redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
  rescue Redis::CannotConnectError => e
    AppLogger.instance.warn("Redis connection failed: #{e.message}")
    @redis = nil
  end
  
  def get(key)
    return nil unless @redis
    
    value = @redis.get(key)
    JSON.parse(value) if value
  rescue => e
    AppLogger.instance.error("Cache get error: #{e.message}")
    nil
  end
  
  def set(key, value, expires_in = 300)
    return false unless @redis
    
    @redis.setex(key, expires_in, value.to_json)
    true
  rescue => e
    AppLogger.instance.error("Cache set error: #{e.message}")
    false
  end
  
  def delete(key)
    return false unless @redis
    
    @redis.del(key) > 0
  rescue => e
    AppLogger.instance.error("Cache delete error: #{e.message}")
    false
  end
  
  def clear
    return false unless @redis
    
    @redis.flushdb
    true
  rescue => e
    AppLogger.instance.error("Cache clear error: #{e.message}")
    false
  end
end

class RateLimiter
  def initialize(cache_service, max_requests = 100, window = 3600)
    @cache = cache_service
    @max_requests = max_requests
    @window = window
  end
  
  def exceeded?(identifier)
    key = "rate_limit:#{identifier}"
    requests = @cache.get(key) || []
    current_time = Time.now.to_i
    
    requests = requests.select { |timestamp| current_time - timestamp < @window }
    
    if requests.length >= @max_requests
      true
    else
      requests << current_time
      @cache.set(key, requests, @window)
      false
    end
  end
end

class InputSanitizer
  def self.sanitize_html(input)
    return '' unless input
    
    input.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi, '')
         .gsub(/on\w+\s*=\s*"[^"]*"/i, '')
         .gsub(/javascript:/i, '')
         .strip
  end
  
  def self.sanitize_sql(input)
    return '' unless input
    
    input.gsub(/['";\\]/, '')
         .gsub(/(--)|(\/\*)/, '')
         .strip
  end
  
  def self.validate_email(email)
    email&.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end
  
  def self.validate_password(password)
    return false unless password&.length&.>= 8
    
    password.match?(/[A-Z]/) &&
    password.match?(/[a-z]/) &&
    password.match?(/\d/)
  end
end

class WebApplication < Sinatra::Base
  configure do
    enable :sessions
    set :session_secret, ENV['SESSION_SECRET'] || SecureRandom.hex(32)
    set :show_exceptions, development?
    set :dump_errors, development?
    
    use Rack::Csrf, raise: true unless test?
    
    @@cache = CacheService.new
    @@rate_limiter = RateLimiter.new(@@cache)
  end
  
  helpers do
    def current_user
      @current_user ||= AuthService.current_user(request)
    end
    
    def authenticated?
      !current_user.nil?
    end
    
    def require_authentication!
      halt 401, json(error: 'Authentication required') unless authenticated?
    end
    
    def require_admin!
      require_authentication!
      halt 403, json(error: 'Admin access required') unless current_user.admin?
    end
    
    def json_response(data, status = 200)
      content_type :json
      status status
      data.to_json
    end
    
    def paginate(dataset, page = 1, per_page = 20)
      page = [page.to_i, 1].max
      per_page = [[per_page.to_i, 1].max, 100].min
      
      offset = (page - 1) * per_page
      total = dataset.count
      
      {
        data: dataset.limit(per_page, offset).all,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_items: total,
          total_pages: (total.to_f / per_page).ceil
        }
      }
    end
    
    def rate_limit_check!
      identifier = request.ip
      if @@rate_limiter.exceeded?(identifier)
        halt 429, json(error: 'Rate limit exceeded')
      end
    end
  end
  
  before do
    rate_limit_check! unless request.path_info.start_with?('/health')
    content_type :json
    
    AppLogger.instance.info(
      "#{request.request_method} #{request.path_info} - " \
      "IP: #{request.ip} - User: #{current_user&.username || 'anonymous'}"
    )
  end
  
  error 400 do
    json_response({ error: 'Bad Request' }, 400)
  end
  
  error 401 do
    json_response({ error: 'Unauthorized' }, 401)
  end
  
  error 403 do
    json_response({ error: 'Forbidden' }, 403)
  end
  
  error 404 do
    json_response({ error: 'Not Found' }, 404)
  end
  
  error 422 do
    json_response({ error: 'Unprocessable Entity' }, 422)
  end
  
  error 429 do
    json_response({ error: 'Too Many Requests' }, 429)
  end
  
  error 500 do
    AppLogger.instance.error("Internal server error: #{env['sinatra.error']}")
    json_response({ error: 'Internal Server Error' }, 500)
  end
  
  get '/health' do
    json_response({
      status: 'healthy',
      timestamp: Time.now.iso8601,
      version: '1.0.0'
    })
  end
  
  get '/health/detailed' do
    db_status = begin
      DB.test_connection
      'healthy'
    rescue => e
      AppLogger.instance.error("Database health check failed: #{e.message}")
      'unhealthy'
    end
    
    cache_status = @@cache.get('health_check').nil? ? 'unknown' : 'healthy'
    
    json_response({
      status: 'healthy',
      timestamp: Time.now.iso8601,
      services: {
        database: db_status,
        cache: cache_status
      }
    })
  end
  
  post '/auth/register' do
    data = JSON.parse(request.body.read)
    
    unless InputSanitizer.validate_email(data['email'])
      halt 422, json_response({ error: 'Invalid email format' }, 422)
    end
    
    unless InputSanitizer.validate_password(data['password'])
      halt 422, json_response({ 
        error: 'Password must be at least 8 characters with uppercase, lowercase, and digit' 
      }, 422)
    end
    
    begin
      user = User.create(
        username: InputSanitizer.sanitize_sql(data['username']),
        email: data['email'].downcase.strip,
        password: data['password'],
        full_name: InputSanitizer.sanitize_html(data['full_name'])
      )
      
      token = AuthService.generate_token(user.id)
      
      json_response({
        user: user.to_hash,
        token: token
      }, 201)
      
    rescue Sequel::ValidationFailed => e
      halt 422, json_response({ error: e.message }, 422)
    rescue Sequel::UniqueConstraintViolation
      halt 422, json_response({ error: 'Username or email already exists' }, 422)
    end
  end
  
  post '/auth/login' do
    data = JSON.parse(request.body.read)
    
    user = User.where(username: data['username']).first
    
    if user&.authenticate(data['password'])
      token = AuthService.generate_token(user.id)
      
      json_response({
        user: user.to_hash,
        token: token
      })
    else
      halt 401, json_response({ error: 'Invalid credentials' }, 401)
    end
  end
  
  get '/auth/me' do
    require_authentication!
    json_response({ user: current_user.to_hash })
  end
  
  get '/posts' do
    page = params['page']&.to_i || 1
    per_page = params['per_page']&.to_i || 20
    status_filter = params['status'] || 'published'
    
    cache_key = "posts:#{page}:#{per_page}:#{status_filter}"
    cached_result = @@cache.get(cache_key)
    
    if cached_result
      return json_response(cached_result)
    end
    
    posts_dataset = Post.where(status: status_filter)
                       .order(Sequel.desc(:created_at))
                       .eager(:user)
    
    result = paginate(posts_dataset, page, per_page)
    result[:data] = result[:data].map(&:to_hash)
    
    @@cache.set(cache_key, result, 300)
    
    json_response(result)
  end
  
  get '/posts/:slug' do
    post = Post.where(slug: params['slug']).eager(:user, :comments).first
    halt 404, json_response({ error: 'Post not found' }, 404) unless post
    
    post.update(view_count: post.view_count + 1)
    
    comments = post.comments.select(&:approved?).map(&:to_hash)
    
    post_data = post.to_hash
    post_data[:comments] = comments
    
    json_response({ post: post_data })
  end
  
  post '/posts' do
    require_authentication!
    
    data = JSON.parse(request.body.read)
    
    begin
      post = Post.create(
        title: InputSanitizer.sanitize_html(data['title']),
        content: InputSanitizer.sanitize_html(data['content']),
        status: data['status'] || 'draft',
        user_id: current_user.id,
        published_at: data['status'] == 'published' ? Time.now : nil
      )
      
      @@cache.delete('posts:1:20:published')
      
      json_response({ post: post.to_hash }, 201)
      
    rescue Sequel::ValidationFailed => e
      halt 422, json_response({ error: e.message }, 422)
    end
  end
  
  put '/posts/:id' do
    require_authentication!
    
    post = Post[params['id']]
    halt 404, json_response({ error: 'Post not found' }, 404) unless post
    halt 403, json_response({ error: 'Access denied' }, 403) unless post.user_id == current_user.id
    
    data = JSON.parse(request.body.read)
    
    begin
      update_data = {}
      update_data[:title] = InputSanitizer.sanitize_html(data['title']) if data['title']
      update_data[:content] = InputSanitizer.sanitize_html(data['content']) if data['content']
      update_data[:status] = data['status'] if data['status']
      update_data[:published_at] = Time.now if data['status'] == 'published' && !post.published?
      
      post.update(update_data)
      
      @@cache.delete('posts:1:20:published')
      
      json_response({ post: post.to_hash })
      
    rescue Sequel::ValidationFailed => e
      halt 422, json_response({ error: e.message }, 422)
    end
  end
  
  delete '/posts/:id' do
    require_authentication!
    
    post = Post[params['id']]
    halt 404, json_response({ error: 'Post not found' }, 404) unless post
    halt 403, json_response({ error: 'Access denied' }, 403) unless post.user_id == current_user.id
    
    post.destroy
    
    @@cache.delete('posts:1:20:published')
    
    status 204
  end
  
  post '/posts/:post_id/comments' do
    require_authentication!
    
    post = Post[params['post_id']]
    halt 404, json_response({ error: 'Post not found' }, 404) unless post
    
    data = JSON.parse(request.body.read)
    
    begin
      comment = Comment.create(
        content: InputSanitizer.sanitize_html(data['content']),
        post_id: post.id,
        user_id: current_user.id,
        status: 'pending'
      )
      
      json_response({ comment: comment.to_hash }, 201)
      
    rescue Sequel::ValidationFailed => e
      halt 422, json_response({ error: e.message }, 422)
    end
  end
  
  get '/analytics/dashboard' do
    require_authentication!
    
    cache_key = "analytics:dashboard:#{current_user.id}"
    cached_result = @@cache.get(cache_key)
    
    if cached_result
      return json_response(cached_result)
    end
    
    user_posts = current_user.posts
    
    analytics = {
      total_posts: user_posts.count,
      published_posts: user_posts.where(status: 'published').count,
      draft_posts: user_posts.where(status: 'draft').count,
      total_views: user_posts.sum(:view_count) || 0,
      total_comments: Comment.where(post_id: user_posts.select(:id)).count,
      recent_activity: user_posts.order(Sequel.desc(:updated_at))
                                .limit(5)
                                .map(&:to_hash)
    }
    
    @@cache.set(cache_key, analytics, 600)
    
    json_response({ analytics: analytics })
  end
  
  get '/search' do
    query = params['q']&.strip
    halt 400, json_response({ error: 'Query parameter required' }, 400) if query.nil? || query.empty?
    
    posts = Post.where(status: 'published')
               .where(Sequel.ilike(:title, "%#{query}%") | Sequel.ilike(:content, "%#{query}%"))
               .order(Sequel.desc(:created_at))
               .limit(20)
               .eager(:user)
               .all
    
    results = posts.map do |post|
      post_hash = post.to_hash
      post_hash[:excerpt] = post.excerpt(200)
      post_hash
    end
    
    json_response({
      query: query,
      results: results,
      total: results.length
    })
  end
end

class EmailNotificationJob
  def self.perform(user_id, subject, message)
    user = User[user_id]
    return unless user
    
    AppLogger.instance.info("Sending email to #{user.email}: #{subject}")
    sleep(1)
    AppLogger.instance.info("Email sent successfully to #{user.email}")
  rescue => e
    AppLogger.instance.error("Failed to send email: #{e.message}")
  end
end

class DatabaseSeeder
  def self.seed!
    return if User.count > 0
    
    AppLogger.instance.info("Seeding database...")
    
    admin = User.create(
      username: 'admin',
      email: 'admin@example.com',
      password: 'Password123',
      full_name: 'Administrator'
    )
    
    author = User.create(
      username: 'author',
      email: 'author@example.com',
      password: 'Password123',
      full_name: 'Content Author'
    )
    
    5.times do |i|
      post = Post.create(
        title: "Sample Post #{i + 1}",
        content: "This is the content for sample post #{i + 1}. " * 20,
        status: 'published',
        user_id: [admin.id, author.id].sample,
        published_at: Time.now - rand(30).days
      )
      
      rand(3).times do |j|
        Comment.create(
          content: "This is a sample comment #{j + 1} for post #{i + 1}.",
          post_id: post.id,
          user_id: [admin.id, author.id].sample,
          status: 'approved'
        )
      end
    end
    
    AppLogger.instance.info("Database seeded successfully!")
  end
end

if __FILE__ == $0
  puts "=== Ruby Web Application Framework Demo ==="
  puts "Initializing application..."
  
  DatabaseSeeder.seed!
  
  puts "Starting web server..."
  puts "API Documentation:"
  puts "  Health Check: GET /health"
  puts "  Register: POST /auth/register"
  puts "  Login: POST /auth/login"
  puts "  Posts: GET /posts"
  puts "  Create Post: POST /posts"
  puts "  Search: GET /search?q=query"
  puts ""
  puts "Demo Credentials:"
  puts "  Username: admin, Password: Password123"
  puts "  Username: author, Password: Password123"
  
  WebApplication.run! host: '0.0.0.0', port: 4567
end 