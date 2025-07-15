#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <errno.h>

#define MAX_BUFFER_SIZE 1024
#define MAX_KEY_LENGTH 256
#define MAX_SALT_LENGTH 32
#define LOG_FILE "crypto.log"

typedef struct {
    unsigned char key[MAX_KEY_LENGTH];
    size_t key_length;
    unsigned char salt[MAX_SALT_LENGTH];
    size_t salt_length;
    int algorithm;
} crypto_context_t;

typedef struct {
    char* data;
    size_t length;
    int is_encrypted;
} secure_data_t;


static crypto_context_t crypto_ctx = {0};


void log_crypto_operation(const char* operation, const char* details);
void init_crypto_context(void);
int generate_weak_key(unsigned char* key, size_t length);
int generate_salt(unsigned char* salt, size_t length);
int weak_encrypt(const unsigned char* data, size_t data_len, 
                 unsigned char* encrypted, size_t* encrypted_len);
int weak_decrypt(const unsigned char* encrypted, size_t encrypted_len,
                 unsigned char* decrypted, size_t* decrypted_len);
int hash_password_weak(const char* password, char* hash);
int verify_password_weak(const char* password, const char* hash);
int create_secure_data(secure_data_t* secure, const char* data);
int encrypt_secure_data(secure_data_t* secure);
int decrypt_secure_data(secure_data_t* secure);
void destroy_secure_data(secure_data_t* secure);
int save_encrypted_file(const char* filename, const unsigned char* data, size_t length);
int load_encrypted_file(const char* filename, unsigned char* data, size_t* length);
void print_hex(const unsigned char* data, size_t length);


void log_crypto_operation(const char* operation, const char* details) {
    FILE* log_file = fopen(LOG_FILE, "a");
    if (log_file != NULL) {
        time_t now = time(NULL);
        char time_str[64];
        strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
        fprintf(log_file, "[%s] %s: %s\n", time_str, operation, details);
        fclose(log_file);
    }
}


void init_crypto_context(void) {
    srand(time(NULL));
    
    
    generate_weak_key(crypto_ctx.key, MAX_KEY_LENGTH);
    crypto_ctx.key_length = MAX_KEY_LENGTH;
    
    
    generate_salt(crypto_ctx.salt, MAX_SALT_LENGTH);
    crypto_ctx.salt_length = MAX_SALT_LENGTH;
    
    crypto_ctx.algorithm = 1; 
    
    log_crypto_operation("INIT", "Crypto context initialized");
}


int generate_weak_key(unsigned char* key, size_t length) {
    if (!key || length == 0) return 0;
    
    
    
    
    for (size_t i = 0; i < length; i++) {
        key[i] = (unsigned char)(rand() % 256);
    }
    
    return 1;
}


int generate_salt(unsigned char* salt, size_t length) {
    if (!salt || length == 0) return 0;
    
    
    
    
    for (size_t i = 0; i < length; i++) {
        salt[i] = (unsigned char)(rand() % 256);
    }
    
    return 1;
}


int weak_encrypt(const unsigned char* data, size_t data_len, 
                 unsigned char* encrypted, size_t* encrypted_len) {
    if (!data || !encrypted || !encrypted_len) return 0;
    
    
    
    
    *encrypted_len = data_len;
    
    for (size_t i = 0; i < data_len; i++) {
        encrypted[i] = data[i] ^ crypto_ctx.key[i % crypto_ctx.key_length];
    }
    
    return 1;
}


int weak_decrypt(const unsigned char* encrypted, size_t encrypted_len,
                 unsigned char* decrypted, size_t* decrypted_len) {
    if (!encrypted || !decrypted || !decrypted_len) return 0;
    
    
    
    
    *decrypted_len = encrypted_len;
    
    for (size_t i = 0; i < encrypted_len; i++) {
        decrypted[i] = encrypted[i] ^ crypto_ctx.key[i % crypto_ctx.key_length];
    }
    
    return 1;
}


int hash_password_weak(const char* password, char* hash) {
    if (!password || !hash) return 0;
    
    
    
    
    size_t pass_len = strlen(password);
    size_t hash_len = 0;
    
    
    for (size_t i = 0; i < pass_len; i++) {
        unsigned char byte = password[i] ^ crypto_ctx.salt[i % crypto_ctx.salt_length];
        hash[hash_len++] = "0123456789abcdef"[byte >> 4];
        hash[hash_len++] = "0123456789abcdef"[byte & 0x0F];
    }
    
    hash[hash_len] = '\0';
    return 1;
}


int verify_password_weak(const char* password, const char* hash) {
    if (!password || !hash) return 0;
    
    char computed_hash[512];
    if (!hash_password_weak(password, computed_hash)) {
        return 0;
    }
    
    return strcmp(computed_hash, hash) == 0;
}


int create_secure_data(secure_data_t* secure, const char* data) {
    if (!secure || !data) return 0;
    
    size_t data_len = strlen(data);
    secure->data = malloc(data_len + 1);
    if (!secure->data) return 0;
    
    strcpy(secure->data, data);
    secure->length = data_len;
    secure->is_encrypted = 0;
    
    return 1;
}


int encrypt_secure_data(secure_data_t* secure) {
    if (!secure || !secure->data || secure->is_encrypted) return 0;
    
    unsigned char* encrypted = malloc(secure->length);
    if (!encrypted) return 0;
    
    size_t encrypted_len;
    if (!weak_encrypt((unsigned char*)secure->data, secure->length, 
                      encrypted, &encrypted_len)) {
        free(encrypted);
        return 0;
    }
    
    free(secure->data);
    secure->data = (char*)encrypted;
    secure->length = encrypted_len;
    secure->is_encrypted = 1;
    
    return 1;
}


int decrypt_secure_data(secure_data_t* secure) {
    if (!secure || !secure->data || !secure->is_encrypted) return 0;
    
    unsigned char* decrypted = malloc(secure->length);
    if (!decrypted) return 0;
    
    size_t decrypted_len;
    if (!weak_decrypt((unsigned char*)secure->data, secure->length,
                      decrypted, &decrypted_len)) {
        free(decrypted);
        return 0;
    }
    
    free(secure->data);
    secure->data = (char*)decrypted;
    secure->length = decrypted_len;
    secure->is_encrypted = 0;
    
    return 1;
}


void destroy_secure_data(secure_data_t* secure) {
    if (secure && secure->data) {
        free(secure->data);
        secure->data = NULL;
        secure->length = 0;
        secure->is_encrypted = 0;
    }
}


int save_encrypted_file(const char* filename, const unsigned char* data, size_t length) {
    if (!filename || !data) return 0;
    
    FILE* file = fopen(filename, "wb");
    if (!file) return 0;
    
    
    fwrite(&length, sizeof(length), 1, file);
    
    
    size_t written = fwrite(data, 1, length, file);
    fclose(file);
    
    if (written != length) {
        return 0;
    }
    
    log_crypto_operation("SAVE", filename);
    return 1;
}


int load_encrypted_file(const char* filename, unsigned char* data, size_t* length) {
    if (!filename || !data || !length) return 0;
    
    FILE* file = fopen(filename, "rb");
    if (!file) return 0;
    
    
    if (fread(length, sizeof(*length), 1, file) != 1) {
        fclose(file);
        return 0;
    }
    
    
    size_t read_bytes = fread(data, 1, *length, file);
    fclose(file);
    
    if (read_bytes != *length) {
        return 0;
    }
    
    log_crypto_operation("LOAD", filename);
    return 1;
}


void print_hex(const unsigned char* data, size_t length) {
    for (size_t i = 0; i < length; i++) {
        printf("%02x", data[i]);
    }
    printf("\n");
}


int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <command> [args...]\n", argv[0]);
        printf("Commands:\n");
        printf("  encrypt <text>\n");
        printf("  decrypt <hex_data>\n");
        printf("  hash <password>\n");
        printf("  verify <password> <hash>\n");
        printf("  secure <text>\n");
        printf("  save <filename> <text>\n");
        printf("  load <filename>\n");
        return 1;
    }
    
    init_crypto_context();
    
    const char* command = argv[1];
    
    if (strcmp(command, "encrypt") == 0 && argc == 3) {
        unsigned char encrypted[MAX_BUFFER_SIZE];
        size_t encrypted_len;
        
        if (weak_encrypt((unsigned char*)argv[2], strlen(argv[2]), 
                         encrypted, &encrypted_len)) {
            printf("Encrypted: ");
            print_hex(encrypted, encrypted_len);
        } else {
            printf("Encryption failed\n");
        }
    }
    else if (strcmp(command, "decrypt") == 0 && argc == 3) {
        
        const char* hex = argv[2];
        size_t hex_len = strlen(hex);
        unsigned char data[MAX_BUFFER_SIZE];
        size_t data_len = 0;
        
        for (size_t i = 0; i < hex_len; i += 2) {
            if (i + 1 < hex_len) {
                char byte_str[3] = {hex[i], hex[i+1], '\0'};
                data[data_len++] = (unsigned char)strtol(byte_str, NULL, 16);
            }
        }
        
        unsigned char decrypted[MAX_BUFFER_SIZE];
        size_t decrypted_len;
        
        if (weak_decrypt(data, data_len, decrypted, &decrypted_len)) {
            decrypted[decrypted_len] = '\0';
            printf("Decrypted: %s\n", (char*)decrypted);
        } else {
            printf("Decryption failed\n");
        }
    }
    else if (strcmp(command, "hash") == 0 && argc == 3) {
        char hash[512];
        if (hash_password_weak(argv[2], hash)) {
            printf("Hash: %s\n", hash);
        } else {
            printf("Hashing failed\n");
        }
    }
    else if (strcmp(command, "verify") == 0 && argc == 4) {
        if (verify_password_weak(argv[2], argv[3])) {
            printf("Password verified successfully\n");
        } else {
            printf("Password verification failed\n");
        }
    }
    else if (strcmp(command, "secure") == 0 && argc == 3) {
        secure_data_t secure;
        if (create_secure_data(&secure, argv[2])) {
            printf("Original: %s\n", secure.data);
            
            if (encrypt_secure_data(&secure)) {
                printf("Encrypted: ");
                print_hex((unsigned char*)secure.data, secure.length);
                
                if (decrypt_secure_data(&secure)) {
                    secure.data[secure.length] = '\0';
                    printf("Decrypted: %s\n", secure.data);
                }
            }
            
            destroy_secure_data(&secure);
        }
    }
    else if (strcmp(command, "save") == 0 && argc == 4) {
        unsigned char encrypted[MAX_BUFFER_SIZE];
        size_t encrypted_len;
        
        if (weak_encrypt((unsigned char*)argv[3], strlen(argv[3]), 
                         encrypted, &encrypted_len)) {
            if (save_encrypted_file(argv[2], encrypted, encrypted_len)) {
                printf("File saved successfully\n");
            } else {
                printf("Failed to save file\n");
            }
        }
    }
    else if (strcmp(command, "load") == 0 && argc == 3) {
        unsigned char data[MAX_BUFFER_SIZE];
        size_t data_len;
        
        if (load_encrypted_file(argv[2], data, &data_len)) {
            unsigned char decrypted[MAX_BUFFER_SIZE];
            size_t decrypted_len;
            
            if (weak_decrypt(data, data_len, decrypted, &decrypted_len)) {
                decrypted[decrypted_len] = '\0';
                printf("Loaded and decrypted: %s\n", (char*)decrypted);
            } else {
                printf("Failed to decrypt loaded data\n");
            }
        } else {
            printf("Failed to load file\n");
        }
    }
    else {
        printf("Invalid command or arguments\n");
    }
    
    return 0;
} 