// AI-Generated Code Header
// **Intent:** Data processing system with LINQ and functional programming features
// **Optimization:** Efficient data transformations and query operations
// **Safety:** Null checks, exception handling, and defensive programming

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.IO;
using System.Threading.Tasks;
using System.Globalization;

namespace DataProcessing
{
    // AI-SUGGESTION: Data models for demonstration
    public record Employee(
        int Id,
        string FirstName,
        string LastName,
        string Department,
        string Position,
        decimal Salary,
        DateTime HireDate,
        string Email,
        bool IsActive
    )
    {
        public string FullName => $"{FirstName} {LastName}";
        public int YearsOfService => DateTime.Now.Year - HireDate.Year;
        public decimal AnnualSalary => Salary * 12;
    }
    
    public record SalesRecord(
        int Id,
        int EmployeeId,
        string ProductName,
        decimal Amount,
        DateTime SaleDate,
        string Region,
        string CustomerType
    );
    
    public record DepartmentSummary(
        string Department,
        int EmployeeCount,
        decimal AverageSalary,
        decimal TotalSalary,
        DateTime EarliestHireDate,
        DateTime LatestHireDate
    );
    
    public record SalesAnalytics(
        string Period,
        decimal TotalSales,
        int TransactionCount,
        decimal AverageTransactionValue,
        string TopPerformer,
        string BestSellingProduct
    );
    
    // AI-SUGGESTION: Data generation utility
    public static class DataGenerator
    {
        private static readonly Random _random = new();
        
        private static readonly string[] _firstNames = {
            "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
            "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica"
        };
        
        private static readonly string[] _lastNames = {
            "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
            "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas"
        };
        
        private static readonly string[] _departments = {
            "Engineering", "Sales", "Marketing", "HR", "Finance", "Operations", "IT", "Legal"
        };
        
        private static readonly string[] _positions = {
            "Manager", "Senior", "Junior", "Lead", "Director", "Analyst", "Specialist", "Coordinator"
        };
        
        private static readonly string[] _products = {
            "Laptop Pro", "Smartphone X", "Tablet Plus", "Headphones", "Monitor 4K", "Keyboard", "Mouse", "Webcam"
        };
        
        private static readonly string[] _regions = {
            "North", "South", "East", "West", "Central"
        };
        
        private static readonly string[] _customerTypes = {
            "Individual", "Business", "Enterprise", "Government"
        };
        
        public static List<Employee> GenerateEmployees(int count)
        {
            return Enumerable.Range(1, count)
                .Select(i => new Employee(
                    Id: i,
                    FirstName: _firstNames[_random.Next(_firstNames.Length)],
                    LastName: _lastNames[_random.Next(_lastNames.Length)],
                    Department: _departments[_random.Next(_departments.Length)],
                    Position: _positions[_random.Next(_positions.Length)],
                    Salary: Math.Round((decimal)(_random.NextDouble() * 8000 + 3000), 2),
                    HireDate: DateTime.Now.AddDays(-_random.Next(365 * 10)),
                    Email: string.Empty,
                    IsActive: _random.NextDouble() > 0.1
                ))
                .Select(emp => emp with { Email = $"{emp.FirstName.ToLower()}.{emp.LastName.ToLower()}@company.com" })
                .ToList();
        }
        
        public static List<SalesRecord> GenerateSalesRecords(List<Employee> employees, int recordsPerEmployee)
        {
            var salesEmployees = employees.Where(e => e.Department == "Sales" && e.IsActive).ToList();
            var records = new List<SalesRecord>();
            int id = 1;
            
            foreach (var employee in salesEmployees)
            {
                for (int i = 0; i < recordsPerEmployee; i++)
                {
                    records.Add(new SalesRecord(
                        Id: id++,
                        EmployeeId: employee.Id,
                        ProductName: _products[_random.Next(_products.Length)],
                        Amount: Math.Round((decimal)(_random.NextDouble() * 5000 + 100), 2),
                        SaleDate: DateTime.Now.AddDays(-_random.Next(365)),
                        Region: _regions[_random.Next(_regions.Length)],
                        CustomerType: _customerTypes[_random.Next(_customerTypes.Length)]
                    ));
                }
            }
            
            return records;
        }
    }
    
    // AI-SUGGESTION: Data processing engine with LINQ operations
    public class DataProcessor
    {
        private readonly List<Employee> _employees;
        private readonly List<SalesRecord> _salesRecords;
        
        public DataProcessor(List<Employee> employees, List<SalesRecord> salesRecords)
        {
            _employees = employees ?? throw new ArgumentNullException(nameof(employees));
            _salesRecords = salesRecords ?? throw new ArgumentNullException(nameof(salesRecords));
        }
        
        // AI-SUGGESTION: Complex LINQ queries for data analysis
        public IEnumerable<DepartmentSummary> GetDepartmentSummaries()
        {
            return _employees
                .Where(e => e.IsActive)
                .GroupBy(e => e.Department)
                .Select(g => new DepartmentSummary(
                    Department: g.Key,
                    EmployeeCount: g.Count(),
                    AverageSalary: Math.Round(g.Average(e => e.Salary), 2),
                    TotalSalary: g.Sum(e => e.Salary),
                    EarliestHireDate: g.Min(e => e.HireDate),
                    LatestHireDate: g.Max(e => e.HireDate)
                ))
                .OrderByDescending(d => d.TotalSalary);
        }
        
        public IEnumerable<Employee> GetTopPerformers(int count = 10)
        {
            var salesByEmployee = _salesRecords
                .GroupBy(s => s.EmployeeId)
                .ToDictionary(g => g.Key, g => g.Sum(s => s.Amount));
            
            return _employees
                .Where(e => e.IsActive && salesByEmployee.ContainsKey(e.Id))
                .OrderByDescending(e => salesByEmployee[e.Id])
                .Take(count);
        }
        
        public IEnumerable<SalesAnalytics> GetMonthlySalesAnalytics()
        {
            return _salesRecords
                .GroupBy(s => new { s.SaleDate.Year, s.SaleDate.Month })
                .Select(g => new SalesAnalytics(
                    Period: $"{g.Key.Year}-{g.Key.Month:D2}",
                    TotalSales: g.Sum(s => s.Amount),
                    TransactionCount: g.Count(),
                    AverageTransactionValue: Math.Round(g.Average(s => s.Amount), 2),
                    TopPerformer: GetTopPerformerInPeriod(g),
                    BestSellingProduct: g.GroupBy(s => s.ProductName)
                                       .OrderByDescending(pg => pg.Sum(s => s.Amount))
                                       .First().Key
                ))
                .OrderBy(a => a.Period);
        }
        
        private string GetTopPerformerInPeriod(IGrouping<dynamic, SalesRecord> salesGroup)
        {
            var topEmployeeId = salesGroup
                .GroupBy(s => s.EmployeeId)
                .OrderByDescending(g => g.Sum(s => s.Amount))
                .First().Key;
                
            var employee = _employees.FirstOrDefault(e => e.Id == topEmployeeId);
            return employee?.FullName ?? "Unknown";
        }
        
        public IEnumerable<dynamic> GetSalaryDistribution()
        {
            var salaryRanges = new[]
            {
                new { Min = 0m, Max = 3000m, Label = "Entry Level" },
                new { Min = 3000m, Max = 5000m, Label = "Mid Level" },
                new { Min = 5000m, Max = 7000m, Label = "Senior Level" },
                new { Min = 7000m, Max = 10000m, Label = "Executive Level" },
                new { Min = 10000m, Max = decimal.MaxValue, Label = "C-Level" }
            };
            
            return salaryRanges.Select(range => new
            {
                SalaryRange = range.Label,
                Count = _employees.Count(e => e.IsActive && e.Salary >= range.Min && e.Salary < range.Max),
                AverageSalary = _employees
                    .Where(e => e.IsActive && e.Salary >= range.Min && e.Salary < range.Max)
                    .DefaultIfEmpty()
                    .Average(e => e?.Salary ?? 0),
                Percentage = Math.Round(
                    (double)_employees.Count(e => e.IsActive && e.Salary >= range.Min && e.Salary < range.Max) 
                    / _employees.Count(e => e.IsActive) * 100, 1)
            }).Where(r => r.Count > 0);
        }
        
        // AI-SUGGESTION: Advanced filtering and transformation methods
        public IEnumerable<Employee> FindEmployees(Func<Employee, bool> predicate)
        {
            return _employees.Where(predicate);
        }
        
        public IEnumerable<TResult> TransformData<TResult>(Func<Employee, TResult> selector)
        {
            return _employees.Select(selector);
        }
        
        public IEnumerable<Employee> GetEmployeesHiredInYear(int year)
        {
            return _employees.Where(e => e.HireDate.Year == year && e.IsActive);
        }
        
        public IEnumerable<dynamic> GetSalesTrends()
        {
            return _salesRecords
                .GroupBy(s => s.SaleDate.Date)
                .OrderBy(g => g.Key)
                .Select(g => new
                {
                    Date = g.Key.ToString("yyyy-MM-dd"),
                    TotalSales = g.Sum(s => s.Amount),
                    TransactionCount = g.Count(),
                    AverageTransaction = Math.Round(g.Average(s => s.Amount), 2),
                    TopRegion = g.GroupBy(s => s.Region)
                               .OrderByDescending(rg => rg.Sum(s => s.Amount))
                               .First().Key
                });
        }
        
        // AI-SUGGESTION: Statistical analysis methods
        public dynamic GetStatisticalSummary()
        {
            var activeSalaries = _employees.Where(e => e.IsActive).Select(e => e.Salary).ToList();
            var salesAmounts = _salesRecords.Select(s => s.Amount).ToList();
            
            return new
            {
                Employees = new
                {
                    Total = _employees.Count,
                    Active = _employees.Count(e => e.IsActive),
                    Departments = _employees.Select(e => e.Department).Distinct().Count(),
                    SalaryStats = new
                    {
                        Average = Math.Round(activeSalaries.Average(), 2),
                        Median = CalculateMedian(activeSalaries),
                        Min = activeSalaries.Min(),
                        Max = activeSalaries.Max(),
                        StandardDeviation = Math.Round(CalculateStandardDeviation(activeSalaries), 2)
                    }
                },
                Sales = new
                {
                    TotalRecords = _salesRecords.Count,
                    TotalAmount = _salesRecords.Sum(s => s.Amount),
                    TransactionStats = new
                    {
                        Average = Math.Round(salesAmounts.Average(), 2),
                        Median = CalculateMedian(salesAmounts),
                        Min = salesAmounts.Min(),
                        Max = salesAmounts.Max()
                    }
                }
            };
        }
        
        private static decimal CalculateMedian(List<decimal> values)
        {
            var sorted = values.OrderBy(v => v).ToList();
            int count = sorted.Count;
            
            if (count % 2 == 0)
            {
                return (sorted[count / 2 - 1] + sorted[count / 2]) / 2;
            }
            else
            {
                return sorted[count / 2];
            }
        }
        
        private static double CalculateStandardDeviation(List<decimal> values)
        {
            double mean = (double)values.Average();
            double sumOfSquaredDifferences = values.Sum(v => Math.Pow((double)v - mean, 2));
            return Math.Sqrt(sumOfSquaredDifferences / values.Count);
        }
        
        // AI-SUGGESTION: Data export functionality
        public async Task ExportToJsonAsync(string filePath)
        {
            var exportData = new
            {
                GeneratedDate = DateTime.Now,
                Summary = GetStatisticalSummary(),
                DepartmentSummaries = GetDepartmentSummaries(),
                TopPerformers = GetTopPerformers(5),
                MonthlySalesAnalytics = GetMonthlySalesAnalytics(),
                SalaryDistribution = GetSalaryDistribution()
            };
            
            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            
            var json = JsonSerializer.Serialize(exportData, options);
            await File.WriteAllTextAsync(filePath, json);
        }
        
        // AI-SUGGESTION: Custom aggregation methods
        public IEnumerable<dynamic> GetCustomAggregations()
        {
            // AI-SUGGESTION: Department performance metrics
            var departmentMetrics = _employees
                .Where(e => e.IsActive)
                .Join(_salesRecords, e => e.Id, s => s.EmployeeId, (e, s) => new { Employee = e, Sale = s })
                .GroupBy(x => x.Employee.Department)
                .Select(g => new
                {
                    Department = g.Key,
                    EmployeeCount = g.Select(x => x.Employee.Id).Distinct().Count(),
                    TotalSales = g.Sum(x => x.Sale.Amount),
                    AverageSalesPerEmployee = Math.Round(g.Sum(x => x.Sale.Amount) / g.Select(x => x.Employee.Id).Distinct().Count(), 2),
                    SalesEfficiency = Math.Round(g.Sum(x => x.Sale.Amount) / g.Select(x => x.Employee).Sum(e => e.Salary), 2)
                })
                .OrderByDescending(d => d.SalesEfficiency);
            
            return departmentMetrics;
        }
        
        // AI-SUGGESTION: Functional programming utilities
        public IEnumerable<TResult> Pipeline<TResult>(
            IEnumerable<Employee> source,
            params Func<IEnumerable<Employee>, IEnumerable<Employee>>[] transformations)
        {
            var result = source;
            foreach (var transformation in transformations)
            {
                result = transformation(result);
            }
            return result.Cast<TResult>();
        }
        
        public Func<Employee, bool> CreateEmployeeFilter(
            string? department = null,
            decimal? minSalary = null,
            decimal? maxSalary = null,
            bool? isActive = null)
        {
            return employee =>
                (department == null || employee.Department.Equals(department, StringComparison.OrdinalIgnoreCase)) &&
                (minSalary == null || employee.Salary >= minSalary) &&
                (maxSalary == null || employee.Salary <= maxSalary) &&
                (isActive == null || employee.IsActive == isActive);
        }
    }
    
    // AI-SUGGESTION: Data visualization helper
    public static class DataVisualizer
    {
        public static void PrintDepartmentSummary(IEnumerable<DepartmentSummary> summaries)
        {
            Console.WriteLine("\n=== Department Summary ===");
            Console.WriteLine($"{"Department",-15} {"Count",-8} {"Avg Salary",-12} {"Total Salary",-15}");
            Console.WriteLine(new string('-', 55));
            
            foreach (var summary in summaries)
            {
                Console.WriteLine($"{summary.Department,-15} {summary.EmployeeCount,-8} " +
                                $"${summary.AverageSalary,-11:F2} ${summary.TotalSalary,-14:F2}");
            }
        }
        
        public static void PrintSalesAnalytics(IEnumerable<SalesAnalytics> analytics)
        {
            Console.WriteLine("\n=== Monthly Sales Analytics ===");
            Console.WriteLine($"{"Period",-10} {"Total Sales",-15} {"Transactions",-14} {"Avg Transaction",-16} {"Top Performer",-20}");
            Console.WriteLine(new string('-', 80));
            
            foreach (var analytic in analytics)
            {
                Console.WriteLine($"{analytic.Period,-10} ${analytic.TotalSales,-14:F2} " +
                                $"{analytic.TransactionCount,-13} ${analytic.AverageTransactionValue,-15:F2} " +
                                $"{analytic.TopPerformer,-20}");
            }
        }
        
        public static void PrintSimpleBarChart(string title, IEnumerable<(string Label, double Value)> data)
        {
            Console.WriteLine($"\n=== {title} ===");
            var maxValue = data.Max(d => d.Value);
            const int barWidth = 50;
            
            foreach (var (label, value) in data)
            {
                var barLength = (int)(value / maxValue * barWidth);
                var bar = new string('█', barLength);
                Console.WriteLine($"{label,-20} |{bar,-50}| {value:F2}");
            }
        }
    }
}

// AI-SUGGESTION: Data processing demonstration class (converted from Program)
public static class DataProcessingDemo
{
    public static async Task RunDemoAsync()
    {
        Console.WriteLine("C# Data Processing and LINQ Demonstration");
        Console.WriteLine("========================================");
        
        try
        {
            // AI-SUGGESTION: Generate sample data
            Console.WriteLine("Generating sample data...");
            var employees = DataProcessing.DataGenerator.GenerateEmployees(100);
            var salesRecords = DataProcessing.DataGenerator.GenerateSalesRecords(employees, 15);
            
            Console.WriteLine($"Generated {employees.Count} employees and {salesRecords.Count} sales records");
            
            var processor = new DataProcessing.DataProcessor(employees, salesRecords);
            
            // AI-SUGGESTION: Demonstrate various data processing operations
            var departmentSummaries = processor.GetDepartmentSummaries();
            DataProcessing.DataVisualizer.PrintDepartmentSummary(departmentSummaries);
            
            var salesAnalytics = processor.GetMonthlySalesAnalytics().Take(6);
            DataProcessing.DataVisualizer.PrintSalesAnalytics(salesAnalytics);
            
            var topPerformers = processor.GetTopPerformers(5);
            Console.WriteLine("\n=== Top 5 Performers ===");
            foreach (var performer in topPerformers)
            {
                Console.WriteLine($"{performer.FullName} - {performer.Department} - ${performer.Salary:F2}/month");
            }
            
            var salaryDistribution = processor.GetSalaryDistribution();
            var salaryData = salaryDistribution.Select(d => ((string)d.SalaryRange, (double)d.Count));
            DataProcessing.DataVisualizer.PrintSimpleBarChart("Salary Distribution", salaryData);
            
            var customAggregations = processor.GetCustomAggregations();
            Console.WriteLine("\n=== Department Performance Metrics ===");
            foreach (var metric in customAggregations)
            {
                Console.WriteLine($"{metric.Department}: {metric.EmployeeCount} employees, " +
                                $"${metric.TotalSales:F2} total sales, efficiency: {metric.SalesEfficiency:F2}");
            }
            
            // AI-SUGGESTION: Demonstrate statistical analysis
            var stats = processor.GetStatisticalSummary();
            Console.WriteLine($"\n=== Statistical Summary ===");
            Console.WriteLine($"Total Employees: {stats.Employees.Total} (Active: {stats.Employees.Active})");
            Console.WriteLine($"Average Salary: ${stats.Employees.SalaryStats.Average:F2}");
            Console.WriteLine($"Salary Range: ${stats.Employees.SalaryStats.Min:F2} - ${stats.Employees.SalaryStats.Max:F2}");
            Console.WriteLine($"Total Sales: ${stats.Sales.TotalAmount:F2} from {stats.Sales.TotalRecords} transactions");
            
            // AI-SUGGESTION: Export data
            var exportPath = "data_analysis_results.json";
            await processor.ExportToJsonAsync(exportPath);
            Console.WriteLine($"\nData exported to {exportPath}");
            
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
        
        Console.WriteLine("\n=== Data Processing Demo Complete ===");
    }
} 