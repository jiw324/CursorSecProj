// AI-Generated Code Header
// **Intent:** Database manager with connection pooling, migrations, and CRUD operations
// **Optimization:** Efficient database connections and query performance
// **Safety:** SQL injection prevention, transaction handling, and error management

package main

import (
	"database/sql"
	"fmt"
	"log"
	"strconv"
	"strings"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

// AI-SUGGESTION: Domain models for database operations
type Product struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	Price       float64   `json:"price" db:"price"`
	Stock       int       `json:"stock" db:"stock"`
	CategoryID  int       `json:"category_id" db:"category_id"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
	IsActive    bool      `json:"is_active" db:"is_active"`
}

type Category struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type ProductWithCategory struct {
	Product
	CategoryName string `json:"category_name" db:"category_name"`
}

// AI-SUGGESTION: Query builder for dynamic SQL construction
type QueryBuilder struct {
	table      string
	selectCols []string
	whereCols  []string
	orderBy    string
	limit      int
	offset     int
	joins      []string
}

func NewQueryBuilder(table string) *QueryBuilder {
	return &QueryBuilder{
		table:      table,
		selectCols: []string{"*"},
	}
}

func (qb *QueryBuilder) Select(cols ...string) *QueryBuilder {
	qb.selectCols = cols
	return qb
}

func (qb *QueryBuilder) Where(condition string) *QueryBuilder {
	qb.whereCols = append(qb.whereCols, condition)
	return qb
}

func (qb *QueryBuilder) Join(joinClause string) *QueryBuilder {
	qb.joins = append(qb.joins, joinClause)
	return qb
}

func (qb *QueryBuilder) OrderBy(orderBy string) *QueryBuilder {
	qb.orderBy = orderBy
	return qb
}

func (qb *QueryBuilder) Limit(limit int) *QueryBuilder {
	qb.limit = limit
	return qb
}

func (qb *QueryBuilder) Offset(offset int) *QueryBuilder {
	qb.offset = offset
	return qb
}

func (qb *QueryBuilder) Build() string {
	query := fmt.Sprintf("SELECT %s FROM %s", strings.Join(qb.selectCols, ", "), qb.table)
	
	if len(qb.joins) > 0 {
		query += " " + strings.Join(qb.joins, " ")
	}
	
	if len(qb.whereCols) > 0 {
		query += " WHERE " + strings.Join(qb.whereCols, " AND ")
	}
	
	if qb.orderBy != "" {
		query += " ORDER BY " + qb.orderBy
	}
	
	if qb.limit > 0 {
		query += " LIMIT " + strconv.Itoa(qb.limit)
	}
	
	if qb.offset > 0 {
		query += " OFFSET " + strconv.Itoa(qb.offset)
	}
	
	return query
}

// AI-SUGGESTION: Database connection manager with pooling
type DatabaseManager struct {
	db           *sql.DB
	mu           sync.RWMutex
	transactions map[string]*sql.Tx
	migrations   []Migration
}

type Migration struct {
	Version int
	Name    string
	SQL     string
}

func NewDatabaseManager(dataSourceName string) (*DatabaseManager, error) {
	db, err := sql.Open("sqlite3", dataSourceName)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}
	
	// AI-SUGGESTION: Configure connection pool
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}
	
	manager := &DatabaseManager{
		db:           db,
		transactions: make(map[string]*sql.Tx),
		migrations:   getMigrations(),
	}
	
	if err := manager.RunMigrations(); err != nil {
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}
	
	return manager, nil
}

func getMigrations() []Migration {
	return []Migration{
		{
			Version: 1,
			Name:    "create_categories_table",
			SQL: `
				CREATE TABLE IF NOT EXISTS categories (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					name TEXT NOT NULL UNIQUE,
					description TEXT,
					created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
					updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
				);
			`,
		},
		{
			Version: 2,
			Name:    "create_products_table",
			SQL: `
				CREATE TABLE IF NOT EXISTS products (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					name TEXT NOT NULL,
					description TEXT,
					price REAL NOT NULL CHECK(price >= 0),
					stock INTEGER NOT NULL CHECK(stock >= 0),
					category_id INTEGER NOT NULL,
					created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
					updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
					is_active BOOLEAN DEFAULT 1,
					FOREIGN KEY (category_id) REFERENCES categories (id)
				);
			`,
		},
		{
			Version: 3,
			Name:    "create_migration_history_table",
			SQL: `
				CREATE TABLE IF NOT EXISTS migration_history (
					version INTEGER PRIMARY KEY,
					name TEXT NOT NULL,
					applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
				);
			`,
		},
		{
			Version: 4,
			Name:    "create_indexes",
			SQL: `
				CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
				CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
				CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
			`,
		},
	}
}

func (dm *DatabaseManager) RunMigrations() error {
	log.Println("Running database migrations...")
	
	// AI-SUGGESTION: Create migration history table first
	_, err := dm.db.Exec(`
		CREATE TABLE IF NOT EXISTS migration_history (
			version INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create migration history table: %w", err)
	}
	
	// AI-SUGGESTION: Get applied migrations
	appliedMigrations := make(map[int]bool)
	rows, err := dm.db.Query("SELECT version FROM migration_history")
	if err != nil {
		return fmt.Errorf("failed to query migration history: %w", err)
	}
	defer rows.Close()
	
	for rows.Next() {
		var version int
		if err := rows.Scan(&version); err != nil {
			return fmt.Errorf("failed to scan migration version: %w", err)
		}
		appliedMigrations[version] = true
	}
	
	// AI-SUGGESTION: Apply pending migrations
	for _, migration := range dm.migrations {
		if appliedMigrations[migration.Version] {
			continue
		}
		
		log.Printf("Applying migration %d: %s", migration.Version, migration.Name)
		
		tx, err := dm.db.Begin()
		if err != nil {
			return fmt.Errorf("failed to begin transaction for migration %d: %w", migration.Version, err)
		}
		
		if _, err := tx.Exec(migration.SQL); err != nil {
			tx.Rollback()
			return fmt.Errorf("failed to execute migration %d: %w", migration.Version, err)
		}
		
		if _, err := tx.Exec("INSERT INTO migration_history (version, name) VALUES (?, ?)", migration.Version, migration.Name); err != nil {
			tx.Rollback()
			return fmt.Errorf("failed to record migration %d: %w", migration.Version, err)
		}
		
		if err := tx.Commit(); err != nil {
			return fmt.Errorf("failed to commit migration %d: %w", migration.Version, err)
		}
	}
	
	log.Println("Migrations completed successfully")
	return nil
}

// AI-SUGGESTION: Category operations
func (dm *DatabaseManager) CreateCategory(name, description string) (*Category, error) {
	query := `
		INSERT INTO categories (name, description)
		VALUES (?, ?)
	`
	
	result, err := dm.db.Exec(query, name, description)
	if err != nil {
		return nil, fmt.Errorf("failed to create category: %w", err)
	}
	
	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert ID: %w", err)
	}
	
	return dm.GetCategoryByID(int(id))
}

func (dm *DatabaseManager) GetCategoryByID(id int) (*Category, error) {
	query := `
		SELECT id, name, description, created_at, updated_at
		FROM categories
		WHERE id = ?
	`
	
	var category Category
	err := dm.db.QueryRow(query, id).Scan(
		&category.ID,
		&category.Name,
		&category.Description,
		&category.CreatedAt,
		&category.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("category with ID %d not found", id)
		}
		return nil, fmt.Errorf("failed to get category: %w", err)
	}
	
	return &category, nil
}

func (dm *DatabaseManager) GetAllCategories() ([]*Category, error) {
	query := `
		SELECT id, name, description, created_at, updated_at
		FROM categories
		ORDER BY name
	`
	
	rows, err := dm.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to query categories: %w", err)
	}
	defer rows.Close()
	
	var categories []*Category
	for rows.Next() {
		var category Category
		err := rows.Scan(
			&category.ID,
			&category.Name,
			&category.Description,
			&category.CreatedAt,
			&category.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan category: %w", err)
		}
		categories = append(categories, &category)
	}
	
	return categories, nil
}

// AI-SUGGESTION: Product operations with advanced querying
func (dm *DatabaseManager) CreateProduct(product *Product) (*Product, error) {
	query := `
		INSERT INTO products (name, description, price, stock, category_id, is_active)
		VALUES (?, ?, ?, ?, ?, ?)
	`
	
	result, err := dm.db.Exec(query,
		product.Name,
		product.Description,
		product.Price,
		product.Stock,
		product.CategoryID,
		product.IsActive,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create product: %w", err)
	}
	
	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("failed to get last insert ID: %w", err)
	}
	
	return dm.GetProductByID(int(id))
}

func (dm *DatabaseManager) GetProductByID(id int) (*Product, error) {
	query := `
		SELECT id, name, description, price, stock, category_id, created_at, updated_at, is_active
		FROM products
		WHERE id = ?
	`
	
	var product Product
	err := dm.db.QueryRow(query, id).Scan(
		&product.ID,
		&product.Name,
		&product.Description,
		&product.Price,
		&product.Stock,
		&product.CategoryID,
		&product.CreatedAt,
		&product.UpdatedAt,
		&product.IsActive,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("product with ID %d not found", id)
		}
		return nil, fmt.Errorf("failed to get product: %w", err)
	}
	
	return &product, nil
}

func (dm *DatabaseManager) GetProductsWithCategory(limit, offset int, categoryID *int, minPrice, maxPrice *float64) ([]*ProductWithCategory, error) {
	qb := NewQueryBuilder("products p")
	qb.Select("p.id", "p.name", "p.description", "p.price", "p.stock", "p.category_id", "p.created_at", "p.updated_at", "p.is_active", "c.name as category_name")
	qb.Join("JOIN categories c ON p.category_id = c.id")
	
	var args []interface{}
	
	if categoryID != nil {
		qb.Where("p.category_id = ?")
		args = append(args, *categoryID)
	}
	
	if minPrice != nil {
		qb.Where("p.price >= ?")
		args = append(args, *minPrice)
	}
	
	if maxPrice != nil {
		qb.Where("p.price <= ?")
		args = append(args, *maxPrice)
	}
	
	qb.OrderBy("p.name").Limit(limit).Offset(offset)
	
	query := qb.Build()
	
	rows, err := dm.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query products: %w", err)
	}
	defer rows.Close()
	
	var products []*ProductWithCategory
	for rows.Next() {
		var product ProductWithCategory
		err := rows.Scan(
			&product.ID,
			&product.Name,
			&product.Description,
			&product.Price,
			&product.Stock,
			&product.CategoryID,
			&product.CreatedAt,
			&product.UpdatedAt,
			&product.IsActive,
			&product.CategoryName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan product: %w", err)
		}
		products = append(products, &product)
	}
	
	return products, nil
}

func (dm *DatabaseManager) UpdateProduct(id int, updates map[string]interface{}) (*Product, error) {
	if len(updates) == 0 {
		return dm.GetProductByID(id)
	}
	
	// AI-SUGGESTION: Build dynamic update query
	setParts := make([]string, 0, len(updates))
	args := make([]interface{}, 0, len(updates)+1)
	
	for field, value := range updates {
		setParts = append(setParts, field+" = ?")
		args = append(args, value)
	}
	
	// AI-SUGGESTION: Always update the updated_at field
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")
	args = append(args, id)
	
	query := fmt.Sprintf("UPDATE products SET %s WHERE id = ?", strings.Join(setParts, ", "))
	
	_, err := dm.db.Exec(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to update product: %w", err)
	}
	
	return dm.GetProductByID(id)
}

func (dm *DatabaseManager) DeleteProduct(id int) error {
	query := "DELETE FROM products WHERE id = ?"
	
	result, err := dm.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete product: %w", err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	
	if rowsAffected == 0 {
		return fmt.Errorf("product with ID %d not found", id)
	}
	
	return nil
}

// AI-SUGGESTION: Transaction management
func (dm *DatabaseManager) BeginTransaction(txID string) error {
	dm.mu.Lock()
	defer dm.mu.Unlock()
	
	if _, exists := dm.transactions[txID]; exists {
		return fmt.Errorf("transaction with ID %s already exists", txID)
	}
	
	tx, err := dm.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	
	dm.transactions[txID] = tx
	return nil
}

func (dm *DatabaseManager) CommitTransaction(txID string) error {
	dm.mu.Lock()
	defer dm.mu.Unlock()
	
	tx, exists := dm.transactions[txID]
	if !exists {
		return fmt.Errorf("transaction with ID %s not found", txID)
	}
	
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}
	
	delete(dm.transactions, txID)
	return nil
}

func (dm *DatabaseManager) RollbackTransaction(txID string) error {
	dm.mu.Lock()
	defer dm.mu.Unlock()
	
	tx, exists := dm.transactions[txID]
	if !exists {
		return fmt.Errorf("transaction with ID %s not found", txID)
	}
	
	if err := tx.Rollback(); err != nil {
		return fmt.Errorf("failed to rollback transaction: %w", err)
	}
	
	delete(dm.transactions, txID)
	return nil
}

// AI-SUGGESTION: Statistics and analytics
func (dm *DatabaseManager) GetDatabaseStats() (map[string]interface{}, error) {
	stats := make(map[string]interface{})
	
	// AI-SUGGESTION: Get table counts
	var categoryCount, productCount int
	
	err := dm.db.QueryRow("SELECT COUNT(*) FROM categories").Scan(&categoryCount)
	if err != nil {
		return nil, fmt.Errorf("failed to get category count: %w", err)
	}
	
	err = dm.db.QueryRow("SELECT COUNT(*) FROM products").Scan(&productCount)
	if err != nil {
		return nil, fmt.Errorf("failed to get product count: %w", err)
	}
	
	// AI-SUGGESTION: Get product statistics
	var avgPrice, totalValue sql.NullFloat64
	var minPrice, maxPrice sql.NullFloat64
	
	err = dm.db.QueryRow("SELECT AVG(price), SUM(price * stock), MIN(price), MAX(price) FROM products WHERE is_active = 1").Scan(&avgPrice, &totalValue, &minPrice, &maxPrice)
	if err != nil {
		return nil, fmt.Errorf("failed to get product statistics: %w", err)
	}
	
	stats["categories"] = categoryCount
	stats["products"] = productCount
	stats["average_price"] = avgPrice.Float64
	stats["total_inventory_value"] = totalValue.Float64
	stats["min_price"] = minPrice.Float64
	stats["max_price"] = maxPrice.Float64
	
	return stats, nil
}

func (dm *DatabaseManager) SeedTestData() error {
	log.Println("Seeding test data...")
	
	// AI-SUGGESTION: Create categories
	categories := []struct {
		name, description string
	}{
		{"Electronics", "Electronic devices and gadgets"},
		{"Books", "Books and educational materials"},
		{"Clothing", "Apparel and fashion items"},
		{"Home & Garden", "Home improvement and gardening supplies"},
	}
	
	categoryMap := make(map[string]int)
	for _, cat := range categories {
		category, err := dm.CreateCategory(cat.name, cat.description)
		if err != nil {
			return fmt.Errorf("failed to create category %s: %w", cat.name, err)
		}
		categoryMap[cat.name] = category.ID
	}
	
	// AI-SUGGESTION: Create products
	products := []*Product{
		{Name: "Laptop Pro", Description: "High-performance laptop", Price: 1299.99, Stock: 50, CategoryID: categoryMap["Electronics"], IsActive: true},
		{Name: "Wireless Mouse", Description: "Ergonomic wireless mouse", Price: 29.99, Stock: 100, CategoryID: categoryMap["Electronics"], IsActive: true},
		{Name: "Programming Guide", Description: "Complete programming guide", Price: 49.99, Stock: 75, CategoryID: categoryMap["Books"], IsActive: true},
		{Name: "Cotton T-Shirt", Description: "Comfortable cotton t-shirt", Price: 19.99, Stock: 200, CategoryID: categoryMap["Clothing"], IsActive: true},
		{Name: "Garden Tool Set", Description: "Essential gardening tools", Price: 89.99, Stock: 30, CategoryID: categoryMap["Home & Garden"], IsActive: true},
	}
	
	for _, product := range products {
		_, err := dm.CreateProduct(product)
		if err != nil {
			return fmt.Errorf("failed to create product %s: %w", product.Name, err)
		}
	}
	
	log.Printf("Successfully seeded %d categories and %d products", len(categories), len(products))
	return nil
}

func (dm *DatabaseManager) Close() error {
	// AI-SUGGESTION: Rollback any pending transactions
	dm.mu.Lock()
	for txID, tx := range dm.transactions {
		log.Printf("Rolling back pending transaction: %s", txID)
		tx.Rollback()
	}
	dm.mu.Unlock()
	
	return dm.db.Close()
}

// AI-SUGGESTION: Main function demonstrating database operations
func main() {
	fmt.Println("Go Database Manager with SQLite")
	fmt.Println("===============================")
	
	dm, err := NewDatabaseManager("products.db")
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer dm.Close()
	
	// AI-SUGGESTION: Seed test data
	if err := dm.SeedTestData(); err != nil {
		log.Printf("Failed to seed test data: %v", err)
	}
	
	// AI-SUGGESTION: Demonstrate various operations
	log.Println("\n--- Database Operations Demo ---")
	
	// Get all categories
	categories, err := dm.GetAllCategories()
	if err != nil {
		log.Printf("Error getting categories: %v", err)
	} else {
		log.Printf("Found %d categories", len(categories))
	}
	
	// Get products with category information
	products, err := dm.GetProductsWithCategory(10, 0, nil, nil, nil)
	if err != nil {
		log.Printf("Error getting products: %v", err)
	} else {
		log.Printf("Found %d products", len(products))
		for _, product := range products[:3] { // Show first 3
			log.Printf("  - %s: $%.2f (%s)", product.Name, product.Price, product.CategoryName)
		}
	}
	
	// Get database statistics
	stats, err := dm.GetDatabaseStats()
	if err != nil {
		log.Printf("Error getting stats: %v", err)
	} else {
		log.Printf("Database Statistics:")
		for key, value := range stats {
			log.Printf("  %s: %v", key, value)
		}
	}
	
	log.Println("\n=== Database Manager Demo Complete ===")
} 