#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <errno.h>
#include <signal.h>

#define PORT 8080
#define BUFFER_SIZE 4096
#define MAX_ROUTES 50
#define MAX_PATH_LENGTH 256
#define MAX_HEADERS 20
#define BACKLOG 10


typedef struct {
    char method[16];
    char path[MAX_PATH_LENGTH];
    char version[16];
    char headers[MAX_HEADERS][256];
    int header_count;
    char* body;
    int body_length;
} HttpRequest;


typedef struct {
    int status_code;
    char status_message[64];
    char headers[MAX_HEADERS][256];
    int header_count;
    char* body;
    int body_length;
} HttpResponse;


typedef void (*RouteHandler)(HttpRequest* req, HttpResponse* res);


typedef struct {
    char method[16];
    char path[MAX_PATH_LENGTH];
    RouteHandler handler;
} Route;


typedef struct {
    int server_socket;
    struct sockaddr_in server_addr;
    Route routes[MAX_ROUTES];
    int route_count;
    int running;
} HttpServer;


HttpServer* g_server = NULL;


void signal_handler(int signal) {
    if (g_server) {
        printf("\nShutting down server...\n");
        g_server->running = 0;
        if (g_server->server_socket > 0) {
            close(g_server->server_socket);
        }
    }
    exit(0);
}


void init_request(HttpRequest* req) {
    memset(req, 0, sizeof(HttpRequest));
    req->body = NULL;
    req->body_length = 0;
    req->header_count = 0;
}


void init_response(HttpResponse* res) {
    memset(res, 0, sizeof(HttpResponse));
    res->status_code = 200;
    strcpy(res->status_message, "OK");
    res->body = NULL;
    res->body_length = 0;
    res->header_count = 0;
}


void add_response_header(HttpResponse* res, const char* name, const char* value) {
    if (res->header_count < MAX_HEADERS) {
        snprintf(res->headers[res->header_count], 256, "%s: %s", name, value);
        res->header_count++;
    }
}


void set_response_body(HttpResponse* res, const char* body) {
    if (res->body) {
        free(res->body);
    }
    res->body_length = strlen(body);
    res->body = malloc(res->body_length + 1);
    strcpy(res->body, body);
    
    
    char content_length[32];
    snprintf(content_length, sizeof(content_length), "%d", res->body_length);
    add_response_header(res, "Content-Length", content_length);
}


int parse_request(const char* raw_data, HttpRequest* req) {
    init_request(req);
    
    char* data_copy = strdup(raw_data);
    char* line = strtok(data_copy, "\r\n");
    
    if (!line) {
        free(data_copy);
        return -1;
    }
    
    
    char* token = strtok(line, " ");
    if (token) strncpy(req->method, token, sizeof(req->method) - 1);
    
    token = strtok(NULL, " ");
    if (token) strncpy(req->path, token, sizeof(req->path) - 1);
    
    token = strtok(NULL, " ");
    if (token) strncpy(req->version, token, sizeof(req->version) - 1);
    
    
    while ((line = strtok(NULL, "\r\n")) && strlen(line) > 0) {
        if (req->header_count < MAX_HEADERS) {
            strncpy(req->headers[req->header_count], line, 255);
            req->header_count++;
        }
    }
    
    
    if (line && strlen(line) == 0) {
        line = strtok(NULL, "\r\n");
        if (line) {
            req->body_length = strlen(line);
            req->body = malloc(req->body_length + 1);
            strcpy(req->body, line);
        }
    }
    
    free(data_copy);
    return 0;
}


char* generate_response(HttpResponse* res) {
    char* response = malloc(BUFFER_SIZE);
    int offset = 0;
    
    
    offset += snprintf(response + offset, BUFFER_SIZE - offset,
                      "HTTP/1.1 %d %s\r\n", res->status_code, res->status_message);
    
    
    time_t now = time(NULL);
    char date_str[64];
    strftime(date_str, sizeof(date_str), "%a, %d %b %Y %H:%M:%S GMT", gmtime(&now));
    offset += snprintf(response + offset, BUFFER_SIZE - offset,
                      "Date: %s\r\n", date_str);
    offset += snprintf(response + offset, BUFFER_SIZE - offset,
                      "Server: SimpleHTTP/1.0\r\n");
    offset += snprintf(response + offset, BUFFER_SIZE - offset,
                      "Connection: close\r\n");
    
    
    for (int i = 0; i < res->header_count; i++) {
        offset += snprintf(response + offset, BUFFER_SIZE - offset,
                          "%s\r\n", res->headers[i]);
    }
    
    
    offset += snprintf(response + offset, BUFFER_SIZE - offset, "\r\n");
    
    
    if (res->body && res->body_length > 0) {
        memcpy(response + offset, res->body, res->body_length);
        offset += res->body_length;
    }
    
    response[offset] = '\0';
    return response;
}


void handle_root(HttpRequest* req, HttpResponse* res) {
    const char* html = 
        "<!DOCTYPE html>\n"
        "<html><head><title>Simple HTTP Server</title></head>\n"
        "<body>\n"
        "<h1>Welcome to Simple HTTP Server</h1>\n"
        "<p>This is a C-based HTTP server!</p>\n"
        "<ul>\n"
        "<li><a href=\"/\">Home</a></li>\n"
        "<li><a href=\"/about\">About</a></li>\n"
        "<li><a href=\"/api/status\">API Status</a></li>\n"
        "<li><a href=\"/api/time\">Current Time</a></li>\n"
        "</ul>\n"
        "</body></html>";
    
    add_response_header(res, "Content-Type", "text/html");
    set_response_body(res, html);
}

void handle_about(HttpRequest* req, HttpResponse* res) {
    const char* html = 
        "<!DOCTYPE html>\n"
        "<html><head><title>About - HTTP Server</title></head>\n"
        "<body>\n"
        "<h1>About This Server</h1>\n"
        "<p>This is a simple HTTP server written in C.</p>\n"
        "<p>Features:</p>\n"
        "<ul>\n"
        "<li>Request parsing</li>\n"
        "<li>Response generation</li>\n"
        "<li>Basic routing</li>\n"
        "<li>Static content serving</li>\n"
        "</ul>\n"
        "<a href=\"/\">Back to Home</a>\n"
        "</body></html>";
    
    add_response_header(res, "Content-Type", "text/html");
    set_response_body(res, html);
}

void handle_api_status(HttpRequest* req, HttpResponse* res) {
    const char* json = 
        "{\n"
        "  \"status\": \"OK\",\n"
        "  \"message\": \"Server is running\",\n"
        "  \"version\": \"1.0\",\n"
        "  \"timestamp\": \"%ld\"\n"
        "}";
    
    char response_body[256];
    snprintf(response_body, sizeof(response_body), json, time(NULL));
    
    add_response_header(res, "Content-Type", "application/json");
    set_response_body(res, response_body);
}

void handle_api_time(HttpRequest* req, HttpResponse* res) {
    time_t now = time(NULL);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S UTC", gmtime(&now));
    
    char json[256];
    snprintf(json, sizeof(json),
             "{\n  \"current_time\": \"%s\",\n  \"timestamp\": %ld\n}",
             time_str, now);
    
    add_response_header(res, "Content-Type", "application/json");
    set_response_body(res, json);
}

void handle_404(HttpRequest* req, HttpResponse* res) {
    res->status_code = 404;
    strcpy(res->status_message, "Not Found");
    
    const char* html = 
        "<!DOCTYPE html>\n"
        "<html><head><title>404 - Not Found</title></head>\n"
        "<body>\n"
        "<h1>404 - Page Not Found</h1>\n"
        "<p>The requested resource was not found on this server.</p>\n"
        "<a href=\"/\">Back to Home</a>\n"
        "</body></html>";
    
    add_response_header(res, "Content-Type", "text/html");
    set_response_body(res, html);
}


HttpServer* init_server(void) {
    HttpServer* server = malloc(sizeof(HttpServer));
    if (!server) {
        perror("Failed to allocate server");
        return NULL;
    }
    
    memset(server, 0, sizeof(HttpServer));
    server->route_count = 0;
    server->running = 1;
    
    return server;
}


void add_route(HttpServer* server, const char* method, const char* path, RouteHandler handler) {
    if (server->route_count < MAX_ROUTES) {
        Route* route = &server->routes[server->route_count];
        strncpy(route->method, method, sizeof(route->method) - 1);
        strncpy(route->path, path, sizeof(route->path) - 1);
        route->handler = handler;
        server->route_count++;
        printf("Added route: %s %s\n", method, path);
    }
}


RouteHandler find_route(HttpServer* server, const char* method, const char* path) {
    for (int i = 0; i < server->route_count; i++) {
        Route* route = &server->routes[i];
        if (strcmp(route->method, method) == 0 && strcmp(route->path, path) == 0) {
            return route->handler;
        }
    }
    return NULL;
}


void handle_client(HttpServer* server, int client_socket) {
    char buffer[BUFFER_SIZE];
    ssize_t bytes_received = recv(client_socket, buffer, BUFFER_SIZE - 1, 0);
    
    if (bytes_received <= 0) {
        close(client_socket);
        return;
    }
    
    buffer[bytes_received] = '\0';
    
    HttpRequest req;
    HttpResponse res;
    init_response(&res);
    
    printf("Received request:\n%s\n", buffer);
    
    if (parse_request(buffer, &req) == 0) {
        printf("Parsed: %s %s %s\n", req.method, req.path, req.version);
        
        RouteHandler handler = find_route(server, req.method, req.path);
        if (handler) {
            handler(&req, &res);
        } else {
            handle_404(&req, &res);
        }
    } else {
        res.status_code = 400;
        strcpy(res.status_message, "Bad Request");
        set_response_body(&res, "400 Bad Request");
    }
    
    char* response = generate_response(&res);
    send(client_socket, response, strlen(response), 0);
    
    printf("Response sent: %d %s\n", res.status_code, res.status_message);
    
    
    if (req.body) free(req.body);
    if (res.body) free(res.body);
    free(response);
    close(client_socket);
}


int start_server(HttpServer* server) {
    server->server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server->server_socket < 0) {
        perror("Socket creation failed");
        return -1;
    }
    
    int opt = 1;
    if (setsockopt(server->server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("Setsockopt failed");
        close(server->server_socket);
        return -1;
    }
    
    server->server_addr.sin_family = AF_INET;
    server->server_addr.sin_addr.s_addr = INADDR_ANY;
    server->server_addr.sin_port = htons(PORT);
    
    if (bind(server->server_socket, (struct sockaddr*)&server->server_addr, sizeof(server->server_addr)) < 0) {
        perror("Bind failed");
        close(server->server_socket);
        return -1;
    }
    
    if (listen(server->server_socket, BACKLOG) < 0) {
        perror("Listen failed");
        close(server->server_socket);
        return -1;
    }
    
    printf("HTTP Server started on port %d\n", PORT);
    printf("Visit http://localhost:%d in your browser\n", PORT);
    
    return 0;
}


void run_server(HttpServer* server) {
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    
    while (server->running) {
        int client_socket = accept(server->server_socket, (struct sockaddr*)&client_addr, &client_len);
        
        if (client_socket < 0) {
            if (server->running) {
                perror("Accept failed");
            }
            continue;
        }
        
        printf("Client connected: %s:%d\n", 
               inet_ntoa(client_addr.sin_addr), 
               ntohs(client_addr.sin_port));
        
        handle_client(server, client_socket);
    }
}


void setup_routes(HttpServer* server) {
    add_route(server, "GET", "/", handle_root);
    add_route(server, "GET", "/about", handle_about);
    add_route(server, "GET", "/api/status", handle_api_status);
    add_route(server, "GET", "/api/time", handle_api_time);
}


void cleanup_server(HttpServer* server) {
    if (server) {
        if (server->server_socket > 0) {
            close(server->server_socket);
        }
        free(server);
    }
}

int main(void) {
    printf("Simple HTTP Server v1.0\n");
    printf("=======================\n");
    
    g_server = init_server();
    if (!g_server) {
        return EXIT_FAILURE;
    }
    
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    setup_routes(g_server);
    
    if (start_server(g_server) != 0) {
        cleanup_server(g_server);
        return EXIT_FAILURE;
    }
    
    run_server(g_server);
    
    cleanup_server(g_server);
    printf("Server shutdown complete\n");
    return EXIT_SUCCESS;
} 