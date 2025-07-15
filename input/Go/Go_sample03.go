package main

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type Category struct {
	ID          int
	Name        string
	Description string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Product struct {
	ID          int
	Name        string
	Description string
	Price       float64
	Stock       int
	CategoryID  int
	CreatedAt   time.Time
	UpdatedAt   time.Time
	IsActive    bool
}

type ProductWithCategory struct {
	Product
	CategoryName        string
	CategoryDescription string
}

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

type QueryBuilder struct {
	query     strings.Builder
	args      []interface{}
	whereUsed bool
}

func NewQueryBuilder() *QueryBuilder {
	return &QueryBuilder{
		args: make([]interface{}, 0),
	}
}

func (qb *QueryBuilder) Select(fields ...string) *QueryBuilder {
	qb.query.WriteString("SELECT ")
	qb.query.WriteString(strings.Join(fields, ", "))
	return qb
}

func (qb *QueryBuilder) From(table string) *QueryBuilder {
	qb.query.WriteString(" FROM ")
	qb.query.WriteString(table)
	return qb
}

func (qb *QueryBuilder) Where(condition string, args ...interface{}) *QueryBuilder {
	if qb.whereUsed {
		qb.query.WriteString(" AND ")
	} else {
		qb.query.WriteString(" WHERE ")
		qb.whereUsed = true
	}
	qb.query.WriteString(condition)
	qb.args = append(qb.args, args...)
	return qb
}

func (qb *QueryBuilder) OrderBy(field string, desc bool) *QueryBuilder {
	qb.query.WriteString(" ORDER BY ")
	qb.query.WriteString(field)
	if desc {
		qb.query.WriteString(" DESC")
	}
	return qb
}

func (qb *QueryBuilder) Limit(limit int) *QueryBuilder {
	qb.query.WriteString(fmt.Sprintf(" LIMIT %d", limit))
	return qb
}

func (qb *QueryBuilder) Offset(offset int) *QueryBuilder {
	qb.query.WriteString(fmt.Sprintf(" OFFSET %d", offset))
	return qb
}

func (qb *QueryBuilder) Join(join string) *QueryBuilder {
	qb.query.WriteString(" ")
	qb.query.WriteString(join)
	return qb
}

func (qb *QueryBuilder) Build() (string, []interface{}) {
	return qb.query.String(), qb.args
}

func NewDatabaseManager(dataSourceName string) (*DatabaseManager, error) {
	db, err := sql.Open("sqlite3", dataSourceName)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}
	
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
	qb := NewQueryBuilder()
	qb.Select("p.id", "p.name", "p.description", "p.price", "p.stock", "p.category_id", "p.created_at", "p.updated_at", "p.is_active", "c.name as category_name")
	qb.From("products p")
	qb.Join("JOIN categories c ON p.category_id = c.id")
	
	if categoryID != nil {
		qb.Where("p.category_id = ?", *categoryID)
	}
	
	if minPrice != nil {
		qb.Where("p.price >= ?", *minPrice)
	}
	
	if maxPrice != nil {
		qb.Where("p.price <= ?", *maxPrice)
	}
	
	qb.OrderBy("p.name", false).Limit(limit).Offset(offset)
	
	query, args := qb.Build()
	
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
	
	setParts := make([]string, 0, len(updates))
	args := make([]interface{}, 0, len(updates)+1)
	
	for field, value := range updates {
		setParts = append(setParts, field+" = ?")
		args = append(args, value)
	}
	
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

func (dm *DatabaseManager) GetDatabaseStats() (map[string]interface{}, error) {
	stats := make(map[string]interface{})
	
	var categoryCount, productCount int
	
	err := dm.db.QueryRow("SELECT COUNT(*) FROM categories").Scan(&categoryCount)
	if err != nil {
		return nil, fmt.Errorf("failed to get category count: %w", err)
	}
	
	err = dm.db.QueryRow("SELECT COUNT(*) FROM products").Scan(&productCount)
	if err != nil {
		return nil, fmt.Errorf("failed to get product count: %w", err)
	}
	
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
	dm.mu.Lock()
	for txID, tx := range dm.transactions {
		log.Printf("Rolling back pending transaction: %s", txID)
		tx.Rollback()
	}
	dm.mu.Unlock()
	
	return dm.db.Close()
}

func main() {
	fmt.Println("Go Database Manager with SQLite")
	fmt.Println("===============================")
	
	dm, err := NewDatabaseManager("products.db")
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer dm.Close()
	
	if err := dm.SeedTestData(); err != nil {
		log.Printf("Failed to seed test data: %v", err)
	}
	
	log.Println("\n--- Database Operations Demo ---")
	
	categories, err := dm.GetAllCategories()
	if err != nil {
		log.Printf("Error getting categories: %v", err)
	} else {
		log.Printf("Found %d categories", len(categories))
	}
	
	products, err := dm.GetProductsWithCategory(10, 0, nil, nil, nil)
	if err != nil {
		log.Printf("Error getting products: %v", err)
	} else {
		log.Printf("Found %d products", len(products))
		for _, product := range products[:3] {
			log.Printf("  - %s: $%.2f (%s)", product.Name, product.Price, product.CategoryName)
		}
	}
	
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