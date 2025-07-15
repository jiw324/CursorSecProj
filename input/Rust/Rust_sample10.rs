use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use std::net::SocketAddr;

use serde::{Deserialize, Serialize};
use tokio::time::sleep;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub username: String,
    pub email: String,
    pub created_at: u64,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub completed: bool,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub email: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateTaskRequest {
    pub title: String,
    pub description: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateTaskRequest {
    pub title: Option<String>,
    pub description: Option<String>,
    pub completed: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
    pub timestamp: u64,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
            timestamp: current_timestamp(),
        }
    }
    
    pub fn error(message: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(message),
            timestamp: current_timestamp(),
        }
    }
}

#[derive(Debug)]
pub enum DatabaseError {
    NotFound,
    InvalidInput(String),
    Internal(String),
}

impl std::fmt::Display for DatabaseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DatabaseError::NotFound => write!(f, "Resource not found"),
            DatabaseError::InvalidInput(msg) => write!(f, "Invalid input: {}", msg),
            DatabaseError::Internal(msg) => write!(f, "Internal error: {}", msg),
        }
    }
}

impl std::error::Error for DatabaseError {}

pub type DatabaseResult<T> = Result<T, DatabaseError>;

#[derive(Clone)]
pub struct Database {
    users: Arc<Mutex<HashMap<Uuid, User>>>,
    tasks: Arc<Mutex<HashMap<Uuid, Task>>>,
}

impl Database {
    pub fn new() -> Self {
        Self {
            users: Arc::new(Mutex::new(HashMap::new())),
            tasks: Arc::new(Mutex::new(HashMap::new())),
        }
    }
    
    pub async fn create_user(&self, req: CreateUserRequest) -> DatabaseResult<User> {
        sleep(Duration::from_millis(10)).await;
        
        let user = User {
            id: Uuid::new_v4(),
            username: req.username,
            email: req.email,
            created_at: current_timestamp(),
            active: true,
        };
        
        let mut users = self.users.lock().unwrap();
        
        if users.values().any(|u| u.username == user.username) {
            return Err(DatabaseError::InvalidInput("Username already exists".to_string()));
        }
        
        users.insert(user.id, user.clone());
        Ok(user)
    }
    
    pub async fn get_user(&self, id: Uuid) -> DatabaseResult<User> {
        sleep(Duration::from_millis(5)).await;
        
        let users = self.users.lock().unwrap();
        users.get(&id)
            .cloned()
            .ok_or(DatabaseError::NotFound)
    }
    
    pub async fn list_users(&self) -> DatabaseResult<Vec<User>> {
        sleep(Duration::from_millis(15)).await;
        
        let users = self.users.lock().unwrap();
        Ok(users.values().cloned().collect())
    }
    
    pub async fn delete_user(&self, id: Uuid) -> DatabaseResult<()> {
        sleep(Duration::from_millis(10)).await;
        
        let mut users = self.users.lock().unwrap();
        if users.remove(&id).is_some() {
            let mut tasks = self.tasks.lock().unwrap();
            tasks.retain(|_, task| task.user_id != id);
            Ok(())
        } else {
            Err(DatabaseError::NotFound)
        }
    }
    
    pub async fn create_task(&self, user_id: Uuid, req: CreateTaskRequest) -> DatabaseResult<Task> {
        sleep(Duration::from_millis(10)).await;
        
        self.get_user(user_id).await?;
        
        let task = Task {
            id: Uuid::new_v4(),
            user_id,
            title: req.title,
            description: req.description,
            completed: false,
            created_at: current_timestamp(),
            updated_at: current_timestamp(),
        };
        
        let mut tasks = self.tasks.lock().unwrap();
        tasks.insert(task.id, task.clone());
        Ok(task)
    }
    
    pub async fn get_task(&self, id: Uuid) -> DatabaseResult<Task> {
        sleep(Duration::from_millis(5)).await;
        
        let tasks = self.tasks.lock().unwrap();
        tasks.get(&id)
            .cloned()
            .ok_or(DatabaseError::NotFound)
    }
    
    pub async fn list_user_tasks(&self, user_id: Uuid) -> DatabaseResult<Vec<Task>> {
        sleep(Duration::from_millis(15)).await;
        
        let tasks = self.tasks.lock().unwrap();
        Ok(tasks.values()
            .filter(|task| task.user_id == user_id)
            .cloned()
            .collect())
    }
    
    pub async fn update_task(&self, id: Uuid, req: UpdateTaskRequest) -> DatabaseResult<Task> {
        sleep(Duration::from_millis(10)).await;
        
        let mut tasks = self.tasks.lock().unwrap();
        let task = tasks.get_mut(&id)
            .ok_or(DatabaseError::NotFound)?;
        
        if let Some(title) = req.title {
            task.title = title;
        }
        if let Some(description) = req.description {
            task.description = Some(description);
        }
        if let Some(completed) = req.completed {
            task.completed = completed;
        }
        task.updated_at = current_timestamp();
        
        Ok(task.clone())
    }
    
    pub async fn delete_task(&self, id: Uuid) -> DatabaseResult<()> {
        sleep(Duration::from_millis(10)).await;
        
        let mut tasks = self.tasks.lock().unwrap();
        if tasks.remove(&id).is_some() {
            Ok(())
        } else {
            Err(DatabaseError::NotFound)
        }
    }
}

pub struct AuthService;

impl AuthService {
    pub fn verify_token(_token: &str) -> Option<Uuid> {
        Some(Uuid::new_v4())
    }
    
    pub fn generate_token(user_id: Uuid) -> String {
        format!("token_{}", user_id)
    }
}

pub struct RateLimiter {
    requests: Arc<Mutex<HashMap<String, Vec<u64>>>>,
    max_requests: usize,
    window_seconds: u64,
}

impl RateLimiter {
    pub fn new(max_requests: usize, window_seconds: u64) -> Self {
        Self {
            requests: Arc::new(Mutex::new(HashMap::new())),
            max_requests,
            window_seconds,
        }
    }
    
    pub fn check_rate_limit(&self, ip: &str) -> bool {
        let current_time = current_timestamp();
        let window_start = current_time - self.window_seconds;
        
        let mut requests = self.requests.lock().unwrap();
        let ip_requests = requests.entry(ip.to_string()).or_insert_with(Vec::new);
        
        ip_requests.retain(|&timestamp| timestamp > window_start);
        
        if ip_requests.len() >= self.max_requests {
            false
        } else {
            ip_requests.push(current_time);
            true
        }
    }
}

use std::convert::Infallible;

pub type WebResult<T> = Result<T, WebError>;

#[derive(Debug)]
pub enum WebError {
    Database(DatabaseError),
    NotFound,
    BadRequest(String),
    Unauthorized,
    RateLimitExceeded,
    Internal(String),
}

impl std::fmt::Display for WebError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WebError::Database(e) => write!(f, "Database error: {}", e),
            WebError::NotFound => write!(f, "Not found"),
            WebError::BadRequest(msg) => write!(f, "Bad request: {}", msg),
            WebError::Unauthorized => write!(f, "Unauthorized"),
            WebError::RateLimitExceeded => write!(f, "Rate limit exceeded"),
            WebError::Internal(msg) => write!(f, "Internal error: {}", msg),
        }
    }
}

impl From<DatabaseError> for WebError {
    fn from(err: DatabaseError) -> Self {
        match err {
            DatabaseError::NotFound => WebError::NotFound,
            DatabaseError::InvalidInput(msg) => WebError::BadRequest(msg),
            DatabaseError::Internal(msg) => WebError::Internal(msg),
        }
    }
}

#[derive(Clone)]
pub struct AppState {
    pub database: Database,
    pub rate_limiter: Arc<RateLimiter>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            database: Database::new(),
            rate_limiter: Arc::new(RateLimiter::new(100, 3600)),
        }
    }
}

pub struct Handlers;

impl Handlers {
    pub async fn health() -> Result<String, Infallible> {
        Ok(serde_json::to_string(&ApiResponse::success("Service is healthy")).unwrap())
    }
    
    pub async fn create_user(
        state: AppState,
        req: CreateUserRequest,
    ) -> WebResult<String> {
        let user = state.database.create_user(req).await?;
        Ok(serde_json::to_string(&ApiResponse::success(user)).unwrap())
    }
    
    pub async fn get_user(
        state: AppState,
        user_id: Uuid,
    ) -> WebResult<String> {
        let user = state.database.get_user(user_id).await?;
        Ok(serde_json::to_string(&ApiResponse::success(user)).unwrap())
    }
    
    pub async fn list_users(state: AppState) -> WebResult<String> {
        let users = state.database.list_users().await?;
        Ok(serde_json::to_string(&ApiResponse::success(users)).unwrap())
    }
    
    pub async fn delete_user(
        state: AppState,
        user_id: Uuid,
    ) -> WebResult<String> {
        state.database.delete_user(user_id).await?;
        Ok(serde_json::to_string(&ApiResponse::success("User deleted")).unwrap())
    }
    
    pub async fn create_task(
        state: AppState,
        user_id: Uuid,
        req: CreateTaskRequest,
    ) -> WebResult<String> {
        let task = state.database.create_task(user_id, req).await?;
        Ok(serde_json::to_string(&ApiResponse::success(task)).unwrap())
    }
    
    pub async fn get_task(
        state: AppState,
        task_id: Uuid,
    ) -> WebResult<String> {
        let task = state.database.get_task(task_id).await?;
        Ok(serde_json::to_string(&ApiResponse::success(task)).unwrap())
    }
    
    pub async fn list_user_tasks(
        state: AppState,
        user_id: Uuid,
    ) -> WebResult<String> {
        let tasks = state.database.list_user_tasks(user_id).await?;
        Ok(serde_json::to_string(&ApiResponse::success(tasks)).unwrap())
    }
    
    pub async fn update_task(
        state: AppState,
        task_id: Uuid,
        req: UpdateTaskRequest,
    ) -> WebResult<String> {
        let task = state.database.update_task(task_id, req).await?;
        Ok(serde_json::to_string(&ApiResponse::success(task)).unwrap())
    }
    
    pub async fn delete_task(
        state: AppState,
        task_id: Uuid,
    ) -> WebResult<String> {
        state.database.delete_task(task_id).await?;
        Ok(serde_json::to_string(&ApiResponse::success("Task deleted")).unwrap())
    }
}

pub fn current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

use tokio::sync::mpsc;

#[derive(Debug)]
pub enum BackgroundTask {
    SendEmail { to: String, subject: String, body: String },
    GenerateReport { user_id: Uuid, report_type: String },
    CleanupOldData { days: u32 },
}

pub struct BackgroundProcessor {
    sender: mpsc::Sender<BackgroundTask>,
}

impl BackgroundProcessor {
    pub fn new() -> (Self, mpsc::Receiver<BackgroundTask>) {
        let (sender, receiver) = mpsc::channel(100);
        (Self { sender }, receiver)
    }
    
    pub async fn submit_task(&self, task: BackgroundTask) -> Result<(), &'static str> {
        self.sender.send(task).await
            .map_err(|_| "Failed to submit background task")
    }
    
    pub async fn process_tasks(mut receiver: mpsc::Receiver<BackgroundTask>) {
        while let Some(task) = receiver.recv().await {
            match task {
                BackgroundTask::SendEmail { to, subject, body } => {
                    Self::send_email(&to, &subject, &body).await;
                }
                BackgroundTask::GenerateReport { user_id, report_type } => {
                    Self::generate_report(user_id, &report_type).await;
                }
                BackgroundTask::CleanupOldData { days } => {
                    Self::cleanup_old_data(days).await;
                }
            }
        }
    }
    
    async fn send_email(to: &str, subject: &str, body: &str) {
        println!("Sending email to {}: {} - {}", to, subject, body);
        sleep(Duration::from_millis(100)).await;
        println!("Email sent successfully");
    }
    
    async fn generate_report(user_id: Uuid, report_type: &str) {
        println!("Generating {} report for user {}", report_type, user_id);
        sleep(Duration::from_millis(500)).await;
        println!("Report generated successfully");
    }
    
    async fn cleanup_old_data(days: u32) {
        println!("Cleaning up data older than {} days", days);
        sleep(Duration::from_millis(200)).await;
        println!("Cleanup completed");
    }
}

use std::collections::HashSet;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebSocketMessage {
    pub message_type: String,
    pub data: serde_json::Value,
    pub timestamp: u64,
}

pub struct WebSocketManager {
    connections: Arc<Mutex<HashSet<Uuid>>>,
}

impl WebSocketManager {
    pub fn new() -> Self {
        Self {
            connections: Arc::new(Mutex::new(HashSet::new())),
        }
    }
    
    pub fn add_connection(&self, connection_id: Uuid) {
        let mut connections = self.connections.lock().unwrap();
        connections.insert(connection_id);
        println!("WebSocket connection added: {}", connection_id);
    }
    
    pub fn remove_connection(&self, connection_id: Uuid) {
        let mut connections = self.connections.lock().unwrap();
        connections.remove(&connection_id);
        println!("WebSocket connection removed: {}", connection_id);
    }
    
    pub async fn broadcast_message(&self, message: WebSocketMessage) {
        let connections = self.connections.lock().unwrap();
        println!("Broadcasting message to {} connections", connections.len());
        
        for connection_id in connections.iter() {
            println!("Sending to connection {}: {:?}", connection_id, message);
        }
    }
    
    pub fn get_connection_count(&self) -> usize {
        let connections = self.connections.lock().unwrap();
        connections.len()
    }
}

pub async fn run_demo_server() -> Result<(), Box<dyn std::error::Error>> {
    println!("=== Rust Web Service Demo ===");
    
    let state = AppState::new();
    
    let (background_processor, task_receiver) = BackgroundProcessor::new();
    
    tokio::spawn(BackgroundProcessor::process_tasks(task_receiver));
    
    let ws_manager = WebSocketManager::new();
    
    println!("1. Testing user operations...");
    
    let create_user_req = CreateUserRequest {
        username: "testuser".to_string(),
        email: "test@example.com".to_string(),
    };
    
    let user_json = Handlers::create_user(state.clone(), create_user_req).await?;
    let user_response: ApiResponse<User> = serde_json::from_str(&user_json)?;
    let user = user_response.data.unwrap();
    
    println!("Created user: {}", user.username);
    
    let get_user_json = Handlers::get_user(state.clone(), user.id).await?;
    println!("Retrieved user: {}", get_user_json);
    
    println!("\n2. Testing task operations...");
    
    let create_task_req = CreateTaskRequest {
        title: "Complete web service demo".to_string(),
        description: Some("Implement all CRUD operations".to_string()),
    };
    
    let task_json = Handlers::create_task(state.clone(), user.id, create_task_req).await?;
    let task_response: ApiResponse<Task> = serde_json::from_str(&task_json)?;
    let task = task_response.data.unwrap();
    
    println!("Created task: {}", task.title);
    
    let update_task_req = UpdateTaskRequest {
        title: None,
        description: Some("Updated description".to_string()),
        completed: Some(true),
    };
    
    let updated_task_json = Handlers::update_task(state.clone(), task.id, update_task_req).await?;
    println!("Updated task: {}", updated_task_json);
    
    let tasks_json = Handlers::list_user_tasks(state.clone(), user.id).await?;
    println!("User tasks: {}", tasks_json);
    
    println!("\n3. Testing background tasks...");
    
    background_processor.submit_task(BackgroundTask::SendEmail {
        to: user.email.clone(),
        subject: "Welcome!".to_string(),
        body: "Welcome to our service!".to_string(),
    }).await?;
    
    background_processor.submit_task(BackgroundTask::GenerateReport {
        user_id: user.id,
        report_type: "activity".to_string(),
    }).await?;
    
    sleep(Duration::from_millis(1000)).await;
    
    println!("\n4. Testing WebSocket functionality...");
    
    let conn1 = Uuid::new_v4();
    let conn2 = Uuid::new_v4();
    
    ws_manager.add_connection(conn1);
    ws_manager.add_connection(conn2);
    
    let ws_message = WebSocketMessage {
        message_type: "task_updated".to_string(),
        data: serde_json::json!({
            "task_id": task.id,
            "status": "completed"
        }),
        timestamp: current_timestamp(),
    };
    
    ws_manager.broadcast_message(ws_message).await;
    
    println!("Active WebSocket connections: {}", ws_manager.get_connection_count());
    
    println!("\n5. Testing rate limiting...");
    
    let test_ip = "192.168.1.1";
    for i in 1..=5 {
        let allowed = state.rate_limiter.check_rate_limit(test_ip);
        println!("Request {}: {}", i, if allowed { "Allowed" } else { "Rate limited" });
    }
    
    println!("\nWeb service demo completed successfully!");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_user_crud() {
        let db = Database::new();
        
        let create_req = CreateUserRequest {
            username: "testuser".to_string(),
            email: "test@example.com".to_string(),
        };
        
        let user = db.create_user(create_req).await.unwrap();
        assert_eq!(user.username, "testuser");
        
        let retrieved_user = db.get_user(user.id).await.unwrap();
        assert_eq!(retrieved_user.id, user.id);
        
        let users = db.list_users().await.unwrap();
        assert_eq!(users.len(), 1);
        
        db.delete_user(user.id).await.unwrap();
        assert!(db.get_user(user.id).await.is_err());
    }
    
    #[tokio::test]
    async fn test_task_crud() {
        let db = Database::new();
        
        let user = db.create_user(CreateUserRequest {
            username: "testuser".to_string(),
            email: "test@example.com".to_string(),
        }).await.unwrap();
        
        let task = db.create_task(user.id, CreateTaskRequest {
            title: "Test task".to_string(),
            description: Some("Description".to_string()),
        }).await.unwrap();
        
        assert_eq!(task.title, "Test task");
        assert!(!task.completed);
        
        let updated_task = db.update_task(task.id, UpdateTaskRequest {
            title: None,
            description: None,
            completed: Some(true),
        }).await.unwrap();
        
        assert!(updated_task.completed);
        
        let tasks = db.list_user_tasks(user.id).await.unwrap();
        assert_eq!(tasks.len(), 1);
        
        db.delete_task(task.id).await.unwrap();
        assert!(db.get_task(task.id).await.is_err());
    }
    
    #[test]
    fn test_rate_limiter() {
        let rate_limiter = RateLimiter::new(2, 60);
        let test_ip = "127.0.0.1";
        
        assert!(rate_limiter.check_rate_limit(test_ip));
        assert!(rate_limiter.check_rate_limit(test_ip));
        assert!(!rate_limiter.check_rate_limit(test_ip));
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    run_demo_server().await
} 