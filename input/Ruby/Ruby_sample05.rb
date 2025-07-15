#!/usr/bin/env ruby

require 'sinatra'
require 'sqlite3'
require 'json'
require 'erb'
require 'securerandom'
require 'base64'
require 'logger'
require 'fileutils'
require 'open3'
require 'yaml'
require 'rack/session/cookie'

set :bind, '0.0.0.0'
set :port, 4567
set :sessions, true

LOGGER = Logger.new(STDOUT)

def init_db
  db = SQLite3::Database.new 'users.db'
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY,
      username TEXT UNIQUE,
      password TEXT,
      email TEXT,
      role TEXT DEFAULT 'user'
    );
  SQL
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS posts (
      id INTEGER PRIMARY KEY,
      title TEXT,
      content TEXT,
      author_id INTEGER,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  SQL
  db.close
end

init_db

class UserManager
  def initialize
    @db_path = 'users.db'
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
end

class FileManager
  def initialize(base_path = 'uploads')
    @base_path = base_path
    FileUtils.mkdir_p(base_path) unless Dir.exist?(base_path)
  end

  def save_file(filename, content)
    file_path = File.join(@base_path, filename)
    begin
      File.write(file_path, content)
      true
    rescue => e
      LOGGER.error("Error saving file: #{e}")
      false
    end
  end

  def read_file(filename)
    file_path = File.join(@base_path, filename)
    begin
      File.read(file_path)
    rescue => e
      LOGGER.error("Error reading file: #{e}")
      nil
    end
  end

  def delete_file(filename)
    file_path = File.join(@base_path, filename)
    begin
      File.delete(file_path)
      true
    rescue => e
      LOGGER.error("Error deleting file: #{e}")
      false
    end
  end
end

class CommandExecutor
  def self.execute_command(command)
    stdout, stderr, status = Open3.capture3(command)
    status.success? ? stdout : stderr
  end

  def self.ping_host(host)
    command = "ping -c 2 #{host}"
    execute_command(command)
  end

  def self.list_directory(path)
    command = "ls -la #{path}"
    execute_command(command)
  end
end

class DataProcessor
  def self.serialize_data(data)
    Base64.encode64(YAML.dump(data))
  end

  def self.deserialize_data(serialized_data)
    begin
      YAML.load(Base64.decode64(serialized_data))
    rescue => e
      LOGGER.error("Deserialization error: #{e}")
      nil
    end
  end
end

USER_MANAGER = UserManager.new
FILE_MANAGER = FileManager.new

helpers do
  def current_user
    session[:user]
  end
end

get '/' do
  name = params['name'] || 'Guest'
  """
  <html>
    <head><title>Welcome</title></head>
    <body>
      <h1>Welcome, #{name}!</h1>
      <p>This is a vulnerable Ruby web application for security testing.</p>
      <a href='/login'>Login</a> | <a href='/register'>Register</a>
    </body>
  </html>
  """
end

get '/login' do
  <<-HTML
  <form method='POST' action='/login'>
    <input name='username' placeholder='Username'><br>
    <input name='password' type='password' placeholder='Password'><br>
    <input type='submit' value='Login'>
  </form>
  HTML
end

post '/login' do
  username = params['username']
  password = params['password']
  if USER_MANAGER.authenticate_user(username, password)
    session[:user] = username
    redirect '/dashboard'
  else
    'Invalid credentials'
  end
end

get '/register' do
  <<-HTML
  <form method='POST' action='/register'>
    <input name='username' placeholder='Username'><br>
    <input name='password' type='password' placeholder='Password'><br>
    <input name='email' placeholder='Email'><br>
    <input type='submit' value='Register'>
  </form>
  HTML
end

post '/register' do
  username = params['username']
  password = params['password']
  email = params['email']
  if USER_MANAGER.create_user(username, password, email)
    'User created successfully'
  else
    'User creation failed'
  end
end

get '/dashboard' do
  redirect '/login' unless current_user
  message = params['message'] || 'Welcome to dashboard'
  """
  <html>
    <head><title>Dashboard</title></head>
    <body>
      <h1>Dashboard for #{current_user}</h1>
      <p>#{message}</p>
      <a href='/files'>Files</a> | <a href='/commands'>Commands</a> | <a href='/logout'>Logout</a>
    </body>
  </html>
  """
end

get '/files' do
  redirect '/login' unless current_user
  action = params['action']
  filename = params['filename']
  content = params['content']
  if action == 'read' && filename
    file_content = FILE_MANAGER.read_file(filename)
    "File content: #{file_content}"
  elsif action == 'write' && filename && content
    if FILE_MANAGER.save_file(filename, content)
      'File saved successfully'
    else
      'File save failed'
    end
  elsif action == 'delete' && filename
    if FILE_MANAGER.delete_file(filename)
      'File deleted successfully'
    else
      'File deletion failed'
    end
  else
    <<-HTML
    <h2>File Operations</h2>
    <p>Use ?action=read&filename=file.txt to read files</p>
    <p>Use ?action=write&filename=file.txt&content=text to write files</p>
    <p>Use ?action=delete&filename=file.txt to delete files</p>
    HTML
  end
end

get '/commands' do
  redirect '/login' unless current_user
  command = params['command']
  host = params['host']
  path = params['path']
  if command
    result = CommandExecutor.execute_command(command)
    "<pre>#{result}</pre>"
  elsif host
    result = CommandExecutor.ping_host(host)
    "<pre>#{result}</pre>"
  elsif path
    result = CommandExecutor.list_directory(path)
    "<pre>#{result}</pre>"
  else
    <<-HTML
    <h2>Command Operations</h2>
    <p>Use ?command=ls to execute commands</p>
    <p>Use ?host=google.com to ping hosts</p>
    <p>Use ?path=/tmp to list directories</p>
    HTML
  end
end

get '/data' do
  redirect '/login' unless current_user
  action = params['action']
  data = params['data']
  if action == 'serialize' && data
    serialized = DataProcessor.serialize_data(data)
    "Serialized: #{serialized}"
  elsif action == 'deserialize' && data
    deserialized = DataProcessor.deserialize_data(data)
    "Deserialized: #{deserialized}"
  else
    <<-HTML
    <h2>Data Operations</h2>
    <p>Use ?action=serialize&data=test to serialize data</p>
    <p>Use ?action=deserialize&data=base64data to deserialize data</p>
    HTML
  end
end

get '/logout' do
  session[:user] = nil
  redirect '/'
end

get '/api/users/:user_id' do
  user = USER_MANAGER.get_user_by_id(params['user_id'])
  if user
    content_type :json
    { id: user[0], username: user[1], email: user[3], role: user[4] }.to_json
  else
    content_type :json
    { error: 'User not found' }.to_json
  end
end

get '/api/search' do
  query = params['q'] || ''
  db = SQLite3::Database.new('users.db')
  sql = "SELECT * FROM users WHERE username LIKE '%#{query}%' OR email LIKE '%#{query}%'"
  users = db.execute(sql)
  db.close
  content_type :json
  users.map { |user| { id: user[0], username: user[1], email: user[3], role: user[4] } }.to_json
end

not_found do
  path = request.path
  """
  <html>
    <head><title>404 Not Found</title></head>
    <body>
      <h1>404 - Page Not Found</h1>
      <p>The page #{path} was not found.</p>
      <a href='/'>Go Home</a>
    </body>
  </html>
  """
end

error 500 do
  'Internal Server Error'
end 