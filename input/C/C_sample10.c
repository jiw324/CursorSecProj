#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAX_LINE_LENGTH 1024
#define MAX_FILENAME 256
#define INITIAL_CAPACITY 100
#define GROWTH_FACTOR 2


typedef struct {
    char** lines;
    int line_count;
    int capacity;
    char* filename;
    int modified;
    int current_line;
} TextBuffer;


typedef struct {
    TextBuffer* buffer;
    int running;
    char clipboard[MAX_LINE_LENGTH];
    int clipboard_empty;
} Editor;


TextBuffer* create_buffer(void) {
    TextBuffer* buffer = (TextBuffer*)malloc(sizeof(TextBuffer));
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed for text buffer\n");
        return NULL;
    }
    
    buffer->lines = (char**)malloc(INITIAL_CAPACITY * sizeof(char*));
    if (!buffer->lines) {
        fprintf(stderr, "Memory allocation failed for lines array\n");
        free(buffer);
        return NULL;
    }
    
    buffer->line_count = 0;
    buffer->capacity = INITIAL_CAPACITY;
    buffer->filename = NULL;
    buffer->modified = 0;
    buffer->current_line = 0;
    
    return buffer;
}


int resize_buffer(TextBuffer* buffer) {
    int new_capacity = buffer->capacity * GROWTH_FACTOR;
    char** new_lines = (char**)realloc(buffer->lines, new_capacity * sizeof(char*));
    
    if (!new_lines) {
        fprintf(stderr, "Failed to resize buffer\n");
        return -1;
    }
    
    buffer->lines = new_lines;
    buffer->capacity = new_capacity;
    printf("Buffer resized to capacity: %d\n", new_capacity);
    return 0;
}


int add_line(TextBuffer* buffer, const char* line) {
    if (buffer->line_count >= buffer->capacity) {
        if (resize_buffer(buffer) != 0) {
            return -1;
        }
    }
    
    buffer->lines[buffer->line_count] = (char*)malloc((strlen(line) + 1) * sizeof(char));
    if (!buffer->lines[buffer->line_count]) {
        fprintf(stderr, "Memory allocation failed for line\n");
        return -1;
    }
    
    strcpy(buffer->lines[buffer->line_count], line);
    buffer->line_count++;
    buffer->modified = 1;
    return 0;
}


int insert_line(TextBuffer* buffer, int position, const char* line) {
    if (position < 0 || position > buffer->line_count) {
        fprintf(stderr, "Invalid line position: %d\n", position);
        return -1;
    }
    
    if (buffer->line_count >= buffer->capacity) {
        if (resize_buffer(buffer) != 0) {
            return -1;
        }
    }
    
    
    for (int i = buffer->line_count; i > position; i--) {
        buffer->lines[i] = buffer->lines[i - 1];
    }
    
    buffer->lines[position] = (char*)malloc((strlen(line) + 1) * sizeof(char));
    if (!buffer->lines[position]) {
        fprintf(stderr, "Memory allocation failed for inserted line\n");
        return -1;
    }
    
    strcpy(buffer->lines[position], line);
    buffer->line_count++;
    buffer->modified = 1;
    printf("Line inserted at position %d\n", position + 1);
    return 0;
}


int delete_line(TextBuffer* buffer, int position) {
    if (position < 0 || position >= buffer->line_count) {
        fprintf(stderr, "Invalid line position: %d\n", position);
        return -1;
    }
    
    free(buffer->lines[position]);
    
    
    for (int i = position; i < buffer->line_count - 1; i++) {
        buffer->lines[i] = buffer->lines[i + 1];
    }
    
    buffer->line_count--;
    buffer->modified = 1;
    printf("Line %d deleted\n", position + 1);
    return 0;
}


int replace_line(TextBuffer* buffer, int position, const char* new_line) {
    if (position < 0 || position >= buffer->line_count) {
        fprintf(stderr, "Invalid line position: %d\n", position);
        return -1;
    }
    
    free(buffer->lines[position]);
    buffer->lines[position] = (char*)malloc((strlen(new_line) + 1) * sizeof(char));
    if (!buffer->lines[position]) {
        fprintf(stderr, "Memory allocation failed for line replacement\n");
        return -1;
    }
    
    strcpy(buffer->lines[position], new_line);
    buffer->modified = 1;
    printf("Line %d replaced\n", position + 1);
    return 0;
}


int load_file(TextBuffer* buffer, const char* filename) {
    FILE* file = fopen(filename, "r");
    if (!file) {
        perror("Failed to open file");
        return -1;
    }
    
    
    for (int i = 0; i < buffer->line_count; i++) {
        free(buffer->lines[i]);
    }
    buffer->line_count = 0;
    
    char line[MAX_LINE_LENGTH];
    while (fgets(line, sizeof(line), file)) {
        
        line[strcspn(line, "\n")] = 0;
        if (add_line(buffer, line) != 0) {
            fclose(file);
            return -1;
        }
    }
    
    fclose(file);
    
    
    if (buffer->filename) {
        free(buffer->filename);
    }
    buffer->filename = (char*)malloc((strlen(filename) + 1) * sizeof(char));
    strcpy(buffer->filename, filename);
    buffer->modified = 0;
    
    printf("Loaded %d lines from '%s'\n", buffer->line_count, filename);
    return 0;
}


int save_file(TextBuffer* buffer, const char* filename) {
    FILE* file = fopen(filename, "w");
    if (!file) {
        perror("Failed to open file for writing");
        return -1;
    }
    
    for (int i = 0; i < buffer->line_count; i++) {
        fprintf(file, "%s\n", buffer->lines[i]);
    }
    
    fclose(file);
    
    
    if (filename && (!buffer->filename || strcmp(buffer->filename, filename) != 0)) {
        if (buffer->filename) {
            free(buffer->filename);
        }
        buffer->filename = (char*)malloc((strlen(filename) + 1) * sizeof(char));
        strcpy(buffer->filename, filename);
    }
    
    buffer->modified = 0;
    printf("File saved as '%s' (%d lines)\n", filename, buffer->line_count);
    return 0;
}


void display_buffer(TextBuffer* buffer, int start_line, int end_line) {
    if (buffer->line_count == 0) {
        printf("Buffer is empty\n");
        return;
    }
    
    if (start_line < 0) start_line = 0;
    if (end_line < 0 || end_line >= buffer->line_count) {
        end_line = buffer->line_count - 1;
    }
    
    printf("\n--- Text Buffer ---\n");
    for (int i = start_line; i <= end_line; i++) {
        printf("%4d: %s\n", i + 1, buffer->lines[i]);
    }
    printf("--- End of Buffer ---\n\n");
}


int search_text(TextBuffer* buffer, const char* search_term, int case_sensitive) {
    int found_count = 0;
    printf("Search results for '%s':\n", search_term);
    
    for (int i = 0; i < buffer->line_count; i++) {
        char* line = buffer->lines[i];
        char* found = NULL;
        
        if (case_sensitive) {
            found = strstr(line, search_term);
        } else {
            
            char* line_lower = (char*)malloc((strlen(line) + 1) * sizeof(char));
            char* term_lower = (char*)malloc((strlen(search_term) + 1) * sizeof(char));
            
            strcpy(line_lower, line);
            strcpy(term_lower, search_term);
            
            for (int j = 0; line_lower[j]; j++) {
                line_lower[j] = tolower(line_lower[j]);
            }
            for (int j = 0; term_lower[j]; j++) {
                term_lower[j] = tolower(term_lower[j]);
            }
            
            found = strstr(line_lower, term_lower);
            free(line_lower);
            free(term_lower);
        }
        
        if (found) {
            printf("Line %d: %s\n", i + 1, line);
            found_count++;
        }
    }
    
    printf("Found %d occurrences\n", found_count);
    return found_count;
}


int replace_text(TextBuffer* buffer, const char* search_term, const char* replace_term, int replace_all) {
    int replacement_count = 0;
    
    for (int i = 0; i < buffer->line_count; i++) {
        char* line = buffer->lines[i];
        char* found = strstr(line, search_term);
        
        while (found) {
            
            int search_len = strlen(search_term);
            int replace_len = strlen(replace_term);
            int old_len = strlen(line);
            int new_len = old_len - search_len + replace_len;
            
            char* new_line = (char*)malloc((new_len + 1) * sizeof(char));
            if (!new_line) {
                fprintf(stderr, "Memory allocation failed for replacement\n");
                return replacement_count;
            }
            
            
            int prefix_len = found - line;
            strncpy(new_line, line, prefix_len);
            new_line[prefix_len] = '\0';
            strcat(new_line, replace_term);
            strcat(new_line, found + search_len);
            
            free(buffer->lines[i]);
            buffer->lines[i] = new_line;
            line = new_line;
            
            replacement_count++;
            buffer->modified = 1;
            
            if (!replace_all) {
                break;
            }
            
            found = strstr(line + prefix_len + replace_len, search_term);
        }
    }
    
    printf("Replaced %d occurrences\n", replacement_count);
    return replacement_count;
}


void copy_line(Editor* editor, int line_number) {
    if (line_number < 0 || line_number >= editor->buffer->line_count) {
        fprintf(stderr, "Invalid line number: %d\n", line_number);
        return;
    }
    
    strncpy(editor->clipboard, editor->buffer->lines[line_number], MAX_LINE_LENGTH - 1);
    editor->clipboard[MAX_LINE_LENGTH - 1] = '\0';
    editor->clipboard_empty = 0;
    printf("Line %d copied to clipboard\n", line_number + 1);
}


void paste_line(Editor* editor, int position) {
    if (editor->clipboard_empty) {
        printf("Clipboard is empty\n");
        return;
    }
    
    if (position < 0) position = 0;
    if (position > editor->buffer->line_count) position = editor->buffer->line_count;
    
    insert_line(editor->buffer, position, editor->clipboard);
    printf("Pasted at line %d\n", position + 1);
}


void print_buffer_stats(TextBuffer* buffer) {
    int total_chars = 0;
    int total_words = 0;
    
    for (int i = 0; i < buffer->line_count; i++) {
        char* line = buffer->lines[i];
        total_chars += strlen(line);
        
        
        int in_word = 0;
        for (int j = 0; line[j]; j++) {
            if (isspace(line[j])) {
                in_word = 0;
            } else if (!in_word) {
                in_word = 1;
                total_words++;
            }
        }
    }
    
    printf("Buffer Statistics:\n");
    printf("==================\n");
    printf("Filename: %s\n", buffer->filename ? buffer->filename : "Untitled");
    printf("Lines: %d\n", buffer->line_count);
    printf("Characters: %d\n", total_chars);
    printf("Words: %d\n", total_words);
    printf("Modified: %s\n", buffer->modified ? "Yes" : "No");
    printf("Current line: %d\n", buffer->current_line + 1);
}


void free_buffer(TextBuffer* buffer) {
    if (buffer) {
        for (int i = 0; i < buffer->line_count; i++) {
            free(buffer->lines[i]);
        }
        free(buffer->lines);
        if (buffer->filename) {
            free(buffer->filename);
        }
        free(buffer);
    }
}


void print_menu(void) {
    printf("\n=== Text Editor Menu ===\n");
    printf("1.  New file\n");
    printf("2.  Open file\n");
    printf("3.  Save file\n");
    printf("4.  Save as\n");
    printf("5.  Insert line\n");
    printf("6.  Delete line\n");
    printf("7.  Replace line\n");
    printf("8.  Display buffer\n");
    printf("9.  Search text\n");
    printf("10. Replace text\n");
    printf("11. Copy line\n");
    printf("12. Paste line\n");
    printf("13. Buffer statistics\n");
    printf("14. Exit\n");
    printf("Choice: ");
}

int main(void) {
    printf("Advanced Text Editor v2.0\n");
    printf("=========================\n");
    
    Editor editor = {0};
    editor.buffer = create_buffer();
    editor.running = 1;
    editor.clipboard_empty = 1;
    
    if (!editor.buffer) {
        return EXIT_FAILURE;
    }
    
    int choice;
    char filename[MAX_FILENAME];
    char line_text[MAX_LINE_LENGTH];
    char search_term[MAX_LINE_LENGTH];
    char replace_term[MAX_LINE_LENGTH];
    int line_number;
    
    while (editor.running) {
        print_menu();
        
        if (scanf("%d", &choice) != 1) {
            printf("Invalid input\n");
            while (getchar() != '\n');
            continue;
        }
        
        switch (choice) {
            case 1: 
                for (int i = 0; i < editor.buffer->line_count; i++) {
                    free(editor.buffer->lines[i]);
                }
                editor.buffer->line_count = 0;
                editor.buffer->modified = 0;
                printf("New file created\n");
                break;
                
            case 2: 
                printf("Enter filename: ");
                scanf("%s", filename);
                load_file(editor.buffer, filename);
                break;
                
            case 3: 
                if (editor.buffer->filename) {
                    save_file(editor.buffer, editor.buffer->filename);
                } else {
                    printf("Enter filename: ");
                    scanf("%s", filename);
                    save_file(editor.buffer, filename);
                }
                break;
                
            case 4: 
                printf("Enter filename: ");
                scanf("%s", filename);
                save_file(editor.buffer, filename);
                break;
                
            case 5: 
                printf("Enter line number (0 for end): ");
                scanf("%d", &line_number);
                printf("Enter text: ");
                getchar(); 
                fgets(line_text, sizeof(line_text), stdin);
                line_text[strcspn(line_text, "\n")] = 0; 
                
                if (line_number == 0) {
                    add_line(editor.buffer, line_text);
                } else {
                    insert_line(editor.buffer, line_number - 1, line_text);
                }
                break;
                
            case 6: 
                printf("Enter line number: ");
                scanf("%d", &line_number);
                delete_line(editor.buffer, line_number - 1);
                break;
                
            case 7: 
                printf("Enter line number: ");
                scanf("%d", &line_number);
                printf("Enter new text: ");
                getchar(); 
                fgets(line_text, sizeof(line_text), stdin);
                line_text[strcspn(line_text, "\n")] = 0;
                replace_line(editor.buffer, line_number - 1, line_text);
                break;
                
            case 8: 
                display_buffer(editor.buffer, 0, -1);
                break;
                
            case 9: 
                printf("Enter search term: ");
                scanf("%s", search_term);
                search_text(editor.buffer, search_term, 1);
                break;
                
            case 10: 
                printf("Enter search term: ");
                scanf("%s", search_term);
                printf("Enter replacement: ");
                scanf("%s", replace_term);
                printf("Replace all? (1=yes, 0=no): ");
                int replace_all;
                scanf("%d", &replace_all);
                replace_text(editor.buffer, search_term, replace_term, replace_all);
                break;
                
            case 11: 
                printf("Enter line number: ");
                scanf("%d", &line_number);
                copy_line(&editor, line_number - 1);
                break;
                
            case 12: 
                printf("Enter position: ");
                scanf("%d", &line_number);
                paste_line(&editor, line_number - 1);
                break;
                
            case 13: 
                print_buffer_stats(editor.buffer);
                break;
                
            case 14: 
                if (editor.buffer->modified) {
                    printf("File has unsaved changes. Save before exit? (y/n): ");
                    char save_choice;
                    scanf(" %c", &save_choice);
                    if (save_choice == 'y' || save_choice == 'Y') {
                        if (editor.buffer->filename) {
                            save_file(editor.buffer, editor.buffer->filename);
                        } else {
                            printf("Enter filename: ");
                            scanf("%s", filename);
                            save_file(editor.buffer, filename);
                        }
                    }
                }
                editor.running = 0;
                break;
                
            default:
                printf("Invalid choice\n");
        }
    }
    
    free_buffer(editor.buffer);
    printf("Editor closed successfully\n");
    return EXIT_SUCCESS;
} 