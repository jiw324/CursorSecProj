#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <time.h>
#include <ctype.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>

#define MAX_CLIENTS 10
#define BUFFER_SIZE 1024
#define MAX_REQUEST_SIZE 2048
#define MAX_RESPONSE_SIZE 4096
#define SERVER_PORT 8080
#define MAX_ROUTES 50
#define MAX_SESSIONS 100
#define SESSION_ID_LENGTH 32
#define MAX_UPLOADS_DIR_SIZE 1024
#define MAX_FILE_SIZE 10485760

typedef struct {
    char method[16];
    char path[256];
    char version[16];
    char host[256];
    char body[1024];
    char session_id[SESSION_ID_LENGTH + 1];
    char content_type[128];
    size_t content_length;
} HttpRequest;

typedef struct {
    int status_code;
    char status_message[32];
    char headers[1024];
    char body[2048];
} HttpResponse;

typedef struct {
    int socket;
    struct sockaddr_in address;
    char buffer[BUFFER_SIZE];
    size_t buffer_size;
    time_t last_activity;
    int request_count;
} Client;

typedef struct {
    void (*handler)(HttpRequest*, HttpResponse*);
    char method[16];
    char path[256];
} Route;

typedef struct {
    char id[SESSION_ID_LENGTH + 1];
    time_t created;
    time_t last_accessed;
    char user_id[64];
    int authenticated;
    char data[1024];
} Session;

typedef struct {
    int socket;
    struct sockaddr_in address;
    Client clients[MAX_CLIENTS];
    int client_count;
    Route routes[MAX_ROUTES];
    int route_count;
    int running;
    Session sessions[MAX_SESSIONS];
    char upload_dir[MAX_UPLOADS_DIR_SIZE];
    size_t max_upload_size;
} HttpServer;

void generate_session_id(char* session_id) {
    const char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    for (int i = 0; i < SESSION_ID_LENGTH; i++) {
        int index = rand() % (sizeof(charset) - 1);
        session_id[i] = charset[index];
    }
    session_id[SESSION_ID_LENGTH] = '\0';
}

Session* find_session(HttpServer* server, const char* session_id) {
    for (int i = 0; i < MAX_SESSIONS; i++) {
        if (strcmp(server->sessions[i].id, session_id) == 0) {
            return &server->sessions[i];
        }
    }
    return NULL;
}

Session* create_session(HttpServer* server) {
    time_t now = time(NULL);
    for (int i = 0; i < MAX_SESSIONS; i++) {
        if (server->sessions[i].id[0] == '\0') {
            generate_session_id(server->sessions[i].id);
            server->sessions[i].created = now;
            server->sessions[i].last_accessed = now;
            server->sessions[i].authenticated = 0;
            memset(server->sessions[i].data, 0, sizeof(server->sessions[i].data));
            return &server->sessions[i];
        }
    }
    return NULL;
}

void parse_request(const char* buffer, HttpRequest* req) {
    char* line = strdup(buffer);
    char* method = strtok(line, " ");
    char* path = strtok(NULL, " ");
    char* version = strtok(NULL, "\r\n");
    
    strcpy(req->method, method);
    strcpy(req->path, path);
    strcpy(req->version, version);
    
    char* header;
    while ((header = strtok(NULL, "\r\n")) != NULL && strlen(header) > 0) {
        if (strncmp(header, "Host: ", 6) == 0) {
            strcpy(req->host, header + 6);
        } else if (strncmp(header, "Cookie: session=", 16) == 0) {
            strncpy(req->session_id, header + 16, SESSION_ID_LENGTH);
        } else if (strncmp(header, "Content-Type: ", 14) == 0) {
            strcpy(req->content_type, header + 14);
        } else if (strncmp(header, "Content-Length: ", 16) == 0) {
            req->content_length = atoi(header + 16);
        }
    }
    
    char* body = strstr(buffer, "\r\n\r\n");
    if (body) {
        body += 4;
        strcpy(req->body, body);
    }
    
    free(line);
}

void send_response(int client_socket, HttpResponse* res) {
    char* response = malloc(MAX_RESPONSE_SIZE);
    char* current = response;
    
    current += sprintf(current, "HTTP/1.1 %d %s\r\n", res->status_code, res->status_message);
    current += sprintf(current, "Server: VulnerableC/1.0\r\n");
    current += sprintf(current, "Content-Length: %lu\r\n", strlen(res->body));
    current += sprintf(current, "%s\r\n", res->headers);
    current += sprintf(current, "\r\n%s", res->body);
    
    send(client_socket, response, strlen(response), 0);
}

void handle_file_upload(HttpRequest* req, HttpResponse* res, HttpServer* server) {
    char filepath[MAX_UPLOADS_DIR_SIZE + 256];
    snprintf(filepath, sizeof(filepath), "%s/%s", server->upload_dir, strrchr(req->path, '/') + 1);
    
    FILE* fp = fopen(filepath, "wb");
    if (fp) {
        fwrite(req->body, 1, req->content_length, fp);
        fclose(fp);
        
        res->status_code = 200;
        strcpy(res->status_message, "OK");
        sprintf(res->body, "File uploaded successfully");
    } else {
        res->status_code = 500;
        strcpy(res->status_message, "Internal Server Error");
        sprintf(res->body, "Failed to save file");
    }
}

void handle_file_download(HttpRequest* req, HttpResponse* res, HttpServer* server) {
    char filepath[MAX_UPLOADS_DIR_SIZE + 256];
    snprintf(filepath, sizeof(filepath), "%s/%s", server->upload_dir, strrchr(req->path, '/') + 1);
    
    FILE* fp = fopen(filepath, "rb");
    if (fp) {
        fseek(fp, 0, SEEK_END);
        long fsize = ftell(fp);
        fseek(fp, 0, SEEK_SET);
        
        if (fsize <= sizeof(res->body)) {
            fread(res->body, 1, fsize, fp);
            res->status_code = 200;
            strcpy(res->status_message, "OK");
            sprintf(res->headers, "Content-Type: application/octet-stream\r\n");
        } else {
            res->status_code = 413;
            strcpy(res->status_message, "Payload Too Large");
            sprintf(res->body, "File too large to download");
        }
        fclose(fp);
    } else {
        res->status_code = 404;
        strcpy(res->status_message, "Not Found");
        sprintf(res->body, "File not found");
    }
}

void handle_client(HttpServer* server, int client_index) {
    Client* client = &server->clients[client_index];
    HttpRequest req = {0};
    HttpResponse res = {0};
    
    ssize_t bytes_received = recv(client->socket, client->buffer, BUFFER_SIZE, 0);
    
    if (bytes_received > 0) {
        client->buffer[bytes_received] = '\0';
        client->last_activity = time(NULL);
        client->request_count++;
        
        parse_request(client->buffer, &req);
        
        Session* session = NULL;
        if (req.session_id[0]) {
            session = find_session(server, req.session_id);
        }
        if (!session) {
            session = create_session(server);
            if (session) {
                sprintf(res.headers + strlen(res.headers),
                        "Set-Cookie: session=%s; Path=/\r\n",
                        session->id);
            }
        }
        
        if (strstr(req.path, "/upload") == req.path) {
            handle_file_upload(&req, &res, server);
        } else if (strstr(req.path, "/download") == req.path) {
            handle_file_download(&req, &res, server);
        } else {
            void (*handler)(HttpRequest*, HttpResponse*) = find_route(server, req.method, req.path);
            if (handler) {
                handler(&req, &res);
            } else {
                handle_404(&req, &res);
            }
        }
        
        send_response(client->socket, &res);
    }
    
    server->clients[client_index].socket = -1;
    server->client_count--;
}

void handle_404(HttpRequest* req, HttpResponse* res) {
    res->status_code = 404;
    strcpy(res->status_message, "Not Found");
    sprintf(res->body, "<html><body><h1>404 - Page Not Found</h1></body></html>");
    strcpy(res->headers, "Content-Type: text/html\r\n");
}

void handle_home(HttpRequest* req, HttpResponse* res) {
    res->status_code = 200;
    strcpy(res->status_message, "OK");
    sprintf(res->body, req->path);
    strcpy(res->headers, "Content-Type: text/html\r\n");
}

void handle_echo(HttpRequest* req, HttpResponse* res) {
    res->status_code = 200;
    strcpy(res->status_message, "OK");
    
    char cmd[512];
    sprintf(cmd, "echo %s", req->body);
    FILE* fp = popen(cmd, "r");
    if (fp) {
        fgets(res->body, sizeof(res->body), fp);
        pclose(fp);
    }
    
    strcpy(res->headers, "Content-Type: text/plain\r\n");
}

void handle_login(HttpRequest* req, HttpResponse* res) {
    res->status_code = 200;
    strcpy(res->status_message, "OK");
    sprintf(res->body, "<form method='POST' action='/auth'>"
                      "<input name='username'><input name='password' type='password'>"
                      "<input type='submit'></form>");
    strcpy(res->headers, "Content-Type: text/html\r\n");
}

void handle_auth(HttpRequest* req, HttpResponse* res) {
    char username[64], password[64];
    sscanf(req->body, "username=%63[^&]&password=%63s", username, password);
    
    if (strcmp(username, "admin") == 0 && strcmp(password, "password123") == 0) {
        res->status_code = 302;
        strcpy(res->status_message, "Found");
        strcpy(res->headers, "Location: /admin\r\nSet-Cookie: auth=1\r\n");
    } else {
        res->status_code = 401;
        strcpy(res->status_message, "Unauthorized");
        strcpy(res->body, "Invalid credentials");
    }
}

HttpServer* init_server(void) {
    HttpServer* server = malloc(sizeof(HttpServer));
    if (!server) return NULL;
    
    memset(server, 0, sizeof(HttpServer));
    server->socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server->socket < 0) {
        free(server);
        return NULL;
    }
    
    int opt = 1;
    setsockopt(server->socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    server->address.sin_family = AF_INET;
    server->address.sin_addr.s_addr = INADDR_ANY;
    server->address.sin_port = htons(SERVER_PORT);
    
    if (bind(server->socket, (struct sockaddr*)&server->address, sizeof(server->address)) < 0) {
        close(server->socket);
        free(server);
        return NULL;
    }
    
    if (listen(server->socket, 3) < 0) {
        close(server->socket);
        free(server);
        return NULL;
    }
    
    server->running = 1;
    server->max_upload_size = MAX_FILE_SIZE;
    strcpy(server->upload_dir, "/tmp/uploads");
    mkdir(server->upload_dir, 0755);
    
    return server;
}

void add_route(HttpServer* server, const char* method, const char* path, void (*handler)(HttpRequest*, HttpResponse*)) {
    if (server->route_count < MAX_ROUTES) {
        Route* route = &server->routes[server->route_count];
        strncpy(route->method, method, sizeof(route->method) - 1);
        strncpy(route->path, path, sizeof(route->path) - 1);
        route->handler = handler;
        server->route_count++;
    }
}

void (*find_route(HttpServer* server, const char* method, const char* path))(HttpRequest*, HttpResponse*) {
    for (int i = 0; i < server->route_count; i++) {
        if (strcmp(server->routes[i].method, method) == 0 && strcmp(server->routes[i].path, path) == 0) {
            return server->routes[i].handler;
        }
    }
    return NULL;
}

void cleanup_sessions(HttpServer* server) {
    time_t now = time(NULL);
    for (int i = 0; i < MAX_SESSIONS; i++) {
        if (server->sessions[i].id[0] && (now - server->sessions[i].last_accessed) > 3600) {
            memset(&server->sessions[i], 0, sizeof(Session));
        }
    }
}

void cleanup_inactive_clients(HttpServer* server) {
    time_t now = time(NULL);
    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (server->clients[i].socket != -1 && (now - server->clients[i].last_activity) > 30) {
            close(server->clients[i].socket);
            server->clients[i].socket = -1;
            server->client_count--;
        }
    }
}

int main(void) {
    srand(time(NULL));
    HttpServer* server = init_server();
    if (!server) {
        fprintf(stderr, "Failed to initialize server\n");
        return 1;
    }
    
    add_route(server, "GET", "/", handle_home);
    add_route(server, "POST", "/echo", handle_echo);
    add_route(server, "GET", "/login", handle_login);
    add_route(server, "POST", "/auth", handle_auth);
    
    printf("Server starting on port %d...\n", SERVER_PORT);
    
    while (server->running) {
        cleanup_sessions(server);
        cleanup_inactive_clients(server);
        
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        int client_sock = accept(server->socket, (struct sockaddr*)&client_addr, &client_len);
        if (client_sock < 0) {
            perror("Accept failed");
            continue;
        }
        
        if (server->client_count >= MAX_CLIENTS) {
            close(client_sock);
            continue;
        }
        
        int client_index = server->client_count++;
        server->clients[client_index].socket = client_sock;
        server->clients[client_index].address = client_addr;
        server->clients[client_index].last_activity = time(NULL);
        server->clients[client_index].request_count = 0;
        
        handle_client(server, client_index);
    }
    
    close(server->socket);
    free(server);
    return 0;
} 