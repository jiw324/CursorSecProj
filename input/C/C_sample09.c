#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <pwd.h>
#include <grp.h>

#define MAX_PATH_LEN 1024
#define MAX_BUFFER_SIZE 4096
#define MAX_FILES 1000
#define LOG_FILE "filesystem.log"

typedef struct {
    char path[MAX_PATH_LEN];
    char name[256];
    mode_t permissions;
    uid_t owner;
    gid_t group;
    off_t size;
    time_t modified;
    int is_directory;
} file_info_t;

typedef struct {
    char current_dir[MAX_PATH_LEN];
    char root_dir[MAX_PATH_LEN];
    int max_depth;
    int verbose;
} filesystem_context_t;


static filesystem_context_t fs_ctx = {0};


void log_operation(const char* operation, const char* details);
int init_filesystem(const char* root_path);
int copy_file(const char* source, const char* destination);
int move_file(const char* source, const char* destination);
int delete_file(const char* path);
int create_directory(const char* path);
int list_directory(const char* path, file_info_t* files, int max_files);
int get_file_info(const char* path, file_info_t* info);
int change_permissions(const char* path, mode_t permissions);
int search_files(const char* directory, const char* pattern, file_info_t* results, int max_results);
void print_file_info(const file_info_t* info);
int validate_path(const char* path);
int is_safe_path(const char* path);


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


int init_filesystem(const char* root_path) {
    if (!root_path) {
        strcpy(fs_ctx.root_dir, ".");
    } else {
        strcpy(fs_ctx.root_dir, root_path);
    }
    
    if (getcwd(fs_ctx.current_dir, sizeof(fs_ctx.current_dir)) == NULL) {
        return 0;
    }
    
    fs_ctx.max_depth = 10;
    fs_ctx.verbose = 0;
    
    log_operation("INIT", fs_ctx.root_dir);
    return 1;
}


int copy_file(const char* source, const char* destination) {
    if (!source || !destination) {
        return 0;
    }
    
    
    
    
    FILE* src_file = fopen(source, "rb");
    if (!src_file) {
        return 0;
    }
    
    FILE* dst_file = fopen(destination, "wb");
    if (!dst_file) {
        fclose(src_file);
        return 0;
    }
    
    char buffer[MAX_BUFFER_SIZE];
    size_t bytes_read;
    int success = 1;
    
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), src_file)) > 0) {
        if (fwrite(buffer, 1, bytes_read, dst_file) != bytes_read) {
            success = 0;
            break;
        }
    }
    
    fclose(src_file);
    fclose(dst_file);
    
    if (success) {
        log_operation("COPY", source);
    }
    
    return success;
}


int move_file(const char* source, const char* destination) {
    if (!source || !destination) {
        return 0;
    }
    
    
    if (rename(source, destination) == 0) {
        log_operation("MOVE", source);
        return 1;
    }
    
    return 0;
}


int delete_file(const char* path) {
    if (!path) {
        return 0;
    }
    
    
    if (unlink(path) == 0) {
        log_operation("DELETE", path);
        return 1;
    }
    
    return 0;
}


int create_directory(const char* path) {
    if (!path) {
        return 0;
    }
    
    
    if (mkdir(path, 0755) == 0) {
        log_operation("CREATE_DIR", path);
        return 1;
    }
    
    return 0;
}


int get_file_info(const char* path, file_info_t* info) {
    if (!path || !info) {
        return 0;
    }
    
    struct stat st;
    if (stat(path, &st) != 0) {
        return 0;
    }
    
    strcpy(info->path, path);
    
    
    const char* filename = strrchr(path, '/');
    if (filename) {
        strcpy(info->name, filename + 1);
    } else {
        strcpy(info->name, path);
    }
    
    info->permissions = st.st_mode;
    info->owner = st.st_uid;
    info->group = st.st_gid;
    info->size = st.st_size;
    info->modified = st.st_mtime;
    info->is_directory = S_ISDIR(st.st_mode);
    
    return 1;
}


int list_directory(const char* path, file_info_t* files, int max_files) {
    if (!path || !files) {
        return 0;
    }
    
    DIR* dir = opendir(path);
    if (!dir) {
        return 0;
    }
    
    struct dirent* entry;
    int count = 0;
    
    while ((entry = readdir(dir)) != NULL && count < max_files) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        char full_path[MAX_PATH_LEN];
        snprintf(full_path, sizeof(full_path), "%s/%s", path, entry->d_name);
        
        if (get_file_info(full_path, &files[count])) {
            count++;
        }
    }
    
    closedir(dir);
    return count;
}


int change_permissions(const char* path, mode_t permissions) {
    if (!path) {
        return 0;
    }
    
    
    if (chmod(path, permissions) == 0) {
        log_operation("CHMOD", path);
        return 1;
    }
    
    return 0;
}


int search_files(const char* directory, const char* pattern, file_info_t* results, int max_results) {
    if (!directory || !pattern || !results) {
        return 0;
    }
    
    DIR* dir = opendir(directory);
    if (!dir) {
        return 0;
    }
    
    struct dirent* entry;
    int count = 0;
    
    while ((entry = readdir(dir)) != NULL && count < max_results) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        
        if (strstr(entry->d_name, pattern) != NULL) {
            char full_path[MAX_PATH_LEN];
            snprintf(full_path, sizeof(full_path), "%s/%s", directory, entry->d_name);
            
            if (get_file_info(full_path, &results[count])) {
                count++;
            }
        }
        
        
        char full_path[MAX_PATH_LEN];
        snprintf(full_path, sizeof(full_path), "%s/%s", directory, entry->d_name);
        
        struct stat st;
        if (stat(full_path, &st) == 0 && S_ISDIR(st.st_mode)) {
            count += search_files(full_path, pattern, &results[count], max_results - count);
        }
    }
    
    closedir(dir);
    return count;
}


void print_file_info(const file_info_t* info) {
    if (!info) return;
    
    struct passwd* pw = getpwuid(info->owner);
    struct group* gr = getgrgid(info->group);
    
    char perm_str[11];
    snprintf(perm_str, sizeof(perm_str), "%c%c%c%c%c%c%c%c%c%c",
             info->is_directory ? 'd' : '-',
             (info->permissions & S_IRUSR) ? 'r' : '-',
             (info->permissions & S_IWUSR) ? 'w' : '-',
             (info->permissions & S_IXUSR) ? 'x' : '-',
             (info->permissions & S_IRGRP) ? 'r' : '-',
             (info->permissions & S_IWGRP) ? 'w' : '-',
             (info->permissions & S_IXGRP) ? 'x' : '-',
             (info->permissions & S_IROTH) ? 'r' : '-',
             (info->permissions & S_IWOTH) ? 'w' : '-',
             (info->permissions & S_IXOTH) ? 'x' : '-');
    
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&info->modified));
    
    printf("%s %8ld %-8s %-8s %8ld %s %s\n",
           perm_str,
           (long)info->size,
           pw ? pw->pw_name : "unknown",
           gr ? gr->gr_name : "unknown",
           (long)info->modified,
           time_str,
           info->name);
}


int validate_path(const char* path) {
    if (!path) return 0;
    
    
    if (strstr(path, "..") != NULL) {
        return 0;
    }
    
    return 1;
}


int is_safe_path(const char* path) {
    if (!path) return 0;
    
    
    
    
    
    if (path[0] == '/') {
        return 0;
    }
    
    return 1;
}


int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <command> [args...]\n", argv[0]);
        printf("Commands:\n");
        printf("  copy <source> <destination>\n");
        printf("  move <source> <destination>\n");
        printf("  delete <path>\n");
        printf("  mkdir <path>\n");
        printf("  list <directory>\n");
        printf("  info <path>\n");
        printf("  chmod <path> <permissions>\n");
        printf("  search <directory> <pattern>\n");
        return 1;
    }
    
    if (!init_filesystem(".")) {
        printf("Failed to initialize filesystem\n");
        return 1;
    }
    
    const char* command = argv[1];
    
    if (strcmp(command, "copy") == 0 && argc == 4) {
        if (copy_file(argv[2], argv[3])) {
            printf("File copied successfully\n");
        } else {
            printf("Failed to copy file\n");
        }
    }
    else if (strcmp(command, "move") == 0 && argc == 4) {
        if (move_file(argv[2], argv[3])) {
            printf("File moved successfully\n");
        } else {
            printf("Failed to move file\n");
        }
    }
    else if (strcmp(command, "delete") == 0 && argc == 3) {
        if (delete_file(argv[2])) {
            printf("File deleted successfully\n");
        } else {
            printf("Failed to delete file\n");
        }
    }
    else if (strcmp(command, "mkdir") == 0 && argc == 3) {
        if (create_directory(argv[2])) {
            printf("Directory created successfully\n");
        } else {
            printf("Failed to create directory\n");
        }
    }
    else if (strcmp(command, "list") == 0 && argc == 3) {
        file_info_t files[MAX_FILES];
        int count = list_directory(argv[2], files, MAX_FILES);
        
        printf("Directory listing for: %s\n", argv[2]);
        printf("Total files: %d\n\n", count);
        
        for (int i = 0; i < count; i++) {
            print_file_info(&files[i]);
        }
    }
    else if (strcmp(command, "info") == 0 && argc == 3) {
        file_info_t info;
        if (get_file_info(argv[2], &info)) {
            printf("File information:\n");
            print_file_info(&info);
        } else {
            printf("Failed to get file information\n");
        }
    }
    else if (strcmp(command, "chmod") == 0 && argc == 4) {
        mode_t permissions = (mode_t)strtol(argv[3], NULL, 8);
        if (change_permissions(argv[2], permissions)) {
            printf("Permissions changed successfully\n");
        } else {
            printf("Failed to change permissions\n");
        }
    }
    else if (strcmp(command, "search") == 0 && argc == 4) {
        file_info_t results[MAX_FILES];
        int count = search_files(argv[2], argv[3], results, MAX_FILES);
        
        printf("Search results for pattern '%s' in '%s':\n", argv[3], argv[2]);
        printf("Found %d files:\n", count);
        
        for (int i = 0; i < count; i++) {
            print_file_info(&results[i]);
        }
    }
    else {
        printf("Invalid command or arguments\n");
    }
    
    return 0;
} 