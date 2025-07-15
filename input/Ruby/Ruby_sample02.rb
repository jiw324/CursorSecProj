#!/usr/bin/env ruby

require 'fileutils'
require 'find'
require 'digest'
require 'net/http'
require 'uri'
require 'json'
require 'logger'
require 'yaml'
require 'csv'
require 'open3'

class FileSystemAutomator
  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
  end

  def organize_files_by_extension(source_dir, target_dir)
    @logger.info("Organizing files from #{source_dir} to #{target_dir}")
    
    FileUtils.mkdir_p(target_dir)
    organized_count = 0

    Find.find(source_dir) do |path|
      next if File.directory?(path)
      
      extension = File.extname(path).downcase
      extension = 'no_extension' if extension.empty?
      
      target_subdir = File.join(target_dir, extension[1..-1] || 'no_extension')
      FileUtils.mkdir_p(target_subdir)
      
      filename = File.basename(path)
      target_path = File.join(target_subdir, filename)
      
      counter = 1
      while File.exist?(target_path)
        name_without_ext = File.basename(filename, extension)
        target_path = File.join(target_subdir, "#{name_without_ext}_#{counter}#{extension}")
        counter += 1
      end
      
      FileUtils.cp(path, target_path)
      organized_count += 1
      @logger.debug("Moved #{filename} to #{target_subdir}")
    end

    @logger.info("Organized #{organized_count} files")
    organized_count
  end

  def find_duplicate_files(directory)
    @logger.info("Finding duplicate files in #{directory}")
    
    file_hashes = {}
    duplicates = []

    Find.find(directory) do |path|
      next if File.directory?(path)
      
      begin
        hash = Digest::MD5.file(path).hexdigest
        size = File.size(path)
        key = "#{hash}_#{size}"
        
        if file_hashes[key]
          duplicates << [file_hashes[key], path]
          @logger.debug("Duplicate found: #{path}")
        else
          file_hashes[key] = path
        end
      rescue => e
        @logger.error("Error processing #{path}: #{e.message}")
      end
    end

    @logger.info("Found #{duplicates.size} duplicate pairs")
    duplicates
  end

  def cleanup_old_files(directory, days_old = 30)
    @logger.info("Cleaning up files older than #{days_old} days in #{directory}")
    
    cutoff_time = Time.now - (days_old * 24 * 60 * 60)
    deleted_count = 0

    Find.find(directory) do |path|
      next if File.directory?(path)
      
      begin
        if File.mtime(path) < cutoff_time
          File.delete(path)
          deleted_count += 1
          @logger.debug("Deleted old file: #{path}")
        end
      rescue => e
        @logger.error("Error deleting #{path}: #{e.message}")
      end
    end

    @logger.info("Deleted #{deleted_count} old files")
    deleted_count
  end

  def backup_directory(source_dir, backup_dir, compress: true)
    @logger.info("Backing up #{source_dir} to #{backup_dir}")
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_name = "backup_#{File.basename(source_dir)}_#{timestamp}"
    
    if compress
      backup_path = File.join(backup_dir, "#{backup_name}.tar.gz")
      FileUtils.mkdir_p(backup_dir)
      
      system("tar -czf '#{backup_path}' -C '#{File.dirname(source_dir)}' '#{File.basename(source_dir)}'")
      @logger.info("Compressed backup created: #{backup_path}")
    else
      backup_path = File.join(backup_dir, backup_name)
      FileUtils.cp_r(source_dir, backup_path)
      @logger.info("Directory backup created: #{backup_path}")
    end

    backup_path
  end
end

class SystemMonitor
  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
  end

  def get_system_info
    info = {}
    
    cpu_info = `top -l 1 | grep "CPU usage"`.strip rescue "Unknown"
    info[:cpu] = cpu_info
    
    memory_info = `vm_stat | head -10`.strip rescue "Unknown"
    info[:memory] = memory_info
    
    disk_info = `df -h`.strip rescue "Unknown"
    info[:disk] = disk_info
    
    load_info = `uptime`.strip rescue "Unknown"
    info[:load] = load_info
    
    network_info = `ifconfig | grep -E '^[a-z]|inet '`.strip rescue "Unknown"
    info[:network] = network_info
    
    info[:timestamp] = Time.now.iso8601
    info
  end

  def monitor_processes(process_names = [])
    @logger.info("Monitoring processes: #{process_names.join(', ')}")
    
    running_processes = {}
    
    process_names.each do |process_name|
      output = `pgrep -f #{process_name}`.strip
      pids = output.split("\n").reject(&:empty?)
      
      running_processes[process_name] = {
        running: !pids.empty?,
        pid_count: pids.size,
        pids: pids
      }
      
      @logger.debug("Process #{process_name}: #{pids.size} instances")
    end

    running_processes
  end

  def check_disk_space(threshold_percent = 80)
    @logger.info("Checking disk space (threshold: #{threshold_percent}%)")
    
    alerts = []
    
    `df -h`.lines[1..-1].each do |line|
      parts = line.split
      next if parts.size < 5
      
      filesystem = parts[0]
      usage_percent = parts[4].to_i
      mount_point = parts[5]
      
      if usage_percent > threshold_percent
        alert = {
          filesystem: filesystem,
          mount_point: mount_point,
          usage_percent: usage_percent,
          severity: usage_percent > 90 ? 'critical' : 'warning'
        }
        alerts << alert
        @logger.warn("Disk space alert: #{mount_point} at #{usage_percent}%")
      end
    end

    alerts
  end

  def generate_system_report
    @logger.info("Generating system report")
    
    report = {
      timestamp: Time.now.iso8601,
      system_info: get_system_info,
      disk_alerts: check_disk_space,
      hostname: `hostname`.strip,
      uptime: `uptime`.strip,
      users: `who`.strip.split("\n")
    }

    report
  end
end

class LogAnalyzer
  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
  end

  def analyze_access_log(log_file_path)
    @logger.info("Analyzing access log: #{log_file_path}")
    
    stats = {
      total_requests: 0,
      unique_ips: Set.new,
      status_codes: Hash.new(0),
      popular_pages: Hash.new(0),
      user_agents: Hash.new(0),
      hourly_traffic: Hash.new(0),
      top_ips: Hash.new(0)
    }

    File.foreach(log_file_path) do |line|
      if match = line.match(/^(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+) \S+" (\d+) \S+ "([^"]*)" "([^"]*)"/)
        ip, timestamp, method, url, status, referer, user_agent = match.captures
        
        stats[:total_requests] += 1
        stats[:unique_ips] << ip
        stats[:status_codes][status] += 1
        stats[:popular_pages][url] += 1
        stats[:user_agents][user_agent] += 1
        stats[:top_ips][ip] += 1
        
        if time_match = timestamp.match(/\d{2}\/\w{3}\/\d{4}:(\d{2})/)
          hour = time_match[1]
          stats[:hourly_traffic][hour] += 1
        end
      end
    end

    stats[:unique_ips] = stats[:unique_ips].size
    stats[:top_pages] = stats[:popular_pages].sort_by { |_, count| -count }.first(10).to_h
    stats[:top_user_agents] = stats[:user_agents].sort_by { |_, count| -count }.first(5).to_h
    stats[:top_ips] = stats[:top_ips].sort_by { |_, count| -count }.first(10).to_h

    @logger.info("Analyzed #{stats[:total_requests]} requests from #{stats[:unique_ips]} unique IPs")
    stats
  end

  def find_errors_in_log(log_file_path, error_patterns = ['ERROR', 'FATAL', 'Exception'])
    @logger.info("Finding errors in log: #{log_file_path}")
    
    errors = []
    line_number = 0

    File.foreach(log_file_path) do |line|
      line_number += 1
      
      error_patterns.each do |pattern|
        if line.include?(pattern)
          errors << {
            line_number: line_number,
            pattern: pattern,
            content: line.strip,
            timestamp: extract_timestamp(line)
          }
          break
        end
      end
    end

    @logger.info("Found #{errors.size} error lines")
    errors
  end

  private

  def extract_timestamp(line)
    patterns = [
      /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/,
      /\[\d{2}\/\w{3}\/\d{4}:\d{2}:\d{2}:\d{2}/,
      /\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}/
    ]
    
    patterns.each do |pattern|
      match = line.match(pattern)
      return match[0] if match
    end
    
    nil
  end
end

class ConfigManager
  def initialize(config_dir = './config')
    @config_dir = config_dir
    @configs = {}
    @logger = Logger.new(STDOUT)
    
    FileUtils.mkdir_p(@config_dir)
    load_all_configs
  end

  def load_all_configs
    Dir.glob(File.join(@config_dir, '*.{yml,yaml,json}')).each do |file|
      name = File.basename(file, File.extname(file))
      load_config(name)
    end
  end

  def load_config(name)
    file_path = find_config_file(name)
    return nil unless file_path

    begin
      case File.extname(file_path).downcase
      when '.yml', '.yaml'
        @configs[name] = YAML.load_file(file_path)
      when '.json'
        @configs[name] = JSON.parse(File.read(file_path))
      end
      
      @logger.info("Loaded config: #{name}")
      @configs[name]
    rescue => e
      @logger.error("Failed to load config #{name}: #{e.message}")
      nil
    end
  end

  def save_config(name, config)
    file_path = File.join(@config_dir, "#{name}.yml")
    
    begin
      File.write(file_path, config.to_yaml)
      @configs[name] = config
      @logger.info("Saved config: #{name}")
      true
    rescue => e
      @logger.error("Failed to save config #{name}: #{e.message}")
      false
    end
  end

  def get_config(name, key = nil)
    config = @configs[name]
    return nil unless config
    
    if key
      key.split('.').reduce(config) { |c, k| c&.dig(k) }
    else
      config
    end
  end

  def update_config(name, key, value)
    return false unless @configs[name]
    
    keys = key.split('.')
    target = keys[0..-2].reduce(@configs[name]) { |c, k| c[k] ||= {} }
    target[keys.last] = value
    
    save_config(name, @configs[name])
  end

  private

  def find_config_file(name)
    %w[.yml .yaml .json].each do |ext|
      file_path = File.join(@config_dir, "#{name}#{ext}")
      return file_path if File.exist?(file_path)
    end
    nil
  end
end

class TaskScheduler
  def initialize
    @tasks = []
    @running = false
    @logger = Logger.new(STDOUT)
  end

  def schedule_task(name, interval_seconds, &block)
    task = {
      name: name,
      interval: interval_seconds,
      block: block,
      last_run: nil,
      next_run: Time.now + interval_seconds
    }
    
    @tasks << task
    @logger.info("Scheduled task: #{name} (every #{interval_seconds}s)")
  end

  def start
    @running = true
    @logger.info("Task scheduler started")
    
    while @running
      current_time = Time.now
      
      @tasks.each do |task|
        if current_time >= task[:next_run]
          begin
            @logger.info("Running task: #{task[:name]}")
            task[:block].call
            task[:last_run] = current_time
            task[:next_run] = current_time + task[:interval]
          rescue => e
            @logger.error("Task #{task[:name]} failed: #{e.message}")
          end
        end
      end
      
      sleep(1)
    end
  end

  def stop
    @running = false
    @logger.info("Task scheduler stopped")
  end

  def get_task_status
    @tasks.map do |task|
      {
        name: task[:name],
        interval: task[:interval],
        last_run: task[:last_run]&.iso8601,
        next_run: task[:next_run].iso8601,
        overdue: Time.now > task[:next_run]
      }
    end
  end
end

class AutomationDemo
  def self.run
    puts "=== Ruby Automation Scripts Demo ==="
    
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    
    puts "\n1. Setting up demo environment..."
    
    FileUtils.mkdir_p('demo_files')
    FileUtils.mkdir_p('demo_backup')
    
    %w[.txt .log .csv .json .rb].each_with_index do |ext, i|
      3.times do |j|
        filename = "demo_files/sample_#{i}_#{j}#{ext}"
        File.write(filename, "Sample content #{i}-#{j}\nTimestamp: #{Time.now}")
      end
    end
    
    puts "\n2. File System Automation Demo..."
    
    fs_automator = FileSystemAutomator.new(logger)
    
    organized_count = fs_automator.organize_files_by_extension('demo_files', 'organized_files')
    puts "   Organized #{organized_count} files by extension"
    
    duplicates = fs_automator.find_duplicate_files('demo_files')
    puts "   Found #{duplicates.size} duplicate file pairs"
    
    backup_path = fs_automator.backup_directory('demo_files', 'demo_backup', compress: false)
    puts "   Created backup: #{backup_path}"
    
    puts "\n3. System Monitoring Demo..."
    
    monitor = SystemMonitor.new(logger)
    
    system_info = monitor.get_system_info
    puts "   System timestamp: #{system_info[:timestamp]}"
    puts "   Load average: #{system_info[:load]}"
    
    disk_alerts = monitor.check_disk_space(50)
    puts "   Disk space alerts: #{disk_alerts.size}"
    
    puts "\n4. Configuration Management Demo..."
    
    config_manager = ConfigManager.new('./demo_config')
    
    sample_config = {
      'app' => {
        'name' => 'Demo App',
        'version' => '1.0.0',
        'database' => {
          'host' => 'localhost',
          'port' => 5432
        }
      }
    }
    
    config_manager.save_config('app', sample_config)
    puts "   Saved sample configuration"
    
    app_name = config_manager.get_config('app', 'app.name')
    db_port = config_manager.get_config('app', 'app.database.port')
    puts "   App name: #{app_name}, DB port: #{db_port}"
    
    puts "\n5. Task Scheduler Demo..."
    
    scheduler = TaskScheduler.new
    
    scheduler.schedule_task('log_time', 2) do
      puts "     [Task] Current time: #{Time.now}"
    end
    
    scheduler.schedule_task('check_memory', 5) do
      puts "     [Task] Memory check completed"
    end
    
    puts "   Running scheduler for 10 seconds..."
    
    scheduler_thread = Thread.new { scheduler.start }
    sleep(10)
    scheduler.stop
    scheduler_thread.join
    
    task_status = scheduler.get_task_status
    puts "   Task status: #{task_status.size} tasks tracked"
    
    puts "\n6. Cleanup..."
    
    FileUtils.rm_rf('demo_files')
    FileUtils.rm_rf('organized_files')
    FileUtils.rm_rf('demo_backup')
    FileUtils.rm_rf('demo_config')
    
    puts "   Demo environment cleaned up"
    puts "\nAutomation demo completed successfully!"
  end
end

if __FILE__ == $0
  AutomationDemo.run
end 