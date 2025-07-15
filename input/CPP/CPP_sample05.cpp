#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <fstream>
#include <sstream>
#include <chrono>
#include <thread>
#include <mutex>
#include <random>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <cctype>
#include <openssl/sha.h>
#include <openssl/hmac.h>
#include <openssl/rand.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>


const int PORT = 8080;
const int MAX_CONNECTIONS = 10;
const int BUFFER_SIZE = 4096;
const int MAX_FILE_SIZE = 10 * 1024 * 1024; 
const int SESSION_TIMEOUT = 3600; 
const int MAX_LOGIN_ATTEMPTS = 5;
const int LOCKOUT_DURATION = 900; 
const std::string UPLOAD_DIR = "./uploads/";
const std::string LOG_FILE = "./server.log";


const std::vector<std::string> ALLOWED_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".pdf", ".doc", ".docx"
};


struct User {
    std::string id;
    std::string username;
    std::string email;
    std::string password_hash;
    std::string salt;
    std::string role;
    bool is_active;
    int failed_attempts;
    std::chrono::system_clock::time_point lockout_until;
    std::chrono::system_clock::time_point created_at;
    std::chrono::system_clock::time_point last_login;
};


struct Session {
    std::string user_id;
    std::string username;
    std::string role;
    std::chrono::system_clock::time_point created_at;
};


struct FileInfo {
    std::string id;
    std::string filename;
    std::string original_name;
    std::string file_path;
    size_t file_size;
    std::string uploaded_by;
    std::chrono::system_clock::time_point uploaded_at;
};

class Logger {
private:
    std::mutex log_mutex;
    std::ofstream log_file;

public:
    Logger() {
        log_file.open(LOG_FILE, std::ios::app);
    }

    ~Logger() {
        if (log_file.is_open()) {
            log_file.close();
        }
    }

    void log(const std::string& message, const std::string& level = "INFO") {
        std::lock_guard<std::mutex> lock(log_mutex);
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        std::string timestamp = std::ctime(&time_t);
        timestamp.pop_back(); 

        std::string log_entry = "[" + timestamp + "] [" + level + "] " + message + "\n";
        
        if (log_file.is_open()) {
            log_file << log_entry;
            log_file.flush();
        }
        
        std::cout << "[" << level << "] " << message << std::endl;
    }

    void error(const std::string& message) {
        log(message, "ERROR");
    }

    void warn(const std::string& message) {
        log(message, "WARN");
    }
};

class SecurityUtils {
private:
    Logger logger;

public:
    std::string generateSalt(size_t length = 32) {
        std::vector<unsigned char> salt_bytes(length);
        if (RAND_bytes(salt_bytes.data(), length) != 1) {
            logger.error("Failed to generate random salt");
            return "";
        }
        
        std::stringstream ss;
        for (unsigned char byte : salt_bytes) {
            ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(byte);
        }
        return ss.str();
    }

    std::string hashPassword(const std::string& password, const std::string& salt) {
        unsigned char hash[SHA256_DIGEST_LENGTH];
        std::string data = password + salt;
        
        SHA256_CTX sha256;
        SHA256_Init(&sha256);
        SHA256_Update(&sha256, data.c_str(), data.length());
        SHA256_Final(hash, &sha256);
        
        std::stringstream ss;
        for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
            ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
        }
        return ss.str();
    }

    bool verifyPassword(const std::string& password, const std::string& hash, const std::string& salt) {
        std::string computed_hash = hashPassword(password, salt);
        return hash == computed_hash;
    }

    std::string generateToken(const std::string& user_id, const std::string& username, const std::string& role) {
        auto now = std::chrono::system_clock::now();
        auto timestamp = std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();
        
        std::string payload = user_id + ":" + username + ":" + role + ":" + std::to_string(timestamp);
        
        unsigned char hmac[SHA256_DIGEST_LENGTH];
        unsigned int hmac_len;
        
        HMAC(EVP_sha256(), "secret_key", 10, 
             reinterpret_cast<const unsigned char*>(payload.c_str()), payload.length(),
             hmac, &hmac_len);
        
        std::stringstream ss;
        for (unsigned int i = 0; i < hmac_len; i++) {
            ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hmac[i]);
        }
        
        return payload + "." + ss.str();
    }

    bool verifyToken(const std::string& token) {
        size_t dot_pos = token.find_last_of('.');
        if (dot_pos == std::string::npos) {
            return false;
        }
        
        std::string payload = token.substr(0, dot_pos);
        std::string signature = token.substr(dot_pos + 1);
        
        unsigned char hmac[SHA256_DIGEST_LENGTH];
        unsigned int hmac_len;
        
        HMAC(EVP_sha256(), "secret_key", 10,
             reinterpret_cast<const unsigned char*>(payload.c_str()), payload.length(),
             hmac, &hmac_len);
        
        std::stringstream ss;
        for (unsigned int i = 0; i < hmac_len; i++) {
            ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hmac[i]);
        }
        
        return signature == ss.str();
    }

    std::string sanitizeInput(const std::string& input, const std::string& type = "text") {
        std::string sanitized = input;
        
        
        if (type == "html") {
            size_t pos = 0;
            while ((pos = sanitized.find('<')) != std::string::npos) {
                size_t end_pos = sanitized.find('>', pos);
                if (end_pos != std::string::npos) {
                    sanitized.erase(pos, end_pos - pos + 1);
                } else {
                    break;
                }
            }
        }
        
        
        if (type == "sql") {
            std::vector<std::string> sql_keywords = {
                "union", "select", "insert", "update", "delete", "drop", "create", "alter"
            };
            
            for (const auto& keyword : sql_keywords) {
                size_t pos = 0;
                while ((pos = sanitized.find(keyword, pos)) != std::string::npos) {
                    sanitized.erase(pos, keyword.length());
                }
            }
        }
        
        
        std::string invalid_chars = "<>:\"|?*";
        for (char c : invalid_chars) {
            sanitized.erase(std::remove(sanitized.begin(), sanitized.end(), c), sanitized.end());
        }
        
        return sanitized;
    }

    bool validateEmail(const std::string& email) {
        size_t at_pos = email.find('@');
        if (at_pos == std::string::npos) {
            return false;
        }
        
        size_t dot_pos = email.find('.', at_pos);
        if (dot_pos == std::string::npos) {
            return false;
        }
        
        return dot_pos > at_pos + 1 && dot_pos < email.length() - 1;
    }

    bool validatePassword(const std::string& password) {
        if (password.length() < 8) {
            return false;
        }
        
        bool has_upper = false, has_lower = false, has_digit = false;
        for (char c : password) {
            if (std::isupper(c)) has_upper = true;
            if (std::islower(c)) has_lower = true;
            if (std::isdigit(c)) has_digit = true;
        }
        
        return has_upper && has_lower && has_digit;
    }
};

class UserManager {
private:
    std::map<std::string, User> users;
    std::map<std::string, Session> sessions;
    std::map<std::string, std::pair<int, std::chrono::system_clock::time_point>> failed_attempts;
    std::mutex users_mutex;
    std::mutex sessions_mutex;
    Logger logger;
    SecurityUtils security_utils;

public:
    bool registerUser(const std::string& username, const std::string& email, 
                     const std::string& password, const std::string& role = "user") {
        std::lock_guard<std::mutex> lock(users_mutex);
        
        try {
            
            if (username.empty() || email.empty() || password.empty()) {
                logger.warn("Registration failed: Missing required fields");
                return false;
            }

            if (!security_utils.validateEmail(email)) {
                logger.warn("Registration failed: Invalid email format");
                return false;
            }

            if (!security_utils.validatePassword(password)) {
                logger.warn("Registration failed: Password does not meet requirements");
                return false;
            }

            
            for (const auto& pair : users) {
                if (pair.second.username == username || pair.second.email == email) {
                    logger.warn("Registration failed: User already exists");
                    return false;
                }
            }

            
            std::string salt = security_utils.generateSalt();
            std::string password_hash = security_utils.hashPassword(password, salt);

            
            User user;
            user.id = std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count());
            user.username = security_utils.sanitizeInput(username);
            user.email = security_utils.sanitizeInput(email);
            user.password_hash = password_hash;
            user.salt = salt;
            user.role = role;
            user.is_active = true;
            user.created_at = std::chrono::system_clock::now();
            user.failed_attempts = 0;

            users[user.id] = user;
            logger.log("User registered successfully: " + username);
            return true;

        } catch (const std::exception& e) {
            logger.error("Registration failed: " + std::string(e.what()));
            return false;
        }
    }

    std::string authenticateUser(const std::string& username, const std::string& password) {
        std::lock_guard<std::mutex> lock(users_mutex);
        
        try {
            
            User* user = nullptr;
            for (auto& pair : users) {
                if (pair.second.username == username) {
                    user = &pair.second;
                    break;
                }
            }

            if (!user) {
                recordFailedAttempt(username);
                return "";
            }

            
            if (user->lockout_until > std::chrono::system_clock::now()) {
                logger.warn("Account locked: " + username);
                return "";
            }

            
            if (!user->is_active) {
                logger.warn("Account deactivated: " + username);
                return "";
            }

            
            if (!security_utils.verifyPassword(password, user->password_hash, user->salt)) {
                recordFailedAttempt(username);
                return "";
            }

            
            user->failed_attempts = 0;
            user->last_login = std::chrono::system_clock::now();

            
            std::string token = security_utils.generateToken(user->id, user->username, user->role);
            
            
            Session session;
            session.user_id = user->id;
            session.username = user->username;
            session.role = user->role;
            session.created_at = std::chrono::system_clock::now();

            {
                std::lock_guard<std::mutex> session_lock(sessions_mutex);
                sessions[token] = session;
            }

            logger.log("User authenticated successfully: " + username);
            return token;

        } catch (const std::exception& e) {
            logger.error("Authentication failed: " + std::string(e.what()));
            return "";
        }
    }

    void recordFailedAttempt(const std::string& username) {
        auto now = std::chrono::system_clock::now();
        
        if (failed_attempts.find(username) == failed_attempts.end()) {
            failed_attempts[username] = {0, now};
        }

        failed_attempts[username].first++;

        if (failed_attempts[username].first >= MAX_LOGIN_ATTEMPTS) {
            auto lockout_until = now + std::chrono::seconds(LOCKOUT_DURATION);
            failed_attempts[username].second = lockout_until;
            logger.warn("Account locked: " + username);
        }
    }

    Session* validateSession(const std::string& token) {
        std::lock_guard<std::mutex> lock(sessions_mutex);
        
        if (sessions.find(token) == sessions.end()) {
            return nullptr;
        }

        Session& session = sessions[token];
        auto now = std::chrono::system_clock::now();
        
        if (now - session.created_at > std::chrono::seconds(SESSION_TIMEOUT)) {
            sessions.erase(token);
            return nullptr;
        }

        return &session;
    }

    bool logout(const std::string& token) {
        std::lock_guard<std::mutex> lock(sessions_mutex);
        
        if (sessions.find(token) != sessions.end()) {
            sessions.erase(token);
            logger.log("User logged out successfully");
            return true;
        }
        return false;
    }
};

class FileManager {
private:
    std::map<std::string, FileInfo> files;
    std::mutex files_mutex;
    Logger logger;

public:
    FileManager() {
        
        std::string command = "mkdir -p " + UPLOAD_DIR;
        system(command.c_str());
    }

    bool validateFilename(const std::string& filename) {
        
        if (filename.find("..") != std::string::npos || 
            filename.find("/") != std::string::npos || 
            filename.find("\\") != std::string::npos) {
            return false;
        }

        size_t dot_pos = filename.find_last_of('.');
        if (dot_pos == std::string::npos) {
            return false;
        }

        std::string extension = filename.substr(dot_pos);
        std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);
        
        return std::find(ALLOWED_EXTENSIONS.begin(), ALLOWED_EXTENSIONS.end(), extension) != ALLOWED_EXTENSIONS.end();
    }

    std::string uploadFile(const std::vector<char>& file_data, const std::string& filename, 
                          const std::string& user_id) {
        std::lock_guard<std::mutex> lock(files_mutex);
        
        try {
            if (!validateFilename(filename)) {
                logger.warn("File upload failed: Invalid filename: " + filename);
                return "";
            }

            if (file_data.size() > MAX_FILE_SIZE) {
                logger.warn("File upload failed: File too large: " + std::to_string(file_data.size()) + " bytes");
                return "";
            }

            auto now = std::chrono::system_clock::now();
            auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                now.time_since_epoch()).count();
            
            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_int_distribution<> dis(0, 999999);
            int random_num = dis(gen);
            
            size_t dot_pos = filename.find_last_of('.');
            std::string extension = (dot_pos != std::string::npos) ? filename.substr(dot_pos) : "";
            std::string safe_filename = std::to_string(timestamp) + "_" + 
                                      std::to_string(random_num) + extension;
            std::string file_path = UPLOAD_DIR + safe_filename;

            std::ofstream file(file_path, std::ios::binary);
            if (!file.is_open()) {
                logger.error("Failed to create file: " + file_path);
                return "";
            }

            file.write(file_data.data(), file_data.size());
            file.close();

            FileInfo file_info;
            file_info.id = std::to_string(timestamp);
            file_info.filename = safe_filename;
            file_info.original_name = filename;
            file_info.file_path = file_path;
            file_info.file_size = file_data.size();
            file_info.uploaded_by = user_id;
            file_info.uploaded_at = now;

            files[file_info.id] = file_info;
            logger.log("File uploaded successfully: " + safe_filename);
            return file_info.id;

        } catch (const std::exception& e) {
            logger.error("File upload failed: " + std::string(e.what()));
            return "";
        }
    }

    FileInfo* getFile(const std::string& file_id, const std::string& user_id) {
        std::lock_guard<std::mutex> lock(files_mutex);
        
        if (files.find(file_id) == files.end()) {
            return nullptr;
        }

        FileInfo& file_info = files[file_id];
        if (file_info.uploaded_by != user_id) {
            return nullptr;
        }

        std::ifstream file(file_info.file_path);
        if (!file.good()) {
            return nullptr;
        }

        return &file_info;
    }

    bool deleteFile(const std::string& file_id, const std::string& user_id) {
        std::lock_guard<std::mutex> lock(files_mutex);
        
        FileInfo* file_info = getFile(file_id, user_id);
        if (!file_info) {
            return false;
        }

        if (std::remove(file_info->file_path.c_str()) != 0) {
            logger.error("Failed to delete physical file: " + file_info->file_path);
        }

        files.erase(file_id);
        logger.log("File deleted successfully: " + file_info->filename);
        return true;
    }
};

class NetworkServer {
private:
    int server_socket;
    UserManager user_manager;
    FileManager file_manager;
    Logger logger;
    bool running;

public:
    NetworkServer() : running(false) {
    }

    ~NetworkServer() {
        if (server_socket > 0) {
            close(server_socket);
        }
    }

    bool start() {
        try {
            server_socket = socket(AF_INET, SOCK_STREAM, 0);
            if (server_socket < 0) {
                logger.error("Failed to create socket");
                return false;
            }

            int opt = 1;
            if (setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
                logger.error("Failed to set socket options");
                return false;
            }

            struct sockaddr_in address;
            address.sin_family = AF_INET;
            address.sin_addr.s_addr = INADDR_ANY;
            address.sin_port = htons(PORT);

            if (bind(server_socket, (struct sockaddr*)&address, sizeof(address)) < 0) {
                logger.error("Failed to bind socket");
                return false;
            }

            if (listen(server_socket, MAX_CONNECTIONS) < 0) {
                logger.error("Failed to listen on socket");
                return false;
            }

            running = true;
            logger.log("Server started on port " + std::to_string(PORT));
            return true;

        } catch (const std::exception& e) {
            logger.error("Server start failed: " + std::string(e.what()));
            return false;
        }
    }

    void run() {
        while (running) {
            struct sockaddr_in client_addr;
            socklen_t client_len = sizeof(client_addr);
            
            int client_socket = accept(server_socket, (struct sockaddr*)&client_addr, &client_len);
            if (client_socket < 0) {
                logger.error("Failed to accept connection");
                continue;
            }

            std::thread client_thread(&NetworkServer::handleClient, this, client_socket);
            client_thread.detach();
        }
    }

    void handleClient(int client_socket) {
        char buffer[BUFFER_SIZE];
        int bytes_read = recv(client_socket, buffer, BUFFER_SIZE - 1, 0);
        
        if (bytes_read > 0) {
            buffer[bytes_read] = '\0';
            std::string request(buffer);
            
            std::string response = "HTTP/1.1 200 OK\r\n";
            response += "Content-Type: application/json\r\n";
            response += "Content-Length: 25\r\n\r\n";
            response += "{\"status\": \"success\"}";
            
            send(client_socket, response.c_str(), response.length(), 0);
        }
        
        close(client_socket);
    }

    void stop() {
        running = false;
        logger.log("Server stopped");
    }
};

int main() {
    try {
        Logger logger;
        UserManager user_manager;
        FileManager file_manager;
        NetworkServer server;

        logger.log("Security-sensitive C++ server initializing...");

        if (user_manager.registerUser("testuser", "test@example.com", "SecurePass123")) {
            logger.log("Test user registered successfully");
        }

        std::string token = user_manager.authenticateUser("testuser", "SecurePass123");
        if (!token.empty()) {
            logger.log("User authenticated successfully");
            
            std::vector<char> file_data = {'H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd'};
            std::string file_id = file_manager.uploadFile(file_data, "test.txt", "1");
            if (!file_id.empty()) {
                logger.log("File uploaded successfully");
            }
        }

        if (server.start()) {
            server.run();
        }

    } catch (const std::exception& e) {
        std::cerr << "Application error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
} 