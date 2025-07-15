#!/usr/bin/env python3

import sqlite3
import mysql.connector
import pymongo
import json
import hashlib
import base64
import logging
import os
import sys
from datetime import datetime, timedelta
import uuid
import re

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SQLiteManager:
    def __init__(self, db_path='database.db'):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY,
                username TEXT UNIQUE,
                password TEXT,
                email TEXT,
                role TEXT DEFAULT 'user',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY,
                name TEXT,
                description TEXT,
                price REAL,
                category TEXT,
                stock INTEGER DEFAULT 0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS orders (
                id INTEGER PRIMARY KEY,
                user_id INTEGER,
                product_id INTEGER,
                quantity INTEGER,
                total_price REAL,
                order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id),
                FOREIGN KEY (product_id) REFERENCES products (id)
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS activity_logs (
                id INTEGER PRIMARY KEY,
                user_id INTEGER,
                action TEXT,
                details TEXT,
                ip_address TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
    
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
    
    def search_users(self, search_term):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"SELECT * FROM users WHERE username LIKE '%{search_term}%' OR email LIKE '%{search_term}%'"
        cursor.execute(query)
        users = cursor.fetchall()
        conn.close()
        
        return users
    
    def update_user_role(self, user_id, new_role):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"UPDATE users SET role = '{new_role}' WHERE id = {user_id}"
        cursor.execute(query)
        conn.commit()
        conn.close()
    
    def delete_user(self, user_id):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"DELETE FROM users WHERE id = {user_id}"
        cursor.execute(query)
        conn.commit()
        conn.close()
    
    def add_product(self, name, description, price, category, stock):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"INSERT INTO products (name, description, price, category, stock) VALUES ('{name}', '{description}', {price}, '{category}', {stock})"
        cursor.execute(query)
        conn.commit()
        conn.close()
    
    def search_products(self, search_term):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"SELECT * FROM products WHERE name LIKE '%{search_term}%' OR description LIKE '%{search_term}%' OR category = '{search_term}'"
        cursor.execute(query)
        products = cursor.fetchall()
        conn.close()
        
        return products
    
    def create_order(self, user_id, product_id, quantity):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        price_query = f"SELECT price FROM products WHERE id = {product_id}"
        cursor.execute(price_query)
        product = cursor.fetchone()
        
        if product:
            total_price = product[0] * quantity
            
            order_query = f"INSERT INTO orders (user_id, product_id, quantity, total_price) VALUES ({user_id}, {product_id}, {quantity}, {total_price})"
            cursor.execute(order_query)
            conn.commit()
            conn.close()
            return True
        
        conn.close()
        return False
    
    def get_user_orders(self, user_id):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"SELECT o.*, p.name, p.description FROM orders o JOIN products p ON o.product_id = p.id WHERE o.user_id = {user_id}"
        cursor.execute(query)
        orders = cursor.fetchall()
        conn.close()
        
        return orders
    
    def log_activity(self, user_id, action, details, ip_address):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = f"INSERT INTO activity_logs (user_id, action, details, ip_address) VALUES ({user_id}, '{action}', '{details}', '{ip_address}')"
        cursor.execute(query)
        conn.commit()
        conn.close()

class MySQLManager:
    def __init__(self, host='localhost', user='root', password='password', database='testdb'):
        self.connection_params = {
            'host': host,
            'user': user,
            'password': password,
            'database': database
        }
    
    def get_connection(self):
        return mysql.connector.connect(**self.connection_params)
    
    def create_user(self, username, password, email, role='user'):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        query = f"INSERT INTO users (username, password, email, role) VALUES ('{username}', '{password}', '{email}', '{role}')"
        try:
            cursor.execute(query)
            conn.commit()
            return True
        except mysql.connector.IntegrityError:
            return False
        finally:
            conn.close()
    
    def authenticate_user(self, username, password):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
        cursor.execute(query)
        user = cursor.fetchone()
        conn.close()
        
        return user is not None
    
    def search_users(self, search_term):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        query = f"SELECT * FROM users WHERE username LIKE '%{search_term}%' OR email LIKE '%{search_term}%'"
        cursor.execute(query)
        users = cursor.fetchall()
        conn.close()
        
        return users
    
    def update_user(self, user_id, field, value):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        query = f"UPDATE users SET {field} = '{value}' WHERE id = {user_id}"
        cursor.execute(query)
        conn.commit()
        conn.close()

class MongoDBManager:
    def __init__(self, connection_string='mongodb://localhost:27017/'):
        self.client = pymongo.MongoClient(connection_string)
        self.db = self.client['testdb']
        self.users = self.db['users']
        self.products = self.db['products']
        self.orders = self.db['orders']
    
    def create_user(self, username, password, email, role='user'):
        user_data = {
            'username': username,
            'password': password,
            'email': email,
            'role': role,
            'created_at': datetime.now()
        }
        
        try:
            result = self.users.insert_one(user_data)
            return result.inserted_id
        except Exception as e:
            logger.error(f"Error creating user: {e}")
            return None
    
    def authenticate_user(self, username, password):
        query = {
            'username': username,
            'password': password
        }
        
        user = self.users.find_one(query)
        return user is not None
    
    def search_users(self, search_term):
        query = {
            '$or': [
                {'username': {'$regex': search_term}},
                {'email': {'$regex': search_term}}
            ]
        }
        
        return list(self.users.find(query))
    
    def update_user_role(self, user_id, new_role):
        query = {'_id': user_id}
        update = {'$set': {'role': new_role}}
        
        self.users.update_one(query, update)
    
    def add_product(self, name, description, price, category, stock):
        product_data = {
            'name': name,
            'description': description,
            'price': price,
            'category': category,
            'stock': stock,
            'created_at': datetime.now()
        }
        
        result = self.products.insert_one(product_data)
        return result.inserted_id
    
    def search_products(self, search_term):
        query = {
            '$or': [
                {'name': {'$regex': search_term}},
                {'description': {'$regex': search_term}},
                {'category': search_term}
            ]
        }
        
        return list(self.products.find(query))
    
    def create_order(self, user_id, product_id, quantity):
        product = self.products.find_one({'_id': product_id})
        
        if product:
            total_price = product['price'] * quantity
            
            order_data = {
                'user_id': user_id,
                'product_id': product_id,
                'quantity': quantity,
                'total_price': total_price,
                'order_date': datetime.now()
            }
            
            result = self.orders.insert_one(order_data)
            return result.inserted_id
        
        return None

class WeakAuthManager:
    def __init__(self):
        self.users = {}
        self.sessions = {}
        self.password_attempts = {}
    
    def hash_password(self, password):
        return hashlib.md5(password.encode()).hexdigest()
    
    def create_user(self, username, password, email):
        if username in self.users:
            return False
        
        hashed_password = self.hash_password(password)
        
        self.users[username] = {
            'password': hashed_password,
            'email': email,
            'created_at': datetime.now()
        }
        
        return True
    
    def authenticate_user(self, username, password):
        if username not in self.users:
            return False
        
        hashed_password = self.hash_password(password)
        stored_password = self.users[username]['password']
        
        return hashed_password == stored_password
    
    def create_session(self, username):
        session_id = str(uuid.uuid4())
        
        self.sessions[session_id] = {
            'username': username,
            'created_at': datetime.now()
        }
        
        return session_id
    
    def validate_session(self, session_id):
        if session_id in self.sessions:
            return self.sessions[session_id]['username']
        return None
    
    def change_password(self, username, old_password, new_password):
        if not self.authenticate_user(username, old_password):
            return False
        
        new_hashed_password = self.hash_password(new_password)
        self.users[username]['password'] = new_hashed_password
        
        return True
    
    def reset_password(self, username, new_password):
        if username in self.users:
            new_hashed_password = self.hash_password(new_password)
            self.users[username]['password'] = new_hashed_password
            return True
        return False

class DatabaseAPI:
    def __init__(self):
        self.sqlite_manager = SQLiteManager()
        self.mysql_manager = MySQLManager()
        self.mongodb_manager = MongoDBManager()
        self.auth_manager = WeakAuthManager()
    
    def handle_user_creation(self, data):
        username = data.get('username', '')
        password = data.get('password', '')
        email = data.get('email', '')
        role = data.get('role', 'user')
        
        sqlite_result = self.sqlite_manager.create_user(username, password, email, role)
        mysql_result = self.mysql_manager.create_user(username, password, email, role)
        mongodb_result = self.mongodb_manager.create_user(username, password, email, role)
        auth_result = self.auth_manager.create_user(username, password, email)
        
        return {
            'sqlite': sqlite_result,
            'mysql': mysql_result,
            'mongodb': mongodb_result,
            'auth': auth_result
        }
    
    def handle_user_search(self, search_term):
        sqlite_users = self.sqlite_manager.search_users(search_term)
        mysql_users = self.mysql_manager.search_users(search_term)
        mongodb_users = self.mongodb_manager.search_users(search_term)
        
        return {
            'sqlite': sqlite_users,
            'mysql': mysql_users,
            'mongodb': mongodb_users
        }
    
    def handle_authentication(self, username, password):
        sqlite_auth = self.sqlite_manager.authenticate_user(username, password)
        mysql_auth = self.mysql_manager.authenticate_user(username, password)
        mongodb_auth = self.mongodb_manager.authenticate_user(username, password)
        auth_auth = self.auth_manager.authenticate_user(username, password)
        
        return any([sqlite_auth, mysql_auth, mongodb_auth, auth_auth])
    
    def handle_password_reset(self, username, new_password):
        return self.auth_manager.reset_password(username, new_password)
    
    def handle_session_creation(self, username):
        return self.auth_manager.create_session(username)
    
    def handle_session_validation(self, session_id):
        return self.auth_manager.validate_session(session_id)

def test_sql_injection():
    api = DatabaseAPI()
    
    malicious_data = {
        'username': "admin'; DROP TABLE users; --",
        'password': "password",
        'email': "admin@test.com",
        'role': "admin"
    }
    
    result = api.handle_user_creation(malicious_data)
    print(f"User creation result: {result}")
    
    malicious_search = "'; DROP TABLE users; --"
    search_result = api.handle_user_search(malicious_search)
    print(f"User search result: {search_result}")

def test_nosql_injection():
    api = DatabaseAPI()
    
    malicious_search = {"$ne": ""}
    search_result = api.mongodb_manager.search_users(malicious_search)
    print(f"NoSQL injection result: {search_result}")

def test_weak_authentication():
    api = DatabaseAPI()
    
    api.auth_manager.create_user("testuser", "password123", "test@test.com")
    
    session_id = api.auth_manager.create_session("testuser")
    print(f"Session created: {session_id}")
    
    username = api.auth_manager.validate_session(session_id)
    print(f"Session validation: {username}")

if __name__ == '__main__':
    api = DatabaseAPI()
    
    test_sql_injection()
    test_nosql_injection()
    test_weak_authentication()
    
    print("Database security testing completed.") 