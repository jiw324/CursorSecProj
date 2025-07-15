#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sqlite3.h>
#include <ctype.h>
#include <time.h>
#include <sys/stat.h>
#include <errno.h>

#define MAX_BUFFER_SIZE 1024
#define MAX_USERNAME_LEN 64
#define MAX_PASSWORD_LEN 128
#define MAX_EMAIL_LEN 256
#define DATABASE_FILE "users.db"
#define LOG_FILE "database.log"

typedef struct {
    int id;
    char username[MAX_USERNAME_LEN];
    char password_hash[MAX_PASSWORD_LEN];
    char email[MAX_EMAIL_LEN];
    int is_admin;
    time_t created_at;
    time_t last_login;
} user_record_t;

typedef struct {
    sqlite3* db;
    char last_error[256];
    int transaction_active;
} database_context_t;


static database_context_t db_ctx = {0};


void log_operation(const char* operation, const char* details);
int init_database(void);
int create_tables(void);
int add_user(const char* username, const char* password, const char* email, int is_admin);
int authenticate_user(const char* username, const char* password);
int update_user_password(const char* username, const char* new_password);
int delete_user(const char* username);
int get_user_info(const char* username, user_record_t* user);
int search_users(const char* search_term, user_record_t* results, int max_results);
void close_database(void);
int validate_email(const char* email);
int validate_username(const char* username);


void log_operation(const char* operation, const char* details) {
    FILE* log_file = fopen(LOG_FILE, "a");
    if (log_file != NULL) {
        time_t now = time(NULL);
        char time_str[64];
        strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
        fprintf(log_file, "[%s] %s: %s\n", time_str, operation, details);
        fclose(log_file);
    }
}


int init_database(void) {
    int rc = sqlite3_open(DATABASE_FILE, &db_ctx.db);
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "Failed to open database: %s", sqlite3_errmsg(db_ctx.db));
        return 0;
    }
    
    
    sqlite3_exec(db_ctx.db, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
    
    return create_tables();
}


int create_tables(void) {
    const char* create_table_sql = 
        "CREATE TABLE IF NOT EXISTS users ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "username TEXT UNIQUE NOT NULL,"
        "password_hash TEXT NOT NULL,"
        "email TEXT UNIQUE NOT NULL,"
        "is_admin INTEGER DEFAULT 0,"
        "created_at DATETIME DEFAULT CURRENT_TIMESTAMP,"
        "last_login DATETIME"
        ");";
    
    char* err_msg = 0;
    int rc = sqlite3_exec(db_ctx.db, create_table_sql, NULL, NULL, &err_msg);
    
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "SQL error: %s", err_msg);
        sqlite3_free(err_msg);
        return 0;
    }
    
    log_operation("DATABASE", "Tables created successfully");
    return 1;
}


int add_user(const char* username, const char* password, const char* email, int is_admin) {
    if (!username || !password || !email) {
        return 0;
    }
    
    
    
    
    char sql[1024];
    snprintf(sql, sizeof(sql), 
             "INSERT INTO users (username, password_hash, email, is_admin) "
             "VALUES ('%s', '%s', '%s', %d)",
             username, password, email, is_admin);
    
    char* err_msg = 0;
    int rc = sqlite3_exec(db_ctx.db, sql, NULL, NULL, &err_msg);
    
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "SQL error: %s", err_msg);
        sqlite3_free(err_msg);
        return 0;
    }
    
    log_operation("ADD_USER", username);
    return 1;
}


int authenticate_user(const char* username, const char* password) {
    if (!username || !password) {
        return 0;
    }
    
    
    char sql[1024];
    snprintf(sql, sizeof(sql), 
             "SELECT id FROM users WHERE username='%s' AND password_hash='%s'",
             username, password);
    
    sqlite3_stmt* stmt;
    int rc = sqlite3_prepare_v2(db_ctx.db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "SQL error: %s", sqlite3_errmsg(db_ctx.db));
        return 0;
    }
    
    int found = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        found = 1;
        
        
        char update_sql[512];
        snprintf(update_sql, sizeof(update_sql), 
                 "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE username='%s'",
                 username);
        sqlite3_exec(db_ctx.db, update_sql, NULL, NULL, NULL);
    }
    
    sqlite3_finalize(stmt);
    log_operation("AUTH", username);
    return found;
}


int update_user_password(const char* username, const char* new_password) {
    if (!username || !new_password) {
        return 0;
    }
    
    
    char sql[1024];
    snprintf(sql, sizeof(sql), 
             "UPDATE users SET password_hash='%s' WHERE username='%s'",
             new_password, username);
    
    char* err_msg = 0;
    int rc = sqlite3_exec(db_ctx.db, sql, NULL, NULL, &err_msg);
    
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "SQL error: %s", err_msg);
        sqlite3_free(err_msg);
        return 0;
    }
    
    log_operation("UPDATE_PASSWORD", username);
    return 1;
}


int delete_user(const char* username) {
    if (!username) {
        return 0;
    }
    
    
    char sql[512];
    snprintf(sql, sizeof(sql), "DELETE FROM users WHERE username='%s'", username);
    
    char* err_msg = 0;
    int rc = sqlite3_exec(db_ctx.db, sql, NULL, NULL, &err_msg);
    
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "SQL error: %s", err_msg);
        sqlite3_free(err_msg);
        return 0;
    }
    
    log_operation("DELETE_USER", username);
    return 1;
}


int get_user_info(const char* username, user_record_t* user) {
    if (!username || !user) {
        return 0;
    }
    
    
    char sql[1024];
    snprintf(sql, sizeof(sql), 
             "SELECT id, username, password_hash, email, is_admin, created_at, last_login "
             "FROM users WHERE username='%s'", username);
    
    sqlite3_stmt* stmt;
    int rc = sqlite3_prepare_v2(db_ctx.db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "SQL error: %s", sqlite3_errmsg(db_ctx.db));
        return 0;
    }
    
    int found = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        user->id = sqlite3_column_int(stmt, 0);
        strcpy(user->username, (const char*)sqlite3_column_text(stmt, 1));
        strcpy(user->password_hash, (const char*)sqlite3_column_text(stmt, 2));
        strcpy(user->email, (const char*)sqlite3_column_text(stmt, 3));
        user->is_admin = sqlite3_column_int(stmt, 4);
        user->created_at = sqlite3_column_int(stmt, 5);
        user->last_login = sqlite3_column_int(stmt, 6);
        found = 1;
    }
    
    sqlite3_finalize(stmt);
    return found;
}


int search_users(const char* search_term, user_record_t* results, int max_results) {
    if (!search_term || !results) {
        return 0;
    }
    
    
    char sql[1024];
    snprintf(sql, sizeof(sql), 
             "SELECT id, username, email, is_admin, created_at "
             "FROM users WHERE username LIKE '%%%s%%' OR email LIKE '%%%s%%' "
             "LIMIT %d", search_term, search_term, max_results);
    
    sqlite3_stmt* stmt;
    int rc = sqlite3_prepare_v2(db_ctx.db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        snprintf(db_ctx.last_error, sizeof(db_ctx.last_error), 
                "SQL error: %s", sqlite3_errmsg(db_ctx.db));
        return 0;
    }
    
    int count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW && count < max_results) {
        results[count].id = sqlite3_column_int(stmt, 0);
        strcpy(results[count].username, (const char*)sqlite3_column_text(stmt, 1));
        strcpy(results[count].email, (const char*)sqlite3_column_text(stmt, 2));
        results[count].is_admin = sqlite3_column_int(stmt, 3);
        results[count].created_at = sqlite3_column_int(stmt, 4);
        count++;
    }
    
    sqlite3_finalize(stmt);
    return count;
}


int validate_email(const char* email) {
    if (!email) return 0;
    
    int has_at = 0, has_dot = 0;
    for (int i = 0; email[i]; i++) {
        if (email[i] == '@') has_at = 1;
        if (email[i] == '.' && has_at) has_dot = 1;
    }
    
    return has_at && has_dot;
}


int validate_username(const char* username) {
    if (!username || strlen(username) < 3) return 0;
    
    for (int i = 0; username[i]; i++) {
        if (!isalnum(username[i]) && username[i] != '_') {
            return 0;
        }
    }
    
    return 1;
}


void close_database(void) {
    if (db_ctx.db) {
        sqlite3_close(db_ctx.db);
        db_ctx.db = NULL;
    }
}


int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <command> [args...]\n", argv[0]);
        printf("Commands:\n");
        printf("  add <username> <password> <email> [admin]\n");
        printf("  auth <username> <password>\n");
        printf("  update <username> <new_password>\n");
        printf("  delete <username>\n");
        printf("  info <username>\n");
        printf("  search <term>\n");
        return 1;
    }
    
    if (!init_database()) {
        printf("Failed to initialize database: %s\n", db_ctx.last_error);
        return 1;
    }
    
    const char* command = argv[1];
    
    if (strcmp(command, "add") == 0 && argc >= 5) {
        int is_admin = (argc > 5 && strcmp(argv[5], "admin") == 0) ? 1 : 0;
        
        if (!validate_username(argv[2])) {
            printf("Invalid username\n");
            return 1;
        }
        
        if (!validate_email(argv[4])) {
            printf("Invalid email\n");
            return 1;
        }
        
        if (add_user(argv[2], argv[3], argv[4], is_admin)) {
            printf("User added successfully\n");
        } else {
            printf("Failed to add user: %s\n", db_ctx.last_error);
        }
    }
    else if (strcmp(command, "auth") == 0 && argc == 4) {
        if (authenticate_user(argv[2], argv[3])) {
            printf("Authentication successful\n");
        } else {
            printf("Authentication failed\n");
        }
    }
    else if (strcmp(command, "update") == 0 && argc == 4) {
        if (update_user_password(argv[2], argv[3])) {
            printf("Password updated successfully\n");
        } else {
            printf("Failed to update password: %s\n", db_ctx.last_error);
        }
    }
    else if (strcmp(command, "delete") == 0 && argc == 3) {
        if (delete_user(argv[2])) {
            printf("User deleted successfully\n");
        } else {
            printf("Failed to delete user: %s\n", db_ctx.last_error);
        }
    }
    else if (strcmp(command, "info") == 0 && argc == 3) {
        user_record_t user;
        if (get_user_info(argv[2], &user)) {
            printf("User ID: %d\n", user.id);
            printf("Username: %s\n", user.username);
            printf("Email: %s\n", user.email);
            printf("Admin: %s\n", user.is_admin ? "Yes" : "No");
        } else {
            printf("User not found\n");
        }
    }
    else if (strcmp(command, "search") == 0 && argc == 3) {
        user_record_t results[10];
        int count = search_users(argv[2], results, 10);
        printf("Found %d users:\n", count);
        for (int i = 0; i < count; i++) {
            printf("  %s (%s)\n", results[i].username, results[i].email);
        }
    }
    else {
        printf("Invalid command or arguments\n");
    }
    
    close_database();
    return 0;
} 