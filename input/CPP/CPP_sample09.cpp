#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <typeinfo>
#include <memory>
#include <functional>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <type_traits>
#include <chrono>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <atomic>
#include <set>
#include <optional>
#include <variant>
#include <random>
#include <bitset>

template<typename T>
class TypeWrapper {
private:
    T value;
    std::string type_name;
    std::atomic<bool> is_locked{false};
    mutable std::mutex mtx;
    std::chrono::steady_clock::time_point creation_time;
    std::thread::id owner_thread;
    bool allow_unsafe_cast;

public:
    TypeWrapper(const T& val) 
        : value(val), allow_unsafe_cast(false) {
        type_name = typeid(T).name();
        creation_time = std::chrono::steady_clock::now();
        owner_thread = std::this_thread::get_id();
    }
    
    T get_value() const { 
        std::lock_guard<std::mutex> lock(mtx);
        return value; 
    }
    
    void set_value(const T& val) { 
        std::lock_guard<std::mutex> lock(mtx);
        value = val; 
    }
    
    std::string get_type_name() const { 
        return type_name; 
    }
    
    void set_allow_unsafe_cast(bool allow) {
        allow_unsafe_cast = allow;
    }
    
    bool try_lock() {
        return !is_locked.exchange(true);
    }
    
    void unlock() {
        is_locked = false;
    }
    
    template<typename U>
    U unsafe_cast() const {
        if (!allow_unsafe_cast) {
            throw std::runtime_error("Unsafe cast not allowed");
        }
        return reinterpret_cast<U>(value);
    }
    
    template<typename U>
    std::optional<U> safe_cast() const {
        if constexpr (std::is_convertible_v<T, U>) {
            return static_cast<U>(value);
        }
        return std::nullopt;
    }
    
    bool is_owned_by_current_thread() const {
        return owner_thread == std::this_thread::get_id();
    }
    
    std::chrono::steady_clock::duration get_age() const {
        return std::chrono::steady_clock::now() - creation_time;
    }
};

class TypeConfusionTest {
private:
    std::map<std::string, void*> type_registry;
    std::vector<std::pair<std::string, std::string>> type_history;
    std::mutex registry_mutex;
    std::condition_variable registry_cv;
    std::atomic<size_t> confusion_count{0};
    std::set<std::string> protected_types;
    std::map<std::string, std::function<void(void*)>> type_validators;
    
    template<typename T>
    struct TypeInfo {
        std::string name;
        size_t size;
        bool is_pointer;
        bool is_const;
        bool is_volatile;
        bool is_reference;
        bool is_array;
        bool is_class;
        bool is_union;
        bool is_enum;
        std::vector<std::string> base_classes;
        
        TypeInfo() {
            name = typeid(T).name();
            size = sizeof(T);
            is_pointer = std::is_pointer<T>::value;
            is_const = std::is_const<T>::value;
            is_volatile = std::is_volatile<T>::value;
            is_reference = std::is_reference<T>::value;
            is_array = std::is_array<T>::value;
            is_class = std::is_class<T>::value;
            is_union = std::is_union<T>::value;
            is_enum = std::is_enum<T>::value;
        }
        
        void add_base_class(const std::string& base) {
            base_classes.push_back(base);
        }
        
        bool has_base_class(const std::string& base) const {
            return std::find(base_classes.begin(), base_classes.end(), base) != base_classes.end();
        }
    };
    
    struct TypeCastResult {
        bool success;
        std::string error_message;
        void* result_ptr;
        
        static TypeCastResult success_result(void* ptr) {
            return {true, "", ptr};
        }
        
        static TypeCastResult error_result(const std::string& error) {
            return {false, error, nullptr};
        }
    };

public:
    TypeConfusionTest() = default;
    ~TypeConfusionTest() = default;
    
    template<typename T>
    void register_type(const std::string& name) {
        std::lock_guard<std::mutex> lock(registry_mutex);
        
        TypeInfo<T> info;
        type_registry[name] = reinterpret_cast<void*>(&info);
        
        type_history.push_back({name, info.name});
        
        add_type_validator<T>(name);
    }
    
    template<typename T>
    void add_type_validator(const std::string& name) {
        type_validators[name] = [](void* ptr) {
            T* typed_ptr = static_cast<T*>(ptr);
            if (!typed_ptr) {
                throw std::runtime_error("Invalid type cast");
            }
        };
    }
    
    void protect_type(const std::string& name) {
        std::lock_guard<std::mutex> lock(registry_mutex);
        protected_types.insert(name);
    }
    
    bool is_type_protected(const std::string& name) const {
        std::lock_guard<std::mutex> lock(registry_mutex);
        return protected_types.find(name) != protected_types.end();
    }
    
    template<typename T>
    T* get_registered_type(const std::string& name) {
        std::lock_guard<std::mutex> lock(registry_mutex);
        
        auto it = type_registry.find(name);
        if (it != type_registry.end()) {
            if (is_type_protected(name)) {
                throw std::runtime_error("Access to protected type denied");
            }
            return reinterpret_cast<T*>(it->second);
        }
        return nullptr;
    }
    
    template<typename From, typename To>
    TypeCastResult try_cast(From* ptr) {
        if (!ptr) {
            return TypeCastResult::error_result("Null pointer");
        }
        
        if (std::is_same_v<From, To>) {
            return TypeCastResult::success_result(ptr);
        }
        
        if (std::is_base_of_v<From, To> || std::is_base_of_v<To, From>) {
            try {
                To* result = dynamic_cast<To*>(ptr);
                if (result) {
                    return TypeCastResult::success_result(result);
                }
            } catch (...) {
                confusion_count++;
            }
        }
        
        return TypeCastResult::error_result("Invalid cast");
    }
    
    template<typename From, typename To>
    To* unsafe_type_cast(From* ptr) {
        confusion_count++;
        return reinterpret_cast<To*>(ptr);
    }
    
    template<typename T>
    void* get_raw_pointer(T* ptr) {
        return reinterpret_cast<void*>(ptr);
    }
    
    template<typename T>
    T* restore_from_void(void* ptr) {
        return reinterpret_cast<T*>(ptr);
    }
    
    size_t get_confusion_count() const {
        return confusion_count;
    }
    
    void test_type_confusion() {
        std::cout << "Testing type confusion vulnerabilities..." << std::endl;
        
        int int_value = 42;
        double double_value = 3.14;
        std::string string_value = "test";
        
        void* int_ptr = get_raw_pointer(&int_value);
        void* double_ptr = get_raw_pointer(&double_value);
        void* string_ptr = get_raw_pointer(&string_value);
        
        double* confused_double = restore_from_void<double>(int_ptr);
        std::cout << "Int value as double: " << *confused_double << std::endl;
        
        int* confused_int = restore_from_void<int>(double_ptr);
        std::cout << "Double value as int: " << *confused_int << std::endl;
        
        int* confused_string = restore_from_void<int>(string_ptr);
        std::cout << "String value as int: " << *confused_string << std::endl;
    }
    
    void test_template_vulnerability() {
        std::cout << "\nTesting template vulnerabilities..." << std::endl;
        
        TypeWrapper<int> int_wrapper(100);
        TypeWrapper<double> double_wrapper(2.5);
        TypeWrapper<std::string> string_wrapper("hello");
        
        try {
            int_wrapper.set_allow_unsafe_cast(true);
            double int_as_double = int_wrapper.unsafe_cast<double>();
            std::cout << "Int as double: " << int_as_double << std::endl;
            
            double_wrapper.set_allow_unsafe_cast(true);
            int double_as_int = double_wrapper.unsafe_cast<int>();
            std::cout << "Double as int: " << double_as_int << std::endl;
            
            string_wrapper.set_allow_unsafe_cast(true);
            int string_as_int = string_wrapper.unsafe_cast<int>();
            std::cout << "String as int: " << string_as_int << std::endl;
        } catch (const std::exception& e) {
            std::cout << "Caught exception: " << e.what() << std::endl;
        }
    }
    
    void test_pointer_arithmetic() {
        std::cout << "\nTesting pointer arithmetic vulnerabilities..." << std::endl;
        
        int array[5] = {1, 2, 3, 4, 5};
        int* ptr = array;
        
        for (int i = 0; i < 10; i++) {
            std::cout << "array[" << i << "] = " << ptr[i] << std::endl;
        }
        
        char* char_ptr = reinterpret_cast<char*>(ptr);
        double* double_ptr = reinterpret_cast<double*>(ptr);
        
        std::cout << "Char pointer arithmetic:" << std::endl;
        for (int i = 0; i < 20; i++) {
            std::cout << "char_ptr[" << i << "] = " << static_cast<int>(char_ptr[i]) << std::endl;
        }
        
        std::cout << "Double pointer arithmetic:" << std::endl;
        for (int i = 0; i < 3; i++) {
            std::cout << "double_ptr[" << i << "] = " << double_ptr[i] << std::endl;
        }
    }
    
    void test_union_vulnerability() {
        std::cout << "\nTesting union vulnerabilities..." << std::endl;
        
        union VulnerableUnion {
            int int_value;
            double double_value;
            char char_array[8];
            void* ptr_value;
            std::bitset<64> bits;
        };
        
        VulnerableUnion u;
        u.int_value = 0x41424344;
        
        std::cout << "As int: " << u.int_value << std::endl;
        std::cout << "As double: " << u.double_value << std::endl;
        std::cout << "As char array: ";
        for (int i = 0; i < 8; i++) {
            std::cout << u.char_array[i];
        }
        std::cout << std::endl;
        std::cout << "As pointer: " << u.ptr_value << std::endl;
        std::cout << "As bits: " << u.bits << std::endl;
        
        u.double_value = 3.14159;
        std::cout << "After setting as double:" << std::endl;
        std::cout << "As int: " << u.int_value << std::endl;
        std::cout << "As double: " << u.double_value << std::endl;
        std::cout << "As pointer: " << u.ptr_value << std::endl;
        std::cout << "As bits: " << u.bits << std::endl;
    }
    
    void test_function_pointer_vulnerability() {
        std::cout << "\nTesting function pointer vulnerabilities..." << std::endl;
        
        typedef void (*VoidFunc)();
        typedef int (*IntFunc)(int);
        typedef double (*DoubleFunc)(double);
        
        auto void_func = []() { std::cout << "Void function called" << std::endl; };
        auto int_func = [](int x) { std::cout << "Int function called with " << x << std::endl; return x * 2; };
        auto double_func = [](double x) { std::cout << "Double function called with " << x << std::endl; return x * 2.0; };
        
        VoidFunc void_ptr = reinterpret_cast<VoidFunc>(void_func);
        IntFunc int_ptr = reinterpret_cast<IntFunc>(int_func);
        DoubleFunc double_ptr = reinterpret_cast<DoubleFunc>(double_func);
        
        void_ptr();
        
        VoidFunc confused_void = reinterpret_cast<VoidFunc>(int_ptr);
        confused_void();
        
        IntFunc confused_int = reinterpret_cast<IntFunc>(double_ptr);
        int result = confused_int(42);
        std::cout << "Result: " << result << std::endl;
    }
    
    void test_virtual_function_confusion() {
        std::cout << "\nTesting virtual function confusion..." << std::endl;
        
        class Base {
        public:
            virtual void foo() { std::cout << "Base::foo" << std::endl; }
            virtual ~Base() = default;
        };
        
        class Derived : public Base {
        public:
            void foo() override { std::cout << "Derived::foo" << std::endl; }
        };
        
        Base* base = new Base();
        Derived* derived = new Derived();
        
        void** base_vtable = *reinterpret_cast<void***>(base);
        void** derived_vtable = *reinterpret_cast<void***>(derived);
        
        std::cout << "Base vtable: " << base_vtable << std::endl;
        std::cout << "Derived vtable: " << derived_vtable << std::endl;
        
        *reinterpret_cast<void***>(base) = derived_vtable;
        base->foo();
        
        delete base;
        delete derived;
    }
    
    void test_object_slicing() {
        std::cout << "\nTesting object slicing..." << std::endl;
        
        class Base {
        protected:
            int value;
        public:
            Base(int v) : value(v) {}
            virtual void print() { std::cout << "Base value: " << value << std::endl; }
            virtual ~Base() = default;
        };
        
        class Derived : public Base {
            int extra;
        public:
            Derived(int v, int e) : Base(v), extra(e) {}
            void print() override {
                std::cout << "Derived value: " << value << ", extra: " << extra << std::endl;
            }
        };
        
        Derived d(1, 2);
        Base b = d;
        
        std::cout << "Original derived object:" << std::endl;
        d.print();
        
        std::cout << "Sliced base object:" << std::endl;
        b.print();
    }
    
    void test_template_specialization_vulnerability() {
        std::cout << "\nTesting template specialization vulnerabilities..." << std::endl;
        
        template<typename T>
        struct VulnerableTemplate {
            T value;
            
            VulnerableTemplate(const T& v) : value(v) {}
            
            template<typename U>
            U unsafe_convert() const {
                return reinterpret_cast<U>(value);
            }
        };
        
        template<typename T>
        struct VulnerableTemplate<T*> {
            T* value;
            
            VulnerableTemplate(T* v) : value(v) {}
            
            template<typename U>
            U* unsafe_convert() const {
                return reinterpret_cast<U*>(value);
            }
        };
        
        int int_val = 100;
        double double_val = 3.14;
        
        VulnerableTemplate<int> int_template(int_val);
        VulnerableTemplate<double*> double_template(&double_val);
        
        double int_as_double = int_template.unsafe_convert<double>();
        int* double_as_int_ptr = double_template.unsafe_convert<int>();
        
        std::cout << "Int as double: " << int_as_double << std::endl;
        std::cout << "Double pointer as int pointer: " << *double_as_int_ptr << std::endl;
    }
    
    void test_std_function_vulnerability() {
        std::cout << "\nTesting std::function vulnerabilities..." << std::endl;
        
        std::function<void()> void_func = []() { std::cout << "Void function" << std::endl; };
        std::function<int(int)> int_func = [](int x) { return x * 2; };
        std::function<double(double)> double_func = [](double x) { return x * 2.0; };
        
        void* void_ptr = reinterpret_cast<void*>(&void_func);
        void* int_ptr = reinterpret_cast<void*>(&int_func);
        void* double_ptr = reinterpret_cast<void*>(&double_func);
        
        std::function<void()>* confused_void = reinterpret_cast<std::function<void()>*>(int_ptr);
        std::function<int(int)>* confused_int = reinterpret_cast<std::function<int(int)>*>(double_ptr);
        
        (*confused_void)();
        int result = (*confused_int)(42);
        std::cout << "Confused function result: " << result << std::endl;
    }
    
    void run_all_tests() {
        test_type_confusion();
        test_template_vulnerability();
        test_pointer_arithmetic();
        test_union_vulnerability();
        test_function_pointer_vulnerability();
        test_virtual_function_confusion();
        test_object_slicing();
        test_template_specialization_vulnerability();
        test_std_function_vulnerability();
        
        std::cout << "\nType registry status:" << std::endl;
        for (const auto& pair : type_registry) {
            std::cout << "  " << pair.first << " -> " << pair.second << std::endl;
        }
        
        std::cout << "\nType history:" << std::endl;
        for (const auto& pair : type_history) {
            std::cout << "  " << pair.first << " -> " << pair.second << std::endl;
        }
        
        std::cout << "\nTotal type confusion attempts: " << confusion_count << std::endl;
    }
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <command>" << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  test - Run all vulnerability tests" << std::endl;
        std::cout << "  confusion - Test type confusion" << std::endl;
        std::cout << "  template - Test template vulnerabilities" << std::endl;
        std::cout << "  pointer - Test pointer arithmetic" << std::endl;
        std::cout << "  union - Test union vulnerabilities" << std::endl;
        std::cout << "  function - Test function pointer vulnerabilities" << std::endl;
        std::cout << "  virtual - Test virtual function confusion" << std::endl;
        std::cout << "  slicing - Test object slicing" << std::endl;
        std::cout << "  specialization - Test template specialization" << std::endl;
        std::cout << "  std_function - Test std::function vulnerabilities" << std::endl;
        return 1;
    }
    
    TypeConfusionTest test;
    std::string command = argv[1];
    
    try {
        if (command == "test") {
            test.run_all_tests();
        }
        else if (command == "confusion") {
            test.test_type_confusion();
        }
        else if (command == "template") {
            test.test_template_vulnerability();
        }
        else if (command == "pointer") {
            test.test_pointer_arithmetic();
        }
        else if (command == "union") {
            test.test_union_vulnerability();
        }
        else if (command == "function") {
            test.test_function_pointer_vulnerability();
        }
        else if (command == "virtual") {
            test.test_virtual_function_confusion();
        }
        else if (command == "slicing") {
            test.test_object_slicing();
        }
        else if (command == "specialization") {
            test.test_template_specialization_vulnerability();
        }
        else if (command == "std_function") {
            test.test_std_function_vulnerability();
        }
        else {
            std::cout << "Invalid command" << std::endl;
        }
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
} 