#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <sstream>
#include <fstream>
#include <cstring>
#include <cstdlib>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <thread>
#include <chrono>
#include <algorithm>
#include <regex>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <iomanip>

class RateLimiter {
private:
    struct ClientInfo {
        std::queue<std::chrono::steady_clock::time_point> requests;
        bool is_blocked;
        std::chrono::steady_clock::time_point block_until;
    };
    
    std::map<std::string, ClientInfo> clients;
    std::mutex mtx;
    const size_t max_requests;
    const std::chrono::seconds window;
    const std::chrono::minutes block_duration;

public:
    RateLimiter(size_t max_req = 100, 
                std::chrono::seconds win = std::chrono::seconds(60),
                std::chrono::minutes block = std::chrono::minutes(10))
        : max_requests(max_req), window(win), block_duration(block) {}
    
    bool should_allow_request(const std::string& client_ip) {
        std::lock_guard<std::mutex> lock(mtx);
        auto now = std::chrono::steady_clock::now();
        auto& client = clients[client_ip];
        
        if (client.is_blocked) {
            if (now < client.block_until) {
                return false;
            }
            client.is_blocked = false;
            client.requests = std::queue<std::chrono::steady_clock::time_point>();
        }
        
        while (!client.requests.empty() && 
               now - client.requests.front() > window) {
            client.requests.pop();
        }
        
        if (client.requests.size() >= max_requests) {
            client.is_blocked = true;
            client.block_until = now + block_duration;
            return false;
        }
        
        client.requests.push(now);
        return true;
    }
};

class RequestLogger {
private:
    std::ofstream log_file;
    std::mutex mtx;

public:
    RequestLogger(const std::string& filename = "http_requests.log") {
        log_file.open(filename, std::ios::app);
    }
    
    ~RequestLogger() {
        if (log_file.is_open()) {
            log_file.close();
        }
    }
    
    void log_request(const std::string& client_ip, 
                    const std::string& method,
                    const std::string& path,
                    int status_code,
                    const std::string& user_agent) {
        std::lock_guard<std::mutex> lock(mtx);
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        log_file << std::ctime(&time) << " " 
                << client_ip << " "
                << method << " "
                << path << " "
                << status_code << " "
                << user_agent << std::endl;
    }
};

class SecurityHeaders {
public:
    static std::map<std::string, std::string> get_default_security_headers() {
        return {
            {"X-Content-Type-Options", "nosniff"},
            {"X-Frame-Options", "DENY"},
            {"X-XSS-Protection", "1; mode=block"},
            {"Content-Security-Policy", "default-src 'self'"},
            {"Strict-Transport-Security", "max-age=31536000; includeSubDomains"},
            {"Referrer-Policy", "strict-origin-when-cross-origin"},
            {"Feature-Policy", "camera 'none'; microphone 'none'"}
        };
    }
};

class HTTPServer {
private:
    int server_socket;
    int port;
    bool running;
    std::map<std::string, std::string> routes;
    std::map<std::string, std::string> headers;
    RateLimiter rate_limiter;
    RequestLogger request_logger;
    std::atomic<size_t> active_connections{0};
    const size_t max_connections = 100;
    std::condition_variable connection_cv;
    std::mutex connection_mtx;
    
    struct HTTPRequest {
        std::string method;
        std::string path;
        std::string version;
        std::map<std::string, std::string> headers;
        std::string body;
        std::string client_ip;
    };
    
    struct HTTPResponse {
        int status_code;
        std::string status_text;
        std::map<std::string, std::string> headers;
        std::string body;
    };

public:
    HTTPServer(int port = 8080) : port(port), running(false) {
        headers = SecurityHeaders::get_default_security_headers();
    }
    
    ~HTTPServer() {
        if (server_socket > 0) {
            close(server_socket);
        }
    }
    
    bool start() {
        server_socket = socket(AF_INET, SOCK_STREAM, 0);
        if (server_socket < 0) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }
        
        int opt = 1;
        setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        struct sockaddr_in server_addr;
        memset(&server_addr, 0, sizeof(server_addr));
        server_addr.sin_family = AF_INET;
        server_addr.sin_addr.s_addr = INADDR_ANY;
        server_addr.sin_port = htons(port);
        
        if (bind(server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
            std::cerr << "Failed to bind socket" << std::endl;
            return false;
        }
        
        if (listen(server_socket, 10) < 0) {
            std::cerr << "Failed to listen on socket" << std::endl;
            return false;
        }
        
        running = true;
        std::cout << "Server listening on port " << port << std::endl;
        
        while (running) {
            struct sockaddr_in client_addr;
            socklen_t client_len = sizeof(client_addr);
            int client_socket = accept(server_socket, (struct sockaddr*)&client_addr, &client_len);
            
            if (client_socket < 0) {
                continue;
            }
            
            std::string client_ip = inet_ntoa(client_addr.sin_addr);
            
            if (!rate_limiter.should_allow_request(client_ip)) {
                HTTPResponse response;
                response.status_code = 429;
                response.status_text = "Too Many Requests";
                response.body = "Rate limit exceeded. Please try again later.";
                send_response(client_socket, response);
                close(client_socket);
                continue;
            }
            
            std::unique_lock<std::mutex> lock(connection_mtx);
            if (active_connections >= max_connections) {
                connection_cv.wait(lock, [this]() {
                    return active_connections < max_connections;
                });
            }
            active_connections++;
            lock.unlock();
            
            std::thread([this, client_socket, client_ip]() {
                handle_client(client_socket, client_ip);
                
                std::lock_guard<std::mutex> lock(connection_mtx);
                active_connections--;
                connection_cv.notify_one();
            }).detach();
        }
        
        return true;
    }
    
    void stop() {
        running = false;
    }
    
    void add_route(const std::string& path, const std::string& handler) {
        routes[path] = handler;
    }

private:
    void handle_client(int client_socket, const std::string& client_ip) {
        char buffer[4096];
        int bytes_received = recv(client_socket, buffer, sizeof(buffer) - 1, 0);
        
        if (bytes_received <= 0) {
            close(client_socket);
            return;
        }
        
        buffer[bytes_received] = '\0';
        
        HTTPRequest request = parse_request(buffer);
        request.client_ip = client_ip;
        HTTPResponse response = process_request(request);
        
        request_logger.log_request(
            client_ip,
            request.method,
            request.path,
            response.status_code,
            request.headers["User-Agent"]
        );
        
        send_response(client_socket, response);
        close(client_socket);
    }
    
    HTTPRequest parse_request(const std::string& raw_request) {
        HTTPRequest request;
        std::istringstream stream(raw_request);
        std::string line;
        
        if (std::getline(stream, line)) {
            std::istringstream line_stream(line);
            line_stream >> request.method >> request.path >> request.version;
        }
        
        while (std::getline(stream, line) && line != "\r") {
            if (line.empty() || line == "\r") break;
            
            size_t colon_pos = line.find(':');
            if (colon_pos != std::string::npos) {
                std::string key = line.substr(0, colon_pos);
                std::string value = line.substr(colon_pos + 1);
                
                value.erase(0, value.find_first_not_of(" \t"));
                
                if (!value.empty() && value.back() == '\r') {
                    value.pop_back();
                }
                
                request.headers[key] = value;
            }
        }
        
        std::string body;
        while (std::getline(stream, line)) {
            body += line + "\n";
        }
        request.body = body;
        
        return request;
    }
    
    std::string hash_password(const std::string& password) {
        unsigned char hash[SHA256_DIGEST_LENGTH];
        SHA256_CTX sha256;
        SHA256_Init(&sha256);
        SHA256_Update(&sha256, password.c_str(), password.length());
        SHA256_Final(hash, &sha256);
        
        std::stringstream ss;
        for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
            ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];
        }
        return ss.str();
    }
    
    bool validate_file_path(const std::string& path) {
        if (path.find("..") != std::string::npos) return false;
        if (path.find("~") != std::string::npos) return false;
        if (path[0] == '/') return false;
        return true;
    }
    
    bool validate_command(const std::string& command) {
        static const std::regex unsafe_patterns[] = {
            std::regex("rm\\s+[-rf]+"),
            std::regex(">[>&]"),
            std::regex("\\|"),
            std::regex(";"),
            std::regex("`"),
            std::regex("\\$\\("),
            std::regex("sudo"),
            std::regex("chmod")
        };
        
        for (const auto& pattern : unsafe_patterns) {
            if (std::regex_search(command, pattern)) {
                return false;
            }
        }
        return true;
    }
    
    HTTPResponse process_request(const HTTPRequest& request) {
        HTTPResponse response;
        response.status_code = 404;
        response.status_text = "Not Found";
        response.headers = SecurityHeaders::get_default_security_headers();
        response.headers["Content-Type"] = "text/html";
        
        if (request.method == "GET") {
            if (request.path == "/") {
                response.status_code = 200;
                response.status_text = "OK";
                response.body = "<html><body><h1>Welcome to Vulnerable Server</h1></body></html>";
            }
            else if (request.path.find("/file/") == 0) {
                std::string filename = request.path.substr(6);
                if (!validate_file_path(filename)) {
                    response.status_code = 403;
                    response.status_text = "Forbidden";
                    response.body = "Invalid file path";
                } else {
                    response = serve_file(filename);
                }
            }
            else if (request.path.find("/exec/") == 0) {
                std::string command = request.path.substr(6);
                if (!validate_command(command)) {
                    response.status_code = 403;
                    response.status_text = "Forbidden";
                    response.body = "Invalid command";
                } else {
                    response = execute_command(command);
                }
            }
            else if (request.path.find("/search") == 0) {
                size_t query_pos = request.path.find("?q=");
                if (query_pos != std::string::npos) {
                    std::string query = request.path.substr(query_pos + 3);
                    response = search_files(query);
                }
            }
        }
        else if (request.method == "POST") {
            if (request.path == "/upload") {
                response = handle_file_upload(request);
            }
            else if (request.path == "/login") {
                response = handle_login(request);
            }
        }
        
        return response;
    }
    
    HTTPResponse serve_file(const std::string& filename) {
        HTTPResponse response;
        response.status_code = 200;
        response.status_text = "OK";
        response.headers["Content-Type"] = "text/plain";
        
        std::ifstream file(filename);
        if (file.is_open()) {
            std::string content((std::istreambuf_iterator<char>(file)),
                               std::istreambuf_iterator<char>());
            response.body = content;
        } else {
            response.status_code = 404;
            response.status_text = "File Not Found";
            response.body = "File not found: " + filename;
        }
        
        return response;
    }
    
    HTTPResponse execute_command(const std::string& command) {
        HTTPResponse response;
        response.status_code = 200;
        response.status_text = "OK";
        response.headers["Content-Type"] = "text/plain";
        
        std::string full_command = command + " 2>&1";
        FILE* pipe = popen(full_command.c_str(), "r");
        
        if (pipe) {
            char buffer[128];
            std::string result;
            
            while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
                result += buffer;
            }
            
            pclose(pipe);
            response.body = result;
        } else {
            response.status_code = 500;
            response.status_text = "Internal Server Error";
            response.body = "Failed to execute command";
        }
        
        return response;
    }
    
    HTTPResponse search_files(const std::string& query) {
        HTTPResponse response;
        response.status_code = 200;
        response.status_text = "OK";
        response.headers["Content-Type"] = "text/html";
        
        std::string command = "find . -name '*" + query + "*' -type f 2>/dev/null";
        FILE* pipe = popen(command.c_str(), "r");
        
        std::string result = "<html><body><h1>Search Results</h1><ul>";
        
        if (pipe) {
            char buffer[256];
            while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
                std::string line(buffer);
                line.erase(line.find_last_not_of("\n\r") + 1);
                result += "<li>" + line + "</li>";
            }
            pclose(pipe);
        }
        
        result += "</ul></body></html>";
        response.body = result;
        
        return response;
    }
    
    HTTPResponse handle_file_upload(const HTTPRequest& request) {
        HTTPResponse response;
        response.status_code = 200;
        response.status_text = "OK";
        response.headers["Content-Type"] = "text/html";
        
        std::string filename = "upload_" + std::to_string(std::chrono::system_clock::now().time_since_epoch().count());
        std::ofstream file(filename);
        
        if (file.is_open()) {
            file << request.body;
            file.close();
            response.body = "<html><body><h1>File uploaded successfully</h1></body></html>";
        } else {
            response.status_code = 500;
            response.status_text = "Internal Server Error";
            response.body = "<html><body><h1>Upload failed</h1></body></html>";
        }
        
        return response;
    }
    
    HTTPResponse handle_login(const HTTPRequest& request) {
        HTTPResponse response;
        response.status_code = 200;
        response.status_text = "OK";
        response.headers["Content-Type"] = "text/html";
        
        std::string body = request.body;
        size_t user_pos = body.find("username=");
        size_t pass_pos = body.find("password=");
        
        if (user_pos != std::string::npos && pass_pos != std::string::npos) {
            std::string username = body.substr(user_pos + 9, body.find('&', user_pos) - user_pos - 9);
            std::string password = body.substr(pass_pos + 9);
            std::string hashed_password = hash_password(password);
            
            if (username == "admin" && password == "admin123") {
                response.body = "<html><body><h1>Login successful</h1></body></html>";
                response.headers["Set-Cookie"] = "session=admin; HttpOnly; Secure; SameSite=Strict";
            } else {
                response.body = "<html><body><h1>Login failed</h1></body></html>";
            }
        } else {
            response.body = "<html><body><h1>Invalid login data</h1></body></html>";
        }
        
        return response;
    }
    
    void send_response(int client_socket, const HTTPResponse& response) {
        std::string response_str = "HTTP/1.1 " + std::to_string(response.status_code) + 
                                 " " + response.status_text + "\r\n";
        
        for (const auto& header : response.headers) {
            response_str += header.first + ": " + header.second + "\r\n";
        }
        
        response_str += "Content-Length: " + std::to_string(response.body.length()) + "\r\n";
        response_str += "\r\n";
        response_str += response.body;
        
        send(client_socket, response_str.c_str(), response_str.length(), 0);
    }
};

int main(int argc, char* argv[]) {
    int port = 8080;
    
    if (argc > 1) {
        port = std::atoi(argv[1]);
    }
    
    HTTPServer server(port);
    
    server.add_route("/", "index");
    server.add_route("/file", "file_handler");
    server.add_route("/exec", "command_handler");
    server.add_route("/search", "search_handler");
    server.add_route("/upload", "upload_handler");
    server.add_route("/login", "login_handler");
    
    std::cout << "Starting vulnerable HTTP server on port " << port << std::endl;
    std::cout << "Available endpoints:" << std::endl;
    std::cout << "  GET /file/<filename> - Read file" << std::endl;
    std::cout << "  GET /exec/<command> - Execute command" << std::endl;
    std::cout << "  GET /search?q=<query> - Search files" << std::endl;
    std::cout << "  POST /upload - Upload file" << std::endl;
    std::cout << "  POST /login - Login (admin/admin123)" << std::endl;
    
    server.start();
    
    return 0;
} 