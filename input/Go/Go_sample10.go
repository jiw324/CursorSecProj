package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/mux"
)

type User struct {
	ID        int       `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	FirstName string    `json:"first_name"`
	LastName  string    `json:"last_name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	IsActive  bool      `json:"is_active"`
}

type CreateUserRequest struct {
	Username  string `json:"username"`
	Email     string `json:"email"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

type UpdateUserRequest struct {
	Username  *string `json:"username,omitempty"`
	Email     *string `json:"email,omitempty"`
	FirstName *string `json:"first_name,omitempty"`
	LastName  *string `json:"last_name,omitempty"`
	IsActive  *bool   `json:"is_active,omitempty"`
}

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
	Error   string      `json:"error,omitempty"`
}

type PaginatedResponse struct {
	Items      []User `json:"items"`
	TotalCount int    `json:"total_count"`
	Page       int    `json:"page"`
	PageSize   int    `json:"page_size"`
	TotalPages int    `json:"total_pages"`
}

type UserStore struct {
	mu    sync.RWMutex
	users map[int]*User
	nextID int
}

func NewUserStore() *UserStore {
	store := &UserStore{
		users:  make(map[int]*User),
		nextID: 1,
	}
	store.seedData()
	return store
}

func (s *UserStore) seedData() {
	sampleUsers := []*User{
		{Username: "johndoe", Email: "john@example.com", FirstName: "John", LastName: "Doe", IsActive: true},
		{Username: "janedoe", Email: "jane@example.com", FirstName: "Jane", LastName: "Doe", IsActive: true},
		{Username: "bobsmith", Email: "bob@example.com", FirstName: "Bob", LastName: "Smith", IsActive: true},
		{Username: "alicejohnson", Email: "alice@example.com", FirstName: "Alice", LastName: "Johnson", IsActive: false},
	}

	for _, user := range sampleUsers {
		s.CreateUser(user)
	}
}

func (s *UserStore) CreateUser(user *User) *User {
	s.mu.Lock()
	defer s.mu.Unlock()

	user.ID = s.nextID
	s.nextID++
	user.CreatedAt = time.Now()
	user.UpdatedAt = time.Now()
	
	s.users[user.ID] = user
	return user
}

func (s *UserStore) GetUser(id int) (*User, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	user, exists := s.users[id]
	return user, exists
}

func (s *UserStore) GetAllUsers() []*User {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	users := make([]*User, 0, len(s.users))
	for _, user := range s.users {
		users = append(users, user)
	}
	return users
}

func (s *UserStore) UpdateUser(id int, updates *UpdateUserRequest) (*User, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	user, exists := s.users[id]
	if !exists {
		return nil, false
	}

	if updates.Username != nil {
		user.Username = *updates.Username
	}
	if updates.Email != nil {
		user.Email = *updates.Email
	}
	if updates.FirstName != nil {
		user.FirstName = *updates.FirstName
	}
	if updates.LastName != nil {
		user.LastName = *updates.LastName
	}
	if updates.IsActive != nil {
		user.IsActive = *updates.IsActive
	}
	user.UpdatedAt = time.Now()
	
	return user, true
}

func (s *UserStore) DeleteUser(id int) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	_, exists := s.users[id]
	if exists {
		delete(s.users, id)
	}
	return exists
}

func (s *UserStore) GetUsersPaginated(page, pageSize int) (*PaginatedResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 10
	}

	allUsers := make([]User, 0, len(s.users))
	for _, user := range s.users {
		allUsers = append(allUsers, *user)
	}

	totalCount := len(allUsers)
	totalPages := (totalCount + pageSize - 1) / pageSize
	
	start := (page - 1) * pageSize
	end := start + pageSize
	
	if start >= totalCount {
		return &PaginatedResponse{
			Items:      []User{},
			TotalCount: totalCount,
			Page:       page,
			PageSize:   pageSize,
			TotalPages: totalPages,
		}, nil
	}
	
	if end > totalCount {
		end = totalCount
	}
	
	items := allUsers[start:end]
	
	return &PaginatedResponse{
		Items:      items,
		TotalCount: totalCount,
		Page:       page,
		PageSize:   pageSize,
		TotalPages: totalPages,
	}, nil
}

type APIServer struct {
	store  *UserStore
	router *mux.Router
}

func NewAPIServer() *APIServer {
	server := &APIServer{
		store:  NewUserStore(),
		router: mux.NewRouter(),
	}
	server.setupRoutes()
	return server
}

func (s *APIServer) setupRoutes() {
	api := s.router.PathPrefix("/api").Subrouter()
	api.Use(s.loggingMiddleware)
	api.Use(s.corsMiddleware)
	api.Use(s.jsonMiddleware)

	api.HandleFunc("/users", s.getUsers).Methods("GET")
	api.HandleFunc("/users", s.createUser).Methods("POST")
	api.HandleFunc("/users/{id:[0-9]+}", s.getUser).Methods("GET")
	api.HandleFunc("/users/{id:[0-9]+}", s.updateUser).Methods("PUT")
	api.HandleFunc("/users/{id:[0-9]+}", s.deleteUser).Methods("DELETE")

	s.router.HandleFunc("/health", s.healthCheck).Methods("GET")
	
	s.router.HandleFunc("/metrics", s.getMetrics).Methods("GET")
}

func (s *APIServer) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next.ServeHTTP(wrapped, r)
		
		duration := time.Since(start)
		log.Printf("%s %s %d %v", r.Method, r.URL.Path, wrapped.statusCode, duration)
	})
}

func (s *APIServer) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		
		next.ServeHTTP(w, r)
	})
}

func (s *APIServer) jsonMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		next.ServeHTTP(w, r)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (s *APIServer) getUsers(w http.ResponseWriter, r *http.Request) {
	pageStr := r.URL.Query().Get("page")
	pageSizeStr := r.URL.Query().Get("page_size")
	
	page, _ := strconv.Atoi(pageStr)
	pageSize, _ := strconv.Atoi(pageSizeStr)
	
	if page == 0 && pageSize == 0 {
		users := s.store.GetAllUsers()
		response := APIResponse{
			Success: true,
			Data:    users,
		}
		json.NewEncoder(w).Encode(response)
		return
	}
	
	paginatedUsers, err := s.store.GetUsersPaginated(page, pageSize)
	if err != nil {
		s.writeErrorResponse(w, http.StatusInternalServerError, err.Error())
		return
	}
	
	response := APIResponse{
		Success: true,
		Data:    paginatedUsers,
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) getUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		s.writeErrorResponse(w, http.StatusBadRequest, "Invalid user ID")
		return
	}
	
	user, exists := s.store.GetUser(id)
	if !exists {
		s.writeErrorResponse(w, http.StatusNotFound, "User not found")
		return
	}
	
	response := APIResponse{
		Success: true,
		Data:    user,
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) createUser(w http.ResponseWriter, r *http.Request) {
	var req CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		s.writeErrorResponse(w, http.StatusBadRequest, "Invalid JSON")
		return
	}
	
	if strings.TrimSpace(req.Username) == "" {
		s.writeErrorResponse(w, http.StatusBadRequest, "Username is required")
		return
	}
	if strings.TrimSpace(req.Email) == "" {
		s.writeErrorResponse(w, http.StatusBadRequest, "Email is required")
		return
	}
	
	user := &User{
		Username:  req.Username,
		Email:     req.Email,
		FirstName: req.FirstName,
		LastName:  req.LastName,
		IsActive:  true,
	}
	
	createdUser := s.store.CreateUser(user)
	
	w.WriteHeader(http.StatusCreated)
	response := APIResponse{
		Success: true,
		Data:    createdUser,
		Message: "User created successfully",
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) updateUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		s.writeErrorResponse(w, http.StatusBadRequest, "Invalid user ID")
		return
	}
	
	var req UpdateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		s.writeErrorResponse(w, http.StatusBadRequest, "Invalid JSON")
		return
	}
	
	updatedUser, exists := s.store.UpdateUser(id, &req)
	if !exists {
		s.writeErrorResponse(w, http.StatusNotFound, "User not found")
		return
	}
	
	response := APIResponse{
		Success: true,
		Data:    updatedUser,
		Message: "User updated successfully",
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) deleteUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		s.writeErrorResponse(w, http.StatusBadRequest, "Invalid user ID")
		return
	}
	
	deleted := s.store.DeleteUser(id)
	if !deleted {
		s.writeErrorResponse(w, http.StatusNotFound, "User not found")
		return
	}
	
	response := APIResponse{
		Success: true,
		Message: "User deleted successfully",
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) healthCheck(w http.ResponseWriter, r *http.Request) {
	health := map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now(),
		"version":   "1.0.0",
		"uptime":    time.Since(startTime),
	}
	
	response := APIResponse{
		Success: true,
		Data:    health,
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) getMetrics(w http.ResponseWriter, r *http.Request) {
	users := s.store.GetAllUsers()
	activeUsers := 0
	for _, user := range users {
		if user.IsActive {
			activeUsers++
		}
	}
	
	metrics := map[string]interface{}{
		"total_users":  len(users),
		"active_users": activeUsers,
		"inactive_users": len(users) - activeUsers,
		"timestamp": time.Now(),
	}
	
	response := APIResponse{
		Success: true,
		Data:    metrics,
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) writeErrorResponse(w http.ResponseWriter, statusCode int, message string) {
	w.WriteHeader(statusCode)
	response := APIResponse{
		Success: false,
		Error:   message,
	}
	json.NewEncoder(w).Encode(response)
}

func (s *APIServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(w, r)
}

var startTime = time.Now()

func main() {
	fmt.Println("Go Web Server with REST API")
	fmt.Println("===========================")
	
	server := NewAPIServer()
	
	httpServer := &http.Server{
		Addr:         ":8080",
		Handler:      server,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	
	go func() {
		log.Printf("Starting server on http://localhost:8080")
		log.Printf("API endpoints:")
		log.Printf("  GET    /health - Health check")
		log.Printf("  GET    /metrics - Server metrics")
		log.Printf("  GET    /api/users - Get all users")
		log.Printf("  POST   /api/users - Create user")
		log.Printf("  GET    /api/users/{id} - Get user by ID")
		log.Printf("  PUT    /api/users/{id} - Update user")
		log.Printf("  DELETE /api/users/{id} - Delete user")
		
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()
	
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	
	log.Println("Shutting down server...")
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	if err := httpServer.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
	
	log.Println("Server gracefully stopped")
} 