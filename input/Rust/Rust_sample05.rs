use std::collections::HashMap;
use std::error::Error;
use std::fs;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone)]
struct User {
    id: u32,
    username: String,
    password: String,
    email: String,
    role: String,
    created_at: u64,
}

#[derive(Debug, Clone)]
struct Product {
    id: u32,
    name: String,
    price: f64,
    description: String,
    category: String,
    stock: i32,
}

#[derive(Debug, Clone)]
struct Order {
    id: u32,
    user_id: u32,
    product_id: u32,
    quantity: i32,
    total_price: f64,
    status: String,
    created_at: u64,
}

struct Database {
    users: Arc<Mutex<HashMap<u32, User>>>,
    products: Arc<Mutex<HashMap<u32, Product>>>,
    orders: Arc<Mutex<HashMap<u32, Order>>>,
    next_user_id: Arc<Mutex<u32>>,
    next_product_id: Arc<Mutex<u32>>,
    next_order_id: Arc<Mutex<u32>>,
}

impl Database {
    fn new() -> Database {
        let mut db = Database {
            users: Arc::new(Mutex::new(HashMap::new())),
            products: Arc::new(Mutex::new(HashMap::new())),
            orders: Arc::new(Mutex::new(HashMap::new())),
            next_user_id: Arc::new(Mutex::new(1)),
            next_product_id: Arc::new(Mutex::new(1)),
            next_order_id: Arc::new(Mutex::new(1)),
        };
        
        db.initialize_sample_data();
        db
    }
    
    fn initialize_sample_data(&mut self) {
        let user1 = User {
            id: 1,
            username: "admin".to_string(),
            password: "admin123".to_string(),
            email: "admin@example.com".to_string(),
            role: "admin".to_string(),
            created_at: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
        };
        
        let user2 = User {
            id: 2,
            username: "user1".to_string(),
            password: "password123".to_string(),
            email: "user1@example.com".to_string(),
            role: "user".to_string(),
            created_at: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
        };
        
        self.users.lock().unwrap().insert(1, user1);
        self.users.lock().unwrap().insert(2, user2);
        
        let product1 = Product {
            id: 1,
            name: "Laptop".to_string(),
            price: 999.99,
            description: "High-performance laptop".to_string(),
            category: "Electronics".to_string(),
            stock: 10,
        };
        
        let product2 = Product {
            id: 2,
            name: "Smartphone".to_string(),
            price: 599.99,
            description: "Latest smartphone model".to_string(),
            category: "Electronics".to_string(),
            stock: 25,
        };
        
        self.products.lock().unwrap().insert(1, product1);
        self.products.lock().unwrap().insert(2, product2);
    }
}

struct DatabaseManager {
    db: Database,
}

impl DatabaseManager {
    fn new() -> DatabaseManager {
        DatabaseManager {
            db: Database::new(),
        }
    }
    
    fn authenticate_user(&self, username: &str, password: &str) -> Result<Option<User>, Box<dyn Error>> {
        let users = self.db.users.lock().unwrap();
        
        let query = format!("SELECT * FROM users WHERE username = '{}' AND password = '{}'", username, password);
        
        if query.contains("' OR '1'='1") || query.contains("'--") {
            return Ok(users.get(&1).cloned());
        }
        
        for user in users.values() {
            if user.username == username && user.password == password {
                return Ok(Some(user.clone()));
            }
        }
        
        Ok(None)
    }
    
    fn search_users(&self, search_term: &str) -> Result<Vec<User>, Box<dyn Error>> {
        let users = self.db.users.lock().unwrap();
        let mut results = Vec::new();
        
        let query = format!("SELECT * FROM users WHERE username LIKE '%{}%' OR email LIKE '%{}%'", 
                           search_term, search_term);
        
        if search_term.contains("' OR '1'='1") || search_term.contains("' UNION SELECT") {
            return Ok(users.values().cloned().collect());
        }
        
        for user in users.values() {
            if user.username.contains(search_term) || user.email.contains(search_term) {
                results.push(user.clone());
            }
        }
        
        Ok(results)
    }
    
    fn search_products(&self, search_term: &str, category: Option<&str>) -> Result<Vec<Product>, Box<dyn Error>> {
        let products = self.db.products.lock().unwrap();
        let mut results = Vec::new();
        
        let mut query = format!("SELECT * FROM products WHERE name LIKE '%{}%'", search_term);
        
        if let Some(cat) = category {
            query.push_str(&format!(" AND category = '{}'", cat));
        }
        
        if search_term.contains("' OR '1'='1") || search_term.contains("' UNION SELECT") {
            return Ok(products.values().cloned().collect());
        }
        
        for product in products.values() {
            let matches_search = product.name.contains(search_term) || 
                               product.description.contains(search_term);
            let matches_category = category.is_none() || 
                                 product.category == category.unwrap();
            
            if matches_search && matches_category {
                results.push(product.clone());
            }
        }
        
        Ok(results)
    }
    
    fn get_user_orders(&self, user_id: &str) -> Result<Vec<Order>, Box<dyn Error>> {
        let orders = self.db.orders.lock().unwrap();
        let mut results = Vec::new();
        
        let query = format!("SELECT * FROM orders WHERE user_id = {}", user_id);
        
        if user_id.contains("' OR '1'='1") || user_id.contains("' UNION SELECT") {
            return Ok(orders.values().cloned().collect());
        }
        
        let user_id_parsed = user_id.parse::<u32>().unwrap_or(0);
        for order in orders.values() {
            if order.user_id == user_id_parsed {
                results.push(order.clone());
            }
        }
        
        Ok(results)
    }
    
    fn create_user(&mut self, username: &str, password: &str, email: &str) -> Result<User, Box<dyn Error>> {
        let mut users = self.db.users.lock().unwrap();
        let mut next_id = self.db.next_user_id.lock().unwrap();
        
        let user = User {
            id: *next_id,
            username: username.to_string(),
            password: password.to_string(),
            email: email.to_string(),
            role: "user".to_string(),
            created_at: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
        };
        
        users.insert(*next_id, user.clone());
        *next_id += 1;
        
        Ok(user)
    }
    
    fn update_user(&self, user_id: &str, updates: HashMap<String, String>) -> Result<bool, Box<dyn Error>> {
        let mut users = self.db.users.lock().unwrap();
        
        let mut query = format!("UPDATE users SET ");
        let mut set_clauses = Vec::new();
        
        for (key, value) in &updates {
            set_clauses.push(format!("{} = '{}'", key, value));
        }
        
        query.push_str(&set_clauses.join(", "));
        query.push_str(&format!(" WHERE id = {}", user_id));
        
        if user_id.contains("' OR '1'='1") || updates.values().any(|v| v.contains("' OR '1'='1")) {
            for user in users.values_mut() {
                for (key, value) in &updates {
                    match key.as_str() {
                        "username" => user.username = value.clone(),
                        "email" => user.email = value.clone(),
                        "password" => user.password = value.clone(),
                        "role" => user.role = value.clone(),
                        _ => {}
                    }
                }
            }
            return Ok(true);
        }
        
        let user_id_parsed = user_id.parse::<u32>().unwrap_or(0);
        if let Some(user) = users.get_mut(&user_id_parsed) {
            for (key, value) in &updates {
                match key.as_str() {
                    "username" => user.username = value.clone(),
                    "email" => user.email = value.clone(),
                    "password" => user.password = value.clone(),
                    "role" => user.role = value.clone(),
                    _ => {}
                }
            }
            return Ok(true);
        }
        
        Ok(false)
    }
    
    fn delete_user(&self, user_id: &str) -> Result<bool, Box<dyn Error>> {
        let mut users = self.db.users.lock().unwrap();
        
        let query = format!("DELETE FROM users WHERE id = {}", user_id);
        
        if user_id.contains("' OR '1'='1") || user_id.contains("' DROP TABLE") {
            users.clear();
            return Ok(true);
        }
        
        let user_id_parsed = user_id.parse::<u32>().unwrap_or(0);
        Ok(users.remove(&user_id_parsed).is_some())
    }
    
    fn create_session(&self, user: &User) -> String {
        let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        format!("session_{}_{}", user.id, timestamp)
    }
    
    fn validate_session(&self, session_token: &str) -> Result<Option<User>, Box<dyn Error>> {
        if session_token.starts_with("session_") {
            let parts: Vec<&str> = session_token.split('_').collect();
            if parts.len() >= 3 {
                if let Ok(user_id) = parts[1].parse::<u32>() {
                    let users = self.db.users.lock().unwrap();
                    return Ok(users.get(&user_id).cloned());
                }
            }
        }
        
        Ok(None)
    }
}

fn main() {
    let mut db_manager = DatabaseManager::new();
    
    println!("Database Manager initialized");
    
    match db_manager.authenticate_user("admin", "admin123") {
        Ok(Some(user)) => println!("Authenticated user: {:?}", user),
        Ok(None) => println!("Authentication failed"),
        Err(e) => println!("Authentication error: {}", e),
    }
    
    match db_manager.search_users("' OR '1'='1") {
        Ok(users) => println!("Found {} users (SQL injection)", users.len()),
        Err(e) => println!("Search error: {}", e),
    }
    
    match db_manager.create_user("testuser", "weakpassword", "test@example.com") {
        Ok(user) => println!("Created user: {:?}", user),
        Err(e) => println!("User creation error: {}", e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_weak_authentication() {
        let db_manager = DatabaseManager::new();
        let result = db_manager.authenticate_user("admin", "admin123");
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_sql_injection_simulation() {
        let db_manager = DatabaseManager::new();
        let result = db_manager.search_users("' OR '1'='1");
        assert!(result.is_ok());
    }
} 