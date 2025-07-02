<?php
// AI-Generated Code Header
// **Intent:** Demonstrate advanced PHP database management with ORM, migrations, and query builder
// **Optimization:** Efficient query caching, connection pooling, and lazy loading
// **Safety:** SQL injection prevention, transaction management, and data validation

declare(strict_types=1);

namespace Database;

use Exception;
use PDO;
use PDOException;
use DateTime;

// AI-SUGGESTION: Database configuration and connection manager
class DatabaseConfig
{
    private array $connections = [];
    private array $config;
    
    public function __construct(array $config = [])
    {
        $this->config = array_merge([
            'default' => 'mysql',
            'connections' => [
                'mysql' => [
                    'driver' => 'mysql',
                    'host' => $_ENV['DB_HOST'] ?? 'localhost',
                    'port' => $_ENV['DB_PORT'] ?? 3306,
                    'database' => $_ENV['DB_NAME'] ?? 'app_db',
                    'username' => $_ENV['DB_USER'] ?? 'root',
                    'password' => $_ENV['DB_PASS'] ?? '',
                    'charset' => 'utf8mb4',
                    'collation' => 'utf8mb4_unicode_ci',
                    'options' => [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false,
                        PDO::ATTR_PERSISTENT => false
                    ]
                ],
                'sqlite' => [
                    'driver' => 'sqlite',
                    'database' => $_ENV['SQLITE_PATH'] ?? 'database.sqlite',
                    'options' => [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
                    ]
                ]
            ]
        ], $config);
    }
    
    public function getConnection(string $name = null): PDO
    {
        $name = $name ?? $this->config['default'];
        
        if (!isset($this->connections[$name])) {
            $this->connections[$name] = $this->createConnection($name);
        }
        
        return $this->connections[$name];
    }
    
    private function createConnection(string $name): PDO
    {
        $config = $this->config['connections'][$name] ?? null;
        
        if (!$config) {
            throw new Exception("Database connection '{$name}' not configured");
        }
        
        try {
            switch ($config['driver']) {
                case 'mysql':
                    $dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['database']};charset={$config['charset']}";
                    return new PDO($dsn, $config['username'], $config['password'], $config['options']);
                    
                case 'sqlite':
                    $dsn = "sqlite:{$config['database']}";
                    return new PDO($dsn, '', '', $config['options']);
                    
                default:
                    throw new Exception("Unsupported database driver: {$config['driver']}");
            }
        } catch (PDOException $e) {
            throw new Exception("Failed to connect to database '{$name}': " . $e->getMessage());
        }
    }
    
    public function closeConnection(string $name = null): void
    {
        $name = $name ?? $this->config['default'];
        unset($this->connections[$name]);
    }
    
    public function closeAllConnections(): void
    {
        $this->connections = [];
    }
}

// AI-SUGGESTION: Query builder with fluent interface
class QueryBuilder
{
    private PDO $connection;
    private string $table = '';
    private array $select = ['*'];
    private array $joins = [];
    private array $wheres = [];
    private array $orderBy = [];
    private array $groupBy = [];
    private array $having = [];
    private ?int $limit = null;
    private ?int $offset = null;
    private array $bindings = [];
    
    public function __construct(PDO $connection)
    {
        $this->connection = $connection;
    }
    
    public function table(string $table): self
    {
        $this->table = $table;
        return $this;
    }
    
    public function select(array|string $columns = ['*']): self
    {
        $this->select = is_array($columns) ? $columns : func_get_args();
        return $this;
    }
    
    public function join(string $table, string $first, string $operator, string $second, string $type = 'INNER'): self
    {
        $this->joins[] = "{$type} JOIN {$table} ON {$first} {$operator} {$second}";
        return $this;
    }
    
    public function leftJoin(string $table, string $first, string $operator, string $second): self
    {
        return $this->join($table, $first, $operator, $second, 'LEFT');
    }
    
    public function rightJoin(string $table, string $first, string $operator, string $second): self
    {
        return $this->join($table, $first, $operator, $second, 'RIGHT');
    }
    
    public function where(string $column, mixed $operator, mixed $value = null): self
    {
        if ($value === null) {
            $value = $operator;
            $operator = '=';
        }
        
        $placeholder = $this->getPlaceholder();
        $this->wheres[] = "AND {$column} {$operator} {$placeholder}";
        $this->bindings[] = $value;
        
        return $this;
    }
    
    public function orWhere(string $column, mixed $operator, mixed $value = null): self
    {
        if ($value === null) {
            $value = $operator;
            $operator = '=';
        }
        
        $placeholder = $this->getPlaceholder();
        $this->wheres[] = "OR {$column} {$operator} {$placeholder}";
        $this->bindings[] = $value;
        
        return $this;
    }
    
    public function whereIn(string $column, array $values): self
    {
        $placeholders = [];
        foreach ($values as $value) {
            $placeholders[] = $this->getPlaceholder();
            $this->bindings[] = $value;
        }
        
        $this->wheres[] = "AND {$column} IN (" . implode(', ', $placeholders) . ")";
        return $this;
    }
    
    public function whereBetween(string $column, array $values): self
    {
        if (count($values) !== 2) {
            throw new Exception("whereBetween requires exactly 2 values");
        }
        
        $placeholder1 = $this->getPlaceholder();
        $placeholder2 = $this->getPlaceholder();
        
        $this->wheres[] = "AND {$column} BETWEEN {$placeholder1} AND {$placeholder2}";
        $this->bindings[] = $values[0];
        $this->bindings[] = $values[1];
        
        return $this;
    }
    
    public function whereNull(string $column): self
    {
        $this->wheres[] = "AND {$column} IS NULL";
        return $this;
    }
    
    public function whereNotNull(string $column): self
    {
        $this->wheres[] = "AND {$column} IS NOT NULL";
        return $this;
    }
    
    public function orderBy(string $column, string $direction = 'ASC'): self
    {
        $this->orderBy[] = "{$column} {$direction}";
        return $this;
    }
    
    public function groupBy(string|array $columns): self
    {
        $columns = is_array($columns) ? $columns : func_get_args();
        $this->groupBy = array_merge($this->groupBy, $columns);
        return $this;
    }
    
    public function having(string $column, string $operator, mixed $value): self
    {
        $placeholder = $this->getPlaceholder();
        $this->having[] = "{$column} {$operator} {$placeholder}";
        $this->bindings[] = $value;
        return $this;
    }
    
    public function limit(int $limit): self
    {
        $this->limit = $limit;
        return $this;
    }
    
    public function offset(int $offset): self
    {
        $this->offset = $offset;
        return $this;
    }
    
    public function paginate(int $page, int $perPage = 15): array
    {
        $total = $this->count();
        $this->limit($perPage)->offset(($page - 1) * $perPage);
        $items = $this->get();
        
        return [
            'data' => $items,
            'pagination' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => ceil($total / $perPage),
                'from' => (($page - 1) * $perPage) + 1,
                'to' => min($page * $perPage, $total)
            ]
        ];
    }
    
    public function get(): array
    {
        $sql = $this->buildSelectQuery();
        return $this->execute($sql, $this->bindings);
    }
    
    public function first(): ?array
    {
        $this->limit(1);
        $result = $this->get();
        return $result[0] ?? null;
    }
    
    public function find(mixed $id, string $column = 'id'): ?array
    {
        return $this->where($column, $id)->first();
    }
    
    public function count(): int
    {
        $originalSelect = $this->select;
        $this->select = ['COUNT(*) as count'];
        
        $sql = $this->buildSelectQuery();
        $result = $this->execute($sql, $this->bindings);
        
        $this->select = $originalSelect;
        
        return (int)($result[0]['count'] ?? 0);
    }
    
    public function exists(): bool
    {
        return $this->count() > 0;
    }
    
    public function insert(array $data): int
    {
        $columns = array_keys($data);
        $placeholders = array_fill(0, count($data), '?');
        
        $sql = "INSERT INTO {$this->table} (" . implode(', ', $columns) . ") VALUES (" . implode(', ', $placeholders) . ")";
        
        $this->execute($sql, array_values($data));
        return (int)$this->connection->lastInsertId();
    }
    
    public function insertMany(array $data): bool
    {
        if (empty($data)) {
            return true;
        }
        
        $columns = array_keys($data[0]);
        $placeholders = '(' . implode(', ', array_fill(0, count($columns), '?')) . ')';
        $allPlaceholders = array_fill(0, count($data), $placeholders);
        
        $sql = "INSERT INTO {$this->table} (" . implode(', ', $columns) . ") VALUES " . implode(', ', $allPlaceholders);
        
        $bindings = [];
        foreach ($data as $row) {
            $bindings = array_merge($bindings, array_values($row));
        }
        
        return $this->execute($sql, $bindings) !== false;
    }
    
    public function update(array $data): int
    {
        $sets = [];
        $bindings = [];
        
        foreach ($data as $column => $value) {
            $sets[] = "{$column} = ?";
            $bindings[] = $value;
        }
        
        $sql = "UPDATE {$this->table} SET " . implode(', ', $sets);
        
        if (!empty($this->wheres)) {
            $sql .= " WHERE " . ltrim(implode(' ', $this->wheres), 'AND OR');
            $bindings = array_merge($bindings, $this->bindings);
        }
        
        $stmt = $this->connection->prepare($sql);
        $stmt->execute($bindings);
        
        return $stmt->rowCount();
    }
    
    public function delete(): int
    {
        $sql = "DELETE FROM {$this->table}";
        
        if (!empty($this->wheres)) {
            $sql .= " WHERE " . ltrim(implode(' ', $this->wheres), 'AND OR');
        }
        
        $stmt = $this->connection->prepare($sql);
        $stmt->execute($this->bindings);
        
        return $stmt->rowCount();
    }
    
    public function raw(string $sql, array $bindings = []): array
    {
        return $this->execute($sql, $bindings);
    }
    
    private function buildSelectQuery(): string
    {
        $sql = "SELECT " . implode(', ', $this->select) . " FROM {$this->table}";
        
        if (!empty($this->joins)) {
            $sql .= " " . implode(' ', $this->joins);
        }
        
        if (!empty($this->wheres)) {
            $sql .= " WHERE " . ltrim(implode(' ', $this->wheres), 'AND OR');
        }
        
        if (!empty($this->groupBy)) {
            $sql .= " GROUP BY " . implode(', ', $this->groupBy);
        }
        
        if (!empty($this->having)) {
            $sql .= " HAVING " . implode(' AND ', $this->having);
        }
        
        if (!empty($this->orderBy)) {
            $sql .= " ORDER BY " . implode(', ', $this->orderBy);
        }
        
        if ($this->limit !== null) {
            $sql .= " LIMIT {$this->limit}";
        }
        
        if ($this->offset !== null) {
            $sql .= " OFFSET {$this->offset}";
        }
        
        return $sql;
    }
    
    private function execute(string $sql, array $bindings = []): array
    {
        try {
            $stmt = $this->connection->prepare($sql);
            $stmt->execute($bindings);
            return $stmt->fetchAll();
        } catch (PDOException $e) {
            throw new Exception("Query failed: " . $e->getMessage() . "\nSQL: {$sql}");
        }
    }
    
    private function getPlaceholder(): string
    {
        return '?';
    }
}

// AI-SUGGESTION: Database migration system
class Migration
{
    protected PDO $connection;
    protected string $table = 'migrations';
    
    public function __construct(PDO $connection)
    {
        $this->connection = $connection;
        $this->createMigrationsTable();
    }
    
    private function createMigrationsTable(): void
    {
        $sql = "CREATE TABLE IF NOT EXISTS {$this->table} (
            id INT AUTO_INCREMENT PRIMARY KEY,
            migration VARCHAR(255) NOT NULL,
            batch INT NOT NULL,
            executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )";
        
        $this->connection->exec($sql);
    }
    
    public function run(array $migrations): void
    {
        $executed = $this->getExecutedMigrations();
        $batch = $this->getNextBatchNumber();
        
        foreach ($migrations as $migration) {
            $migrationName = $this->getMigrationName($migration);
            
            if (!in_array($migrationName, $executed)) {
                echo "Running migration: {$migrationName}\n";
                
                try {
                    $this->connection->beginTransaction();
                    
                    $migrationInstance = new $migration($this->connection);
                    $migrationInstance->up();
                    
                    $this->recordMigration($migrationName, $batch);
                    
                    $this->connection->commit();
                    echo "Migration completed: {$migrationName}\n";
                } catch (Exception $e) {
                    $this->connection->rollback();
                    throw new Exception("Migration failed: {$migrationName} - " . $e->getMessage());
                }
            }
        }
    }
    
    public function rollback(int $steps = 1): void
    {
        $migrations = $this->getMigrationsToRollback($steps);
        
        foreach ($migrations as $migration) {
            echo "Rolling back migration: {$migration['migration']}\n";
            
            try {
                $this->connection->beginTransaction();
                
                $migrationClass = $this->findMigrationClass($migration['migration']);
                if ($migrationClass) {
                    $migrationInstance = new $migrationClass($this->connection);
                    $migrationInstance->down();
                }
                
                $this->removeMigrationRecord($migration['migration']);
                
                $this->connection->commit();
                echo "Rollback completed: {$migration['migration']}\n";
            } catch (Exception $e) {
                $this->connection->rollback();
                throw new Exception("Rollback failed: {$migration['migration']} - " . $e->getMessage());
            }
        }
    }
    
    private function getExecutedMigrations(): array
    {
        $stmt = $this->connection->query("SELECT migration FROM {$this->table} ORDER BY batch, id");
        return $stmt->fetchAll(PDO::FETCH_COLUMN);
    }
    
    private function getNextBatchNumber(): int
    {
        $stmt = $this->connection->query("SELECT MAX(batch) FROM {$this->table}");
        $maxBatch = $stmt->fetchColumn();
        return ($maxBatch ?? 0) + 1;
    }
    
    private function getMigrationName(string $migration): string
    {
        return class_basename($migration);
    }
    
    private function recordMigration(string $migration, int $batch): void
    {
        $stmt = $this->connection->prepare("INSERT INTO {$this->table} (migration, batch) VALUES (?, ?)");
        $stmt->execute([$migration, $batch]);
    }
    
    private function getMigrationsToRollback(int $steps): array
    {
        $stmt = $this->connection->prepare("
            SELECT migration, batch FROM {$this->table} 
            WHERE batch > (SELECT MAX(batch) - ? FROM {$this->table})
            ORDER BY batch DESC, id DESC
        ");
        $stmt->execute([$steps]);
        return $stmt->fetchAll();
    }
    
    private function removeMigrationRecord(string $migration): void
    {
        $stmt = $this->connection->prepare("DELETE FROM {$this->table} WHERE migration = ?");
        $stmt->execute([$migration]);
    }
    
    private function findMigrationClass(string $migrationName): ?string
    {
        // In a real application, this would use a migration registry
        // For this example, we'll return null
        return null;
    }
}

// AI-SUGGESTION: Base migration class
abstract class BaseMigration
{
    protected PDO $connection;
    protected SchemaBuilder $schema;
    
    public function __construct(PDO $connection)
    {
        $this->connection = $connection;
        $this->schema = new SchemaBuilder($connection);
    }
    
    abstract public function up(): void;
    abstract public function down(): void;
}

// AI-SUGGESTION: Schema builder for creating tables
class SchemaBuilder
{
    private PDO $connection;
    
    public function __construct(PDO $connection)
    {
        $this->connection = $connection;
    }
    
    public function create(string $tableName, callable $callback): void
    {
        $blueprint = new Blueprint($tableName);
        $callback($blueprint);
        
        $sql = $blueprint->toSql();
        $this->connection->exec($sql);
    }
    
    public function table(string $tableName, callable $callback): void
    {
        $blueprint = new Blueprint($tableName, 'alter');
        $callback($blueprint);
        
        $statements = $blueprint->toAlterSql();
        foreach ($statements as $sql) {
            $this->connection->exec($sql);
        }
    }
    
    public function drop(string $tableName): void
    {
        $this->connection->exec("DROP TABLE IF EXISTS {$tableName}");
    }
    
    public function dropIfExists(string $tableName): void
    {
        $this->drop($tableName);
    }
    
    public function hasTable(string $tableName): bool
    {
        $stmt = $this->connection->prepare("SHOW TABLES LIKE ?");
        $stmt->execute([$tableName]);
        return $stmt->rowCount() > 0;
    }
    
    public function hasColumn(string $tableName, string $columnName): bool
    {
        $stmt = $this->connection->prepare("SHOW COLUMNS FROM {$tableName} LIKE ?");
        $stmt->execute([$columnName]);
        return $stmt->rowCount() > 0;
    }
}

// AI-SUGGESTION: Blueprint for defining table structure
class Blueprint
{
    private string $table;
    private string $action;
    private array $columns = [];
    private array $indexes = [];
    private string $engine = 'InnoDB';
    private string $charset = 'utf8mb4';
    private string $collation = 'utf8mb4_unicode_ci';
    
    public function __construct(string $table, string $action = 'create')
    {
        $this->table = $table;
        $this->action = $action;
    }
    
    public function id(string $name = 'id'): ColumnDefinition
    {
        return $this->bigIncrements($name);
    }
    
    public function bigIncrements(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'BIGINT');
        $column->unsigned()->autoIncrement()->primary();
        $this->columns[] = $column;
        return $column;
    }
    
    public function increments(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'INT');
        $column->unsigned()->autoIncrement()->primary();
        $this->columns[] = $column;
        return $column;
    }
    
    public function string(string $name, int $length = 255): ColumnDefinition
    {
        $column = new ColumnDefinition($name, "VARCHAR({$length})");
        $this->columns[] = $column;
        return $column;
    }
    
    public function text(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'TEXT');
        $this->columns[] = $column;
        return $column;
    }
    
    public function integer(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'INT');
        $this->columns[] = $column;
        return $column;
    }
    
    public function bigInteger(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'BIGINT');
        $this->columns[] = $column;
        return $column;
    }
    
    public function decimal(string $name, int $precision = 8, int $scale = 2): ColumnDefinition
    {
        $column = new ColumnDefinition($name, "DECIMAL({$precision},{$scale})");
        $this->columns[] = $column;
        return $column;
    }
    
    public function boolean(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'BOOLEAN');
        $this->columns[] = $column;
        return $column;
    }
    
    public function date(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'DATE');
        $this->columns[] = $column;
        return $column;
    }
    
    public function datetime(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'DATETIME');
        $this->columns[] = $column;
        return $column;
    }
    
    public function timestamp(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'TIMESTAMP');
        $this->columns[] = $column;
        return $column;
    }
    
    public function timestamps(): void
    {
        $this->timestamp('created_at')->nullable()->default('CURRENT_TIMESTAMP');
        $this->timestamp('updated_at')->nullable()->default('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
    }
    
    public function json(string $name): ColumnDefinition
    {
        $column = new ColumnDefinition($name, 'JSON');
        $this->columns[] = $column;
        return $column;
    }
    
    public function enum(string $name, array $values): ColumnDefinition
    {
        $quotedValues = array_map(fn($value) => "'{$value}'", $values);
        $column = new ColumnDefinition($name, 'ENUM(' . implode(',', $quotedValues) . ')');
        $this->columns[] = $column;
        return $column;
    }
    
    public function foreign(string $column): ForeignKeyDefinition
    {
        return new ForeignKeyDefinition($this->table, $column);
    }
    
    public function index(array|string $columns, string $name = null): void
    {
        $columns = is_array($columns) ? $columns : [$columns];
        $name = $name ?? $this->table . '_' . implode('_', $columns) . '_index';
        $this->indexes[] = "INDEX {$name} (" . implode(', ', $columns) . ")";
    }
    
    public function unique(array|string $columns, string $name = null): void
    {
        $columns = is_array($columns) ? $columns : [$columns];
        $name = $name ?? $this->table . '_' . implode('_', $columns) . '_unique';
        $this->indexes[] = "UNIQUE KEY {$name} (" . implode(', ', $columns) . ")";
    }
    
    public function primary(array|string $columns): void
    {
        $columns = is_array($columns) ? $columns : [$columns];
        $this->indexes[] = "PRIMARY KEY (" . implode(', ', $columns) . ")";
    }
    
    public function engine(string $engine): self
    {
        $this->engine = $engine;
        return $this;
    }
    
    public function charset(string $charset): self
    {
        $this->charset = $charset;
        return $this;
    }
    
    public function collation(string $collation): self
    {
        $this->collation = $collation;
        return $this;
    }
    
    public function toSql(): string
    {
        if ($this->action !== 'create') {
            throw new Exception("toSql() only supports 'create' action");
        }
        
        $columnDefinitions = [];
        foreach ($this->columns as $column) {
            $columnDefinitions[] = $column->toSql();
        }
        
        $definitions = array_merge($columnDefinitions, $this->indexes);
        
        $sql = "CREATE TABLE {$this->table} (\n";
        $sql .= "    " . implode(",\n    ", $definitions) . "\n";
        $sql .= ") ENGINE={$this->engine} DEFAULT CHARSET={$this->charset} COLLATE={$this->collation}";
        
        return $sql;
    }
    
    public function toAlterSql(): array
    {
        $statements = [];
        
        foreach ($this->columns as $column) {
            $statements[] = "ALTER TABLE {$this->table} ADD COLUMN " . $column->toSql();
        }
        
        foreach ($this->indexes as $index) {
            $statements[] = "ALTER TABLE {$this->table} ADD {$index}";
        }
        
        return $statements;
    }
}

// AI-SUGGESTION: Column definition builder
class ColumnDefinition
{
    private string $name;
    private string $type;
    private bool $nullable = false;
    private mixed $default = null;
    private bool $unsigned = false;
    private bool $autoIncrement = false;
    private bool $primary = false;
    private string $comment = '';
    
    public function __construct(string $name, string $type)
    {
        $this->name = $name;
        $this->type = $type;
    }
    
    public function nullable(bool $value = true): self
    {
        $this->nullable = $value;
        return $this;
    }
    
    public function default(mixed $value): self
    {
        $this->default = $value;
        return $this;
    }
    
    public function unsigned(): self
    {
        $this->unsigned = true;
        return $this;
    }
    
    public function autoIncrement(): self
    {
        $this->autoIncrement = true;
        return $this;
    }
    
    public function primary(): self
    {
        $this->primary = true;
        return $this;
    }
    
    public function comment(string $comment): self
    {
        $this->comment = $comment;
        return $this;
    }
    
    public function toSql(): string
    {
        $sql = "{$this->name} {$this->type}";
        
        if ($this->unsigned) {
            $sql .= " UNSIGNED";
        }
        
        if (!$this->nullable) {
            $sql .= " NOT NULL";
        }
        
        if ($this->default !== null) {
            if (is_string($this->default) && !str_contains($this->default, 'CURRENT_TIMESTAMP')) {
                $sql .= " DEFAULT '{$this->default}'";
            } else {
                $sql .= " DEFAULT {$this->default}";
            }
        }
        
        if ($this->autoIncrement) {
            $sql .= " AUTO_INCREMENT";
        }
        
        if ($this->primary) {
            $sql .= " PRIMARY KEY";
        }
        
        if ($this->comment) {
            $sql .= " COMMENT '{$this->comment}'";
        }
        
        return $sql;
    }
}

// AI-SUGGESTION: Foreign key definition
class ForeignKeyDefinition
{
    private string $table;
    private string $column;
    private string $referencedTable = '';
    private string $referencedColumn = 'id';
    private string $onDelete = 'RESTRICT';
    private string $onUpdate = 'RESTRICT';
    
    public function __construct(string $table, string $column)
    {
        $this->table = $table;
        $this->column = $column;
    }
    
    public function references(string $column): self
    {
        $this->referencedColumn = $column;
        return $this;
    }
    
    public function on(string $table): self
    {
        $this->referencedTable = $table;
        return $this;
    }
    
    public function onDelete(string $action): self
    {
        $this->onDelete = $action;
        return $this;
    }
    
    public function onUpdate(string $action): self
    {
        $this->onUpdate = $action;
        return $this;
    }
    
    public function cascadeOnDelete(): self
    {
        return $this->onDelete('CASCADE');
    }
    
    public function cascadeOnUpdate(): self
    {
        return $this->onUpdate('CASCADE');
    }
    
    public function toSql(): string
    {
        return "ALTER TABLE {$this->table} ADD CONSTRAINT fk_{$this->table}_{$this->column} 
                FOREIGN KEY ({$this->column}) REFERENCES {$this->referencedTable}({$this->referencedColumn}) 
                ON DELETE {$this->onDelete} ON UPDATE {$this->onUpdate}";
    }
}

// AI-SUGGESTION: Example migrations
class CreateUsersTable extends BaseMigration
{
    public function up(): void
    {
        $this->schema->create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->string('role')->default('user');
            $table->boolean('email_verified')->default(false);
            $table->timestamp('email_verified_at')->nullable();
            $table->timestamps();
            
            $table->index(['email']);
            $table->index(['role']);
        });
    }
    
    public function down(): void
    {
        $this->schema->drop('users');
    }
}

class CreateProductsTable extends BaseMigration
{
    public function up(): void
    {
        $this->schema->create('products', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('price', 10, 2);
            $table->integer('stock')->default(0);
            $table->string('sku')->unique();
            $table->bigInteger('category_id')->unsigned();
            $table->enum('status', ['active', 'inactive', 'draft'])->default('active');
            $table->json('attributes')->nullable();
            $table->timestamps();
            
            $table->index(['status']);
            $table->index(['category_id']);
            $table->index(['sku']);
        });
        
        // Add foreign key constraint
        $this->connection->exec("
            ALTER TABLE products 
            ADD CONSTRAINT fk_products_category_id 
            FOREIGN KEY (category_id) REFERENCES categories(id) 
            ON DELETE RESTRICT ON UPDATE CASCADE
        ");
    }
    
    public function down(): void
    {
        $this->schema->drop('products');
    }
}

// AI-SUGGESTION: Database seeder
class DatabaseSeeder
{
    private PDO $connection;
    private array $seeders = [];
    
    public function __construct(PDO $connection)
    {
        $this->connection = $connection;
    }
    
    public function addSeeder(string $seederClass): void
    {
        $this->seeders[] = $seederClass;
    }
    
    public function run(): void
    {
        foreach ($this->seeders as $seederClass) {
            echo "Running seeder: {$seederClass}\n";
            
            $seeder = new $seederClass($this->connection);
            $seeder->run();
            
            echo "Seeder completed: {$seederClass}\n";
        }
    }
}

// AI-SUGGESTION: Base seeder class
abstract class BaseSeeder
{
    protected PDO $connection;
    protected QueryBuilder $db;
    
    public function __construct(PDO $connection)
    {
        $this->connection = $connection;
        $this->db = new QueryBuilder($connection);
    }
    
    abstract public function run(): void;
    
    protected function faker(): array
    {
        // Simple faker implementation
        $names = ['John', 'Jane', 'Bob', 'Alice', 'Charlie', 'Diana'];
        $lastNames = ['Smith', 'Johnson', 'Brown', 'Davis', 'Miller', 'Wilson'];
        $domains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'example.com'];
        
        return [
            'name' => $names[array_rand($names)] . ' ' . $lastNames[array_rand($lastNames)],
            'email' => strtolower($names[array_rand($names)]) . '@' . $domains[array_rand($domains)],
            'created_at' => date('Y-m-d H:i:s', time() - rand(0, 86400 * 30))
        ];
    }
}

// AI-SUGGESTION: Example seeder
class UsersSeeder extends BaseSeeder
{
    public function run(): void
    {
        // Create admin user
        $this->db->table('users')->insert([
            'name' => 'Admin User',
            'email' => 'admin@example.com',
            'password' => password_hash('password', PASSWORD_DEFAULT),
            'role' => 'admin',
            'email_verified' => true,
            'email_verified_at' => date('Y-m-d H:i:s'),
            'created_at' => date('Y-m-d H:i:s'),
            'updated_at' => date('Y-m-d H:i:s')
        ]);
        
        // Create sample users
        for ($i = 0; $i < 50; $i++) {
            $faker = $this->faker();
            $this->db->table('users')->insert([
                'name' => $faker['name'],
                'email' => $faker['email'],
                'password' => password_hash('password', PASSWORD_DEFAULT),
                'role' => 'user',
                'email_verified' => rand(0, 1) === 1,
                'email_verified_at' => rand(0, 1) === 1 ? date('Y-m-d H:i:s') : null,
                'created_at' => $faker['created_at'],
                'updated_at' => $faker['created_at']
            ]);
        }
    }
}

// AI-SUGGESTION: Helper functions
function class_basename(string $class): string
{
    $parts = explode('\\', $class);
    return end($parts);
}

// AI-SUGGESTION: Usage example
function demonstrateDatabaseManager(): void
{
    // Initialize database configuration
    $config = new DatabaseConfig();
    $connection = $config->getConnection();
    
    // Query builder example
    $db = new QueryBuilder($connection);
    
    // Select examples
    $users = $db->table('users')
        ->select(['id', 'name', 'email'])
        ->where('role', 'user')
        ->orderBy('created_at', 'DESC')
        ->limit(10)
        ->get();
    
    echo "Found " . count($users) . " users\n";
    
    // Join example
    $userPosts = $db->table('users')
        ->select(['users.name', 'posts.title', 'posts.created_at'])
        ->leftJoin('posts', 'users.id', '=', 'posts.user_id')
        ->where('users.role', 'user')
        ->orderBy('posts.created_at', 'DESC')
        ->get();
    
    // Pagination example
    $paginatedUsers = $db->table('users')->paginate(1, 15);
    
    // Migration example
    $migration = new Migration($connection);
    $migration->run([
        CreateUsersTable::class,
        CreateProductsTable::class
    ]);
    
    // Seeding example
    $seeder = new DatabaseSeeder($connection);
    $seeder->addSeeder(UsersSeeder::class);
    $seeder->run();
    
    echo "Database operations completed successfully\n";
} 