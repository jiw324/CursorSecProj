// AI-Generated Code Header
// **Intent:** Comprehensive template programming demonstration with modern C++ features
// **Optimization:** Compile-time computation and type safety
// **Safety:** SFINAE, concept-like constraints, and template metaprogramming

#include <iostream>
#include <vector>
#include <string>
#include <memory>
#include <type_traits>
#include <algorithm>
#include <functional>
#include <utility>
#include <tuple>
#include <array>
#include <chrono>
#include <numeric>
#include <random>

namespace TemplateEngine {

// AI-SUGGESTION: Basic generic container template
template<typename T, size_t N = 10>
class StaticArray {
private:
    T data_[N];
    size_t size_ = 0;
    
public:
    using value_type = T;
    using iterator = T*;
    using const_iterator = const T*;
    
    constexpr size_t capacity() const noexcept { return N; }
    constexpr size_t size() const noexcept { return size_; }
    constexpr bool empty() const noexcept { return size_ == 0; }
    constexpr bool full() const noexcept { return size_ == N; }
    
    void push_back(const T& value) {
        if (full()) {
            throw std::overflow_error("StaticArray is full");
        }
        data_[size_++] = value;
    }
    
    template<typename... Args>
    void emplace_back(Args&&... args) {
        if (full()) {
            throw std::overflow_error("StaticArray is full");
        }
        new (&data_[size_++]) T(std::forward<Args>(args)...);
    }
    
    T& operator[](size_t index) { return data_[index]; }
    const T& operator[](size_t index) const { return data_[index]; }
    
    T& at(size_t index) {
        if (index >= size_) throw std::out_of_range("Index out of range");
        return data_[index];
    }
    
    iterator begin() { return data_; }
    iterator end() { return data_ + size_; }
    const_iterator begin() const { return data_; }
    const_iterator end() const { return data_ + size_; }
    const_iterator cbegin() const { return data_; }
    const_iterator cend() const { return data_ + size_; }
};

// AI-SUGGESTION: Template specialization for bool
template<size_t N>
class StaticArray<bool, N> {
private:
    std::array<uint8_t, (N + 7) / 8> data_{};
    size_t size_ = 0;
    
    class BitReference {
        uint8_t& byte_;
        uint8_t mask_;
    public:
        BitReference(uint8_t& byte, uint8_t mask) : byte_(byte), mask_(mask) {}
        operator bool() const { return byte_ & mask_; }
        BitReference& operator=(bool value) {
            if (value) byte_ |= mask_;
            else byte_ &= ~mask_;
            return *this;
        }
    };
    
public:
    constexpr size_t capacity() const noexcept { return N; }
    constexpr size_t size() const noexcept { return size_; }
    constexpr bool empty() const noexcept { return size_ == 0; }
    constexpr bool full() const noexcept { return size_ == N; }
    
    void push_back(bool value) {
        if (full()) throw std::overflow_error("StaticArray<bool> is full");
        (*this)[size_++] = value;
    }
    
    BitReference operator[](size_t index) {
        uint8_t& byte = data_[index / 8];
        uint8_t mask = 1 << (index % 8);
        return BitReference(byte, mask);
    }
    
    bool operator[](size_t index) const {
        const uint8_t& byte = data_[index / 8];
        uint8_t mask = 1 << (index % 8);
        return byte & mask;
    }
};

// AI-SUGGESTION: Advanced template metaprogramming utilities
template<typename T>
struct TypeTraits {
    static constexpr bool is_pointer = std::is_pointer_v<T>;
    static constexpr bool is_reference = std::is_reference_v<T>;
    static constexpr bool is_arithmetic = std::is_arithmetic_v<T>;
    static constexpr bool is_class = std::is_class_v<T>;
    static constexpr size_t size = sizeof(T);
    using remove_cv = std::remove_cv_t<T>;
    using remove_ref = std::remove_reference_t<T>;
    using decay = std::decay_t<T>;
};

// AI-SUGGESTION: SFINAE utilities for type checking
// AI-SUGGESTION: Portable detection using SFINAE
template<typename T, typename = void>
struct has_size_method : std::false_type {};

template<typename T>
struct has_size_method<T, std::void_t<decltype(std::declval<T>().size())>> : std::true_type {};

template<typename T>
constexpr bool has_size_v = has_size_method<T>::value;

template<typename T, typename = void>
struct has_begin_method : std::false_type {};

template<typename T>
struct has_begin_method<T, std::void_t<decltype(std::declval<T>().begin())>> : std::true_type {};

template<typename T>
constexpr bool is_iterable_v = has_begin_method<T>::value;

// AI-SUGGESTION: Variadic template function for printing
template<typename T>
void print_single(const T& value) {
    std::cout << value;
}

template<typename First, typename... Rest>
void print_variadic(const First& first, const Rest&... rest) {
    print_single(first);
    if constexpr (sizeof...(rest) > 0) {
        std::cout << ", ";
        print_variadic(rest...);
    }
}

template<typename... Args>
void print_all(const Args&... args) {
    std::cout << "Values: ";
    if constexpr (sizeof...(args) > 0) {
        print_variadic(args...);
    }
    std::cout << "\n";
}

// AI-SUGGESTION: Template function with SFINAE
template<typename Container>
std::enable_if_t<has_size_v<Container>, size_t>
get_container_size(const Container& container) {
    return container.size();
}

template<typename Container>
std::enable_if_t<!has_size_v<Container> && is_iterable_v<Container>, size_t>
get_container_size(const Container& container) {
    return std::distance(container.begin(), container.end());
}

// AI-SUGGESTION: Generic algorithms with templates
template<typename InputIt, typename Predicate>
constexpr size_t count_if_template(InputIt first, InputIt last, Predicate pred) {
    size_t count = 0;
    for (; first != last; ++first) {
        if (pred(*first)) {
            ++count;
        }
    }
    return count;
}

template<typename Container, typename Predicate>
constexpr auto count_if_container(const Container& container, Predicate pred) {
    return count_if_template(container.begin(), container.end(), pred);
}

// AI-SUGGESTION: Template-based smart pointer implementation
template<typename T>
class UniquePtr {
private:
    T* ptr_;
    
public:
    explicit UniquePtr(T* ptr = nullptr) : ptr_(ptr) {}
    
    ~UniquePtr() {
        delete ptr_;
    }
    
    // AI-SUGGESTION: Move semantics
    UniquePtr(UniquePtr&& other) noexcept : ptr_(other.ptr_) {
        other.ptr_ = nullptr;
    }
    
    UniquePtr& operator=(UniquePtr&& other) noexcept {
        if (this != &other) {
            delete ptr_;
            ptr_ = other.ptr_;
            other.ptr_ = nullptr;
        }
        return *this;
    }
    
    // AI-SUGGESTION: Disable copy operations
    UniquePtr(const UniquePtr&) = delete;
    UniquePtr& operator=(const UniquePtr&) = delete;
    
    T& operator*() const { return *ptr_; }
    T* operator->() const { return ptr_; }
    T* get() const { return ptr_; }
    
    explicit operator bool() const { return ptr_ != nullptr; }
    
    T* release() {
        T* temp = ptr_;
        ptr_ = nullptr;
        return temp;
    }
    
    void reset(T* ptr = nullptr) {
        delete ptr_;
        ptr_ = ptr;
    }
};

template<typename T, typename... Args>
UniquePtr<T> make_unique_custom(Args&&... args) {
    return UniquePtr<T>(new T(std::forward<Args>(args)...));
}

// AI-SUGGESTION: Template-based functional programming utilities
template<typename Func, typename... Args>
class PartialApplication {
    Func func_;
    std::tuple<Args...> args_;
    
public:
    PartialApplication(Func func, Args... args) 
        : func_(func), args_(std::make_tuple(args...)) {}
    
    template<typename... NewArgs>
    auto operator()(NewArgs&&... newArgs) const {
        return std::apply(func_, std::tuple_cat(args_, std::make_tuple(std::forward<NewArgs>(newArgs)...)));
    }
};

template<typename Func, typename... Args>
auto partial(Func func, Args... args) {
    return PartialApplication<Func, Args...>(func, args...);
}

// AI-SUGGESTION: Template-based tuple utilities
template<typename Tuple, size_t... Indices>
void print_tuple_impl(const Tuple& tuple, std::index_sequence<Indices...>) {
    ((std::cout << (Indices == 0 ? "" : ", ") << std::get<Indices>(tuple)), ...);
}

template<typename... Types>
void print_tuple(const std::tuple<Types...>& tuple) {
    std::cout << "(";
    print_tuple_impl(tuple, std::make_index_sequence<sizeof...(Types)>{});
    std::cout << ")";
}

// AI-SUGGESTION: Compile-time computations
template<int N>
struct Factorial {
    static constexpr int value = N * Factorial<N-1>::value;
};

template<>
struct Factorial<0> {
    static constexpr int value = 1;
};

template<int N>
constexpr int factorial_v = Factorial<N>::value;

// AI-SUGGESTION: Constexpr fibonacci
constexpr int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n-1) + fibonacci(n-2);
}

// AI-SUGGESTION: Template-based observer pattern
template<typename EventType>
class Observable {
private:
    std::vector<std::function<void(const EventType&)>> observers_;
    
public:
    void subscribe(std::function<void(const EventType&)> observer) {
        observers_.push_back(std::move(observer));
    }
    
    void notify(const EventType& event) {
        for (const auto& observer : observers_) {
            observer(event);
        }
    }
    
    template<typename T>
    void subscribe_member(T* object, void (T::*method)(const EventType&)) {
        subscribe([object, method](const EventType& event) {
            (object->*method)(event);
        });
    }
};

// AI-SUGGESTION: Template-based visitor pattern
template<typename... Types>
class Variant {
private:
    std::aligned_union_t<0, Types...> storage_;
    size_t type_index_;
    
    template<typename T>
    static constexpr size_t type_to_index() {
        constexpr std::array<bool, sizeof...(Types)> matches = 
            {{std::is_same_v<T, Types>...}};
        for (size_t i = 0; i < matches.size(); ++i) {
            if (matches[i]) return i;
        }
        return SIZE_MAX;
    }
    
public:
    template<typename T>
    Variant(T&& value) : type_index_(type_to_index<std::decay_t<T>>()) {
        new (&storage_) std::decay_t<T>(std::forward<T>(value));
    }
    
    template<typename T>
    T& get() {
        if (type_index_ != type_to_index<T>()) {
            throw std::bad_cast();
        }
        return *reinterpret_cast<T*>(&storage_);
    }
    
    template<typename Visitor>
    auto visit(Visitor&& visitor) {
        return visit_impl(std::forward<Visitor>(visitor), 
                         std::make_index_sequence<sizeof...(Types)>{});
    }
    
private:
    template<typename Visitor, size_t... Indices>
    auto visit_impl(Visitor&& visitor, std::index_sequence<Indices...>) {
        using ReturnType = std::common_type_t<
            decltype(visitor(std::declval<Types&>()))...>;
        
        ReturnType (*visitors[])(Visitor&&, void*) = {
            [](Visitor&& vis, void* storage) -> ReturnType {
                return vis(*reinterpret_cast<Types*>(storage));
            }...
        };
        
        return visitors[type_index_](std::forward<Visitor>(visitor), &storage_);
    }
};

// AI-SUGGESTION: Performance measurement template
template<typename Func>
class BenchmarkRunner {
public:
    template<typename... Args>
    static auto measure(Func func, Args&&... args) {
        auto start = std::chrono::high_resolution_clock::now();
        
        if constexpr (std::is_void_v<std::invoke_result_t<Func, Args...>>) {
            func(std::forward<Args>(args)...);
            auto end = std::chrono::high_resolution_clock::now();
            return std::chrono::duration_cast<std::chrono::microseconds>(end - start);
        } else {
            auto result = func(std::forward<Args>(args)...);
            auto end = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
            return std::make_pair(result, duration);
        }
    }
};

} // namespace TemplateEngine

// AI-SUGGESTION: Demonstration functions
void demonstrateBasicTemplates() {
    using namespace TemplateEngine;
    
    std::cout << "=== Basic Template Demonstrations ===\n";
    
    // AI-SUGGESTION: StaticArray demonstration
    StaticArray<int, 5> intArray;
    intArray.push_back(1);
    intArray.push_back(2);
    intArray.push_back(3);
    
    std::cout << "StaticArray<int>: ";
    for (const auto& item : intArray) {
        std::cout << item << " ";
    }
    std::cout << "\n";
    
    // AI-SUGGESTION: Bool specialization
    StaticArray<bool, 10> boolArray;
    boolArray.push_back(true);
    boolArray.push_back(false);
    boolArray.push_back(true);
    
    std::cout << "StaticArray<bool>: ";
    for (size_t i = 0; i < boolArray.size(); ++i) {
        std::cout << boolArray[i] << " ";
    }
    std::cout << "\n";
    
    // AI-SUGGESTION: Variadic templates
    print_all(1, 2.5, "hello", 'c', true);
    
    // AI-SUGGESTION: Type traits
    std::cout << "int is arithmetic: " << TypeTraits<int>::is_arithmetic << "\n";
    std::cout << "string is class: " << TypeTraits<std::string>::is_class << "\n";
    std::cout << "int* is pointer: " << TypeTraits<int*>::is_pointer << "\n";
}

void demonstrateAdvancedTemplates() {
    using namespace TemplateEngine;
    
    std::cout << "\n=== Advanced Template Features ===\n";
    
    // AI-SUGGESTION: Smart pointer demonstration
    auto ptr = make_unique_custom<std::string>("Hello, Templates!");
    std::cout << "UniquePtr content: " << *ptr << "\n";
    
    // AI-SUGGESTION: Partial application
    auto multiply = [](int a, int b, int c) { return a * b * c; };
    auto multiply_by_2_and_3 = partial(multiply, 2, 3);
    std::cout << "Partial application result: " << multiply_by_2_and_3(4) << "\n";
    
    // AI-SUGGESTION: Tuple printing
    auto tuple = std::make_tuple(42, 3.14, "world", 'x');
    std::cout << "Tuple: ";
    print_tuple(tuple);
    std::cout << "\n";
    
    // AI-SUGGESTION: Compile-time computations
    constexpr int fact5 = factorial_v<5>;
    constexpr int fib10 = fibonacci(10);
    std::cout << "5! = " << fact5 << "\n";
    std::cout << "fibonacci(10) = " << fib10 << "\n";
    
    // AI-SUGGESTION: SFINAE demonstration
    std::vector<int> vec = {1, 2, 3, 4, 5};
    std::cout << "Vector size (SFINAE): " << get_container_size(vec) << "\n";
    
    auto even_count = count_if_container(vec, [](int x) { return x % 2 == 0; });
    std::cout << "Even numbers in vector: " << even_count << "\n";
}

void demonstratePatterns() {
    using namespace TemplateEngine;
    
    std::cout << "\n=== Template-Based Patterns ===\n";
    
    // AI-SUGGESTION: Observer pattern
    Observable<std::string> eventSystem;
    
    eventSystem.subscribe([](const std::string& event) {
        std::cout << "Observer 1 received: " << event << "\n";
    });
    
    eventSystem.subscribe([](const std::string& event) {
        std::cout << "Observer 2 processed: " << event << "\n";
    });
    
    eventSystem.notify("Important Event");
    
    // AI-SUGGESTION: Variant and visitor
    Variant<int, std::string, double> var1(42);
    Variant<int, std::string, double> var2(std::string("hello"));
    Variant<int, std::string, double> var3(3.14);
    
    auto printer = [](const auto& value) {
        std::cout << "Variant contains: " << value << "\n";
    };
    
    var1.visit(printer);
    var2.visit(printer);
    var3.visit(printer);
}

void demonstratePerformance() {
    using namespace TemplateEngine;
    
    std::cout << "\n=== Performance Measurements ===\n";
    
    // AI-SUGGESTION: Benchmark sorting
    std::vector<int> data(10000);
    std::iota(data.begin(), data.end(), 1);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::shuffle(data.begin(), data.end(), gen);
    
    auto sort_benchmark = [](std::vector<int> vec) {
        std::sort(vec.begin(), vec.end());
        return vec.size();
    };
    
    auto [result, duration] = BenchmarkRunner<decltype(sort_benchmark)>::measure(sort_benchmark, data);
    std::cout << "Sorted " << result << " elements in " 
              << duration.count() << " microseconds\n";
    
    // AI-SUGGESTION: Benchmark compile-time vs runtime
    auto compile_time_fib = []() { return fibonacci(20); };
    auto [fib_result, fib_duration] = BenchmarkRunner<decltype(compile_time_fib)>::measure(compile_time_fib);
    
    std::cout << "Compile-time fibonacci(20) = " << fib_result << " computed in " 
              << fib_duration.count() << " microseconds\n";
}

int main() {
    std::cout << "C++ Template Programming Demonstration\n";
    std::cout << "=====================================\n\n";
    
    demonstrateBasicTemplates();
    demonstrateAdvancedTemplates();
    demonstratePatterns();
    demonstratePerformance();
    
    std::cout << "\n=== Template Programming Demo Complete ===\n";
    return 0;
} 