#!/usr/bin/env ruby

=begin
AI-Generated Code Header
Intent: Demonstrate Ruby background job processing with queuing and worker management
Optimization: Concurrent processing, memory efficiency, and job persistence
Safety: Error handling, job retry logic, and graceful shutdown
=end

require 'json'
require 'logger'
require 'thread'
require 'redis'
require 'digest'
require 'time'
require 'securerandom'

# AI-SUGGESTION: Job class with serialization
class Job
  attr_accessor :id, :class_name, :method_name, :args, :priority, :attempts, :max_attempts,
                :created_at, :scheduled_at, :started_at, :completed_at, :failed_at, :error

  def initialize(class_name, method_name, args = [], options = {})
    @id = SecureRandom.uuid
    @class_name = class_name
    @method_name = method_name
    @args = args
    @priority = options[:priority] || 5
    @attempts = 0
    @max_attempts = options[:max_attempts] || 3
    @created_at = Time.now
    @scheduled_at = options[:delay] ? Time.now + options[:delay] : Time.now
    @started_at = nil
    @completed_at = nil
    @failed_at = nil
    @error = nil
  end

  def to_h
    {
      id: @id,
      class_name: @class_name,
      method_name: @method_name,
      args: @args,
      priority: @priority,
      attempts: @attempts,
      max_attempts: @max_attempts,
      created_at: @created_at.iso8601,
      scheduled_at: @scheduled_at.iso8601,
      started_at: @started_at&.iso8601,
      completed_at: @completed_at&.iso8601,
      failed_at: @failed_at&.iso8601,
      error: @error
    }
  end

  def self.from_h(hash)
    job = allocate
    job.id = hash[:id]
    job.class_name = hash[:class_name]
    job.method_name = hash[:method_name]
    job.args = hash[:args]
    job.priority = hash[:priority]
    job.attempts = hash[:attempts]
    job.max_attempts = hash[:max_attempts]
    job.created_at = Time.parse(hash[:created_at])
    job.scheduled_at = Time.parse(hash[:scheduled_at])
    job.started_at = hash[:started_at] ? Time.parse(hash[:started_at]) : nil
    job.completed_at = hash[:completed_at] ? Time.parse(hash[:completed_at]) : nil
    job.failed_at = hash[:failed_at] ? Time.parse(hash[:failed_at]) : nil
    job.error = hash[:error]
    job
  end

  def ready_to_run?
    Time.now >= @scheduled_at
  end

  def can_retry?
    @attempts < @max_attempts
  end

  def status
    return 'completed' if @completed_at
    return 'failed' if @failed_at && !can_retry?
    return 'running' if @started_at && !@completed_at && !@failed_at
    return 'scheduled' if Time.now < @scheduled_at
    'pending'
  end
end

# AI-SUGGESTION: Queue interface with Redis backend
class JobQueue
  def initialize(redis_url = 'redis://localhost:6379', namespace = 'jobs')
    @namespace = namespace
    @redis = Redis.new(url: redis_url)
    @logger = Logger.new(STDOUT)
  rescue Redis::CannotConnectError => e
    @logger = Logger.new(STDOUT)
    @logger.error("Redis connection failed: #{e.message}")
    @redis = nil
  end

  def enqueue(job)
    if @redis
      enqueue_redis(job)
    else
      enqueue_memory(job)
    end
  end

  def dequeue(queue_name = 'default')
    if @redis
      dequeue_redis(queue_name)
    else
      dequeue_memory(queue_name)
    end
  end

  def size(queue_name = 'default')
    if @redis
      @redis.llen(queue_key(queue_name))
    else
      @memory_queues ||= {}
      (@memory_queues[queue_name] || []).size
    end
  end

  def clear(queue_name = 'default')
    if @redis
      @redis.del(queue_key(queue_name))
    else
      @memory_queues ||= {}
      @memory_queues[queue_name] = []
    end
  end

  def get_job_status(job_id)
    if @redis
      job_data = @redis.hget(status_key, job_id)
      return nil unless job_data
      Job.from_h(JSON.parse(job_data, symbolize_names: true))
    else
      @job_status ||= {}
      @job_status[job_id]
    end
  end

  def update_job_status(job)
    if @redis
      @redis.hset(status_key, job.id, job.to_h.to_json)
    else
      @job_status ||= {}
      @job_status[job.id] = job
    end
  end

  def get_statistics
    stats = {
      queues: {},
      total_jobs: 0,
      failed_jobs: 0,
      completed_jobs: 0
    }

    if @redis
      # Get queue sizes
      queue_keys = @redis.keys("#{@namespace}:queue:*")
      queue_keys.each do |key|
        queue_name = key.split(':').last
        stats[:queues][queue_name] = @redis.llen(key)
        stats[:total_jobs] += stats[:queues][queue_name]
      end

      # Get job status counts
      all_jobs = @redis.hgetall(status_key)
      all_jobs.values.each do |job_data|
        job = Job.from_h(JSON.parse(job_data, symbolize_names: true))
        case job.status
        when 'completed'
          stats[:completed_jobs] += 1
        when 'failed'
          stats[:failed_jobs] += 1
        end
      end
    else
      @memory_queues ||= {}
      @memory_queues.each do |queue_name, jobs|
        stats[:queues][queue_name] = jobs.size
        stats[:total_jobs] += jobs.size
      end

      @job_status ||= {}
      @job_status.values.each do |job|
        case job.status
        when 'completed'
          stats[:completed_jobs] += 1
        when 'failed'
          stats[:failed_jobs] += 1
        end
      end
    end

    stats
  end

  private

  def enqueue_redis(job)
    queue_name = job.priority <= 3 ? 'high' : 'default'
    
    # Add to queue
    @redis.lpush(queue_key(queue_name), job.to_h.to_json)
    
    # Store job status
    update_job_status(job)
    
    @logger.info("Enqueued job #{job.id} to #{queue_name} queue")
  end

  def dequeue_redis(queue_name)
    job_data = @redis.brpop(queue_key(queue_name), 1)
    return nil unless job_data

    job_json = job_data[1]
    job = Job.from_h(JSON.parse(job_json, symbolize_names: true))
    
    # Only return jobs that are ready to run
    if job.ready_to_run?
      job
    else
      # Put back if not ready
      @redis.lpush(queue_key(queue_name), job_json)
      nil
    end
  end

  def enqueue_memory(job)
    @memory_queues ||= {}
    queue_name = job.priority <= 3 ? 'high' : 'default'
    @memory_queues[queue_name] ||= []
    @memory_queues[queue_name] << job
    update_job_status(job)
    @logger.info("Enqueued job #{job.id} to #{queue_name} queue (memory)")
  end

  def dequeue_memory(queue_name)
    @memory_queues ||= {}
    queue = @memory_queues[queue_name] || []
    
    # Find first ready job
    ready_job = queue.find(&:ready_to_run?)
    if ready_job
      queue.delete(ready_job)
      ready_job
    else
      nil
    end
  end

  def queue_key(queue_name)
    "#{@namespace}:queue:#{queue_name}"
  end

  def status_key
    "#{@namespace}:status"
  end
end

# AI-SUGGESTION: Worker class for processing jobs
class Worker
  attr_reader :id, :status, :current_job, :processed_count, :failed_count

  def initialize(queue, worker_id = nil)
    @id = worker_id || "worker_#{SecureRandom.hex(4)}"
    @queue = queue
    @status = 'idle'
    @current_job = nil
    @processed_count = 0
    @failed_count = 0
    @running = false
    @thread = nil
    @logger = Logger.new(STDOUT)
  end

  def start
    return if @running

    @running = true
    @thread = Thread.new { work_loop }
    @logger.info("Worker #{@id} started")
  end

  def stop
    @running = false
    @thread&.join
    @logger.info("Worker #{@id} stopped")
  end

  def stats
    {
      id: @id,
      status: @status,
      current_job: @current_job&.id,
      processed_count: @processed_count,
      failed_count: @failed_count,
      running: @running
    }
  end

  private

  def work_loop
    while @running
      begin
        # Try high priority queue first, then default
        job = @queue.dequeue('high') || @queue.dequeue('default')
        
        if job
          process_job(job)
        else
          sleep(1) # No jobs available, wait a bit
        end
      rescue => e
        @logger.error("Worker #{@id} error: #{e.message}")
        sleep(1)
      end
    end
  end

  def process_job(job)
    @status = 'working'
    @current_job = job
    
    job.started_at = Time.now
    job.attempts += 1
    
    @queue.update_job_status(job)
    @logger.info("Worker #{@id} processing job #{job.id}")

    begin
      # Get the class and call the method
      klass = Object.const_get(job.class_name)
      
      if job.method_name == 'perform' && klass.respond_to?(:perform)
        # Class method
        klass.send(job.method_name, *job.args)
      elsif klass.respond_to?(:new)
        # Instance method
        instance = klass.new
        instance.send(job.method_name, *job.args)
      else
        raise "Method #{job.method_name} not found on #{job.class_name}"
      end

      # Job completed successfully
      job.completed_at = Time.now
      @queue.update_job_status(job)
      @processed_count += 1
      
      @logger.info("Worker #{@id} completed job #{job.id}")

    rescue => e
      # Job failed
      job.failed_at = Time.now
      job.error = "#{e.class}: #{e.message}"
      
      @queue.update_job_status(job)
      @failed_count += 1
      
      @logger.error("Worker #{@id} failed job #{job.id}: #{e.message}")

      # Retry if possible
      if job.can_retry?
        retry_job = Job.new(job.class_name, job.method_name, job.args, {
          priority: job.priority,
          max_attempts: job.max_attempts,
          delay: calculate_retry_delay(job.attempts)
        })
        retry_job.attempts = job.attempts
        @queue.enqueue(retry_job)
        @logger.info("Scheduled retry for job #{job.id} as #{retry_job.id}")
      end

    ensure
      @status = 'idle'
      @current_job = nil
    end
  end

  def calculate_retry_delay(attempt)
    # Exponential backoff: 2^attempt seconds
    2 ** attempt
  end
end

# AI-SUGGESTION: Job processor manager
class JobProcessor
  def initialize(options = {})
    @redis_url = options[:redis_url] || 'redis://localhost:6379'
    @worker_count = options[:worker_count] || 3
    @namespace = options[:namespace] || 'jobs'
    
    @queue = JobQueue.new(@redis_url, @namespace)
    @workers = []
    @running = false
    @logger = Logger.new(STDOUT)
    
    # Setup signal handlers for graceful shutdown
    setup_signal_handlers
  end

  def start
    return if @running

    @running = true
    @logger.info("Starting job processor with #{@worker_count} workers")

    # Start workers
    @worker_count.times do |i|
      worker = Worker.new(@queue, "worker_#{i + 1}")
      worker.start
      @workers << worker
    end

    @logger.info("Job processor started successfully")
  end

  def stop
    return unless @running

    @logger.info("Stopping job processor...")
    @running = false

    # Stop all workers
    @workers.each(&:stop)
    @workers.clear

    @logger.info("Job processor stopped")
  end

  def enqueue(class_name, method_name, args = [], options = {})
    job = Job.new(class_name, method_name, args, options)
    @queue.enqueue(job)
    job.id
  end

  def get_job_status(job_id)
    @queue.get_job_status(job_id)
  end

  def get_statistics
    stats = @queue.get_statistics
    stats[:workers] = @workers.map(&:stats)
    stats[:processor_status] = @running ? 'running' : 'stopped'
    stats
  end

  def clear_queue(queue_name = 'default')
    @queue.clear(queue_name)
  end

  private

  def setup_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        @logger.info("Received #{signal}, shutting down gracefully...")
        stop
        exit(0)
      end
    end
  end
end

# AI-SUGGESTION: Example job classes
class EmailJob
  def self.perform(to, subject, body)
    # Simulate email sending
    puts "Sending email to #{to}: #{subject}"
    sleep(rand(1..3)) # Simulate network delay
    
    # Simulate occasional failures
    raise "SMTP server unavailable" if rand < 0.1
    
    puts "Email sent successfully to #{to}"
  end
end

class DataProcessingJob
  def initialize
    @logger = Logger.new(STDOUT)
  end

  def process_data(data_set, options = {})
    @logger.info("Processing data set: #{data_set}")
    
    # Simulate data processing
    items = options[:items] || rand(100..1000)
    
    items.times do |i|
      # Simulate processing each item
      sleep(0.01)
      
      if i % 100 == 0
        @logger.debug("Processed #{i}/#{items} items")
      end
    end
    
    # Simulate occasional failures
    raise "Data corruption detected" if rand < 0.05
    
    @logger.info("Data processing completed: #{items} items processed")
  end
end

class ReportGenerationJob
  def self.perform(report_type, user_id, params = {})
    puts "Generating #{report_type} report for user #{user_id}"
    
    # Simulate report generation
    case report_type
    when 'sales'
      generate_sales_report(params)
    when 'analytics'
      generate_analytics_report(params)
    when 'user_activity'
      generate_user_activity_report(user_id, params)
    else
      raise "Unknown report type: #{report_type}"
    end
    
    puts "Report #{report_type} generated successfully"
  end

  private

  def self.generate_sales_report(params)
    sleep(2) # Simulate database queries and calculations
  end

  def self.generate_analytics_report(params)
    sleep(3) # Simulate complex analytics
  end

  def self.generate_user_activity_report(user_id, params)
    sleep(1) # Simulate user data aggregation
  end
end

# AI-SUGGESTION: Job scheduler for recurring tasks
class JobScheduler
  def initialize(processor)
    @processor = processor
    @scheduled_jobs = []
    @running = false
    @thread = nil
    @logger = Logger.new(STDOUT)
  end

  def schedule(cron_expression, class_name, method_name, args = [], options = {})
    scheduled_job = {
      cron: cron_expression,
      class_name: class_name,
      method_name: method_name,
      args: args,
      options: options,
      last_run: nil,
      next_run: calculate_next_run(cron_expression)
    }
    
    @scheduled_jobs << scheduled_job
    @logger.info("Scheduled job: #{class_name}.#{method_name} (#{cron_expression})")
  end

  def start
    return if @running

    @running = true
    @thread = Thread.new { scheduler_loop }
    @logger.info("Job scheduler started")
  end

  def stop
    @running = false
    @thread&.join
    @logger.info("Job scheduler stopped")
  end

  def get_scheduled_jobs
    @scheduled_jobs.map do |job|
      {
        class_name: job[:class_name],
        method_name: job[:method_name],
        cron: job[:cron],
        last_run: job[:last_run]&.iso8601,
        next_run: job[:next_run].iso8601
      }
    end
  end

  private

  def scheduler_loop
    while @running
      current_time = Time.now

      @scheduled_jobs.each do |job|
        if current_time >= job[:next_run]
          # Enqueue the job
          @processor.enqueue(
            job[:class_name],
            job[:method_name],
            job[:args],
            job[:options]
          )

          # Update run times
          job[:last_run] = current_time
          job[:next_run] = calculate_next_run(job[:cron], current_time)

          @logger.info("Triggered scheduled job: #{job[:class_name]}.#{job[:method_name]}")
        end
      end

      sleep(60) # Check every minute
    end
  end

  def calculate_next_run(cron_expression, from_time = Time.now)
    # Simple cron parser (supports only basic expressions)
    case cron_expression
    when '@hourly'
      from_time + 3600
    when '@daily'
      from_time + 86400
    when '@weekly'
      from_time + 604800
    else
      # Default to hourly for unsupported expressions
      from_time + 3600
    end
  end
end

# AI-SUGGESTION: Demo and testing
class JobProcessorDemo
  def self.run
    puts "=== Ruby Background Job Processor Demo ==="
    
    # Initialize processor
    processor = JobProcessor.new(worker_count: 2)
    processor.start
    
    puts "\n1. Enqueueing various jobs..."
    
    # Enqueue some test jobs
    email_job_id = processor.enqueue('EmailJob', 'perform', 
      ['user@example.com', 'Welcome!', 'Welcome to our service'])
    
    data_job_id = processor.enqueue('DataProcessingJob', 'process_data',
      ['customer_data', { items: 50 }])
    
    report_job_id = processor.enqueue('ReportGenerationJob', 'perform',
      ['sales', 123, { period: 'monthly' }], { priority: 2 })
    
    puts "   Enqueued jobs: #{[email_job_id, data_job_id, report_job_id].join(', ')}"
    
    # Wait for jobs to process
    puts "\n2. Processing jobs (waiting 10 seconds)..."
    sleep(10)
    
    # Check job statuses
    puts "\n3. Job Status Report:"
    [email_job_id, data_job_id, report_job_id].each do |job_id|
      job = processor.get_job_status(job_id)
      if job
        puts "   Job #{job_id[0..7]}: #{job.status}"
        puts "     Attempts: #{job.attempts}/#{job.max_attempts}"
        puts "     Error: #{job.error}" if job.error
      end
    end
    
    # Show processor statistics
    puts "\n4. Processor Statistics:"
    stats = processor.get_statistics
    puts "   Total jobs processed: #{stats[:completed_jobs]}"
    puts "   Failed jobs: #{stats[:failed_jobs]}"
    puts "   Queue sizes: #{stats[:queues]}"
    puts "   Workers:"
    stats[:workers].each do |worker|
      puts "     #{worker[:id]}: #{worker[:status]} (#{worker[:processed_count]} processed)"
    end
    
    # Demonstrate scheduler
    puts "\n5. Testing Job Scheduler..."
    scheduler = JobScheduler.new(processor)
    
    # Schedule some recurring jobs
    scheduler.schedule('@hourly', 'EmailJob', 'perform', 
      ['admin@example.com', 'Hourly Report', 'System status: OK'])
    
    scheduler.schedule('@daily', 'ReportGenerationJob', 'perform',
      ['analytics', 0, { auto_generated: true }])
    
    scheduler.start
    
    # Show scheduled jobs
    puts "   Scheduled jobs:"
    scheduler.get_scheduled_jobs.each do |job|
      puts "     #{job[:class_name]}.#{job[:method_name]} - #{job[:cron]}"
      puts "       Next run: #{job[:next_run]}"
    end
    
    puts "\n6. Running scheduler for 5 seconds..."
    sleep(5)
    
    scheduler.stop
    
    puts "\n7. Final Statistics:"
    final_stats = processor.get_statistics
    puts "   Total processed: #{final_stats[:completed_jobs]}"
    puts "   Total failed: #{final_stats[:failed_jobs]}"
    
    # Cleanup
    puts "\n8. Shutting down..."
    processor.stop
    
    puts "\nBackground job processor demo completed!"
  end
end

# Run demo if script is executed directly
if __FILE__ == $0
  JobProcessorDemo.run
end 