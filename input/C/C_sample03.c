#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_STACK_SIZE 1000
#define MAX_QUEUE_SIZE 1000
#define HASH_TABLE_SIZE 101


typedef struct {
    int* data;
    int top;
    int capacity;
} Stack;


typedef struct {
    int* data;
    int front;
    int rear;
    int size;
    int capacity;
} Queue;


typedef struct TreeNode {
    int data;
    struct TreeNode* left;
    struct TreeNode* right;
} TreeNode;


typedef struct {
    TreeNode* root;
    int size;
} BinaryTree;


typedef struct HashEntry {
    char* key;
    int value;
    struct HashEntry* next;
} HashEntry;


typedef struct {
    HashEntry** buckets;
    int size;
    int capacity;
} HashTable;



Stack* create_stack(int capacity) {
    Stack* stack = malloc(sizeof(Stack));
    if (!stack) return NULL;
    
    stack->data = malloc(capacity * sizeof(int));
    if (!stack->data) {
        free(stack);
        return NULL;
    }
    
    stack->top = -1;
    stack->capacity = capacity;
    printf("Stack created with capacity %d\n", capacity);
    return stack;
}

int is_stack_empty(Stack* stack) {
    return stack->top == -1;
}

int is_stack_full(Stack* stack) {
    return stack->top == stack->capacity - 1;
}

int push(Stack* stack, int value) {
    if (is_stack_full(stack)) {
        printf("Stack overflow!\n");
        return -1;
    }
    
    stack->data[++stack->top] = value;
    printf("Pushed %d to stack\n", value);
    return 0;
}

int pop(Stack* stack) {
    if (is_stack_empty(stack)) {
        printf("Stack underflow!\n");
        return -1;
    }
    
    int value = stack->data[stack->top--];
    printf("Popped %d from stack\n", value);
    return value;
}

int peek_stack(Stack* stack) {
    if (is_stack_empty(stack)) {
        printf("Stack is empty!\n");
        return -1;
    }
    return stack->data[stack->top];
}

void print_stack(Stack* stack) {
    if (is_stack_empty(stack)) {
        printf("Stack is empty\n");
        return;
    }
    
    printf("Stack (top to bottom): ");
    for (int i = stack->top; i >= 0; i--) {
        printf("%d ", stack->data[i]);
    }
    printf("\n");
}

void free_stack(Stack* stack) {
    if (stack) {
        free(stack->data);
        free(stack);
        printf("Stack freed\n");
    }
}



Queue* create_queue(int capacity) {
    Queue* queue = malloc(sizeof(Queue));
    if (!queue) return NULL;
    
    queue->data = malloc(capacity * sizeof(int));
    if (!queue->data) {
        free(queue);
        return NULL;
    }
    
    queue->front = 0;
    queue->rear = -1;
    queue->size = 0;
    queue->capacity = capacity;
    printf("Queue created with capacity %d\n", capacity);
    return queue;
}

int is_queue_empty(Queue* queue) {
    return queue->size == 0;
}

int is_queue_full(Queue* queue) {
    return queue->size == queue->capacity;
}

int enqueue(Queue* queue, int value) {
    if (is_queue_full(queue)) {
        printf("Queue overflow!\n");
        return -1;
    }
    
    queue->rear = (queue->rear + 1) % queue->capacity;
    queue->data[queue->rear] = value;
    queue->size++;
    printf("Enqueued %d to queue\n", value);
    return 0;
}

int dequeue(Queue* queue) {
    if (is_queue_empty(queue)) {
        printf("Queue underflow!\n");
        return -1;
    }
    
    int value = queue->data[queue->front];
    queue->front = (queue->front + 1) % queue->capacity;
    queue->size--;
    printf("Dequeued %d from queue\n", value);
    return value;
}

int front_queue(Queue* queue) {
    if (is_queue_empty(queue)) {
        printf("Queue is empty!\n");
        return -1;
    }
    return queue->data[queue->front];
}

void print_queue(Queue* queue) {
    if (is_queue_empty(queue)) {
        printf("Queue is empty\n");
        return;
    }
    
    printf("Queue (front to rear): ");
    for (int i = 0; i < queue->size; i++) {
        int index = (queue->front + i) % queue->capacity;
        printf("%d ", queue->data[index]);
    }
    printf("\n");
}

void free_queue(Queue* queue) {
    if (queue) {
        free(queue->data);
        free(queue);
        printf("Queue freed\n");
    }
}



TreeNode* create_tree_node(int data) {
    TreeNode* node = malloc(sizeof(TreeNode));
    if (!node) return NULL;
    
    node->data = data;
    node->left = NULL;
    node->right = NULL;
    return node;
}

BinaryTree* create_binary_tree(void) {
    BinaryTree* tree = malloc(sizeof(BinaryTree));
    if (!tree) return NULL;
    
    tree->root = NULL;
    tree->size = 0;
    printf("Binary tree created\n");
    return tree;
}

TreeNode* insert_tree_node(TreeNode* root, int data) {
    if (!root) {
        return create_tree_node(data);
    }
    
    if (data < root->data) {
        root->left = insert_tree_node(root->left, data);
    } else if (data > root->data) {
        root->right = insert_tree_node(root->right, data);
    }
    
    return root;
}

int insert_tree(BinaryTree* tree, int data) {
    tree->root = insert_tree_node(tree->root, data);
    tree->size++;
    printf("Inserted %d into tree\n", data);
    return 0;
}

TreeNode* find_min_node(TreeNode* root) {
    while (root && root->left) {
        root = root->left;
    }
    return root;
}

TreeNode* delete_tree_node(TreeNode* root, int data) {
    if (!root) return NULL;
    
    if (data < root->data) {
        root->left = delete_tree_node(root->left, data);
    } else if (data > root->data) {
        root->right = delete_tree_node(root->right, data);
    } else {
        if (!root->left) {
            TreeNode* temp = root->right;
            free(root);
            return temp;
        } else if (!root->right) {
            TreeNode* temp = root->left;
            free(root);
            return temp;
        }
        
        TreeNode* temp = find_min_node(root->right);
        root->data = temp->data;
        root->right = delete_tree_node(root->right, temp->data);
    }
    
    return root;
}

int delete_tree(BinaryTree* tree, int data) {
    tree->root = delete_tree_node(tree->root, data);
    tree->size--;
    printf("Deleted %d from tree\n", data);
    return 0;
}

TreeNode* search_tree_node(TreeNode* root, int data) {
    if (!root || root->data == data) {
        return root;
    }
    
    if (data < root->data) {
        return search_tree_node(root->left, data);
    }
    
    return search_tree_node(root->right, data);
}

int search_tree(BinaryTree* tree, int data) {
    TreeNode* result = search_tree_node(tree->root, data);
    if (result) {
        printf("Found %d in tree\n", data);
        return 1;
    } else {
        printf("%d not found in tree\n", data);
        return 0;
    }
}

void inorder_traversal(TreeNode* root) {
    if (root) {
        inorder_traversal(root->left);
        printf("%d ", root->data);
        inorder_traversal(root->right);
    }
}

void preorder_traversal(TreeNode* root) {
    if (root) {
        printf("%d ", root->data);
        preorder_traversal(root->left);
        preorder_traversal(root->right);
    }
}

void postorder_traversal(TreeNode* root) {
    if (root) {
        postorder_traversal(root->left);
        postorder_traversal(root->right);
        printf("%d ", root->data);
    }
}

void print_tree_traversals(BinaryTree* tree) {
    printf("Inorder: ");
    inorder_traversal(tree->root);
    printf("\n");
    
    printf("Preorder: ");
    preorder_traversal(tree->root);
    printf("\n");
    
    printf("Postorder: ");
    postorder_traversal(tree->root);
    printf("\n");
}

void free_tree_nodes(TreeNode* root) {
    if (root) {
        free_tree_nodes(root->left);
        free_tree_nodes(root->right);
        free(root);
    }
}

void free_binary_tree(BinaryTree* tree) {
    if (tree) {
        free_tree_nodes(tree->root);
        free(tree);
        printf("Binary tree freed\n");
    }
}



unsigned int hash_function(const char* key) {
    unsigned int hash = 5381;
    int c;
    while ((c = *key++)) {
        hash = ((hash << 5) + hash) + c;
    }
    return hash % HASH_TABLE_SIZE;
}

HashTable* create_hash_table(void) {
    HashTable* table = malloc(sizeof(HashTable));
    if (!table) return NULL;
    
    table->buckets = calloc(HASH_TABLE_SIZE, sizeof(HashEntry*));
    if (!table->buckets) {
        free(table);
        return NULL;
    }
    
    table->size = 0;
    table->capacity = HASH_TABLE_SIZE;
    printf("Hash table created with %d buckets\n", HASH_TABLE_SIZE);
    return table;
}

int hash_insert(HashTable* table, const char* key, int value) {
    unsigned int index = hash_function(key);
    
    HashEntry* entry = table->buckets[index];
    while (entry) {
        if (strcmp(entry->key, key) == 0) {
            entry->value = value;
            printf("Updated key '%s' with value %d\n", key, value);
            return 0;
        }
        entry = entry->next;
    }
    
    HashEntry* new_entry = malloc(sizeof(HashEntry));
    if (!new_entry) return -1;
    
    new_entry->key = strdup(key);
    new_entry->value = value;
    new_entry->next = table->buckets[index];
    table->buckets[index] = new_entry;
    table->size++;
    
    printf("Inserted key '%s' with value %d\n", key, value);
    return 0;
}

int hash_get(HashTable* table, const char* key) {
    unsigned int index = hash_function(key);
    
    HashEntry* entry = table->buckets[index];
    while (entry) {
        if (strcmp(entry->key, key) == 0) {
            printf("Found key '%s' with value %d\n", key, entry->value);
            return entry->value;
        }
        entry = entry->next;
    }
    
    printf("Key '%s' not found\n", key);
    return -1;
}

int hash_delete(HashTable* table, const char* key) {
    unsigned int index = hash_function(key);
    
    HashEntry* entry = table->buckets[index];
    HashEntry* prev = NULL;
    
    while (entry) {
        if (strcmp(entry->key, key) == 0) {
            if (prev) {
                prev->next = entry->next;
            } else {
                table->buckets[index] = entry->next;
            }
            
            free(entry->key);
            free(entry);
            table->size--;
            printf("Deleted key '%s'\n", key);
            return 0;
        }
        prev = entry;
        entry = entry->next;
    }
    
    printf("Key '%s' not found for deletion\n", key);
    return -1;
}

void print_hash_table(HashTable* table) {
    printf("Hash Table Contents (%d items):\n", table->size);
    for (int i = 0; i < table->capacity; i++) {
        if (table->buckets[i]) {
            printf("Bucket %d: ", i);
            HashEntry* entry = table->buckets[i];
            while (entry) {
                printf("['%s': %d] ", entry->key, entry->value);
                entry = entry->next;
            }
            printf("\n");
        }
    }
}

void free_hash_table(HashTable* table) {
    if (table) {
        for (int i = 0; i < table->capacity; i++) {
            HashEntry* entry = table->buckets[i];
            while (entry) {
                HashEntry* temp = entry;
                entry = entry->next;
                free(temp->key);
                free(temp);
            }
        }
        free(table->buckets);
        free(table);
        printf("Hash table freed\n");
    }
}



void demo_stack(void) {
    printf("\n=== STACK DEMO ===\n");
    Stack* stack = create_stack(10);
    
    push(stack, 10);
    push(stack, 20);
    push(stack, 30);
    print_stack(stack);
    
    printf("Top element: %d\n", peek_stack(stack));
    pop(stack);
    print_stack(stack);
    
    free_stack(stack);
}

void demo_queue(void) {
    printf("\n=== QUEUE DEMO ===\n");
    Queue* queue = create_queue(10);
    
    enqueue(queue, 100);
    enqueue(queue, 200);
    enqueue(queue, 300);
    print_queue(queue);
    
    printf("Front element: %d\n", front_queue(queue));
    dequeue(queue);
    print_queue(queue);
    
    free_queue(queue);
}

void demo_binary_tree(void) {
    printf("\n=== BINARY TREE DEMO ===\n");
    BinaryTree* tree = create_binary_tree();
    
    insert_tree(tree, 50);
    insert_tree(tree, 30);
    insert_tree(tree, 70);
    insert_tree(tree, 20);
    insert_tree(tree, 40);
    insert_tree(tree, 60);
    insert_tree(tree, 80);
    
    print_tree_traversals(tree);
    
    search_tree(tree, 40);
    search_tree(tree, 90);
    
    delete_tree(tree, 30);
    printf("After deleting 30:\n");
    print_tree_traversals(tree);
    
    free_binary_tree(tree);
}

void demo_hash_table(void) {
    printf("\n=== HASH TABLE DEMO ===\n");
    HashTable* table = create_hash_table();
    
    hash_insert(table, "apple", 5);
    hash_insert(table, "banana", 3);
    hash_insert(table, "orange", 8);
    hash_insert(table, "grape", 12);
    
    print_hash_table(table);
    
    hash_get(table, "banana");
    hash_get(table, "mango");
    
    hash_delete(table, "orange");
    print_hash_table(table);
    
    free_hash_table(table);
}

int main(void) {
    printf("Data Structures Library Demo\n");
    printf("============================\n");
    
    demo_stack();
    demo_queue();
    demo_binary_tree();
    demo_hash_table();
    
    printf("\nAll demos completed successfully!\n");
    return EXIT_SUCCESS;
} 