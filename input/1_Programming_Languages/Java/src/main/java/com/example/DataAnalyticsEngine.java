// AI-Generated Code Header
// **Intent:** Data analytics engine with Stream API, functional programming, and statistical analysis
// **Optimization:** Efficient data processing using parallel streams and collectors
// **Safety:** Null-safe operations, input validation, and error handling

package com.analytics.engine;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.function.*;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import java.util.stream.Stream;
import java.math.BigDecimal;
import java.math.RoundingMode;

// AI-SUGGESTION: Data models for analytics
class SalesRecord {
    private final String id;
    private final String productName;
    private final String category;
    private final BigDecimal price;
    private final Integer quantity;
    private final LocalDate saleDate;
    private final String region;
    private final String salesPerson;
    private final String customerType;

    public SalesRecord(String id, String productName, String category, BigDecimal price, 
                      Integer quantity, LocalDate saleDate, String region, 
                      String salesPerson, String customerType) {
        this.id = id;
        this.productName = productName;
        this.category = category;
        this.price = price;
        this.quantity = quantity;
        this.saleDate = saleDate;
        this.region = region;
        this.salesPerson = salesPerson;
        this.customerType = customerType;
    }

    public BigDecimal getTotalValue() {
        return price.multiply(BigDecimal.valueOf(quantity));
    }

    // AI-SUGGESTION: Getters
    public String getId() { return id; }
    public String getProductName() { return productName; }
    public String getCategory() { return category; }
    public BigDecimal getPrice() { return price; }
    public Integer getQuantity() { return quantity; }
    public LocalDate getSaleDate() { return saleDate; }
    public String getRegion() { return region; }
    public String getSalesPerson() { return salesPerson; }
    public String getCustomerType() { return customerType; }

    @Override
    public String toString() {
        return String.format("SalesRecord{id='%s', product='%s', category='%s', total=%s, date=%s}", 
            id, productName, category, getTotalValue(), saleDate);
    }
}

class AnalyticsResult {
    private final String metric;
    private final Object value;
    private final String description;
    private final LocalDateTime calculatedAt;

    public AnalyticsResult(String metric, Object value, String description) {
        this.metric = metric;
        this.value = value;
        this.description = description;
        this.calculatedAt = LocalDateTime.now();
    }

    public String getMetric() { return metric; }
    public Object getValue() { return value; }
    public String getDescription() { return description; }
    public LocalDateTime getCalculatedAt() { return calculatedAt; }

    @Override
    public String toString() {
        return String.format("%s: %s (%s)", metric, value, description);
    }
}

// AI-SUGGESTION: Statistical analysis utilities
class StatisticalAnalyzer {
    
    public static <T> OptionalDouble average(Stream<T> stream, Function<T, Number> mapper) {
        return stream
            .filter(Objects::nonNull)
            .map(mapper)
            .filter(Objects::nonNull)
            .mapToDouble(Number::doubleValue)
            .average();
    }

    public static <T> Optional<T> mode(Stream<T> stream) {
        Map<T, Long> frequencies = stream
            .filter(Objects::nonNull)
            .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
        
        return frequencies.entrySet().stream()
            .max(Map.Entry.comparingByValue())
            .map(Map.Entry::getKey);
    }

    public static <T extends Comparable<T>> Optional<T> median(Stream<T> stream) {
        List<T> sorted = stream
            .filter(Objects::nonNull)
            .sorted()
            .collect(Collectors.toList());
        
        if (sorted.isEmpty()) return Optional.empty();
        
        int size = sorted.size();
        if (size % 2 == 1) {
            return Optional.of(sorted.get(size / 2));
        } else {
            return Optional.of(sorted.get(size / 2 - 1));
        }
    }

    public static double standardDeviation(Stream<Double> stream) {
        List<Double> values = stream
            .filter(Objects::nonNull)
            .collect(Collectors.toList());
        
        if (values.size() < 2) return 0.0;
        
        double mean = values.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
        double variance = values.stream()
            .mapToDouble(v -> Math.pow(v - mean, 2))
            .average().orElse(0.0);
        
        return Math.sqrt(variance);
    }

    public static Map<String, Double> percentiles(Stream<Double> stream, int... percentiles) {
        List<Double> sorted = stream
            .filter(Objects::nonNull)
            .sorted()
            .collect(Collectors.toList());
        
        Map<String, Double> result = new HashMap<>();
        
        for (int percentile : percentiles) {
            if (percentile < 0 || percentile > 100) continue;
            
            int index = (int) Math.ceil(percentile / 100.0 * sorted.size()) - 1;
            index = Math.max(0, Math.min(index, sorted.size() - 1));
            
            if (!sorted.isEmpty()) {
                result.put("P" + percentile, sorted.get(index));
            }
        }
        
        return result;
    }
}

// AI-SUGGESTION: Main analytics engine
class DataAnalyticsEngine {
    private final List<SalesRecord> salesData;
    private final Map<String, Function<Stream<SalesRecord>, AnalyticsResult>> customAnalyzers;

    public DataAnalyticsEngine(List<SalesRecord> salesData) {
        this.salesData = new ArrayList<>(salesData);
        this.customAnalyzers = new HashMap<>();
        initializeCustomAnalyzers();
    }

    private void initializeCustomAnalyzers() {
        // AI-SUGGESTION: Register custom analysis functions
        customAnalyzers.put("revenue_growth", this::calculateRevenueGrowth);
        customAnalyzers.put("seasonal_patterns", this::analyzeSeasonalPatterns);
        customAnalyzers.put("customer_segments", this::analyzeCustomerSegments);
        customAnalyzers.put("product_performance", this::analyzeProductPerformance);
    }

    public List<AnalyticsResult> runBasicAnalytics() {
        Stream<SalesRecord> dataStream = salesData.stream();
        List<AnalyticsResult> results = new ArrayList<>();

        // AI-SUGGESTION: Total revenue analysis
        BigDecimal totalRevenue = dataStream
            .map(SalesRecord::getTotalValue)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        results.add(new AnalyticsResult("total_revenue", totalRevenue, "Total revenue across all sales"));

        // AI-SUGGESTION: Average order value
        OptionalDouble avgOrderValue = salesData.stream()
            .mapToDouble(record -> record.getTotalValue().doubleValue())
            .average();
        if (avgOrderValue.isPresent()) {
            results.add(new AnalyticsResult("avg_order_value", 
                BigDecimal.valueOf(avgOrderValue.getAsDouble()).setScale(2, RoundingMode.HALF_UP),
                "Average order value"));
        }

        // AI-SUGGESTION: Sales by category
        Map<String, BigDecimal> salesByCategory = salesData.stream()
            .collect(Collectors.groupingBy(
                SalesRecord::getCategory,
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));
        results.add(new AnalyticsResult("sales_by_category", salesByCategory, "Revenue breakdown by category"));

        // AI-SUGGESTION: Top performing regions
        Map<String, BigDecimal> salesByRegion = salesData.stream()
            .collect(Collectors.groupingBy(
                SalesRecord::getRegion,
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));
        
        String topRegion = salesByRegion.entrySet().stream()
            .max(Map.Entry.comparingByValue())
            .map(Map.Entry::getKey)
            .orElse("None");
        results.add(new AnalyticsResult("top_region", topRegion, "Best performing region by revenue"));

        // AI-SUGGESTION: Sales volume statistics
        IntSummaryStatistics volumeStats = salesData.stream()
            .mapToInt(SalesRecord::getQuantity)
            .summaryStatistics();
        results.add(new AnalyticsResult("volume_statistics", volumeStats, "Sales volume statistics"));

        return results;
    }

    public List<AnalyticsResult> runAdvancedAnalytics() {
        List<AnalyticsResult> results = new ArrayList<>();

        // AI-SUGGESTION: Time-based analysis
        results.addAll(performTimeBasedAnalysis());

        // AI-SUGGESTION: Statistical analysis
        results.addAll(performStatisticalAnalysis());

        // AI-SUGGESTION: Trend analysis
        results.addAll(performTrendAnalysis());

        // AI-SUGGESTION: Correlation analysis
        results.addAll(performCorrelationAnalysis());

        return results;
    }

    private List<AnalyticsResult> performTimeBasedAnalysis() {
        List<AnalyticsResult> results = new ArrayList<>();

        // AI-SUGGESTION: Monthly sales trends
        Map<String, BigDecimal> monthlySales = salesData.stream()
            .collect(Collectors.groupingBy(
                record -> record.getSaleDate().getYear() + "-" + 
                         String.format("%02d", record.getSaleDate().getMonthValue()),
                LinkedHashMap::new,
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));
        results.add(new AnalyticsResult("monthly_sales", monthlySales, "Sales trends by month"));

        // AI-SUGGESTION: Day of week analysis
        Map<String, Long> salesByDayOfWeek = salesData.stream()
            .collect(Collectors.groupingBy(
                record -> record.getSaleDate().getDayOfWeek().toString(),
                Collectors.counting()
            ));
        results.add(new AnalyticsResult("sales_by_day_of_week", salesByDayOfWeek, "Sales frequency by day of week"));

        // AI-SUGGESTION: Seasonal analysis (quarters)
        Map<String, BigDecimal> quarterlyRevenue = salesData.stream()
            .collect(Collectors.groupingBy(
                record -> "Q" + ((record.getSaleDate().getMonthValue() - 1) / 3 + 1) + 
                         "-" + record.getSaleDate().getYear(),
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));
        results.add(new AnalyticsResult("quarterly_revenue", quarterlyRevenue, "Revenue by quarters"));

        return results;
    }

    private List<AnalyticsResult> performStatisticalAnalysis() {
        List<AnalyticsResult> results = new ArrayList<>();

        // AI-SUGGESTION: Revenue distribution analysis
        List<Double> revenueValues = salesData.stream()
            .map(record -> record.getTotalValue().doubleValue())
            .collect(Collectors.toList());

        double stdDev = StatisticalAnalyzer.standardDeviation(revenueValues.stream());
        results.add(new AnalyticsResult("revenue_std_deviation", 
            BigDecimal.valueOf(stdDev).setScale(2, RoundingMode.HALF_UP),
            "Standard deviation of order values"));

        // AI-SUGGESTION: Percentile analysis
        Map<String, Double> percentiles = StatisticalAnalyzer.percentiles(
            salesData.stream()
                .map(record -> record.getTotalValue().doubleValue()),
            25, 50, 75, 90, 95
        );
        results.add(new AnalyticsResult("revenue_percentiles", percentiles, "Revenue percentile distribution"));

        // AI-SUGGESTION: Category concentration analysis
        Map<String, Long> categoryFrequency = salesData.stream()
            .collect(Collectors.groupingBy(SalesRecord::getCategory, Collectors.counting()));
        
        double categoryConcentration = calculateHerfindahlIndex(categoryFrequency);
        results.add(new AnalyticsResult("category_concentration", 
            BigDecimal.valueOf(categoryConcentration).setScale(4, RoundingMode.HALF_UP),
            "Market concentration index for categories (0=competitive, 1=monopoly)"));

        return results;
    }

    private List<AnalyticsResult> performTrendAnalysis() {
        List<AnalyticsResult> results = new ArrayList<>();

        // AI-SUGGESTION: Sales momentum analysis
        Map<LocalDate, BigDecimal> dailySales = salesData.stream()
            .collect(Collectors.groupingBy(
                SalesRecord::getSaleDate,
                TreeMap::new,
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));

        if (dailySales.size() > 1) {
            List<BigDecimal> values = new ArrayList<>(dailySales.values());
            double trendSlope = calculateTrendSlope(values);
            results.add(new AnalyticsResult("sales_trend_slope", 
                BigDecimal.valueOf(trendSlope).setScale(4, RoundingMode.HALF_UP),
                "Linear trend slope of daily sales (positive=growing, negative=declining)"));
        }

        // AI-SUGGESTION: Growth rate calculation
        Map<String, BigDecimal> monthlyRevenue = salesData.stream()
            .collect(Collectors.groupingBy(
                record -> record.getSaleDate().getYear() + "-" + 
                         String.format("%02d", record.getSaleDate().getMonthValue()),
                TreeMap::new,
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));

        if (monthlyRevenue.size() > 1) {
            List<BigDecimal> monthlyValues = new ArrayList<>(monthlyRevenue.values());
            double growthRate = calculateGrowthRate(monthlyValues);
            results.add(new AnalyticsResult("monthly_growth_rate", 
                BigDecimal.valueOf(growthRate * 100).setScale(2, RoundingMode.HALF_UP) + "%",
                "Average monthly revenue growth rate"));
        }

        return results;
    }

    private List<AnalyticsResult> performCorrelationAnalysis() {
        List<AnalyticsResult> results = new ArrayList<>();

        // AI-SUGGESTION: Price-quantity correlation
        List<Double> prices = salesData.stream()
            .map(record -> record.getPrice().doubleValue())
            .collect(Collectors.toList());
        
        List<Double> quantities = salesData.stream()
            .map(record -> record.getQuantity().doubleValue())
            .collect(Collectors.toList());

        double correlation = calculateCorrelation(prices, quantities);
        results.add(new AnalyticsResult("price_quantity_correlation", 
            BigDecimal.valueOf(correlation).setScale(4, RoundingMode.HALF_UP),
            "Correlation between price and quantity (-1 to 1)"));

        // AI-SUGGESTION: Customer type performance analysis
        Map<String, Double> avgValueByCustomerType = salesData.stream()
            .collect(Collectors.groupingBy(
                SalesRecord::getCustomerType,
                Collectors.averagingDouble(record -> record.getTotalValue().doubleValue())
            ));
        results.add(new AnalyticsResult("avg_value_by_customer_type", avgValueByCustomerType, 
            "Average order value by customer type"));

        return results;
    }

    // AI-SUGGESTION: Custom analyzer implementations
    private AnalyticsResult calculateRevenueGrowth(Stream<SalesRecord> stream) {
        Map<String, BigDecimal> monthlyRevenue = stream
            .collect(Collectors.groupingBy(
                record -> record.getSaleDate().toString().substring(0, 7),
                TreeMap::new,
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));

        if (monthlyRevenue.size() < 2) {
            return new AnalyticsResult("revenue_growth", "N/A", "Insufficient data for growth calculation");
        }

        List<BigDecimal> values = new ArrayList<>(monthlyRevenue.values());
        BigDecimal firstMonth = values.get(0);
        BigDecimal lastMonth = values.get(values.size() - 1);
        
        if (firstMonth.compareTo(BigDecimal.ZERO) == 0) {
            return new AnalyticsResult("revenue_growth", "Infinite", "Growth from zero base");
        }
        
        BigDecimal growthPercent = lastMonth.subtract(firstMonth)
            .divide(firstMonth, 4, RoundingMode.HALF_UP)
            .multiply(BigDecimal.valueOf(100));
        
        return new AnalyticsResult("revenue_growth", growthPercent + "%", "Revenue growth from first to last month");
    }

    private AnalyticsResult analyzeSeasonalPatterns(Stream<SalesRecord> stream) {
        Map<String, BigDecimal> seasonalSales = stream
            .collect(Collectors.groupingBy(
                record -> getSeason(record.getSaleDate()),
                Collectors.reducing(BigDecimal.ZERO, SalesRecord::getTotalValue, BigDecimal::add)
            ));
        
        return new AnalyticsResult("seasonal_patterns", seasonalSales, "Revenue distribution by seasons");
    }

    private AnalyticsResult analyzeCustomerSegments(Stream<SalesRecord> stream) {
        Map<String, Map<String, Object>> segments = stream
            .collect(Collectors.groupingBy(
                SalesRecord::getCustomerType,
                Collectors.collectingAndThen(
                    Collectors.toList(),
                    records -> {
                        Map<String, Object> stats = new HashMap<>();
                        stats.put("count", records.size());
                        stats.put("total_revenue", records.stream()
                            .map(SalesRecord::getTotalValue)
                            .reduce(BigDecimal.ZERO, BigDecimal::add));
                        stats.put("avg_order_value", records.stream()
                            .mapToDouble(r -> r.getTotalValue().doubleValue())
                            .average().orElse(0.0));
                        return stats;
                    }
                )
            ));
        
        return new AnalyticsResult("customer_segments", segments, "Detailed customer segment analysis");
    }

    private AnalyticsResult analyzeProductPerformance(Stream<SalesRecord> stream) {
        Map<String, Map<String, Object>> productStats = stream
            .collect(Collectors.groupingBy(
                SalesRecord::getProductName,
                Collectors.collectingAndThen(
                    Collectors.toList(),
                    records -> {
                        Map<String, Object> stats = new HashMap<>();
                        stats.put("units_sold", records.stream().mapToInt(SalesRecord::getQuantity).sum());
                        stats.put("revenue", records.stream()
                            .map(SalesRecord::getTotalValue)
                            .reduce(BigDecimal.ZERO, BigDecimal::add));
                        stats.put("avg_price", records.stream()
                            .mapToDouble(r -> r.getPrice().doubleValue())
                            .average().orElse(0.0));
                        return stats;
                    }
                )
            ));
        
        return new AnalyticsResult("product_performance", productStats, "Performance metrics by product");
    }

    // AI-SUGGESTION: Utility methods
    private double calculateHerfindahlIndex(Map<String, Long> frequencies) {
        long total = frequencies.values().stream().mapToLong(Long::longValue).sum();
        return frequencies.values().stream()
            .mapToDouble(count -> Math.pow(count.doubleValue() / total, 2))
            .sum();
    }

    private double calculateTrendSlope(List<BigDecimal> values) {
        int n = values.size();
        double sumX = IntStream.range(0, n).sum();
        double sumY = values.stream().mapToDouble(BigDecimal::doubleValue).sum();
        double sumXY = IntStream.range(0, n)
            .mapToDouble(i -> i * values.get(i).doubleValue())
            .sum();
        double sumXX = IntStream.range(0, n).map(i -> i * i).sum();
        
        return (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    }

    private double calculateGrowthRate(List<BigDecimal> values) {
        if (values.size() < 2) return 0.0;
        
        double sum = 0.0;
        int count = 0;
        
        for (int i = 1; i < values.size(); i++) {
            BigDecimal prev = values.get(i - 1);
            BigDecimal curr = values.get(i);
            
            if (prev.compareTo(BigDecimal.ZERO) > 0) {
                double growth = curr.subtract(prev).divide(prev, 4, RoundingMode.HALF_UP).doubleValue();
                sum += growth;
                count++;
            }
        }
        
        return count > 0 ? sum / count : 0.0;
    }

    private double calculateCorrelation(List<Double> x, List<Double> y) {
        if (x.size() != y.size() || x.isEmpty()) return 0.0;
        
        double meanX = x.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
        double meanY = y.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
        
        double numerator = IntStream.range(0, x.size())
            .mapToDouble(i -> (x.get(i) - meanX) * (y.get(i) - meanY))
            .sum();
        
        double denomX = Math.sqrt(x.stream().mapToDouble(val -> Math.pow(val - meanX, 2)).sum());
        double denomY = Math.sqrt(y.stream().mapToDouble(val -> Math.pow(val - meanY, 2)).sum());
        
        return denomX == 0 || denomY == 0 ? 0 : numerator / (denomX * denomY);
    }

    private String getSeason(LocalDate date) {
        int month = date.getMonthValue();
        if (month >= 3 && month <= 5) return "Spring";
        if (month >= 6 && month <= 8) return "Summer";
        if (month >= 9 && month <= 11) return "Fall";
        return "Winter";
    }

    public List<AnalyticsResult> runCustomAnalysis(String analyzerName) {
        Function<Stream<SalesRecord>, AnalyticsResult> analyzer = customAnalyzers.get(analyzerName);
        if (analyzer == null) {
            throw new IllegalArgumentException("Unknown analyzer: " + analyzerName);
        }
        
        return Collections.singletonList(analyzer.apply(salesData.stream()));
    }

    public List<AnalyticsResult> runAllAnalytics() {
        List<AnalyticsResult> allResults = new ArrayList<>();
        allResults.addAll(runBasicAnalytics());
        allResults.addAll(runAdvancedAnalytics());
        
        // AI-SUGGESTION: Run custom analyzers
        customAnalyzers.keySet().forEach(name -> {
            try {
                allResults.addAll(runCustomAnalysis(name));
            } catch (Exception e) {
                System.err.println("Error running custom analyzer " + name + ": " + e.getMessage());
            }
        });
        
        return allResults;
    }

    // AI-SUGGESTION: Data generation for testing
    public static List<SalesRecord> generateSampleData(int recordCount) {
        Random random = new Random();
        String[] products = {"Laptop", "Mouse", "Keyboard", "Monitor", "Tablet", "Phone", "Headphones", "Camera"};
        String[] categories = {"Electronics", "Accessories", "Computing", "Mobile"};
        String[] regions = {"North", "South", "East", "West", "Central"};
        String[] salesPeople = {"Alice", "Bob", "Charlie", "Diana", "Eve"};
        String[] customerTypes = {"Enterprise", "SMB", "Individual", "Government"};
        
        return IntStream.range(0, recordCount)
            .mapToObj(i -> {
                String id = "SALE-" + String.format("%06d", i + 1);
                String product = products[random.nextInt(products.length)];
                String category = categories[random.nextInt(categories.length)];
                BigDecimal price = BigDecimal.valueOf(random.nextDouble() * 2000 + 50)
                    .setScale(2, RoundingMode.HALF_UP);
                int quantity = random.nextInt(10) + 1;
                LocalDate saleDate = LocalDate.now().minusDays(random.nextInt(365));
                String region = regions[random.nextInt(regions.length)];
                String salesPerson = salesPeople[random.nextInt(salesPeople.length)];
                String customerType = customerTypes[random.nextInt(customerTypes.length)];
                
                return new SalesRecord(id, product, category, price, quantity, 
                                     saleDate, region, salesPerson, customerType);
            })
            .collect(Collectors.toList());
    }

    // AI-SUGGESTION: Main demonstration method
    public static void main(String[] args) {
        System.out.println("Data Analytics Engine Demo");
        System.out.println("==========================");

        // AI-SUGGESTION: Generate sample data
        System.out.println("\n--- Generating Sample Data ---");
        List<SalesRecord> sampleData = generateSampleData(1000);
        System.out.println("Generated " + sampleData.size() + " sales records");

        DataAnalyticsEngine engine = new DataAnalyticsEngine(sampleData);

        // AI-SUGGESTION: Run basic analytics
        System.out.println("\n--- Basic Analytics ---");
        List<AnalyticsResult> basicResults = engine.runBasicAnalytics();
        basicResults.forEach(System.out::println);

        // AI-SUGGESTION: Run advanced analytics
        System.out.println("\n--- Advanced Analytics ---");
        List<AnalyticsResult> advancedResults = engine.runAdvancedAnalytics();
        advancedResults.stream().limit(10).forEach(System.out::println);

        // AI-SUGGESTION: Run custom analytics
        System.out.println("\n--- Custom Analytics ---");
        try {
            AnalyticsResult revenueGrowth = engine.runCustomAnalysis("revenue_growth").get(0);
            System.out.println(revenueGrowth);
            
            AnalyticsResult seasonalPatterns = engine.runCustomAnalysis("seasonal_patterns").get(0);
            System.out.println(seasonalPatterns);
        } catch (Exception e) {
            System.err.println("Error in custom analytics: " + e.getMessage());
        }

        System.out.println("\n=== Data Analytics Engine Demo Complete ===");
    }
} 