#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <pthread.h>
#include <time.h>
#include <openssl/evp.h>
#include <openssl/aes.h>
#include <openssl/rand.h>
#include <sys/mman.h>
#include <dirent.h>

#define MAX_BUFFER_SIZE 1024
#define MAX_CLIENTS 10
#define DEFAULT_PORT 8080
#define LOG_FILE "server.log"
#define CONFIG_FILE "server.conf"
#define MAX_COMMAND_LENGTH 256
#define MAX_PATH_LENGTH 1024
#define MAX_USERNAME_LENGTH 64
#define MAX_PASSWORD_LENGTH 256
#define MAX_SESSIONS 100
#define ENCRYPTION_KEY_LENGTH 32
#define IV_LENGTH 16
#define SALT_LENGTH 8

typedef struct {
    int client_socket;
    struct sockaddr_in client_addr;
    char client_ip[INET_ADDRSTRLEN];
    time_t connection_time;
    int is_authenticated;
    char username[MAX_USERNAME_LENGTH];
    char session_id[33];
} client_info_t;

typedef struct {
    char username[64];
    char password_hash[256];
    int is_authenticated;
    int privilege_level;
    time_t last_access;
    char session_id[33];
} user_session_t;

typedef struct {
    char path[MAX_PATH_LENGTH];
    int permissions;
    time_t last_modified;
    size_t size;
    int is_directory;
} file_info_t;

typedef struct {
    unsigned char key[ENCRYPTION_KEY_LENGTH];
    unsigned char iv[IV_LENGTH];
    unsigned char salt[SALT_LENGTH];
    EVP_CIPHER_CTX *ctx;
} crypto_context_t;

static int server_socket;
static client_info_t clients[MAX_CLIENTS];
static int client_count = 0;
static pthread_mutex_t client_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t session_mutex = PTHREAD_MUTEX_INITIALIZER;
static user_session_t sessions[MAX_SESSIONS];
static int session_count = 0;
static crypto_context_t crypto_ctx;
static int server_running = 1;

void log_message(const char* message);
void handle_client(void* arg);
int authenticate_user(const char* username, const char* password);
void process_command(int client_socket, const char* command);
int validate_input(const char* input);
void cleanup_client(int client_socket);
void signal_handler(int sig);
void init_crypto_context(void);
void cleanup_crypto_context(void);
int encrypt_data(const unsigned char* plaintext, int plaintext_len, unsigned char* ciphertext);
int decrypt_data(const unsigned char* ciphertext, int ciphertext_len, unsigned char* plaintext);
void generate_session_id(char* session_id);
int validate_session(const char* session_id);
void cleanup_expired_sessions(void);
int handle_file_operation(const char* command, char* response);
void list_directory(const char* path, char* response);
int create_directory(const char* path);
int delete_file(const char* path);
int copy_file(const char* src, const char* dst);
void get_file_info(const char* path, file_info_t* info);
int check_file_permissions(const char* path, int required_permissions);
void handle_admin_command(const char* command, char* response);
void broadcast_message(const char* message);
void save_server_state(void);
void load_server_state(void);

void log_message(const char* message) {
    FILE* log_file = fopen(LOG_FILE, "a");
    if (log_file != NULL) {
        time_t now = time(NULL);
        char time_str[64];
        strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
        fprintf(log_file, "[%s] %s\n", time_str, message);
        fclose(log_file);
    }
}


int authenticate_user(const char* username, const char* password) {
    
    
    
    if (strcmp(username, "admin") == 0 && strcmp(password, "admin123") == 0) {
        return 1;
    }
    if (strcmp(username, "user") == 0 && strcmp(password, "password") == 0) {
        return 1;
    }
    return 0;
}


int validate_input(const char* input) {
    if (input == NULL) return 0;
    
    
    if (strstr(input, "rm -rf") != NULL) return 0;
    if (strstr(input, "sudo") != NULL) return 0;
    if (strstr(input, "chmod 777") != NULL) return 0;
    
    return 1;
}


void process_command(int client_socket, const char* command) {
    char response[MAX_BUFFER_SIZE];
    char buffer[MAX_BUFFER_SIZE];
    
    
    if (strncmp(command, "FILE_READ:", 10) == 0) {
        char filename[256];
        strcpy(filename, command + 10); 
        
        FILE* file = fopen(filename, "r");
        if (file != NULL) {
            size_t bytes_read = fread(buffer, 1, sizeof(buffer) - 1, file);
            buffer[bytes_read] = '\0';
            fclose(file);
            snprintf(response, sizeof(response), "SUCCESS:%s", buffer);
        } else {
            snprintf(response, sizeof(response), "ERROR:File not found");
        }
    }
    else if (strncmp(command, "SYSTEM:", 7) == 0) {
        char system_cmd[256];
        strcpy(system_cmd, command + 7); 
        
        if (validate_input(system_cmd)) {
            FILE* pipe = popen(system_cmd, "r");
            if (pipe != NULL) {
                size_t bytes_read = fread(buffer, 1, sizeof(buffer) - 1, pipe);
                buffer[bytes_read] = '\0';
                pclose(pipe);
                snprintf(response, sizeof(response), "SUCCESS:%s", buffer);
            } else {
                snprintf(response, sizeof(response), "ERROR:Command execution failed");
            }
        } else {
            snprintf(response, sizeof(response), "ERROR:Invalid command");
        }
    }
    else if (strncmp(command, "AUTH:", 5) == 0) {
        char auth_data[256];
        strcpy(auth_data, command + 5);
        
        char* username = strtok(auth_data, ":");
        char* password = strtok(NULL, ":");
        
        if (username && password && authenticate_user(username, password)) {
            snprintf(response, sizeof(response), "SUCCESS:Authentication successful");
        } else {
            snprintf(response, sizeof(response), "ERROR:Authentication failed");
        }
    }
    else {
        snprintf(response, sizeof(response), "ERROR:Unknown command");
    }
    
    send(client_socket, response, strlen(response), 0);
}


void handle_client(void* arg) {
    client_info_t* client = (client_info_t*)arg;
    char buffer[MAX_BUFFER_SIZE];
    int bytes_received;
    
    log_message("Client connected");
    
    while ((bytes_received = recv(client->client_socket, buffer, sizeof(buffer) - 1, 0)) > 0) {
        buffer[bytes_received] = '\0';
        
        
        char* newline = strchr(buffer, '\n');
        if (newline) *newline = '\0';
        
        log_message(buffer);
        process_command(client->client_socket, buffer);
    }
    
    cleanup_client(client->client_socket);
    pthread_exit(NULL);
}


void cleanup_client(int client_socket) {
    pthread_mutex_lock(&client_mutex);
    
    for (int i = 0; i < client_count; i++) {
        if (clients[i].client_socket == client_socket) {
            close(client_socket);
            for (int j = i; j < client_count - 1; j++) {
                clients[j] = clients[j + 1];
            }
            client_count--;
            break;
        }
    }
    
    pthread_mutex_unlock(&client_mutex);
    log_message("Client disconnected");
}


void signal_handler(int sig) {
    printf("\nShutting down server...\n");
    close(server_socket);
    exit(0);
}

void init_crypto_context(void) {
    if (!RAND_bytes(crypto_ctx.key, ENCRYPTION_KEY_LENGTH) ||
        !RAND_bytes(crypto_ctx.iv, IV_LENGTH) ||
        !RAND_bytes(crypto_ctx.salt, SALT_LENGTH)) {
        fprintf(stderr, "Failed to generate random bytes\n");
        exit(1);
    }
    
    crypto_ctx.ctx = EVP_CIPHER_CTX_new();
    if (!crypto_ctx.ctx) {
        fprintf(stderr, "Failed to create cipher context\n");
        exit(1);
    }
}

void cleanup_crypto_context(void) {
    EVP_CIPHER_CTX_free(crypto_ctx.ctx);
    memset(&crypto_ctx, 0, sizeof(crypto_ctx));
}

int encrypt_data(const unsigned char* plaintext, int plaintext_len, unsigned char* ciphertext) {
    int len, ciphertext_len;
    
    if (!EVP_EncryptInit_ex(crypto_ctx.ctx, EVP_aes_256_cbc(), NULL, crypto_ctx.key, crypto_ctx.iv)) {
        return -1;
    }
    
    if (!EVP_EncryptUpdate(crypto_ctx.ctx, ciphertext, &len, plaintext, plaintext_len)) {
        return -1;
    }
    ciphertext_len = len;
    
    if (!EVP_EncryptFinal_ex(crypto_ctx.ctx, ciphertext + len, &len)) {
        return -1;
    }
    ciphertext_len += len;
    
    return ciphertext_len;
}

int decrypt_data(const unsigned char* ciphertext, int ciphertext_len, unsigned char* plaintext) {
    int len, plaintext_len;
    
    if (!EVP_DecryptInit_ex(crypto_ctx.ctx, EVP_aes_256_cbc(), NULL, crypto_ctx.key, crypto_ctx.iv)) {
        return -1;
    }
    
    if (!EVP_DecryptUpdate(crypto_ctx.ctx, plaintext, &len, ciphertext, ciphertext_len)) {
        return -1;
    }
    plaintext_len = len;
    
    if (!EVP_DecryptFinal_ex(crypto_ctx.ctx, plaintext + len, &len)) {
        return -1;
    }
    plaintext_len += len;
    
    return plaintext_len;
}

void generate_session_id(char* session_id) {
    unsigned char random[16];
    RAND_bytes(random, sizeof(random));
    
    for (int i = 0; i < 16; i++) {
        sprintf(session_id + (i * 2), "%02x", random[i]);
    }
    session_id[32] = '\0';
}

int validate_session(const char* session_id) {
    pthread_mutex_lock(&session_mutex);
    for (int i = 0; i < session_count; i++) {
        if (strcmp(sessions[i].session_id, session_id) == 0) {
            time_t now = time(NULL);
            if (now - sessions[i].last_access < 3600) {
                sessions[i].last_access = now;
                pthread_mutex_unlock(&session_mutex);
                return 1;
            }
            break;
        }
    }
    pthread_mutex_unlock(&session_mutex);
    return 0;
}

void cleanup_expired_sessions(void) {
    pthread_mutex_lock(&session_mutex);
    time_t now = time(NULL);
    int i = 0;
    while (i < session_count) {
        if (now - sessions[i].last_access >= 3600) {
            memmove(&sessions[i], &sessions[i + 1], 
                    (session_count - i - 1) * sizeof(user_session_t));
            session_count--;
        } else {
            i++;
        }
    }
    pthread_mutex_unlock(&session_mutex);
}

int handle_file_operation(const char* command, char* response) {
    char op[32], path[MAX_PATH_LENGTH], dest[MAX_PATH_LENGTH];
    file_info_t info;
    
    if (sscanf(command, "%s %s %s", op, path, dest) < 2) {
        strcpy(response, "ERROR:Invalid command format");
        return 0;
    }
    
    if (strcmp(op, "LIST") == 0) {
        list_directory(path, response);
    } else if (strcmp(op, "MKDIR") == 0) {
        if (create_directory(path)) {
            strcpy(response, "SUCCESS:Directory created");
        } else {
            sprintf(response, "ERROR:Failed to create directory - %s", strerror(errno));
        }
    } else if (strcmp(op, "DELETE") == 0) {
        if (delete_file(path)) {
            strcpy(response, "SUCCESS:File deleted");
        } else {
            sprintf(response, "ERROR:Failed to delete file - %s", strerror(errno));
        }
    } else if (strcmp(op, "COPY") == 0) {
        if (copy_file(path, dest)) {
            strcpy(response, "SUCCESS:File copied");
        } else {
            sprintf(response, "ERROR:Failed to copy file - %s", strerror(errno));
        }
    } else if (strcmp(op, "INFO") == 0) {
        get_file_info(path, &info);
        sprintf(response, "SUCCESS:Size=%zu,Modified=%ld,IsDir=%d,Perms=%o",
                info.size, info.last_modified, info.is_directory, info.permissions);
    } else {
        strcpy(response, "ERROR:Unknown file operation");
        return 0;
    }
    
    return 1;
}

void list_directory(const char* path, char* response) {
    DIR* dir = opendir(path);
    if (!dir) {
        sprintf(response, "ERROR:Failed to open directory - %s", strerror(errno));
        return;
    }
    
    struct dirent* entry;
    char* current = response;
    current += sprintf(current, "SUCCESS:");
    
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        current += sprintf(current, "%s,", entry->d_name);
    }
    
    if (current > response + 8) {
        *(current - 1) = '\0';
    }
    
    closedir(dir);
}

int create_directory(const char* path) {
    return mkdir(path, 0755) == 0;
}

int delete_file(const char* path) {
    struct stat st;
    if (stat(path, &st) == 0) {
        if (S_ISDIR(st.st_mode)) {
            return rmdir(path) == 0;
        } else {
            return unlink(path) == 0;
        }
    }
    return 0;
}

int copy_file(const char* src, const char* dst) {
    int src_fd = open(src, O_RDONLY);
    if (src_fd < 0) return 0;
    
    int dst_fd = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (dst_fd < 0) {
        close(src_fd);
        return 0;
    }
    
    char buffer[8192];
    ssize_t bytes_read;
    while ((bytes_read = read(src_fd, buffer, sizeof(buffer))) > 0) {
        if (write(dst_fd, buffer, bytes_read) != bytes_read) {
            close(src_fd);
            close(dst_fd);
            return 0;
        }
    }
    
    close(src_fd);
    close(dst_fd);
    return bytes_read == 0;
}

void get_file_info(const char* path, file_info_t* info) {
    struct stat st;
    
    strncpy(info->path, path, MAX_PATH_LENGTH - 1);
    info->path[MAX_PATH_LENGTH - 1] = '\0';
    
    if (stat(path, &st) == 0) {
        info->permissions = st.st_mode & 0777;
        info->last_modified = st.st_mtime;
        info->size = st.st_size;
        info->is_directory = S_ISDIR(st.st_mode);
    } else {
        info->permissions = 0;
        info->last_modified = 0;
        info->size = 0;
        info->is_directory = 0;
    }
}

int check_file_permissions(const char* path, int required_permissions) {
    struct stat st;
    if (stat(path, &st) != 0) {
        return 0;
    }
    return (st.st_mode & required_permissions) == required_permissions;
}

void handle_admin_command(const char* command, char* response) {
    if (strncmp(command, "SHUTDOWN", 8) == 0) {
        strcpy(response, "SUCCESS:Server shutting down");
        server_running = 0;
    } else if (strncmp(command, "BROADCAST", 9) == 0) {
        broadcast_message(command + 10);
        strcpy(response, "SUCCESS:Message broadcasted");
    } else if (strncmp(command, "SAVE_STATE", 10) == 0) {
        save_server_state();
        strcpy(response, "SUCCESS:Server state saved");
    } else if (strncmp(command, "LOAD_STATE", 10) == 0) {
        load_server_state();
        strcpy(response, "SUCCESS:Server state loaded");
    } else {
        strcpy(response, "ERROR:Unknown admin command");
    }
}

void broadcast_message(const char* message) {
    pthread_mutex_lock(&client_mutex);
    for (int i = 0; i < client_count; i++) {
        if (clients[i].is_authenticated) {
            send(clients[i].client_socket, message, strlen(message), 0);
        }
    }
    pthread_mutex_unlock(&client_mutex);
}

void save_server_state(void) {
    FILE* fp = fopen("server_state.dat", "wb");
    if (!fp) return;
    
    pthread_mutex_lock(&session_mutex);
    fwrite(&session_count, sizeof(session_count), 1, fp);
    fwrite(sessions, sizeof(user_session_t), session_count, fp);
    pthread_mutex_unlock(&session_mutex);
    
    pthread_mutex_lock(&client_mutex);
    fwrite(&client_count, sizeof(client_count), 1, fp);
    fwrite(clients, sizeof(client_info_t), client_count, fp);
    pthread_mutex_unlock(&client_mutex);
    
    fclose(fp);
}

void load_server_state(void) {
    FILE* fp = fopen("server_state.dat", "rb");
    if (!fp) return;
    
    pthread_mutex_lock(&session_mutex);
    fread(&session_count, sizeof(session_count), 1, fp);
    fread(sessions, sizeof(user_session_t), session_count, fp);
    pthread_mutex_unlock(&session_mutex);
    
    pthread_mutex_lock(&client_mutex);
    fread(&client_count, sizeof(client_count), 1, fp);
    fread(clients, sizeof(client_info_t), client_count, fp);
    pthread_mutex_unlock(&client_mutex);
    
    fclose(fp);
}

int main(int argc, char* argv[]) {
    int port = DEFAULT_PORT;
    struct sockaddr_in server_addr;
    pthread_t thread_id;
    
    if (argc > 1) {
        port = atoi(argv[1]);
    }
    
    init_crypto_context();
    
    server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket == -1) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }
    
    int opt = 1;
    if (setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("setsockopt failed");
        exit(EXIT_FAILURE);
    }
    
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);
    
    if (bind(server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        perror("Bind failed");
        exit(EXIT_FAILURE);
    }
    
    if (listen(server_socket, 5) < 0) {
        perror("Listen failed");
        exit(EXIT_FAILURE);
    }
    
    printf("Server listening on port %d\n", port);
    log_message("Server started");
    
    signal(SIGINT, signal_handler);
    
    while (server_running) {
        cleanup_expired_sessions();
        
        struct sockaddr_in client_addr;
        socklen_t client_addr_len = sizeof(client_addr);
        
        int client_socket = accept(server_socket, (struct sockaddr*)&client_addr, &client_addr_len);
        if (client_socket < 0) {
            perror("Accept failed");
            continue;
        }
        
        if (client_count >= MAX_CLIENTS) {
            char* msg = "ERROR:Server at maximum capacity";
            send(client_socket, msg, strlen(msg), 0);
            close(client_socket);
            continue;
        }
        
        pthread_mutex_lock(&client_mutex);
        clients[client_count].client_socket = client_socket;
        clients[client_count].client_addr = client_addr;
        inet_ntop(AF_INET, &client_addr.sin_addr, clients[client_count].client_ip, INET_ADDRSTRLEN);
        clients[client_count].connection_time = time(NULL);
        clients[client_count].is_authenticated = 0;
        memset(clients[client_count].username, 0, MAX_USERNAME_LENGTH);
        memset(clients[client_count].session_id, 0, 33);
        client_count++;
        pthread_mutex_unlock(&client_mutex);
        
        if (pthread_create(&thread_id, NULL, (void*)handle_client, &clients[client_count - 1]) != 0) {
            perror("Thread creation failed");
            close(client_socket);
        }
        
        pthread_detach(thread_id);
    }
    
    cleanup_crypto_context();
    close(server_socket);
    return 0;
} 