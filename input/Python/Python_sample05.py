#!/usr/bin/env python3

import os
import sys
import json
import sqlite3
import subprocess
import urllib.parse
from flask import Flask, request, render_template_string, redirect, session
from werkzeug.security import generate_password_hash, check_password_hash
import hashlib
import base64
import pickle
import logging

app = Flask(__name__)
app.secret_key = 'super_secret_key_12345'

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def init_db():
    conn = sqlite3.connect('users.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE,
            password TEXT,
            email TEXT,
            role TEXT DEFAULT 'user'
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS posts (
            id INTEGER PRIMARY KEY,
            title TEXT,
            content TEXT,
            author_id INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

class UserManager:
    def __init__(self):
        self.db_path = 'users.db'
    
    def create_user(self, username, password, email, role='user'):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"INSERT INTO users (username, password, email, role) VALUES ('{username}', '{password}', '{email}', '{role}')"
        try:
            cursor.execute(query)
            conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False
        finally:
            conn.close()
    
    def authenticate_user(self, username, password):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
        cursor.execute(query)
        user = cursor.fetchone()
        conn.close()
        
        return user is not None
    
    def get_user_by_id(self, user_id):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"SELECT * FROM users WHERE id = {user_id}"
        cursor.execute(query)
        user = cursor.fetchone()
        conn.close()
        
        return user

class FileManager:
    def __init__(self, base_path='uploads'):
        self.base_path = base_path
        if not os.path.exists(base_path):
            os.makedirs(base_path)
    
    def save_file(self, filename, content):
        file_path = os.path.join(self.base_path, filename)
        
        try:
            with open(file_path, 'w') as f:
                f.write(content)
            return True
        except Exception as e:
            logger.error(f"Error saving file: {e}")
            return False
    
    def read_file(self, filename):
        file_path = os.path.join(self.base_path, filename)
        
        try:
            with open(file_path, 'r') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading file: {e}")
            return None
    
    def delete_file(self, filename):
        file_path = os.path.join(self.base_path, filename)
        
        try:
            os.remove(file_path)
            return True
        except Exception as e:
            logger.error(f"Error deleting file: {e}")
            return False

class CommandExecutor:
    @staticmethod
    def execute_command(command):
        try:
            result = subprocess.check_output(command, shell=True, text=True)
            return result
        except subprocess.CalledProcessError as e:
            return f"Error: {e}"
    
    @staticmethod
    def ping_host(host):
        command = f"ping -c 4 {host}"
        return CommandExecutor.execute_command(command)
    
    @staticmethod
    def list_directory(path):
        command = f"ls -la {path}"
        return CommandExecutor.execute_command(command)

class DataProcessor:
    @staticmethod
    def serialize_data(data):
        return base64.b64encode(pickle.dumps(data)).decode('utf-8')
    
    @staticmethod
    def deserialize_data(serialized_data):
        try:
            data = pickle.loads(base64.b64decode(serialized_data))
            return data
        except Exception as e:
            logger.error(f"Deserialization error: {e}")
            return None
    
    @staticmethod
    def process_json_data(json_data):
        try:
            data = json.loads(json_data)
            return data
        except json.JSONDecodeError:
            return None

user_manager = UserManager()
file_manager = FileManager()
command_executor = CommandExecutor()
data_processor = DataProcessor()

@app.route('/')
def index():
    name = request.args.get('name', 'Guest')
    template = f'''
    <!DOCTYPE html>
    <html>
    <head><title>Welcome</title></head>
    <body>
        <h1>Welcome, {name}!</h1>
        <p>This is a vulnerable web application for security testing.</p>
        <a href="/login">Login</a> | <a href="/register">Register</a>
    </body>
    </html>
    '''
    return template

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        if user_manager.authenticate_user(username, password):
            session['user'] = username
            return redirect('/dashboard')
        else:
            return 'Invalid credentials'
    
    return '''
    <form method="POST">
        <input name="username" placeholder="Username"><br>
        <input name="password" type="password" placeholder="Password"><br>
        <input type="submit" value="Login">
    </form>
    '''

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        email = request.form.get('email')
        
        if user_manager.create_user(username, password, email):
            return 'User created successfully'
        else:
            return 'User creation failed'
    
    return '''
    <form method="POST">
        <input name="username" placeholder="Username"><br>
        <input name="password" type="password" placeholder="Password"><br>
        <input name="email" placeholder="Email"><br>
        <input type="submit" value="Register">
    </form>
    '''

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect('/login')
    
    user = session['user']
    message = request.args.get('message', 'Welcome to dashboard')
    
    template = f'''
    <!DOCTYPE html>
    <html>
    <head><title>Dashboard</title></head>
    <body>
        <h1>Dashboard for {user}</h1>
        <p>{message}</p>
        <a href="/files">Files</a> | <a href="/commands">Commands</a> | <a href="/logout">Logout</a>
    </body>
    </html>
    '''
    return template

@app.route('/files')
def file_operations():
    if 'user' not in session:
        return redirect('/login')
    
    action = request.args.get('action')
    filename = request.args.get('filename')
    content = request.args.get('content')
    
    if action == 'read' and filename:
        file_content = file_manager.read_file(filename)
        return f'File content: {file_content}'
    elif action == 'write' and filename and content:
        if file_manager.save_file(filename, content):
            return 'File saved successfully'
        else:
            return 'File save failed'
    elif action == 'delete' and filename:
        if file_manager.delete_file(filename):
            return 'File deleted successfully'
        else:
            return 'File deletion failed'
    
    return '''
    <h2>File Operations</h2>
    <p>Use ?action=read&filename=file.txt to read files</p>
    <p>Use ?action=write&filename=file.txt&content=text to write files</p>
    <p>Use ?action=delete&filename=file.txt to delete files</p>
    '''

@app.route('/commands')
def command_operations():
    if 'user' not in session:
        return redirect('/login')
    
    command = request.args.get('command')
    host = request.args.get('host')
    path = request.args.get('path')
    
    if command:
        result = command_executor.execute_command(command)
        return f'<pre>{result}</pre>'
    elif host:
        result = command_executor.ping_host(host)
        return f'<pre>{result}</pre>'
    elif path:
        result = command_executor.list_directory(path)
        return f'<pre>{result}</pre>'
    
    return '''
    <h2>Command Operations</h2>
    <p>Use ?command=ls to execute commands</p>
    <p>Use ?host=google.com to ping hosts</p>
    <p>Use ?path=/tmp to list directories</p>
    '''

@app.route('/data')
def data_operations():
    if 'user' not in session:
        return redirect('/login')
    
    action = request.args.get('action')
    data = request.args.get('data')
    
    if action == 'serialize' and data:
        serialized = data_processor.serialize_data(data)
        return f'Serialized: {serialized}'
    elif action == 'deserialize' and data:
        deserialized = data_processor.deserialize_data(data)
        return f'Deserialized: {deserialized}'
    elif action == 'json' and data:
        processed = data_processor.process_json_data(data)
        return f'Processed: {processed}'
    
    return '''
    <h2>Data Operations</h2>
    <p>Use ?action=serialize&data=test to serialize data</p>
    <p>Use ?action=deserialize&data=base64data to deserialize data</p>
    <p>Use ?action=json&data={"key":"value"} to process JSON</p>
    '''

@app.route('/logout')
def logout():
    session.pop('user', None)
    return redirect('/')

@app.route('/api/users/<int:user_id>')
def get_user_api(user_id):
    user = user_manager.get_user_by_id(user_id)
    if user:
        return json.dumps({
            'id': user[0],
            'username': user[1],
            'email': user[3],
            'role': user[4]
        })
    else:
        return json.dumps({'error': 'User not found'})

@app.route('/api/search')
def search_users():
    query = request.args.get('q', '')
    conn = sqlite3.connect('users.db')
    cursor = conn.cursor()
    
    sql = f"SELECT * FROM users WHERE username LIKE '%{query}%' OR email LIKE '%{query}%'"
    cursor.execute(sql)
    users = cursor.fetchall()
    conn.close()
    
    return json.dumps([{
        'id': user[0],
        'username': user[1],
        'email': user[3],
        'role': user[4]
    } for user in users])

@app.route('/api/upload', methods=['POST'])
def upload_file():
    if 'user' not in session:
        return json.dumps({'error': 'Not authenticated'})
    
    if 'file' not in request.files:
        return json.dumps({'error': 'No file provided'})
    
    file = request.files['file']
    filename = file.filename
    
    file_path = os.path.join('uploads', filename)
    
    try:
        file.save(file_path)
        return json.dumps({'success': True, 'path': file_path})
    except Exception as e:
        return json.dumps({'error': str(e)})

@app.route('/api/execute', methods=['POST'])
def execute_api():
    if 'user' not in session:
        return json.dumps({'error': 'Not authenticated'})
    
    data = request.get_json()
    command = data.get('command', '')
    
    try:
        result = subprocess.check_output(command, shell=True, text=True)
        return json.dumps({'success': True, 'result': result})
    except subprocess.CalledProcessError as e:
        return json.dumps({'error': str(e)})

@app.route('/api/process', methods=['POST'])
def process_data_api():
    if 'user' not in session:
        return json.dumps({'error': 'Not authenticated'})
    
    data = request.get_json()
    action = data.get('action')
    payload = data.get('payload')
    
    if action == 'deserialize':
        result = data_processor.deserialize_data(payload)
        return json.dumps({'success': True, 'result': str(result)})
    elif action == 'json':
        result = data_processor.process_json_data(payload)
        return json.dumps({'success': True, 'result': result})
    else:
        return json.dumps({'error': 'Invalid action'})

@app.errorhandler(404)
def not_found(error):
    path = request.path
    template = f'''
    <!DOCTYPE html>
    <html>
    <head><title>404 Not Found</title></head>
    <body>
        <h1>404 - Page Not Found</h1>
        <p>The page {path} was not found.</p>
        <a href="/">Go Home</a>
    </body>
    </html>
    '''
    return template, 404

@app.errorhandler(500)
def internal_error(error):
    return 'Internal Server Error', 500

if __name__ == '__main__':
    init_db()
    app.run(debug=True, host='0.0.0.0', port=5000) 