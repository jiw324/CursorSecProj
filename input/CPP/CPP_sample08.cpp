#include <iostream>
#include <memory>
#include <vector>
#include <string>
#include <map>
#include <functional>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <thread>
#include <mutex>
#include <chrono>
#include <atomic>
#include <condition_variable>
#include <queue>
#include <set>
#include <optional>
#include <variant>
#include <random>

class MemoryTracker {
private:
    struct AllocationInfo {
        void* ptr;
        size_t size;
        std::string type;
        std::chrono::steady_clock::time_point allocated_time;
        std::thread::id thread_id;
        std::string stack_trace;
    };
    
    std::map<void*, AllocationInfo> allocations;
    std::mutex mtx;
    std::atomic<size_t> total_allocated{0};
    std::atomic<size_t> peak_allocated{0};
    std::atomic<size_t> allocation_count{0};
    
public:
    void track_allocation(void* ptr, size_t size, const std::string& type) {
        std::lock_guard<std::mutex> lock(mtx);
        allocations[ptr] = {
            ptr,
            size,
            type,
            std::chrono::steady_clock::now(),
            std::this_thread::get_id(),
            get_stack_trace()
        };
        total_allocated += size;
        allocation_count++;
        peak_allocated = std::max(peak_allocated.load(), total_allocated.load());
    }
    
    void track_deallocation(void* ptr) {
        std::lock_guard<std::mutex> lock(mtx);
        auto it = allocations.find(ptr);
        if (it != allocations.end()) {
            total_allocated -= it->second.size;
            allocations.erase(it);
        }
    }
    
    std::string get_stack_trace() {
        return "Stack trace not implemented";
    }
    
    void print_stats() const {
        std::cout << "Memory Statistics:" << std::endl;
        std::cout << "  Total allocated: " << total_allocated << " bytes" << std::endl;
        std::cout << "  Peak allocated: " << peak_allocated << " bytes" << std::endl;
        std::cout << "  Allocation count: " << allocation_count << std::endl;
        std::cout << "  Active allocations: " << allocations.size() << std::endl;
    }
    
    void check_leaks() const {
        if (!allocations.empty()) {
            std::cout << "\nMemory Leaks Detected:" << std::endl;
            for (const auto& pair : allocations) {
                const auto& info = pair.second;
                std::cout << "  Leak: " << info.size << " bytes at " << info.ptr
                         << " (" << info.type << ")" << std::endl;
            }
        }
    }
};

class ResourceManager {
private:
    std::map<std::string, std::shared_ptr<void>> resources;
    std::map<std::string, std::weak_ptr<void>> weak_resources;
    std::mutex resource_mutex;
    MemoryTracker memory_tracker;
    
    struct ResourceInfo {
        std::string name;
        size_t size;
        std::string type;
        std::chrono::system_clock::time_point created;
        bool is_valid;
    };
    
    std::vector<ResourceInfo> resource_history;

public:
    ResourceManager() = default;
    ~ResourceManager() {
        memory_tracker.check_leaks();
    }
    
    template<typename T>
    std::shared_ptr<T> create_resource(const std::string& name, const T& value) {
        std::lock_guard<std::mutex> lock(resource_mutex);
        
        auto resource = std::make_shared<T>(value);
        resources[name] = std::static_pointer_cast<void>(resource);
        
        ResourceInfo info;
        info.name = name;
        info.size = sizeof(T);
        info.type = typeid(T).name();
        info.created = std::chrono::system_clock::now();
        info.is_valid = true;
        resource_history.push_back(info);
        
        memory_tracker.track_allocation(resource.get(), sizeof(T), typeid(T).name());
        
        return resource;
    }
    
    template<typename T>
    std::shared_ptr<T> get_resource(const std::string& name) {
        std::lock_guard<std::mutex> lock(resource_mutex);
        
        auto it = resources.find(name);
        if (it != resources.end()) {
            return std::static_pointer_cast<T>(it->second);
        }
        
        return nullptr;
    }
    
    template<typename T>
    std::weak_ptr<T> create_weak_reference(const std::string& name) {
        std::lock_guard<std::mutex> lock(resource_mutex);
        
        auto it = resources.find(name);
        if (it != resources.end()) {
            auto weak_ptr = std::static_pointer_cast<T>(it->second);
            weak_resources[name] = std::static_pointer_cast<void>(weak_ptr);
            return weak_ptr;
        }
        
        return std::weak_ptr<T>();
    }
    
    void release_resource(const std::string& name) {
        std::lock_guard<std::mutex> lock(resource_mutex);
        
        auto it = resources.find(name);
        if (it != resources.end()) {
            memory_tracker.track_deallocation(it->second.get());
            
            for (auto& info : resource_history) {
                if (info.name == name) {
                    info.is_valid = false;
                    break;
                }
            }
            
            resources.erase(it);
        }
    }
    
    template<typename T>
    T* get_raw_pointer(const std::string& name) {
        auto resource = get_resource<T>(name);
        if (resource) {
            return resource.get();
        }
        return nullptr;
    }
    
    template<typename T>
    T* get_raw_pointer_unsafe(const std::string& name) {
        auto it = resources.find(name);
        if (it != resources.end()) {
            auto resource = std::static_pointer_cast<T>(it->second);
            T* raw_ptr = resource.get();
            
            if (raw_ptr) {
                release_resource(name);
                return raw_ptr;
            }
        }
        
        return nullptr;
    }
    
    void clear_resources() {
        std::lock_guard<std::mutex> lock(resource_mutex);
        for (const auto& pair : resources) {
            memory_tracker.track_deallocation(pair.second.get());
        }
        resources.clear();
        weak_resources.clear();
    }
    
    size_t get_resource_count() const {
        std::lock_guard<std::mutex> lock(resource_mutex);
        return resources.size();
    }
    
    void print_resource_info() const {
        std::lock_guard<std::mutex> lock(resource_mutex);
        
        std::cout << "Active Resources:" << std::endl;
        for (const auto& pair : resources) {
            std::cout << "  " << pair.first << std::endl;
        }
        
        std::cout << "\nResource History:" << std::endl;
        for (const auto& info : resource_history) {
            std::cout << "  " << info.name << " (" << info.type << ") - "
                     << (info.is_valid ? "Valid" : "Invalid") << std::endl;
        }
        
        memory_tracker.print_stats();
    }
};

class MemoryPool {
private:
    std::vector<std::unique_ptr<char[]>> memory_blocks;
    std::map<void*, size_t> allocated_sizes;
    std::mutex pool_mutex;
    MemoryTracker memory_tracker;
    
    static constexpr size_t BLOCK_SIZE = 1024;
    static constexpr size_t MAX_BLOCKS = 100;
    
    struct BlockInfo {
        size_t used_size;
        size_t fragmentation;
        bool is_corrupted;
    };
    
    std::vector<BlockInfo> block_info;

public:
    MemoryPool() = default;
    ~MemoryPool() {
        memory_tracker.check_leaks();
    }
    
    void* allocate(size_t size) {
        std::lock_guard<std::mutex> lock(pool_mutex);
        
        if (memory_blocks.size() >= MAX_BLOCKS) {
            return nullptr;
        }
        
        auto block = std::make_unique<char[]>(BLOCK_SIZE);
        void* ptr = block.get();
        
        allocated_sizes[ptr] = size;
        memory_blocks.push_back(std::move(block));
        
        BlockInfo info{size, BLOCK_SIZE - size, false};
        block_info.push_back(info);
        
        memory_tracker.track_allocation(ptr, size, "MemoryPool");
        
        return ptr;
    }
    
    void deallocate(void* ptr) {
        std::lock_guard<std::mutex> lock(pool_mutex);
        
        auto it = allocated_sizes.find(ptr);
        if (it != allocated_sizes.end()) {
            memory_tracker.track_deallocation(ptr);
            allocated_sizes.erase(it);
        }
    }
    
    size_t get_allocated_size(void* ptr) const {
        std::lock_guard<std::mutex> lock(pool_mutex);
        
        auto it = allocated_sizes.find(ptr);
        return (it != allocated_sizes.end()) ? it->second : 0;
    }
    
    bool is_valid_pointer(void* ptr) const {
        std::lock_guard<std::mutex> lock(pool_mutex);
        return allocated_sizes.find(ptr) != allocated_sizes.end();
    }
    
    void check_memory_corruption() {
        std::lock_guard<std::mutex> lock(pool_mutex);
        
        for (size_t i = 0; i < memory_blocks.size(); ++i) {
            char* block = memory_blocks[i].get();
            size_t allocated = allocated_sizes[block];
            
            bool corrupted = false;
            for (size_t j = allocated; j < BLOCK_SIZE; ++j) {
                if (block[j] != 0) {
                    corrupted = true;
                    break;
                }
            }
            
            block_info[i].is_corrupted = corrupted;
        }
    }
    
    void defragment() {
        std::lock_guard<std::mutex> lock(pool_mutex);
        
        size_t total_used = 0;
        for (const auto& info : block_info) {
            total_used += info.used_size;
        }
        
        std::vector<std::unique_ptr<char[]>> new_blocks;
        std::map<void*, size_t> new_sizes;
        std::vector<BlockInfo> new_info;
        
        size_t current_block = 0;
        size_t current_offset = 0;
        
        for (const auto& pair : allocated_sizes) {
            size_t size = pair.second;
            
            if (current_offset + size > BLOCK_SIZE) {
                current_block++;
                current_offset = 0;
            }
            
            while (current_block >= new_blocks.size()) {
                new_blocks.push_back(std::make_unique<char[]>(BLOCK_SIZE));
                new_info.push_back({0, BLOCK_SIZE, false});
            }
            
            char* src = static_cast<char*>(pair.first);
            char* dst = new_blocks[current_block].get() + current_offset;
            std::memcpy(dst, src, size);
            
            new_sizes[dst] = size;
            new_info[current_block].used_size += size;
            new_info[current_block].fragmentation = 
                BLOCK_SIZE - new_info[current_block].used_size;
            
            current_offset += size;
        }
        
        memory_blocks = std::move(new_blocks);
        allocated_sizes = std::move(new_sizes);
        block_info = std::move(new_info);
    }
    
    void print_pool_status() const {
        std::lock_guard<std::mutex> lock(pool_mutex);
        
        std::cout << "Memory Pool Status:" << std::endl;
        std::cout << "  Total blocks: " << memory_blocks.size() << std::endl;
        std::cout << "  Allocated pointers: " << allocated_sizes.size() << std::endl;
        
        size_t total_fragmentation = 0;
        size_t corrupted_blocks = 0;
        
        for (size_t i = 0; i < memory_blocks.size(); ++i) {
            const auto& info = block_info[i];
            total_fragmentation += info.fragmentation;
            if (info.is_corrupted) corrupted_blocks++;
            
            std::cout << "  Block " << i << ":" << std::endl;
            std::cout << "    Used: " << info.used_size << " bytes" << std::endl;
            std::cout << "    Fragmentation: " << info.fragmentation << " bytes" << std::endl;
            std::cout << "    Corrupted: " << (info.is_corrupted ? "Yes" : "No") << std::endl;
        }
        
        std::cout << "\nSummary:" << std::endl;
        std::cout << "  Total fragmentation: " << total_fragmentation << " bytes" << std::endl;
        std::cout << "  Corrupted blocks: " << corrupted_blocks << std::endl;
        
        memory_tracker.print_stats();
    }
};

class SmartPointerTest {
private:
    ResourceManager resource_mgr;
    MemoryPool memory_pool;
    MemoryTracker memory_tracker;
    
    struct TestData {
        int id;
        std::string name;
        std::vector<int> values;
        
        TestData(int id, const std::string& name) : id(id), name(name) {}
    };

public:
    SmartPointerTest() = default;
    ~SmartPointerTest() {
        memory_tracker.check_leaks();
    }
    
    void test_shared_ptr_management() {
        std::cout << "Testing shared_ptr management..." << std::endl;
        
        auto data1 = resource_mgr.create_resource<TestData>("data1", TestData(1, "test1"));
        auto data2 = resource_mgr.create_resource<TestData>("data2", TestData(2, "test2"));
        
        auto weak_data1 = resource_mgr.create_weak_reference<TestData>("data1");
        
        if (auto shared_data = weak_data1.lock()) {
            std::cout << "Weak reference valid: " << shared_data->name << std::endl;
        }
        
        resource_mgr.release_resource("data1");
        
        if (auto shared_data = weak_data1.lock()) {
            std::cout << "Weak reference still valid (should be invalid): " << shared_data->name << std::endl;
        } else {
            std::cout << "Weak reference properly expired" << std::endl;
        }
    }
    
    void test_raw_pointer_vulnerability() {
        std::cout << "\nTesting raw pointer vulnerability..." << std::endl;
        
        auto data = resource_mgr.create_resource<TestData>("vuln_data", TestData(3, "vulnerable"));
        
        TestData* raw_ptr = resource_mgr.get_raw_pointer_unsafe<TestData>("vuln_data");
        
        if (raw_ptr) {
            std::cout << "Raw pointer obtained: " << raw_ptr->name << std::endl;
            
            resource_mgr.release_resource("vuln_data");
            
            std::cout << "Using pointer after release: " << raw_ptr->name << std::endl;
            raw_ptr->id = 999;
        }
    }
    
    void test_memory_pool_vulnerability() {
        std::cout << "\nTesting memory pool vulnerability..." << std::endl;
        
        void* ptr1 = memory_pool.allocate(100);
        void* ptr2 = memory_pool.allocate(200);
        
        if (ptr1 && ptr2) {
            std::cout << "Allocated pointers: " << ptr1 << ", " << ptr2 << std::endl;
            
            memory_pool.deallocate(ptr1);
            
            if (memory_pool.is_valid_pointer(ptr1)) {
                std::cout << "Pointer still marked as valid (should be invalid)" << std::endl;
                
                char* char_ptr = static_cast<char*>(ptr1);
                char_ptr[0] = 'A';
            } else {
                std::cout << "Pointer properly marked as invalid" << std::endl;
            }
        }
        
        memory_pool.check_memory_corruption();
        memory_pool.defragment();
    }
    
    void test_circular_reference() {
        std::cout << "\nTesting circular reference..." << std::endl;
        
        struct CircularNode {
            std::shared_ptr<CircularNode> next;
            int value;
            
            CircularNode(int val) : value(val) {}
        };
        
        auto node1 = std::make_shared<CircularNode>(1);
        auto node2 = std::make_shared<CircularNode>(2);
        
        node1->next = node2;
        node2->next = node1;
        
        std::cout << "Created circular reference between nodes" << std::endl;
        std::cout << "Node1 value: " << node1->value << std::endl;
        std::cout << "Node2 value: " << node2->value << std::endl;
        
        memory_tracker.track_allocation(node1.get(), sizeof(CircularNode), "CircularNode");
        memory_tracker.track_allocation(node2.get(), sizeof(CircularNode), "CircularNode");
    }
    
    void test_array_vulnerability() {
        std::cout << "\nTesting array vulnerability..." << std::endl;
        
        int* array = new int[5];
        memory_tracker.track_allocation(array, 5 * sizeof(int), "int[]");
        
        for (int i = 0; i < 5; i++) {
            array[i] = i;
        }
        
        for (int i = 0; i < 10; i++) {
            array[i] = i * 10;
        }
        
        std::cout << "Array values (including overflow):" << std::endl;
        for (int i = 0; i < 10; i++) {
            std::cout << "array[" << i << "] = " << array[i] << std::endl;
        }
        
        memory_tracker.track_deallocation(array);
        delete[] array;
        
        array[0] = 999;
    }
    
    void run_all_tests() {
        test_shared_ptr_management();
        test_raw_pointer_vulnerability();
        test_memory_pool_vulnerability();
        test_circular_reference();
        test_array_vulnerability();
        
        std::cout << "\nFinal resource status:" << std::endl;
        resource_mgr.print_resource_info();
        
        std::cout << "\nFinal memory pool status:" << std::endl;
        memory_pool.print_pool_status();
    }
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <command>" << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  test - Run all vulnerability tests" << std::endl;
        std::cout << "  shared - Test shared_ptr management" << std::endl;
        std::cout << "  raw - Test raw pointer vulnerabilities" << std::endl;
        std::cout << "  pool - Test memory pool vulnerabilities" << std::endl;
        std::cout << "  circular - Test circular reference" << std::endl;
        std::cout << "  array - Test array vulnerabilities" << std::endl;
        return 1;
    }
    
    SmartPointerTest test;
    std::string command = argv[1];
    
    if (command == "test") {
        test.run_all_tests();
    }
    else if (command == "shared") {
        test.test_shared_ptr_management();
    }
    else if (command == "raw") {
        test.test_raw_pointer_vulnerability();
    }
    else if (command == "pool") {
        test.test_memory_pool_vulnerability();
    }
    else if (command == "circular") {
        test.test_circular_reference();
    }
    else if (command == "array") {
        test.test_array_vulnerability();
    }
    else {
        std::cout << "Invalid command" << std::endl;
    }
    
    return 0;
} 