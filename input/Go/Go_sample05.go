package main

import (
	"bufio"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type Server struct {
	port     int
	routes   map[string]http.HandlerFunc
	sessions map[string]Session
}

type Session struct {
	UserID   string
	Username string
	IsAdmin  bool
	Created  time.Time
}

type User struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Password string `json:"password"`
	Email    string `json:"email"`
	IsAdmin  bool   `json:"is_admin"`
}

type FileInfo struct {
	Name    string    `json:"name"`
	Path    string    `json:"path"`
	Size    int64     `json:"size"`
	ModTime time.Time `json:"mod_time"`
	IsDir   bool      `json:"is_dir"`
}

var users = map[string]User{
	"admin": {
		ID:       "1",
		Username: "admin",
		Password: "admin123",
		Email:    "admin@example.com",
		IsAdmin:  true,
	},
	"user": {
		ID:       "2",
		Username: "user",
		Password: "password",
		Email:    "user@example.com",
		IsAdmin:  false,
	},
}

func NewServer(port int) *Server {
	return &Server{
		port:     port,
		routes:   make(map[string]http.HandlerFunc),
		sessions: make(map[string]Session),
	}
}

func (s *Server) Start() error {
	s.setupRoutes()
	
	addr := fmt.Sprintf(":%d", s.port)
	fmt.Printf("Starting vulnerable server on port %d\n", s.port)
	fmt.Println("Available endpoints:")
	fmt.Println("  GET /file/<path> - Read file")
	fmt.Println("  GET /exec/<command> - Execute command")
	fmt.Println("  GET /search?q=<query> - Search files")
	fmt.Println("  POST /upload - Upload file")
	fmt.Println("  POST /login - Login (admin/admin123)")
	
	return http.ListenAndServe(addr, s)
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	method := r.Method
	
	fmt.Printf("[%s] %s %s\n", time.Now().Format("2006-01-02 15:04:05"), method, path)
	
	switch {
	case method == "GET" && strings.HasPrefix(path, "/file/"):
		s.handleFileRead(w, r)
	case method == "GET" && strings.HasPrefix(path, "/exec/"):
		s.handleCommandExecution(w, r)
	case method == "GET" && strings.HasPrefix(path, "/search"):
		s.handleFileSearch(w, r)
	case method == "POST" && path == "/upload":
		s.handleFileUpload(w, r)
	case method == "POST" && path == "/login":
		s.handleLogin(w, r)
	case method == "GET" && path == "/":
		s.handleIndex(w, r)
	default:
		http.NotFound(w, r)
	}
}

func (s *Server) setupRoutes() {
	s.routes["/"] = s.handleIndex
	s.routes["/file"] = s.handleFileRead
	s.routes["/exec"] = s.handleCommandExecution
	s.routes["/search"] = s.handleFileSearch
	s.routes["/upload"] = s.handleFileUpload
	s.routes["/login"] = s.handleLogin
}

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	html := `
	<html>
	<head><title>Vulnerable Server</title></head>
	<body>
		<h1>Welcome to Vulnerable Server</h1>
		<p>Available endpoints:</p>
		<ul>
			<li>GET /file/&lt;path&gt; - Read file</li>
			<li>GET /exec/&lt;command&gt; - Execute command</li>
			<li>GET /search?q=&lt;query&gt; - Search files</li>
			<li>POST /upload - Upload file</li>
			<li>POST /login - Login</li>
		</ul>
	</body>
	</html>`
	
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

func (s *Server) handleFileRead(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/file/")
	if path == "" {
		http.Error(w, "No file path specified", http.StatusBadRequest)
		return
	}
	
	content, err := os.ReadFile(path)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error reading file: %v", err), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "text/plain")
	w.Write(content)
}

func (s *Server) handleCommandExecution(w http.ResponseWriter, r *http.Request) {
	command := strings.TrimPrefix(r.URL.Path, "/exec/")
	if command == "" {
		http.Error(w, "No command specified", http.StatusBadRequest)
		return
	}
	
	cmd := exec.Command("sh", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		http.Error(w, fmt.Sprintf("Command execution failed: %v", err), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "text/plain")
	w.Write(output)
}

func (s *Server) handleFileSearch(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		http.Error(w, "No search query specified", http.StatusBadRequest)
		return
	}
	
	searchCmd := fmt.Sprintf("find . -name '*%s*' -type f 2>/dev/null", query)
	cmd := exec.Command("sh", "-c", searchCmd)
	output, err := cmd.CombinedOutput()
	if err != nil {
		http.Error(w, fmt.Sprintf("Search failed: %v", err), http.StatusInternalServerError)
		return
	}
	
	results := strings.Split(string(output), "\n")
	
	html := "<html><body><h1>Search Results</h1><ul>"
	for _, result := range results {
		if result != "" {
			html += fmt.Sprintf("<li>%s</li>", result)
		}
	}
	html += "</ul></body></html>"
	
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

func (s *Server) handleFileUpload(w http.ResponseWriter, r *http.Request) {
	err := r.ParseMultipartForm(32 << 20)
	if err != nil {
		http.Error(w, "Failed to parse form", http.StatusBadRequest)
		return
	}
	
	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "No file uploaded", http.StatusBadRequest)
		return
	}
	defer file.Close()
	
	filename := header.Filename
	if filename == "" {
		filename = fmt.Sprintf("upload_%d", time.Now().Unix())
	}
	
	uploadDir := "uploads"
	os.MkdirAll(uploadDir, 0755)
	
	filepath := filepath.Join(uploadDir, filename)
	
	dst, err := os.Create(filepath)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create file: %v", err), http.StatusInternalServerError)
		return
	}
	defer dst.Close()
	
	_, err = io.Copy(dst, file)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to save file: %v", err), http.StatusInternalServerError)
		return
	}
	
	response := fmt.Sprintf("File uploaded successfully: %s", filepath)
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(fmt.Sprintf("<html><body><h1>%s</h1></body></html>", response)))
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	err := r.ParseForm()
	if err != nil {
		http.Error(w, "Failed to parse form", http.StatusBadRequest)
		return
	}
	
	username := r.FormValue("username")
	password := r.FormValue("password")
	
	user, exists := users[username]
	if !exists || user.Password != password {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		return
	}
	
	token := generateToken()
	s.sessions[token] = Session{
		UserID:   user.ID,
		Username: user.Username,
		IsAdmin:  user.IsAdmin,
		Created:  time.Now(),
	}
	
	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		MaxAge:   3600,
	})
	
	response := fmt.Sprintf("Login successful for user: %s", user.Username)
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(fmt.Sprintf("<html><body><h1>%s</h1></body></html>", response)))
}

func (s *Server) handleUserInfo(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("session")
	if err != nil {
		http.Error(w, "No session found", http.StatusUnauthorized)
		return
	}
	
	session, exists := s.sessions[cookie.Value]
	if !exists {
		http.Error(w, "Invalid session", http.StatusUnauthorized)
		return
	}
	
	userInfo := map[string]interface{}{
		"user_id":   session.UserID,
		"username":  session.Username,
		"is_admin":  session.IsAdmin,
		"created":   session.Created,
		"session_id": cookie.Value,
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(userInfo)
}

func (s *Server) handleAdminPanel(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("session")
	if err != nil {
		http.Error(w, "No session found", http.StatusUnauthorized)
		return
	}
	
	session, exists := s.sessions[cookie.Value]
	if !exists || !session.IsAdmin {
		http.Error(w, "Access denied", http.StatusForbidden)
		return
	}
	
	action := r.URL.Query().Get("action")
	
	switch action {
	case "list_users":
		s.listUsers(w, r)
	case "delete_user":
		s.deleteUser(w, r)
	case "system_info":
		s.getSystemInfo(w, r)
	default:
		http.Error(w, "Invalid action", http.StatusBadRequest)
	}
}

func (s *Server) listUsers(w http.ResponseWriter, r *http.Request) {
	var userList []map[string]interface{}
	for _, user := range users {
		userList = append(userList, map[string]interface{}{
			"id":       user.ID,
			"username": user.Username,
			"email":    user.Email,
			"password": user.Password,
			"is_admin": user.IsAdmin,
		})
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(userList)
}

func (s *Server) deleteUser(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		http.Error(w, "No user ID specified", http.StatusBadRequest)
		return
	}
	
	delete(users, userID)
	
	response := fmt.Sprintf("User %s deleted successfully", userID)
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(fmt.Sprintf("<html><body><h1>%s</h1></body></html>", response)))
}

func (s *Server) getSystemInfo(w http.ResponseWriter, r *http.Request) {
	cmd := exec.Command("uname", "-a")
	output, err := cmd.Output()
	if err != nil {
		http.Error(w, "Failed to get system info", http.StatusInternalServerError)
		return
	}
	
	info := map[string]string{
		"system_info": string(output),
		"timestamp":   time.Now().Format(time.RFC3339),
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

func generateToken() string {
	b := make([]byte, 16)
	rand.Read(b)
	return fmt.Sprintf("%x", b)
}

func main() {
	port := 8080
	if len(os.Args) > 1 {
		if p, err := strconv.Atoi(os.Args[1]); err == nil {
			port = p
		}
	}
	
	server := NewServer(port)
	log.Fatal(server.Start())
} 