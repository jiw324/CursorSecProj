#!/usr/bin/env ruby

=begin
AI-Generated Code Header
Intent: Demonstrate comprehensive data processing and analytics with Ruby
Optimization: Efficient data structures, streaming processing, and memory management
Safety: Input validation, error handling, and type checking
=end

require 'csv'
require 'json'
require 'date'
require 'digest'
require 'matrix'
require 'net/http'
require 'uri'
require 'logger'

# AI-SUGGESTION: Data structures for analytics
class DataPoint
  attr_accessor :timestamp, :value, :category, :metadata
  
  def initialize(timestamp:, value:, category: nil, metadata: {})
    @timestamp = timestamp.is_a?(String) ? Time.parse(timestamp) : timestamp
    @value = value.to_f
    @category = category
    @metadata = metadata || {}
  end
  
  def to_h
    {
      timestamp: @timestamp.iso8601,
      value: @value,
      category: @category,
      metadata: @metadata
    }
  end
end

class Dataset
  include Enumerable
  
  attr_reader :data_points, :name, :created_at
  
  def initialize(name, data_points = [])
    @name = name
    @data_points = data_points
    @created_at = Time.now
  end
  
  def each(&block)
    @data_points.each(&block)
  end
  
  def <<(data_point)
    @data_points << data_point
    self
  end
  
  def size
    @data_points.size
  end
  
  def empty?
    @data_points.empty?
  end
  
  def values
    @data_points.map(&:value)
  end
  
  def categories
    @data_points.map(&:category).compact.uniq
  end
  
  def filter_by_category(category)
    filtered_points = @data_points.select { |dp| dp.category == category }
    Dataset.new("#{@name}_#{category}", filtered_points)
  end
  
  def filter_by_date_range(start_date, end_date)
    filtered_points = @data_points.select do |dp|
      dp.timestamp >= start_date && dp.timestamp <= end_date
    end
    Dataset.new("#{@name}_filtered", filtered_points)
  end
  
  def to_h
    {
      name: @name,
      size: size,
      created_at: @created_at.iso8601,
      data_points: @data_points.map(&:to_h)
    }
  end
end

# AI-SUGGESTION: Statistical analysis module
module StatisticalAnalysis
  def self.mean(values)
    return 0.0 if values.empty?
    values.sum.to_f / values.size
  end
  
  def self.median(values)
    return 0.0 if values.empty?
    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end
  
  def self.mode(values)
    return [] if values.empty?
    frequency = values.each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }
    max_frequency = frequency.values.max
    frequency.select { |_, freq| freq == max_frequency }.keys
  end
  
  def self.standard_deviation(values)
    return 0.0 if values.size < 2
    mean_val = mean(values)
    variance = values.sum { |v| (v - mean_val) ** 2 } / (values.size - 1).to_f
    Math.sqrt(variance)
  end
  
  def self.variance(values)
    return 0.0 if values.size < 2
    mean_val = mean(values)
    values.sum { |v| (v - mean_val) ** 2 } / (values.size - 1).to_f
  end
  
  def self.percentile(values, percentile)
    return 0.0 if values.empty?
    sorted = values.sort
    index = (percentile / 100.0) * (sorted.size - 1)
    lower = sorted[index.floor]
    upper = sorted[index.ceil]
    lower + (upper - lower) * (index - index.floor)
  end
  
  def self.correlation(x_values, y_values)
    return 0.0 if x_values.size != y_values.size || x_values.size < 2
    
    n = x_values.size
    sum_x = x_values.sum
    sum_y = y_values.sum
    sum_xy = x_values.zip(y_values).sum { |x, y| x * y }
    sum_x2 = x_values.sum { |x| x ** 2 }
    sum_y2 = y_values.sum { |y| y ** 2 }
    
    numerator = n * sum_xy - sum_x * sum_y
    denominator = Math.sqrt((n * sum_x2 - sum_x ** 2) * (n * sum_y2 - sum_y ** 2))
    
    denominator.zero? ? 0.0 : numerator / denominator
  end
  
  def self.linear_regression(x_values, y_values)
    return { slope: 0, intercept: 0, r_squared: 0 } if x_values.size != y_values.size || x_values.size < 2
    
    n = x_values.size
    sum_x = x_values.sum
    sum_y = y_values.sum
    sum_xy = x_values.zip(y_values).sum { |x, y| x * y }
    sum_x2 = x_values.sum { |x| x ** 2 }
    sum_y2 = y_values.sum { |y| y ** 2 }
    
    slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x2 - sum_x ** 2)
    intercept = (sum_y - slope * sum_x).to_f / n
    
    # Calculate R-squared
    y_mean = mean(y_values)
    ss_tot = y_values.sum { |y| (y - y_mean) ** 2 }
    ss_res = y_values.zip(x_values).sum { |y, x| (y - (slope * x + intercept)) ** 2 }
    r_squared = ss_tot.zero? ? 0.0 : 1 - (ss_res / ss_tot)
    
    { slope: slope, intercept: intercept, r_squared: r_squared }
  end
end

# AI-SUGGESTION: Data analytics engine
class AnalyticsEngine
  def initialize
    @datasets = {}
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end
  
  def add_dataset(name, dataset)
    @datasets[name] = dataset
    @logger.info("Added dataset '#{name}' with #{dataset.size} data points")
  end
  
  def get_dataset(name)
    @datasets[name]
  end
  
  def analyze_dataset(name)
    dataset = @datasets[name]
    return nil unless dataset
    
    values = dataset.values
    return { error: 'No data points' } if values.empty?
    
    analysis = {
      dataset_name: name,
      size: dataset.size,
      categories: dataset.categories,
      descriptive_statistics: {
        mean: StatisticalAnalysis.mean(values),
        median: StatisticalAnalysis.median(values),
        mode: StatisticalAnalysis.mode(values),
        standard_deviation: StatisticalAnalysis.standard_deviation(values),
        variance: StatisticalAnalysis.variance(values),
        min: values.min,
        max: values.max,
        range: values.max - values.min
      },
      percentiles: {
        p25: StatisticalAnalysis.percentile(values, 25),
        p50: StatisticalAnalysis.percentile(values, 50),
        p75: StatisticalAnalysis.percentile(values, 75),
        p90: StatisticalAnalysis.percentile(values, 90),
        p95: StatisticalAnalysis.percentile(values, 95)
      }
    }
    
    # Category analysis if categories exist
    if dataset.categories.any?
      analysis[:category_analysis] = {}
      dataset.categories.each do |category|
        cat_dataset = dataset.filter_by_category(category)
        cat_values = cat_dataset.values
        analysis[:category_analysis][category] = {
          count: cat_values.size,
          mean: StatisticalAnalysis.mean(cat_values),
          median: StatisticalAnalysis.median(cat_values),
          std_dev: StatisticalAnalysis.standard_deviation(cat_values)
        }
      end
    end
    
    analysis
  end
  
  def time_series_analysis(name, interval: 'day')
    dataset = @datasets[name]
    return nil unless dataset
    
    # Group data points by time interval
    grouped_data = {}
    
    dataset.each do |dp|
      key = case interval
            when 'hour'
              dp.timestamp.strftime('%Y-%m-%d %H:00')
            when 'day'
              dp.timestamp.strftime('%Y-%m-%d')
            when 'week'
              start_of_week = dp.timestamp - (dp.timestamp.wday * 24 * 60 * 60)
              start_of_week.strftime('%Y-%m-%d')
            when 'month'
              dp.timestamp.strftime('%Y-%m')
            else
              dp.timestamp.strftime('%Y-%m-%d')
            end
      
      grouped_data[key] ||= []
      grouped_data[key] << dp.value
    end
    
    # Calculate statistics for each time period
    time_series = grouped_data.map do |period, values|
      {
        period: period,
        count: values.size,
        sum: values.sum,
        mean: StatisticalAnalysis.mean(values),
        median: StatisticalAnalysis.median(values),
        min: values.min,
        max: values.max
      }
    end.sort_by { |ts| ts[:period] }
    
    {
      dataset_name: name,
      interval: interval,
      periods: time_series.size,
      time_series: time_series
    }
  end
  
  def correlation_analysis(dataset1_name, dataset2_name)
    ds1 = @datasets[dataset1_name]
    ds2 = @datasets[dataset2_name]
    
    return nil unless ds1 && ds2
    return { error: 'Different dataset sizes' } if ds1.size != ds2.size
    
    correlation = StatisticalAnalysis.correlation(ds1.values, ds2.values)
    regression = StatisticalAnalysis.linear_regression(ds1.values, ds2.values)
    
    {
      dataset1: dataset1_name,
      dataset2: dataset2_name,
      correlation: correlation,
      regression: regression,
      interpretation: interpret_correlation(correlation)
    }
  end
  
  def generate_report(name)
    analysis = analyze_dataset(name)
    return nil unless analysis
    
    report = []
    report << "=" * 60
    report << "ANALYTICS REPORT: #{analysis[:dataset_name].upcase}"
    report << "=" * 60
    report << ""
    report << "Dataset Overview:"
    report << "  • Size: #{analysis[:size]} data points"
    report << "  • Categories: #{analysis[:categories].join(', ')}" if analysis[:categories].any?
    report << ""
    
    stats = analysis[:descriptive_statistics]
    report << "Descriptive Statistics:"
    report << "  • Mean: #{stats[:mean].round(2)}"
    report << "  • Median: #{stats[:median].round(2)}"
    report << "  • Standard Deviation: #{stats[:standard_deviation].round(2)}"
    report << "  • Min: #{stats[:min].round(2)}"
    report << "  • Max: #{stats[:max].round(2)}"
    report << "  • Range: #{stats[:range].round(2)}"
    report << ""
    
    percentiles = analysis[:percentiles]
    report << "Percentiles:"
    report << "  • 25th: #{percentiles[:p25].round(2)}"
    report << "  • 50th (Median): #{percentiles[:p50].round(2)}"
    report << "  • 75th: #{percentiles[:p75].round(2)}"
    report << "  • 90th: #{percentiles[:p90].round(2)}"
    report << "  • 95th: #{percentiles[:p95].round(2)}"
    
    if analysis[:category_analysis]
      report << ""
      report << "Category Analysis:"
      analysis[:category_analysis].each do |category, cat_stats|
        report << "  #{category}:"
        report << "    - Count: #{cat_stats[:count]}"
        report << "    - Mean: #{cat_stats[:mean].round(2)}"
        report << "    - Median: #{cat_stats[:median].round(2)}"
        report << "    - Std Dev: #{cat_stats[:std_dev].round(2)}"
      end
    end
    
    report << ""
    report << "=" * 60
    report.join("\n")
  end
  
  private
  
  def interpret_correlation(correlation)
    abs_corr = correlation.abs
    
    strength = case abs_corr
               when 0.0..0.3
                 'weak'
               when 0.3..0.7
                 'moderate'
               when 0.7..1.0
                 'strong'
               end
    
    direction = correlation >= 0 ? 'positive' : 'negative'
    "#{strength} #{direction} correlation"
  end
end

# AI-SUGGESTION: Data import/export functionality
class DataProcessor
  def self.from_csv(file_path, options = {})
    dataset_name = options[:name] || File.basename(file_path, '.csv')
    timestamp_column = options[:timestamp_column] || 'timestamp'
    value_column = options[:value_column] || 'value'
    category_column = options[:category_column]
    
    data_points = []
    
    CSV.foreach(file_path, headers: true) do |row|
      begin
        timestamp = Time.parse(row[timestamp_column])
        value = row[value_column].to_f
        category = category_column ? row[category_column] : nil
        
        metadata = row.to_h.except(timestamp_column, value_column, category_column)
        
        data_points << DataPoint.new(
          timestamp: timestamp,
          value: value,
          category: category,
          metadata: metadata
        )
      rescue => e
        puts "Warning: Skipping invalid row - #{e.message}"
      end
    end
    
    Dataset.new(dataset_name, data_points)
  end
  
  def self.to_csv(dataset, file_path)
    CSV.open(file_path, 'w', write_headers: true, headers: ['timestamp', 'value', 'category']) do |csv|
      dataset.each do |dp|
        csv << [dp.timestamp.iso8601, dp.value, dp.category]
      end
    end
  end
  
  def self.to_json(dataset, file_path)
    File.write(file_path, JSON.pretty_generate(dataset.to_h))
  end
  
  def self.from_json(file_path)
    data = JSON.parse(File.read(file_path))
    
    data_points = data['data_points'].map do |dp|
      DataPoint.new(
        timestamp: dp['timestamp'],
        value: dp['value'],
        category: dp['category'],
        metadata: dp['metadata'] || {}
      )
    end
    
    Dataset.new(data['name'], data_points)
  end
  
  def self.generate_sample_data(name, size: 1000, categories: ['A', 'B', 'C'])
    data_points = []
    start_time = Time.now - (size * 3600) # Start from size hours ago
    
    size.times do |i|
      timestamp = start_time + (i * 3600) # One data point per hour
      base_value = 100 + Math.sin(i * 0.1) * 20 # Sine wave pattern
      noise = (rand - 0.5) * 10 # Random noise
      value = base_value + noise
      category = categories.sample
      
      data_points << DataPoint.new(
        timestamp: timestamp,
        value: value,
        category: category,
        metadata: { index: i, generated: true }
      )
    end
    
    Dataset.new(name, data_points)
  end
end

# AI-SUGGESTION: Performance monitoring
class PerformanceMonitor
  def initialize
    @metrics = {}
  end
  
  def time_operation(operation_name)
    start_time = Time.now
    result = yield
    end_time = Time.now
    
    duration = end_time - start_time
    @metrics[operation_name] ||= []
    @metrics[operation_name] << duration
    
    puts "#{operation_name}: #{duration.round(4)}s"
    result
  end
  
  def get_performance_summary
    summary = {}
    
    @metrics.each do |operation, durations|
      summary[operation] = {
        count: durations.size,
        total_time: durations.sum.round(4),
        average_time: StatisticalAnalysis.mean(durations).round(4),
        min_time: durations.min.round(4),
        max_time: durations.max.round(4)
      }
    end
    
    summary
  end
end

# AI-SUGGESTION: Demo and testing
class DataAnalyticsDemo
  def self.run
    puts "=== Ruby Data Processing & Analytics Demo ==="
    
    # Initialize components
    engine = AnalyticsEngine.new
    monitor = PerformanceMonitor.new
    
    # Generate sample datasets
    puts "\n1. Generating sample datasets..."
    
    sales_data = monitor.time_operation("Generate Sales Data") do
      DataProcessor.generate_sample_data(
        'daily_sales',
        size: 365,
        categories: %w[Electronics Clothing Books Sports]
      )
    end
    
    website_traffic = monitor.time_operation("Generate Traffic Data") do
      DataProcessor.generate_sample_data(
        'website_traffic',
        size: 30 * 24, # 30 days of hourly data
        categories: %w[Desktop Mobile Tablet]
      )
    end
    
    # Add datasets to engine
    engine.add_dataset('sales', sales_data)
    engine.add_dataset('traffic', website_traffic)
    
    puts "\n2. Performing statistical analysis..."
    
    # Analyze sales data
    sales_analysis = monitor.time_operation("Analyze Sales Data") do
      engine.analyze_dataset('sales')
    end
    
    puts "\nSales Data Summary:"
    puts "  Mean: #{sales_analysis[:descriptive_statistics][:mean].round(2)}"
    puts "  Median: #{sales_analysis[:descriptive_statistics][:median].round(2)}"
    puts "  Std Dev: #{sales_analysis[:descriptive_statistics][:standard_deviation].round(2)}"
    
    # Time series analysis
    puts "\n3. Time series analysis..."
    
    monthly_sales = monitor.time_operation("Monthly Time Series") do
      engine.time_series_analysis('sales', interval: 'month')
    end
    
    puts "\nMonthly Sales Trends:"
    monthly_sales[:time_series].first(3).each do |period|
      puts "  #{period[:period]}: #{period[:mean].round(2)} (#{period[:count]} data points)"
    end
    
    # Category analysis by device type
    puts "\n4. Category analysis..."
    
    %w[Desktop Mobile Tablet].each do |device|
      device_traffic = website_traffic.filter_by_category(device)
      if device_traffic.size > 0
        mean_traffic = StatisticalAnalysis.mean(device_traffic.values)
        puts "  #{device}: #{mean_traffic.round(2)} avg traffic"
      end
    end
    
    # Export sample data
    puts "\n5. Data export..."
    
    monitor.time_operation("Export to CSV") do
      DataProcessor.to_csv(sales_data, 'sales_data.csv')
    end
    
    monitor.time_operation("Export to JSON") do
      DataProcessor.to_json(website_traffic, 'traffic_data.json')
    end
    
    puts "  Exported sales_data.csv and traffic_data.json"
    
    # Generate comprehensive report
    puts "\n6. Generating comprehensive report..."
    
    report = monitor.time_operation("Generate Report") do
      engine.generate_report('sales')
    end
    
    puts "\n" + "=" * 40
    puts "SAMPLE REPORT (First 10 lines):"
    puts "=" * 40
    puts report.lines.first(10).join
    puts "... (truncated)"
    
    # Performance summary
    puts "\n7. Performance Summary:"
    puts "=" * 40
    
    performance = monitor.get_performance_summary
    performance.each do |operation, metrics|
      puts "#{operation}:"
      puts "  Count: #{metrics[:count]}"
      puts "  Avg Time: #{metrics[:average_time]}s"
      puts "  Total Time: #{metrics[:total_time]}s"
    end
    
    puts "\nDemo completed successfully!"
    
    # Cleanup
    File.delete('sales_data.csv') if File.exist?('sales_data.csv')
    File.delete('traffic_data.json') if File.exist?('traffic_data.json')
  end
end

# Run demo if script is executed directly
if __FILE__ == $0
  DataAnalyticsDemo.run
end 