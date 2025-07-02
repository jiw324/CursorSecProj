// AI-Generated Code Header
// **Intent:** Comprehensive STL algorithms and containers demonstration
// **Optimization:** Efficient use of STL algorithms and modern C++ features
// **Safety:** Range-based operations and iterator safety

#include <iostream>
#include <vector>
#include <deque>
#include <list>
#include <set>
#include <map>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <numeric>
#include <functional>
#include <iterator>
#include <random>
#include <chrono>
#include <string>
#include <sstream>
#include <iomanip>

namespace AlgorithmToolkit {

// AI-SUGGESTION: Custom data structure for demonstrations
struct Person {
    std::string name;
    int age;
    double salary;
    std::string department;
    
    Person(const std::string& n, int a, double s, const std::string& dept)
        : name(n), age(a), salary(s), department(dept) {}
    
    // AI-SUGGESTION: Comparison operators for sorting
    bool operator<(const Person& other) const {
        return age < other.age;
    }
    
    bool operator==(const Person& other) const {
        return name == other.name && age == other.age;
    }
    
    std::string toString() const {
        std::ostringstream oss;
        oss << std::setw(15) << name << " | Age: " << std::setw(2) << age 
            << " | Salary: $" << std::setw(8) << std::fixed << std::setprecision(0) << salary
            << " | Dept: " << department;
        return oss.str();
    }
};

// AI-SUGGESTION: Algorithm analysis and benchmarking utilities
class PerformanceTimer {
    std::chrono::high_resolution_clock::time_point start_time;
    
public:
    void start() {
        start_time = std::chrono::high_resolution_clock::now();
    }
    
    double elapsed_ms() const {
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time);
        return duration.count() / 1000.0;
    }
};

// AI-SUGGESTION: Data generation utilities
class DataGenerator {
private:
    std::mt19937 rng;
    std::vector<std::string> first_names = {
        "Alice", "Bob", "Charlie", "Diana", "Edward", "Fiona", "George", "Helen",
        "Ivan", "Julia", "Kevin", "Laura", "Michael", "Nina", "Oliver", "Penny"
    };
    std::vector<std::string> departments = {
        "Engineering", "Sales", "Marketing", "HR", "Finance", "Operations"
    };
    
public:
    DataGenerator() : rng(std::random_device{}()) {}
    
    std::vector<int> generateIntegers(size_t count, int min_val = 1, int max_val = 1000) {
        std::vector<int> result;
        result.reserve(count);
        
        std::uniform_int_distribution<int> dist(min_val, max_val);
        
        for (size_t i = 0; i < count; ++i) {
            result.push_back(dist(rng));
        }
        
        return result;
    }
    
    std::vector<Person> generatePeople(size_t count) {
        std::vector<Person> result;
        result.reserve(count);
        
        std::uniform_int_distribution<int> age_dist(22, 65);
        std::uniform_real_distribution<double> salary_dist(30000.0, 150000.0);
        std::uniform_int_distribution<size_t> name_dist(0, first_names.size() - 1);
        std::uniform_int_distribution<size_t> dept_dist(0, departments.size() - 1);
        
        for (size_t i = 0; i < count; ++i) {
            std::string name = first_names[name_dist(rng)] + std::to_string(i);
            int age = age_dist(rng);
            double salary = salary_dist(rng);
            std::string dept = departments[dept_dist(rng)];
            
            result.emplace_back(name, age, salary, dept);
        }
        
        return result;
    }
};

// AI-SUGGESTION: Sorting algorithms demonstration
class SortingAlgorithms {
public:
    template<typename Container>
    static void demonstrateSorting(Container& data, const std::string& title) {
        std::cout << "\n=== " << title << " Sorting Demonstration ===\n";
        
        // AI-SUGGESTION: Make copies for different sorting methods
        auto data1 = data;
        auto data2 = data;
        auto data3 = data;
        auto data4 = data;
        
        PerformanceTimer timer;
        
        // AI-SUGGESTION: Standard sort
        timer.start();
        std::sort(data1.begin(), data1.end());
        std::cout << "std::sort: " << timer.elapsed_ms() << " ms\n";
        
        // AI-SUGGESTION: Stable sort
        timer.start();
        std::stable_sort(data2.begin(), data2.end());
        std::cout << "std::stable_sort: " << timer.elapsed_ms() << " ms\n";
        
        // AI-SUGGESTION: Partial sort (top 10 elements)
        size_t partial_count = std::min(data3.size(), size_t(10));
        timer.start();
        std::partial_sort(data3.begin(), data3.begin() + partial_count, data3.end());
        std::cout << "std::partial_sort (top " << partial_count << "): " << timer.elapsed_ms() << " ms\n";
        
        // AI-SUGGESTION: Nth element (median)
        timer.start();
        std::nth_element(data4.begin(), data4.begin() + data4.size()/2, data4.end());
        std::cout << "std::nth_element (median): " << timer.elapsed_ms() << " ms\n";
        
        // AI-SUGGESTION: Verify sorting
        bool is_sorted = std::is_sorted(data1.begin(), data1.end());
        std::cout << "Result is sorted: " << (is_sorted ? "Yes" : "No") << "\n";
    }
    
    static void demonstrateCustomSorting() {
        std::cout << "\n=== Custom Sorting Criteria ===\n";
        
        DataGenerator gen;
        auto people = gen.generatePeople(20);
        
        std::cout << "Original data (first 5):\n";
        for (size_t i = 0; i < std::min(people.size(), size_t(5)); ++i) {
            std::cout << people[i].toString() << "\n";
        }
        
        // AI-SUGGESTION: Sort by salary (descending)
        auto by_salary = people;
        std::sort(by_salary.begin(), by_salary.end(),
                  [](const Person& a, const Person& b) { return a.salary > b.salary; });
        
        std::cout << "\nTop 5 by salary:\n";
        for (size_t i = 0; i < 5; ++i) {
            std::cout << by_salary[i].toString() << "\n";
        }
        
        // AI-SUGGESTION: Sort by department, then by age
        auto by_dept_age = people;
        std::sort(by_dept_age.begin(), by_dept_age.end(),
                  [](const Person& a, const Person& b) {
                      if (a.department == b.department) {
                          return a.age < b.age;
                      }
                      return a.department < b.department;
                  });
        
        std::cout << "\nBy department then age (first 5):\n";
        for (size_t i = 0; i < 5; ++i) {
            std::cout << by_dept_age[i].toString() << "\n";
        }
    }
};

// AI-SUGGESTION: Search algorithms demonstration
class SearchAlgorithms {
public:
    template<typename Container, typename Value>
    static void demonstrateSearch(const Container& data, const Value& target) {
        std::cout << "\n=== Search Algorithms ===\n";
        
        PerformanceTimer timer;
        
        // AI-SUGGESTION: Linear search
        timer.start();
        auto linear_it = std::find(data.begin(), data.end(), target);
        double linear_time = timer.elapsed_ms();
        
        // AI-SUGGESTION: Binary search (requires sorted data)
        auto sorted_data = data;
        std::sort(sorted_data.begin(), sorted_data.end());
        
        timer.start();
        bool binary_found = std::binary_search(sorted_data.begin(), sorted_data.end(), target);
        double binary_time = timer.elapsed_ms();
        
        // AI-SUGGESTION: Lower and upper bound
        timer.start();
        auto lower = std::lower_bound(sorted_data.begin(), sorted_data.end(), target);
        auto upper = std::upper_bound(sorted_data.begin(), sorted_data.end(), target);
        double bound_time = timer.elapsed_ms();
        
        std::cout << "Linear search: " << (linear_it != data.end() ? "Found" : "Not found") 
                  << " in " << linear_time << " ms\n";
        std::cout << "Binary search: " << (binary_found ? "Found" : "Not found") 
                  << " in " << binary_time << " ms\n";
        std::cout << "Bound operations: " << bound_time << " ms\n";
        
        if (lower != sorted_data.end()) {
            size_t count = std::distance(lower, upper);
            std::cout << "Target appears " << count << " times\n";
        }
    }
    
    static void demonstrateAdvancedSearch() {
        std::cout << "\n=== Advanced Search Patterns ===\n";
        
        DataGenerator gen;
        auto people = gen.generatePeople(100);
        
        // AI-SUGGESTION: Find all people in a specific department
        std::string target_dept = "Engineering";
        std::vector<Person> engineers;
        
        std::copy_if(people.begin(), people.end(), std::back_inserter(engineers),
                     [&target_dept](const Person& p) { return p.department == target_dept; });
        
        std::cout << "Found " << engineers.size() << " people in " << target_dept << "\n";
        
        // AI-SUGGESTION: Find people with salary above average
        double avg_salary = std::accumulate(people.begin(), people.end(), 0.0,
                                          [](double sum, const Person& p) { return sum + p.salary; }) / people.size();
        
        auto high_earners = std::count_if(people.begin(), people.end(),
                                        [avg_salary](const Person& p) { return p.salary > avg_salary; });
        
        std::cout << "Average salary: $" << std::fixed << std::setprecision(0) << avg_salary << "\n";
        std::cout << "People earning above average: " << high_earners << "\n";
        
        // AI-SUGGESTION: Find min and max elements
        auto [min_age_it, max_age_it] = std::minmax_element(people.begin(), people.end(),
                                                          [](const Person& a, const Person& b) { return a.age < b.age; });
        
        std::cout << "Youngest person: " << min_age_it->toString() << "\n";
        std::cout << "Oldest person: " << max_age_it->toString() << "\n";
    }
};

// AI-SUGGESTION: Numeric algorithms demonstration
class NumericAlgorithms {
public:
    static void demonstrateAccumulation() {
        std::cout << "\n=== Numeric Algorithms ===\n";
        
        DataGenerator gen;
        auto numbers = gen.generateIntegers(1000, 1, 100);
        
        PerformanceTimer timer;
        
        // AI-SUGGESTION: Basic accumulation
        timer.start();
        int sum = std::accumulate(numbers.begin(), numbers.end(), 0);
        std::cout << "Sum: " << sum << " (computed in " << timer.elapsed_ms() << " ms)\n";
        
        // AI-SUGGESTION: Product calculation
        timer.start();
        long long product = std::accumulate(numbers.begin(), numbers.begin() + 10, 1LL, std::multiplies<long long>());
        std::cout << "Product of first 10: " << product << " (computed in " << timer.elapsed_ms() << " ms)\n";
        
        // AI-SUGGESTION: Custom accumulation - average
        timer.start();
        double average = std::accumulate(numbers.begin(), numbers.end(), 0.0) / numbers.size();
        std::cout << "Average: " << std::fixed << std::setprecision(2) << average 
                  << " (computed in " << timer.elapsed_ms() << " ms)\n";
        
        // AI-SUGGESTION: Alternative accumulation (portable)
        timer.start();
        int parallel_sum = std::accumulate(numbers.begin(), numbers.end(), 0);
        std::cout << "Alternative sum: " << parallel_sum << " (computed in " << timer.elapsed_ms() << " ms)\n";
        
        // AI-SUGGESTION: Transform reduce
        timer.start();
        int sum_of_squares = std::transform_reduce(numbers.begin(), numbers.end(), 0, std::plus<>(),
                                                 [](int x) { return x * x; });
        std::cout << "Sum of squares: " << sum_of_squares << " (computed in " << timer.elapsed_ms() << " ms)\n";
    }
    
    static void demonstrateTransformations() {
        std::cout << "\n=== Transformation Algorithms ===\n";
        
        std::vector<int> input = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
        std::vector<int> output(input.size());
        
        // AI-SUGGESTION: Simple transformation
        std::transform(input.begin(), input.end(), output.begin(),
                      [](int x) { return x * x; });
        
        std::cout << "Squares: ";
        std::copy(output.begin(), output.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: Binary transformation
        std::vector<int> input2 = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100};
        std::vector<int> sums(input.size());
        
        std::transform(input.begin(), input.end(), input2.begin(), sums.begin(), std::plus<int>());
        
        std::cout << "Pairwise sums: ";
        std::copy(sums.begin(), sums.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: In-place transformation
        std::for_each(input.begin(), input.end(), [](int& x) { x *= 2; });
        
        std::cout << "Doubled in-place: ";
        std::copy(input.begin(), input.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
    }
};

// AI-SUGGESTION: Container operations demonstration
class ContainerOperations {
public:
    static void demonstrateSetOperations() {
        std::cout << "\n=== Set Operations ===\n";
        
        std::vector<int> set1 = {1, 2, 3, 4, 5, 6, 7};
        std::vector<int> set2 = {4, 5, 6, 7, 8, 9, 10};
        
        // AI-SUGGESTION: Ensure sets are sorted
        std::sort(set1.begin(), set1.end());
        std::sort(set2.begin(), set2.end());
        
        std::vector<int> result;
        
        // AI-SUGGESTION: Union
        std::set_union(set1.begin(), set1.end(), set2.begin(), set2.end(), std::back_inserter(result));
        std::cout << "Union: ";
        std::copy(result.begin(), result.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: Intersection
        result.clear();
        std::set_intersection(set1.begin(), set1.end(), set2.begin(), set2.end(), std::back_inserter(result));
        std::cout << "Intersection: ";
        std::copy(result.begin(), result.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: Difference
        result.clear();
        std::set_difference(set1.begin(), set1.end(), set2.begin(), set2.end(), std::back_inserter(result));
        std::cout << "Difference (set1 - set2): ";
        std::copy(result.begin(), result.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: Symmetric difference
        result.clear();
        std::set_symmetric_difference(set1.begin(), set1.end(), set2.begin(), set2.end(), std::back_inserter(result));
        std::cout << "Symmetric difference: ";
        std::copy(result.begin(), result.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
    }
    
    static void demonstrateHeapOperations() {
        std::cout << "\n=== Heap Operations ===\n";
        
        DataGenerator gen;
        auto data = gen.generateIntegers(20, 1, 100);
        
        std::cout << "Original data: ";
        std::copy(data.begin(), data.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: Make heap
        std::make_heap(data.begin(), data.end());
        std::cout << "After make_heap: ";
        std::copy(data.begin(), data.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: Extract max elements
        std::cout << "Extracting top 5 elements: ";
        for (int i = 0; i < 5 && !data.empty(); ++i) {
            std::pop_heap(data.begin(), data.end());
            std::cout << data.back() << " ";
            data.pop_back();
        }
        std::cout << "\n";
        
        // AI-SUGGESTION: Add new element
        data.push_back(150);
        std::push_heap(data.begin(), data.end());
        std::cout << "After adding 150 and push_heap: ";
        std::copy(data.begin(), data.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
        
        // AI-SUGGESTION: Sort heap
        std::sort_heap(data.begin(), data.end());
        std::cout << "After sort_heap: ";
        std::copy(data.begin(), data.end(), std::ostream_iterator<int>(std::cout, " "));
        std::cout << "\n";
    }
};

} // namespace AlgorithmToolkit

// AI-SUGGESTION: Main demonstration function
void demonstrateAlgorithmToolkit() {
    using namespace AlgorithmToolkit;
    
    std::cout << "C++ STL Algorithm Toolkit Demonstration\n";
    std::cout << "=======================================\n";
    
    DataGenerator gen;
    
    // AI-SUGGESTION: Demonstrate sorting
    auto integers = gen.generateIntegers(10000);
    SortingAlgorithms::demonstrateSorting(integers, "Integer");
    SortingAlgorithms::demonstrateCustomSorting();
    
    // AI-SUGGESTION: Demonstrate searching
    int target = integers[integers.size() / 2]; // Pick middle element
    SearchAlgorithms::demonstrateSearch(integers, target);
    SearchAlgorithms::demonstrateAdvancedSearch();
    
    // AI-SUGGESTION: Demonstrate numeric algorithms
    NumericAlgorithms::demonstrateAccumulation();
    NumericAlgorithms::demonstrateTransformations();
    
    // AI-SUGGESTION: Demonstrate container operations
    ContainerOperations::demonstrateSetOperations();
    ContainerOperations::demonstrateHeapOperations();
    
    std::cout << "\n=== Algorithm Toolkit Demonstration Complete ===\n";
}

int main() {
    demonstrateAlgorithmToolkit();
    return 0;
} 