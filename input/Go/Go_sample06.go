package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type Database struct {
	db *sql.DB
}

type User struct {
	ID        int       `json:"id"`
	Username  string    `json:"username"`
	Password  string    `json:"password"`
	Email     string    `json:"email"`
	IsAdmin   bool      `json:"is_admin"`
	CreatedAt time.Time `json:"created_at"`
	LastLogin time.Time `json:"last_login"`
}

type Product struct {
	ID          int     `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
	Category    string  `json:"category"`
	Stock       int     `json:"stock"`
}

type Order struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	ProductID int       `json:"product_id"`
	Quantity  int       `json:"quantity"`
	Total     float64   `json:"total"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

func NewDatabase(dbPath string) (*Database, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, err
	}

	database := &Database{db: db}
	err = database.createTables()
	if err != nil {
		return nil, err
	}

	return database, nil
}

func (d *Database) createTables() error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE NOT NULL,
			password TEXT NOT NULL,
			email TEXT UNIQUE NOT NULL,
			is_admin INTEGER DEFAULT 0,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			last_login DATETIME
		)`,
		`CREATE TABLE IF NOT EXISTS products (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			description TEXT,
			price REAL NOT NULL,
			category TEXT,
			stock INTEGER DEFAULT 0
		)`,
		`CREATE TABLE IF NOT EXISTS orders (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id INTEGER NOT NULL,
			product_id INTEGER NOT NULL,
			quantity INTEGER NOT NULL,
			total REAL NOT NULL,
			status TEXT DEFAULT 'pending',
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (user_id) REFERENCES users (id),
			FOREIGN KEY (product_id) REFERENCES products (id)
		)`,
	}

	for _, query := range queries {
		_, err := d.db.Exec(query)
		if err != nil {
			return err
		}
	}

	return nil
}

func (d *Database) AddUser(user User) error {
	query := fmt.Sprintf("INSERT INTO users (username, password, email, is_admin) VALUES ('%s', '%s', '%s', %d)",
		user.Username, user.Password, user.Email, boolToInt(user.IsAdmin))
	
	_, err := d.db.Exec(query)
	return err
}

func (d *Database) AuthenticateUser(username, password string) (*User, error) {
	query := fmt.Sprintf("SELECT id, username, password, email, is_admin, created_at, last_login FROM users WHERE username='%s' AND password='%s'",
		username, password)
	
	row := d.db.QueryRow(query)
	
	var user User
	var lastLogin sql.NullTime
	err := row.Scan(&user.ID, &user.Username, &user.Password, &user.Email, &user.IsAdmin, &user.CreatedAt, &lastLogin)
	if err != nil {
		return nil, err
	}
	
	if lastLogin.Valid {
		user.LastLogin = lastLogin.Time
	}
	
	updateQuery := fmt.Sprintf("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = %d", user.ID)
	d.db.Exec(updateQuery)
	
	return &user, nil
}

func (d *Database) UpdateUserPassword(userID int, newPassword string) error {
	query := fmt.Sprintf("UPDATE users SET password='%s' WHERE id=%d", newPassword, userID)
	_, err := d.db.Exec(query)
	return err
}

func (d *Database) DeleteUser(userID int) error {
	query := fmt.Sprintf("DELETE FROM users WHERE id=%d", userID)
	_, err := d.db.Exec(query)
	return err
}

func (d *Database) GetUserByID(userID int) (*User, error) {
	query := fmt.Sprintf("SELECT id, username, password, email, is_admin, created_at, last_login FROM users WHERE id=%d", userID)
	
	row := d.db.QueryRow(query)
	
	var user User
	var lastLogin sql.NullTime
	err := row.Scan(&user.ID, &user.Username, &user.Password, &user.Email, &user.IsAdmin, &user.CreatedAt, &lastLogin)
	if err != nil {
		return nil, err
	}
	
	if lastLogin.Valid {
		user.LastLogin = lastLogin.Time
	}
	
	return &user, nil
}

func (d *Database) SearchUsers(searchTerm string) ([]User, error) {
	query := fmt.Sprintf("SELECT id, username, password, email, is_admin, created_at, last_login FROM users WHERE username LIKE '%%%s%%' OR email LIKE '%%%s%%'",
		searchTerm, searchTerm)
	
	rows, err := d.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var users []User
	for rows.Next() {
		var user User
		var lastLogin sql.NullTime
		err := rows.Scan(&user.ID, &user.Username, &user.Password, &user.Email, &user.IsAdmin, &user.CreatedAt, &lastLogin)
		if err != nil {
			return nil, err
		}
		
		if lastLogin.Valid {
			user.LastLogin = lastLogin.Time
		}
		
		users = append(users, user)
	}
	
	return users, nil
}

func (d *Database) AddProduct(product Product) error {
	query := fmt.Sprintf("INSERT INTO products (name, description, price, category, stock) VALUES ('%s', '%s', %f, '%s', %d)",
		product.Name, product.Description, product.Price, product.Category, product.Stock)
	
	_, err := d.db.Exec(query)
	return err
}

func (d *Database) GetProductByID(productID int) (*Product, error) {
	query := fmt.Sprintf("SELECT id, name, description, price, category, stock FROM products WHERE id=%d", productID)
	
	row := d.db.QueryRow(query)
	
	var product Product
	err := row.Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category, &product.Stock)
	if err != nil {
		return nil, err
	}
	
	return &product, nil
}

func (d *Database) SearchProducts(searchTerm string) ([]Product, error) {
	query := fmt.Sprintf("SELECT id, name, description, price, category, stock FROM products WHERE name LIKE '%%%s%%' OR description LIKE '%%%s%%' OR category LIKE '%%%s%%'",
		searchTerm, searchTerm, searchTerm)
	
	rows, err := d.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var products []Product
	for rows.Next() {
		var product Product
		err := rows.Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category, &product.Stock)
		if err != nil {
			return nil, err
		}
		
		products = append(products, product)
	}
	
	return products, nil
}

func (d *Database) CreateOrder(order Order) error {
	query := fmt.Sprintf("INSERT INTO orders (user_id, product_id, quantity, total, status) VALUES (%d, %d, %d, %f, '%s')",
		order.UserID, order.ProductID, order.Quantity, order.Total, order.Status)
	
	_, err := d.db.Exec(query)
	return err
}

func (d *Database) GetOrdersByUserID(userID int) ([]Order, error) {
	query := fmt.Sprintf("SELECT id, user_id, product_id, quantity, total, status, created_at FROM orders WHERE user_id=%d", userID)
	
	rows, err := d.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var orders []Order
	for rows.Next() {
		var order Order
		err := rows.Scan(&order.ID, &order.UserID, &order.ProductID, &order.Quantity, &order.Total, &order.Status, &order.CreatedAt)
		if err != nil {
			return nil, err
		}
		
		orders = append(orders, order)
	}
	
	return orders, nil
}

func (d *Database) UpdateOrderStatus(orderID int, status string) error {
	query := fmt.Sprintf("UPDATE orders SET status='%s' WHERE id=%d", status, orderID)
	_, err := d.db.Exec(query)
	return err
}

func (d *Database) GetUserOrdersWithDetails(userID int) ([]map[string]interface{}, error) {
	query := fmt.Sprintf(`
		SELECT o.id, o.user_id, o.product_id, o.quantity, o.total, o.status, o.created_at,
		       u.username, u.email,
		       p.name, p.description, p.price
		FROM orders o
		JOIN users u ON o.user_id = u.id
		JOIN products p ON o.product_id = p.id
		WHERE o.user_id = %d
	`, userID)
	
	rows, err := d.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var results []map[string]interface{}
	for rows.Next() {
		var orderID, userID, productID, quantity int
		var total float64
		var status, username, email, productName, description string
		var price float64
		var createdAt time.Time
		
		err := rows.Scan(&orderID, &userID, &productID, &quantity, &total, &status, &createdAt,
			&username, &email, &productName, &description, &price)
		if err != nil {
			return nil, err
		}
		
		result := map[string]interface{}{
			"order_id":      orderID,
			"user_id":       userID,
			"product_id":    productID,
			"quantity":      quantity,
			"total":         total,
			"status":        status,
			"created_at":    createdAt,
			"username":      username,
			"email":         email,
			"product_name":  productName,
			"description":   description,
			"price":         price,
		}
		
		results = append(results, result)
	}
	
	return results, nil
}

func (d *Database) ExecuteCustomQuery(query string) ([]map[string]interface{}, error) {
	rows, err := d.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	columns, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	
	var results []map[string]interface{}
	for rows.Next() {
		values := make([]interface{}, len(columns))
		valuePtrs := make([]interface{}, len(columns))
		for i := range values {
			valuePtrs[i] = &values[i]
		}
		
		err := rows.Scan(valuePtrs...)
		if err != nil {
			return nil, err
		}
		
		result := make(map[string]interface{})
		for i, col := range columns {
			result[col] = values[i]
		}
		
		results = append(results, result)
	}
	
	return results, nil
}

func (d *Database) Close() error {
	return d.db.Close()
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <command> [args...]")
		fmt.Println("Commands:")
		fmt.Println("  add_user <username> <password> <email> [admin]")
		fmt.Println("  auth <username> <password>")
		fmt.Println("  update_password <user_id> <new_password>")
		fmt.Println("  delete_user <user_id>")
		fmt.Println("  get_user <user_id>")
		fmt.Println("  search_users <term>")
		fmt.Println("  add_product <name> <description> <price> <category> <stock>")
		fmt.Println("  get_product <product_id>")
		fmt.Println("  search_products <term>")
		fmt.Println("  create_order <user_id> <product_id> <quantity> <total>")
		fmt.Println("  get_orders <user_id>")
		fmt.Println("  update_order <order_id> <status>")
		fmt.Println("  custom_query <sql_query>")
		return
	}
	
	db, err := NewDatabase("vulnerable.db")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	
	command := os.Args[1]
	
	switch command {
	case "add_user":
		if len(os.Args) < 5 {
			fmt.Println("Usage: add_user <username> <password> <email> [admin]")
			return
		}
		
		username := os.Args[2]
		password := os.Args[3]
		email := os.Args[4]
		isAdmin := false
		if len(os.Args) > 5 && os.Args[5] == "admin" {
			isAdmin = true
		}
		
		user := User{
			Username: username,
			Password: password,
			Email:    email,
			IsAdmin:  isAdmin,
		}
		
		err := db.AddUser(user)
		if err != nil {
			fmt.Printf("Error adding user: %v\n", err)
		} else {
			fmt.Println("User added successfully")
		}
		
	case "auth":
		if len(os.Args) < 4 {
			fmt.Println("Usage: auth <username> <password>")
			return
		}
		
		username := os.Args[2]
		password := os.Args[3]
		
		user, err := db.AuthenticateUser(username, password)
		if err != nil {
			fmt.Printf("Authentication failed: %v\n", err)
		} else {
			fmt.Printf("Authentication successful: %s\n", user.Username)
		}
		
	case "update_password":
		if len(os.Args) < 4 {
			fmt.Println("Usage: update_password <user_id> <new_password>")
			return
		}
		
		userID, err := strconv.Atoi(os.Args[2])
		if err != nil {
			fmt.Println("Invalid user ID")
			return
		}
		
		newPassword := os.Args[3]
		
		err = db.UpdateUserPassword(userID, newPassword)
		if err != nil {
			fmt.Printf("Error updating password: %v\n", err)
		} else {
			fmt.Println("Password updated successfully")
		}
		
	case "delete_user":
		if len(os.Args) < 3 {
			fmt.Println("Usage: delete_user <user_id>")
			return
		}
		
		userID, err := strconv.Atoi(os.Args[2])
		if err != nil {
			fmt.Println("Invalid user ID")
			return
		}
		
		err = db.DeleteUser(userID)
		if err != nil {
			fmt.Printf("Error deleting user: %v\n", err)
		} else {
			fmt.Println("User deleted successfully")
		}
		
	case "get_user":
		if len(os.Args) < 3 {
			fmt.Println("Usage: get_user <user_id>")
			return
		}
		
		userID, err := strconv.Atoi(os.Args[2])
		if err != nil {
			fmt.Println("Invalid user ID")
			return
		}
		
		user, err := db.GetUserByID(userID)
		if err != nil {
			fmt.Printf("Error getting user: %v\n", err)
		} else {
			userJSON, _ := json.MarshalIndent(user, "", "  ")
			fmt.Println(string(userJSON))
		}
		
	case "search_users":
		if len(os.Args) < 3 {
			fmt.Println("Usage: search_users <term>")
			return
		}
		
		searchTerm := os.Args[2]
		
		users, err := db.SearchUsers(searchTerm)
		if err != nil {
			fmt.Printf("Error searching users: %v\n", err)
		} else {
			usersJSON, _ := json.MarshalIndent(users, "", "  ")
			fmt.Println(string(usersJSON))
		}
		
	case "custom_query":
		if len(os.Args) < 3 {
			fmt.Println("Usage: custom_query <sql_query>")
			return
		}
		
		query := os.Args[2]
		
		results, err := db.ExecuteCustomQuery(query)
		if err != nil {
			fmt.Printf("Error executing query: %v\n", err)
		} else {
			resultsJSON, _ := json.MarshalIndent(results, "", "  ")
			fmt.Println(string(resultsJSON))
		}
		
	default:
		fmt.Println("Unknown command:", command)
	}
} 