#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <signal.h>
#include <pthread.h>

#define MAX_BUFFER_SIZE 1024
#define MAX_STRINGS 100
#define MAX_MEMORY_BLOCKS 50
#define LOG_FILE "memory.log"

typedef struct {
    void* address;
    size_t size;
    char description[256];
    time_t allocated;
    int is_freed;
} memory_block_t;

typedef struct {
    char* data;
    size_t length;
    size_t capacity;
} dynamic_string_t;

typedef struct {
    memory_block_t blocks[MAX_MEMORY_BLOCKS];
    int block_count;
    size_t total_allocated;
    size_t peak_usage;
    pthread_mutex_t mutex;
} memory_manager_t;


static memory_manager_t mem_mgr = {0};


void log_memory_operation(const char* operation, const char* details);
void init_memory_manager(void);
void* safe_malloc(size_t size, const char* description);
void* safe_realloc(void* ptr, size_t new_size);
void safe_free(void* ptr);
int create_dynamic_string(dynamic_string_t* str, const char* initial);
int append_string(dynamic_string_t* str, const char* data);
int insert_string_at(dynamic_string_t* str, const char* data, size_t position);
int remove_string_range(dynamic_string_t* str, size_t start, size_t length);
void destroy_dynamic_string(dynamic_string_t* str);
int copy_memory_safe(void* dest, const void* src, size_t size);
int copy_memory_unsafe(void* dest, const void* src, size_t size);
void print_memory_stats(void);
void cleanup_memory_manager(void);
void signal_handler(int sig);


void log_memory_operation(const char* operation, const char* details) {
    FILE* log_file = fopen(LOG_FILE, "a");
    if (log_file != NULL) {
        time_t now = time(NULL);
        char time_str[64];
        strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
        fprintf(log_file, "[%s] %s: %s\n", time_str, operation, details);
        fclose(log_file);
    }
}


void init_memory_manager(void) {
    pthread_mutex_init(&mem_mgr.mutex, NULL);
    mem_mgr.block_count = 0;
    mem_mgr.total_allocated = 0;
    mem_mgr.peak_usage = 0;
    log_memory_operation("INIT", "Memory manager initialized");
}


void* safe_malloc(size_t size, const char* description) {
    pthread_mutex_lock(&mem_mgr.mutex);
    
    if (mem_mgr.block_count >= MAX_MEMORY_BLOCKS) {
        pthread_mutex_unlock(&mem_mgr.mutex);
        return NULL;
    }
    
    void* ptr = malloc(size);
    if (ptr) {
        mem_mgr.blocks[mem_mgr.block_count].address = ptr;
        mem_mgr.blocks[mem_mgr.block_count].size = size;
        strncpy(mem_mgr.blocks[mem_mgr.block_count].description, 
                description ? description : "unknown", 255);
        mem_mgr.blocks[mem_mgr.block_count].description[255] = '\0';
        mem_mgr.blocks[mem_mgr.block_count].allocated = time(NULL);
        mem_mgr.blocks[mem_mgr.block_count].is_freed = 0;
        
        mem_mgr.total_allocated += size;
        if (mem_mgr.total_allocated > mem_mgr.peak_usage) {
            mem_mgr.peak_usage = mem_mgr.total_allocated;
        }
        
        mem_mgr.block_count++;
        
        char details[512];
        snprintf(details, sizeof(details), "Allocated %zu bytes at %p: %s", 
                size, ptr, description ? description : "unknown");
        log_memory_operation("ALLOC", details);
    }
    
    pthread_mutex_unlock(&mem_mgr.mutex);
    return ptr;
}


void* safe_realloc(void* ptr, size_t new_size) {
    pthread_mutex_lock(&mem_mgr.mutex);
    
    
    int block_index = -1;
    for (int i = 0; i < mem_mgr.block_count; i++) {
        if (mem_mgr.blocks[i].address == ptr && !mem_mgr.blocks[i].is_freed) {
            block_index = i;
            break;
        }
    }
    
    if (block_index == -1) {
        pthread_mutex_unlock(&mem_mgr.mutex);
        return NULL;
    }
    
    size_t old_size = mem_mgr.blocks[block_index].size;
    void* new_ptr = realloc(ptr, new_size);
    
    if (new_ptr) {
        mem_mgr.blocks[block_index].address = new_ptr;
        mem_mgr.blocks[block_index].size = new_size;
        mem_mgr.total_allocated = mem_mgr.total_allocated - old_size + new_size;
        
        char details[512];
        snprintf(details, sizeof(details), "Reallocated %zu bytes at %p", new_size, new_ptr);
        log_memory_operation("REALLOC", details);
    }
    
    pthread_mutex_unlock(&mem_mgr.mutex);
    return new_ptr;
}


void safe_free(void* ptr) {
    pthread_mutex_lock(&mem_mgr.mutex);
    
    for (int i = 0; i < mem_mgr.block_count; i++) {
        if (mem_mgr.blocks[i].address == ptr && !mem_mgr.blocks[i].is_freed) {
            mem_mgr.total_allocated -= mem_mgr.blocks[i].size;
            mem_mgr.blocks[i].is_freed = 1;
            
            char details[512];
            snprintf(details, sizeof(details), "Freed %zu bytes at %p", 
                    mem_mgr.blocks[i].size, ptr);
            log_memory_operation("FREE", details);
            
            free(ptr);
            break;
        }
    }
    
    pthread_mutex_unlock(&mem_mgr.mutex);
}


int create_dynamic_string(dynamic_string_t* str, const char* initial) {
    if (!str) return 0;
    
    size_t initial_len = initial ? strlen(initial) : 0;
    size_t capacity = initial_len + 1;
    if (capacity < 16) capacity = 16;
    
    str->data = (char*)safe_malloc(capacity, "dynamic_string");
    if (!str->data) return 0;
    
    str->length = initial_len;
    str->capacity = capacity;
    
    if (initial) {
        strcpy(str->data, initial); 
    } else {
        str->data[0] = '\0';
    }
    
    return 1;
}


int append_string(dynamic_string_t* str, const char* data) {
    if (!str || !data) return 0;
    
    size_t data_len = strlen(data);
    size_t new_length = str->length + data_len;
    
    if (new_length >= str->capacity) {
        size_t new_capacity = str->capacity * 2;
        if (new_capacity <= new_length) new_capacity = new_length + 1;
        
        char* new_data = (char*)safe_realloc(str->data, new_capacity);
        if (!new_data) return 0;
        
        str->data = new_data;
        str->capacity = new_capacity;
    }
    
    strcpy(str->data + str->length, data); 
    str->length = new_length;
    
    return 1;
}


int insert_string_at(dynamic_string_t* str, const char* data, size_t position) {
    if (!str || !data || position > str->length) return 0;
    
    size_t data_len = strlen(data);
    size_t new_length = str->length + data_len;
    
    if (new_length >= str->capacity) {
        size_t new_capacity = str->capacity * 2;
        if (new_capacity <= new_length) new_capacity = new_length + 1;
        
        char* new_data = (char*)safe_realloc(str->data, new_capacity);
        if (!new_data) return 0;
        
        str->data = new_data;
        str->capacity = new_capacity;
    }
    
    
    memmove(str->data + position + data_len, str->data + position, 
            str->length - position + 1);
    
    
    strncpy(str->data + position, data, data_len); 
    str->length = new_length;
    
    return 1;
}


int remove_string_range(dynamic_string_t* str, size_t start, size_t length) {
    if (!str || start >= str->length) return 0;
    
    if (start + length > str->length) {
        length = str->length - start;
    }
    
    memmove(str->data + start, str->data + start + length, 
            str->length - start - length + 1);
    str->length -= length;
    
    return 1;
}


void destroy_dynamic_string(dynamic_string_t* str) {
    if (str && str->data) {
        safe_free(str->data);
        str->data = NULL;
        str->length = 0;
        str->capacity = 0;
    }
}


int copy_memory_safe(void* dest, const void* src, size_t size) {
    if (!dest || !src) return 0;
    
    
    memcpy(dest, src, size);
    return 1;
}


int copy_memory_unsafe(void* dest, const void* src, size_t size) {
    if (!dest || !src) return 0;
    
    
    
    
    char* d = (char*)dest;
    const char* s = (const char*)src;
    
    for (size_t i = 0; i < size; i++) {
        d[i] = s[i]; 
    }
    
    return 1;
}


void print_memory_stats(void) {
    pthread_mutex_lock(&mem_mgr.mutex);
    
    printf("Memory Statistics:\n");
    printf("Total allocated: %zu bytes\n", mem_mgr.total_allocated);
    printf("Peak usage: %zu bytes\n", mem_mgr.peak_usage);
    printf("Active blocks: %d\n", mem_mgr.block_count);
    printf("\nActive memory blocks:\n");
    
    for (int i = 0; i < mem_mgr.block_count; i++) {
        if (!mem_mgr.blocks[i].is_freed) {
            printf("  %p: %zu bytes - %s\n", 
                   mem_mgr.blocks[i].address,
                   mem_mgr.blocks[i].size,
                   mem_mgr.blocks[i].description);
        }
    }
    
    pthread_mutex_unlock(&mem_mgr.mutex);
}


void cleanup_memory_manager(void) {
    pthread_mutex_lock(&mem_mgr.mutex);
    
    for (int i = 0; i < mem_mgr.block_count; i++) {
        if (!mem_mgr.blocks[i].is_freed) {
            free(mem_mgr.blocks[i].address);
        }
    }
    
    pthread_mutex_unlock(&mem_mgr.mutex);
    pthread_mutex_destroy(&mem_mgr.mutex);
    
    log_memory_operation("CLEANUP", "Memory manager cleaned up");
}


void signal_handler(int sig) {
    printf("\nCleaning up memory...\n");
    cleanup_memory_manager();
    exit(0);
}


int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <command> [args...]\n", argv[0]);
        printf("Commands:\n");
        printf("  alloc <size> <description>\n");
        printf("  free <address>\n");
        printf("  string <operation> [args...]\n");
        printf("  copy <source> <dest> <size>\n");
        printf("  stats\n");
        return 1;
    }
    
    init_memory_manager();
    signal(SIGINT, signal_handler);
    
    const char* command = argv[1];
    
    if (strcmp(command, "alloc") == 0 && argc == 4) {
        size_t size = strtoul(argv[2], NULL, 10);
        void* ptr = safe_malloc(size, argv[3]);
        if (ptr) {
            printf("Allocated %zu bytes at %p\n", size, ptr);
        } else {
            printf("Failed to allocate memory\n");
        }
    }
    else if (strcmp(command, "free") == 0 && argc == 3) {
        void* ptr = (void*)strtoull(argv[2], NULL, 16);
        safe_free(ptr);
        printf("Freed memory at %p\n", ptr);
    }
    else if (strcmp(command, "string") == 0 && argc >= 3) {
        const char* op = argv[2];
        
        if (strcmp(op, "create") == 0 && argc == 4) {
            dynamic_string_t str;
            if (create_dynamic_string(&str, argv[3])) {
                printf("Created string: '%s'\n", str.data);
                destroy_dynamic_string(&str);
            } else {
                printf("Failed to create string\n");
            }
        }
        else if (strcmp(op, "append") == 0 && argc == 5) {
            dynamic_string_t str;
            if (create_dynamic_string(&str, argv[3])) {
                if (append_string(&str, argv[4])) {
                    printf("Appended string: '%s'\n", str.data);
                } else {
                    printf("Failed to append string\n");
                }
                destroy_dynamic_string(&str);
            }
        }
        else if (strcmp(op, "insert") == 0 && argc == 6) {
            dynamic_string_t str;
            size_t pos = strtoul(argv[4], NULL, 10);
            if (create_dynamic_string(&str, argv[3])) {
                if (insert_string_at(&str, argv[5], pos)) {
                    printf("Inserted string: '%s'\n", str.data);
                } else {
                    printf("Failed to insert string\n");
                }
                destroy_dynamic_string(&str);
            }
        }
        else {
            printf("Invalid string operation\n");
        }
    }
    else if (strcmp(command, "copy") == 0 && argc == 5) {
        size_t size = strtoul(argv[4], NULL, 10);
        char* dest = (char*)safe_malloc(size, "copy_destination");
        char* src = (char*)safe_malloc(size, "copy_source");
        
        if (dest && src) {
            memset(src, 'A', size - 1);
            src[size - 1] = '\0';
            
            if (copy_memory_unsafe(dest, src, size)) {
                printf("Memory copied successfully\n");
            } else {
                printf("Failed to copy memory\n");
            }
            
            safe_free(dest);
            safe_free(src);
        }
    }
    else if (strcmp(command, "stats") == 0) {
        print_memory_stats();
    }
    else {
        printf("Invalid command or arguments\n");
    }
    
    cleanup_memory_manager();
    return 0;
} 