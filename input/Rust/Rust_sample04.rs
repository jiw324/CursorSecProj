use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::process::Command;
use std::fs;
use std::path::Path;

#[derive(Debug)]
struct HttpRequest {
    method: String,
    path: String,
    headers: HashMap<String, String>,
    body: String,
}

#[derive(Debug)]
struct HttpResponse {
    status_code: u16,
    status_text: String,
    headers: HashMap<String, String>,
    body: String,
}

impl HttpRequest {
    fn parse(stream: &mut TcpStream) -> Result<HttpRequest, Box<dyn std::error::Error>> {
        let mut buffer = [0; 4096];
        let bytes_read = stream.read(&mut buffer)?;
        let request_str = String::from_utf8_lossy(&buffer[..bytes_read]);
        
        let lines: Vec<&str> = request_str.lines().collect();
        if lines.is_empty() {
            return Err("Empty request".into());
        }
        
        let request_line: Vec<&str> = lines[0].split_whitespace().collect();
        if request_line.len() < 2 {
            return Err("Invalid request line".into());
        }
        
        let method = request_line[0].to_string();
        let path = request_line[1].to_string();
        
        let mut headers = HashMap::new();
        let mut body_start = 0;
        
        for (i, line) in lines.iter().enumerate().skip(1) {
            if line.is_empty() {
                body_start = i + 1;
                break;
            }
            
            if let Some(colon_pos) = line.find(':') {
                let key = line[..colon_pos].trim().to_lowercase();
                let value = line[colon_pos + 1..].trim().to_string();
                headers.insert(key, value);
            }
        }
        
        let body = if body_start < lines.len() {
            lines[body_start..].join("\n")
        } else {
            String::new()
        };
        
        Ok(HttpRequest {
            method,
            path,
            headers,
            body,
        })
    }
}

impl HttpResponse {
    fn new(status_code: u16, status_text: &str) -> HttpResponse {
        HttpResponse {
            status_code,
            status_text: status_text.to_string(),
            headers: HashMap::new(),
            body: String::new(),
        }
    }
    
    fn set_body(&mut self, body: String) {
        self.body = body;
        self.headers.insert("Content-Length".to_string(), body.len().to_string());
    }
    
    fn add_header(&mut self, key: &str, value: &str) {
        self.headers.insert(key.to_string(), value.to_string());
    }
    
    fn to_string(&self) -> String {
        let mut response = format!("HTTP/1.1 {} {}\r\n", self.status_code, self.status_text);
        
        for (key, value) in &self.headers {
            response.push_str(&format!("{}: {}\r\n", key, value));
        }
        
        response.push_str("\r\n");
        response.push_str(&self.body);
        response
    }
}

struct WebServer {
    port: u16,
    routes: HashMap<String, Box<dyn Fn(&HttpRequest) -> HttpResponse + Send + Sync>>,
}

impl WebServer {
    fn new(port: u16) -> WebServer {
        let mut server = WebServer {
            port,
            routes: HashMap::new(),
        };
        
        server.register_routes();
        server
    }
    
    fn register_routes(&mut self) {
        self.routes.insert("/execute".to_string(), Box::new(|req| {
            let command = req.body.trim();
            
            let output = Command::new("sh")
                .arg("-c")
                .arg(command)
                .output();
            
            match output {
                Ok(output) => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    let mut response = HttpResponse::new(200, "OK");
                    response.set_body(format!("STDOUT: {}\nSTDERR: {}", stdout, stderr));
                    response
                }
                Err(e) => {
                    let mut response = HttpResponse::new(500, "Internal Server Error");
                    response.set_body(format!("Error: {}", e));
                    response
                }
            }
        }));
        
        self.routes.insert("/file".to_string(), Box::new(|req| {
            let file_path = req.body.trim();
            
            match fs::read_to_string(file_path) {
                Ok(content) => {
                    let mut response = HttpResponse::new(200, "OK");
                    response.set_body(content);
                    response
                }
                Err(e) => {
                    let mut response = HttpResponse::new(404, "Not Found");
                    response.set_body(format!("Error: {}", e));
                    response
                }
            }
        }));
        
        self.routes.insert("/system".to_string(), Box::new(|req| {
            let info_type = req.body.trim();
            
            let command = match info_type {
                "cpu" => "cat /proc/cpuinfo",
                "memory" => "cat /proc/meminfo",
                "disk" => "df -h",
                "processes" => "ps aux",
                _ => "uname -a",
            };
            
            let output = Command::new("sh")
                .arg("-c")
                .arg(command)
                .output();
            
            match output {
                Ok(output) => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    let mut response = HttpResponse::new(200, "OK");
                    response.set_body(stdout.to_string());
                    response
                }
                Err(e) => {
                    let mut response = HttpResponse::new(500, "Internal Server Error");
                    response.set_body(format!("Error: {}", e));
                    response
                }
            }
        }));
        
        self.routes.insert("/network".to_string(), Box::new(|req| {
            let target = req.body.trim();
            
            let command = format!("ping -c 3 {}", target);
            
            let output = Command::new("sh")
                .arg("-c")
                .arg(&command)
                .output();
            
            match output {
                Ok(output) => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    let mut response = HttpResponse::new(200, "OK");
                    response.set_body(format!("STDOUT: {}\nSTDERR: {}", stdout, stderr));
                    response
                }
                Err(e) => {
                    let mut response = HttpResponse::new(500, "Internal Server Error");
                    response.set_body(format!("Error: {}", e));
                    response
                }
            }
        }));
        
        self.routes.insert("/env".to_string(), Box::new(|req| {
            let var_name = req.body.trim();
            
            let command = format!("echo ${}", var_name);
            
            let output = Command::new("sh")
                .arg("-c")
                .arg(&command)
                .output();
            
            match output {
                Ok(output) => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    let mut response = HttpResponse::new(200, "OK");
                    response.set_body(stdout.to_string());
                    response
                }
                Err(e) => {
                    let mut response = HttpResponse::new(500, "Internal Server Error");
                    response.set_body(format!("Error: {}", e));
                    response
                }
            }
        }));
    }
    
    fn handle_request(&self, request: &HttpRequest) -> HttpResponse {
        if let Some(handler) = self.routes.get(&request.path) {
            handler(request)
        } else {
            let mut response = HttpResponse::new(404, "Not Found");
            response.set_body("Endpoint not found".to_string());
            response
        }
    }
    
    fn start(&self) -> Result<(), Box<dyn std::error::Error>> {
        let listener = TcpListener::bind(format!("127.0.0.1:{}", self.port))?;
        println!("Server listening on port {}", self.port);
        
        for stream in listener.incoming() {
            match stream {
                Ok(mut stream) => {
                    match HttpRequest::parse(&mut stream) {
                        Ok(request) => {
                            let response = self.handle_request(&request);
                            let response_str = response.to_string();
                            
                            if let Err(e) = stream.write_all(response_str.as_bytes()) {
                                eprintln!("Failed to write response: {}", e);
                            }
                        }
                        Err(e) => {
                            eprintln!("Failed to parse request: {}", e);
                            let mut response = HttpResponse::new(400, "Bad Request");
                            response.set_body("Invalid request format".to_string());
                            let response_str = response.to_string();
                            
                            if let Err(e) = stream.write_all(response_str.as_bytes()) {
                                eprintln!("Failed to write error response: {}", e);
                            }
                        }
                    }
                }
                Err(e) => {
                    eprintln!("Failed to accept connection: {}", e);
                }
            }
        }
        
        Ok(())
    }
}

fn main() {
    let server = WebServer::new(8080);
    
    if let Err(e) = server.start() {
        eprintln!("Server error: {}", e);
    }
}

fn create_test_files() {
    let _ = fs::write("/tmp/test.txt", "This is a test file");
    let _ = fs::write("/tmp/sensitive.txt", "Sensitive information here");
}

fn cleanup_test_files() {
    let _ = fs::remove_file("/tmp/test.txt");
    let _ = fs::remove_file("/tmp/sensitive.txt");
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_request_parsing() {
        let request_data = "GET /test HTTP/1.1\r\nHost: localhost\r\n\r\n";
    }
    
    #[test]
    fn test_response_generation() {
        let mut response = HttpResponse::new(200, "OK");
        response.set_body("Hello World".to_string());
        assert!(response.to_string().contains("Hello World"));
    }
} 