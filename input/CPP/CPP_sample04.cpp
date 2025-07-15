#include <iostream>
#include <string>
#include <vector>
#include <memory>
#include <thread>
#include <future>
#include <chrono>
#include <mutex>
#include <atomic>
#include <queue>
#include <functional>
#include <sstream>
#include <fstream>
#include <random>
#include <map>


#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #pragma comment(lib, "ws2_32.lib")
    using socket_t = SOCKET;
    #define CLOSE_SOCKET closesocket
#else
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <unistd.h>
    #include <netdb.h>
    using socket_t = int;
    #define INVALID_SOCKET -1
    #define CLOSE_SOCKET close
#endif

namespace NetworkLib {


class Socket {
private:
    socket_t socket_;
    bool connected_;
    std::string host_;
    int port_;
    
public:
    Socket() : socket_(INVALID_SOCKET), connected_(false), port_(0) {
#ifdef _WIN32
        WSADATA wsaData;
        if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
            throw std::runtime_error("Failed to initialize Winsock");
        }
#endif
    }
    
    ~Socket() {
        disconnect();
#ifdef _WIN32
        WSACleanup();
#endif
    }
    
    
    Socket(Socket&& other) noexcept 
        : socket_(other.socket_), connected_(other.connected_), 
          host_(std::move(other.host_)), port_(other.port_) {
        other.socket_ = INVALID_SOCKET;
        other.connected_ = false;
    }
    
    Socket& operator=(Socket&& other) noexcept {
        if (this != &other) {
            disconnect();
            socket_ = other.socket_;
            connected_ = other.connected_;
            host_ = std::move(other.host_);
            port_ = other.port_;
            other.socket_ = INVALID_SOCKET;
            other.connected_ = false;
        }
        return *this;
    }
    
    
    Socket(const Socket&) = delete;
    Socket& operator=(const Socket&) = delete;
    
    bool connect(const std::string& host, int port) {
        if (connected_) {
            disconnect();
        }
        
        socket_ = socket(AF_INET, SOCK_STREAM, 0);
        if (socket_ == INVALID_SOCKET) {
            return false;
        }
        
        struct sockaddr_in server_addr{};
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(static_cast<uint16_t>(port));
        
        
        struct hostent* host_entry = gethostbyname(host.c_str());
        if (!host_entry) {
            inet_pton(AF_INET, host.c_str(), &server_addr.sin_addr);
        } else {
            memcpy(&server_addr.sin_addr, host_entry->h_addr_list[0], host_entry->h_length);
        }
        
        if (::connect(socket_, reinterpret_cast<struct sockaddr*>(&server_addr), sizeof(server_addr)) == 0) {
            connected_ = true;
            host_ = host;
            port_ = port;
            return true;
        }
        
        CLOSE_SOCKET(socket_);
        socket_ = INVALID_SOCKET;
        return false;
    }
    
    void disconnect() {
        if (socket_ != INVALID_SOCKET) {
            CLOSE_SOCKET(socket_);
            socket_ = INVALID_SOCKET;
        }
        connected_ = false;
    }
    
    ssize_t send(const std::string& data) {
        if (!connected_) return -1;
        return ::send(socket_, data.c_str(), data.length(), 0);
    }
    
    std::string receive(size_t max_size = 4096) {
        if (!connected_) return "";
        
        std::vector<char> buffer(max_size);
        ssize_t bytes_received = recv(socket_, buffer.data(), max_size - 1, 0);
        
        if (bytes_received > 0) {
            buffer[bytes_received] = '\0';
            return std::string(buffer.data(), bytes_received);
        }
        
        return "";
    }
    
    bool is_connected() const { return connected_; }
    const std::string& get_host() const { return host_; }
    int get_port() const { return port_; }
};


class HttpClient {
private:
    Socket socket_;
    std::chrono::seconds timeout_;
    std::map<std::string, std::string> default_headers_;
    
    struct HttpResponse {
        int status_code;
        std::string status_message;
        std::map<std::string, std::string> headers;
        std::string body;
        
        bool is_success() const { return status_code >= 200 && status_code < 300; }
    };
    
    std::string build_request(const std::string& method, const std::string& path,
                            const std::map<std::string, std::string>& headers,
                            const std::string& body = "") {
        std::ostringstream request;
        request << method << " " << path << " HTTP/1.1\r\n";
        
        
        for (const auto& [key, value] : default_headers_) {
            request << key << ": " << value << "\r\n";
        }
        
        
        for (const auto& [key, value] : headers) {
            request << key << ": " << value << "\r\n";
        }
        
        if (!body.empty()) {
            request << "Content-Length: " << body.length() << "\r\n";
        }
        
        request << "\r\n" << body;
        return request.str();
    }
    
    HttpResponse parse_response(const std::string& response_data) {
        HttpResponse response{};
        std::istringstream stream(response_data);
        std::string line;
        
        
        if (std::getline(stream, line)) {
            std::istringstream status_stream(line);
            std::string http_version;
            status_stream >> http_version >> response.status_code;
            std::getline(status_stream, response.status_message);
        }
        
        
        while (std::getline(stream, line) && line != "\r") {
            auto colon_pos = line.find(':');
            if (colon_pos != std::string::npos) {
                std::string key = line.substr(0, colon_pos);
                std::string value = line.substr(colon_pos + 2); 
                value.pop_back(); 
                response.headers[key] = value;
            }
        }
        
        
        std::ostringstream body_stream;
        while (std::getline(stream, line)) {
            body_stream << line << "\n";
        }
        response.body = body_stream.str();
        
        return response;
    }
    
public:
    HttpClient() : timeout_(std::chrono::seconds(30)) {
        default_headers_["User-Agent"] = "CustomHttpClient/1.0";
        default_headers_["Connection"] = "close";
    }
    
    void set_timeout(std::chrono::seconds timeout) {
        timeout_ = timeout;
    }
    
    void set_default_header(const std::string& key, const std::string& value) {
        default_headers_[key] = value;
    }
    
    std::future<HttpResponse> get_async(const std::string& url) {
        return std::async(std::launch::async, [this, url]() {
            return this->get(url);
        });
    }
    
    HttpResponse get(const std::string& url) {
        return request("GET", url, {});
    }
    
    HttpResponse post(const std::string& url, const std::string& data, 
                     const std::string& content_type = "application/json") {
        std::map<std::string, std::string> headers;
        headers["Content-Type"] = content_type;
        return request("POST", url, headers, data);
    }
    
    HttpResponse request(const std::string& method, const std::string& url,
                        const std::map<std::string, std::string>& headers,
                        const std::string& body = "") {
        
        std::string host, path;
        int port = 80;
        
        if (url.substr(0, 7) == "http://") {
            auto url_part = url.substr(7);
            auto path_pos = url_part.find('/');
            if (path_pos != std::string::npos) {
                host = url_part.substr(0, path_pos);
                path = url_part.substr(path_pos);
            } else {
                host = url_part;
                path = "/";
            }
            
            auto port_pos = host.find(':');
            if (port_pos != std::string::npos) {
                port = std::stoi(host.substr(port_pos + 1));
                host = host.substr(0, port_pos);
            }
        }
        
        if (host.empty()) {
            throw std::invalid_argument("Invalid URL format");
        }
        
        
        if (!socket_.connect(host, port)) {
            throw std::runtime_error("Failed to connect to " + host + ":" + std::to_string(port));
        }
        
        auto updated_headers = headers;
        updated_headers["Host"] = host;
        
        std::string request_str = build_request(method, path, updated_headers, body);
        
        if (socket_.send(request_str) <= 0) {
            throw std::runtime_error("Failed to send request");
        }
        
        
        std::string response_data = socket_.receive(8192);
        socket_.disconnect();
        
        if (response_data.empty()) {
            throw std::runtime_error("No response received");
        }
        
        return parse_response(response_data);
    }
};


class ConnectionPool {
private:
    struct PooledConnection {
        std::unique_ptr<Socket> socket;
        std::chrono::steady_clock::time_point last_used;
        std::string host;
        int port;
    };
    
    std::vector<PooledConnection> pool_;
    mutable std::mutex pool_mutex_;
    std::chrono::seconds max_idle_time_;
    std::atomic<bool> cleanup_running_;
    std::thread cleanup_thread_;
    
    void cleanup_expired_connections() {
        while (cleanup_running_) {
            {
                std::lock_guard<std::mutex> lock(pool_mutex_);
                auto now = std::chrono::steady_clock::now();
                
                pool_.erase(
                    std::remove_if(pool_.begin(), pool_.end(),
                        [this, now](const PooledConnection& conn) {
                            return now - conn.last_used > max_idle_time_;
                        }),
                    pool_.end()
                );
            }
            
            std::this_thread::sleep_for(std::chrono::seconds(10));
        }
    }
    
public:
    ConnectionPool(std::chrono::seconds max_idle = std::chrono::seconds(300)) 
        : max_idle_time_(max_idle), cleanup_running_(true) {
        cleanup_thread_ = std::thread(&ConnectionPool::cleanup_expired_connections, this);
    }
    
    ~ConnectionPool() {
        cleanup_running_ = false;
        if (cleanup_thread_.joinable()) {
            cleanup_thread_.join();
        }
    }
    
    std::unique_ptr<Socket> get_connection(const std::string& host, int port) {
        {
            std::lock_guard<std::mutex> lock(pool_mutex_);
            
            auto it = std::find_if(pool_.begin(), pool_.end(),
                [&host, port](const PooledConnection& conn) {
                    return conn.host == host && conn.port == port && conn.socket->is_connected();
                });
            
            if (it != pool_.end()) {
                auto socket = std::move(it->socket);
                pool_.erase(it);
                return socket;
            }
        }
        
        
        auto socket = std::make_unique<Socket>();
        if (socket->connect(host, port)) {
            return socket;
        }
        
        return nullptr;
    }
    
    void return_connection(std::unique_ptr<Socket> socket) {
        if (socket && socket->is_connected()) {
            std::lock_guard<std::mutex> lock(pool_mutex_);
            
            PooledConnection conn;
            conn.socket = std::move(socket);
            conn.last_used = std::chrono::steady_clock::now();
            conn.host = conn.socket->get_host();
            conn.port = conn.socket->get_port();
            
            pool_.push_back(std::move(conn));
        }
    }
    
    size_t size() const {
        std::lock_guard<std::mutex> lock(pool_mutex_);
        return pool_.size();
    }
};


class DownloadManager {
private:
    std::unique_ptr<ConnectionPool> pool_;
    std::vector<std::thread> worker_threads_;
    std::queue<std::function<void()>> task_queue_;
    mutable std::mutex queue_mutex_;
    std::condition_variable queue_cv_;
    std::atomic<bool> shutdown_;
    
    void worker_loop() {
        while (!shutdown_) {
            std::function<void()> task;
            
            {
                std::unique_lock<std::mutex> lock(queue_mutex_);
                queue_cv_.wait(lock, [this] { return !task_queue_.empty() || shutdown_; });
                
                if (shutdown_) break;
                
                task = std::move(task_queue_.front());
                task_queue_.pop();
            }
            
            try {
                task();
            } catch (const std::exception& e) {
                std::cout << "Worker thread error: " << e.what() << "\n";
            }
        }
    }
    
public:
    DownloadManager(size_t num_threads = std::thread::hardware_concurrency()) 
        : pool_(std::make_unique<ConnectionPool>()), shutdown_(false) {
        
        for (size_t i = 0; i < num_threads; ++i) {
            worker_threads_.emplace_back(&DownloadManager::worker_loop, this);
        }
    }
    
    ~DownloadManager() {
        shutdown_ = true;
        queue_cv_.notify_all();
        
        for (auto& thread : worker_threads_) {
            if (thread.joinable()) {
                thread.join();
            }
        }
    }
    
    std::future<bool> download_file_async(const std::string& url, const std::string& filename) {
        auto promise = std::make_shared<std::promise<bool>>();
        auto future = promise->get_future();
        
        {
            std::lock_guard<std::mutex> lock(queue_mutex_);
            task_queue_.push([this, url, filename, promise]() {
                try {
                    HttpClient client;
                    auto response = client.get(url);
                    
                    if (response.is_success()) {
                        std::ofstream file(filename, std::ios::binary);
                        file << response.body;
                        promise->set_value(true);
                    } else {
                        promise->set_value(false);
                    }
                } catch (...) {
                    promise->set_value(false);
                }
            });
        }
        
        queue_cv_.notify_one();
        return future;
    }
    
    size_t get_queue_size() const {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        return task_queue_.size();
    }
};

} 


void demonstrateBasicNetworking() {
    using namespace NetworkLib;
    
    std::cout << "=== Basic Networking Demo ===\n";
    
    try {
        Socket socket;
        if (socket.connect("httpbin.org", 80)) {
            std::cout << "Connected to httpbin.org:80\n";
            
            std::string request = "GET /get HTTP/1.1\r\nHost: httpbin.org\r\nConnection: close\r\n\r\n";
            socket.send(request);
            
            std::string response = socket.receive();
            std::cout << "Response (first 200 chars): " 
                      << response.substr(0, 200) << "...\n";
        } else {
            std::cout << "Failed to connect to httpbin.org\n";
        }
    } catch (const std::exception& e) {
        std::cout << "Socket error: " << e.what() << "\n";
    }
}

void demonstrateHttpClient() {
    using namespace NetworkLib;
    
    std::cout << "\n=== HTTP Client Demo ===\n";
    
    try {
        HttpClient client;
        client.set_default_header("Accept", "application/json");
        
        
        auto response = client.get("http://httpbin.org/json");
        std::cout << "HTTP Status: " << response.status_code << "\n";
        std::cout << "Response body (first 100 chars): " 
                  << response.body.substr(0, 100) << "...\n";
        
        
        auto future_response = client.get_async("http://httpbin.org/headers");
        std::cout << "Making async request...\n";
        
        auto async_response = future_response.get();
        std::cout << "Async response status: " << async_response.status_code << "\n";
        
    } catch (const std::exception& e) {
        std::cout << "HTTP Client error: " << e.what() << "\n";
    }
}

void demonstrateDownloadManager() {
    using namespace NetworkLib;
    
    std::cout << "\n=== Download Manager Demo ===\n";
    
    try {
        DownloadManager manager(2); 
        
        
        std::vector<std::future<bool>> downloads;
        
        downloads.push_back(manager.download_file_async("http://httpbin.org/json", "download1.json"));
        downloads.push_back(manager.download_file_async("http://httpbin.org/xml", "download2.xml"));
        downloads.push_back(manager.download_file_async("http://httpbin.org/html", "download3.html"));
        
        std::cout << "Queued " << downloads.size() << " downloads\n";
        std::cout << "Queue size: " << manager.get_queue_size() << "\n";
        
        
        int successful = 0;
        for (auto& download : downloads) {
            if (download.get()) {
                successful++;
            }
        }
        
        std::cout << "Completed " << successful << "/" << downloads.size() << " downloads successfully\n";
        
    } catch (const std::exception& e) {
        std::cout << "Download Manager error: " << e.what() << "\n";
    }
}

void demonstrateConnectionPool() {
    using namespace NetworkLib;
    
    std::cout << "\n=== Connection Pool Demo ===\n";
    
    ConnectionPool pool;
    std::cout << "Initial pool size: " << pool.size() << "\n";
    
    
    auto conn1 = pool.get_connection("httpbin.org", 80);
    auto conn2 = pool.get_connection("httpbin.org", 80);
    
    if (conn1) {
        std::cout << "Got connection 1 to " << conn1->get_host() << ":" << conn1->get_port() << "\n";
    }
    
    if (conn2) {
        std::cout << "Got connection 2 to " << conn2->get_host() << ":" << conn2->get_port() << "\n";
    }
    
    
    pool.return_connection(std::move(conn1));
    pool.return_connection(std::move(conn2));
    
    std::cout << "Pool size after returning connections: " << pool.size() << "\n";
}

int main() {
    std::cout << "Modern C++ Network Programming Demo\n";
    std::cout << "===================================\n\n";
    
    demonstrateBasicNetworking();
    demonstrateHttpClient();
    demonstrateDownloadManager();
    demonstrateConnectionPool();
    
    std::cout << "\n=== Network Programming Demo Complete ===\n";
    return 0;
} 