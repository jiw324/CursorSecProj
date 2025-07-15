#!/usr/bin/env ruby

require 'logger'
require 'securerandom'
require 'json'
require 'time'
require 'weakref'
require 'thread'
require 'fiber'
require 'set'

LOGGER = Logger.new(STDOUT)

class BufferOverflowManager
  def initialize
    @buffers = {}
    @buffer_sizes = {}
  end

  def create_buffer(buffer_id, size)
    begin
      buffer = Array.new(size, 0)
      @buffers[buffer_id] = buffer
      @buffer_sizes[buffer_id] = size
      true
    rescue => e
      LOGGER.error("Error creating buffer: #{e}")
      false
    end
  end

  def write_to_buffer(buffer_id, data, offset = 0)
    return false unless @buffers.key?(buffer_id)
    buffer = @buffers[buffer_id]
    buffer_size = @buffer_sizes[buffer_id]
    data_length = data.length
    if offset + data_length > buffer_size
      data_length = buffer_size - offset
    end
    begin
      data_length.times do |i|
        buffer[offset + i] = data[i]
      end
      true
    rescue => e
      LOGGER.error("Error writing to buffer: #{e}")
      false
    end
  end

  def read_from_buffer(buffer_id, length, offset = 0)
    return nil unless @buffers.key?(buffer_id)
    buffer = @buffers[buffer_id]
    buffer_size = @buffer_sizes[buffer_id]
    if offset + length > buffer_size
      length = buffer_size - offset
    end
    begin
      result = []
      length.times do |i|
        result << buffer[offset + i]
      end
      result
    rescue => e
      LOGGER.error("Error reading from buffer: #{e}")
      nil
    end
  end

  def overflow_buffer(buffer_id, data)
    return false unless @buffers.key?(buffer_id)
    buffer = @buffers[buffer_id]
    begin
      data.each_with_index do |byte, i|
        buffer[i] = byte
      end
      true
    rescue => e
      LOGGER.error("Buffer overflow error: #{e}")
      false
    end
  end
end

class UseAfterFreeManager
  def initialize
    @allocated_objects = {}
    @freed_objects = Set.new
    @object_refs = {}
  end

  def allocate_object(obj_id, data)
    begin
      obj = {
        id: obj_id,
        data: data,
        size: data.length,
        allocated_at: Time.now
      }
      @allocated_objects[obj_id] = obj
      @object_refs[obj_id] = WeakRef.new(obj)
      true
    rescue => e
      LOGGER.error("Error allocating object: #{e}")
      false
    end
  end

  def free_object(obj_id)
    if @allocated_objects.key?(obj_id)
      obj = @allocated_objects[obj_id]
      @freed_objects.add(obj_id)
      @allocated_objects.delete(obj_id)
      true
    else
      false
    end
  end

  def use_freed_object(obj_id)
    if @freed_objects.include?(obj_id)
      weak_ref = @object_refs[obj_id]
      if weak_ref
        begin
          obj = weak_ref.__getobj__
          obj[:data]
        rescue WeakRef::RefError
          "Object was garbage collected"
        end
      else
        "No reference found"
      end
    elsif @allocated_objects.key?(obj_id)
      @allocated_objects[obj_id][:data]
    else
      "Object not found"
    end
  end

  def double_free(obj_id)
    if @freed_objects.include?(obj_id)
      LOGGER.warn("Double free detected for object #{obj_id}")
      true
    elsif @allocated_objects.key?(obj_id)
      free_object(obj_id)
    else
      false
    end
  end

  def access_after_free(obj_id)
    if @freed_objects.include?(obj_id)
      weak_ref = @object_refs[obj_id]
      if weak_ref
        begin
          obj = weak_ref.__getobj__
          obj[:data] = "Modified after free"
          obj[:data]
        rescue WeakRef::RefError
          "Object was freed"
        end
      else
        "Object was freed"
      end
    else
      "Object not freed"
    end
  end
end

class MemoryLeakManager
  def initialize
    @allocated_memory = {}
    @memory_blocks = []
    @circular_refs = {}
  end

  def allocate_memory(block_id, size)
    begin
      memory_block = Array.new(size, 0)
      @allocated_memory[block_id] = memory_block
      @memory_blocks << {
        id: block_id,
        size: size,
        allocated_at: Time.now,
        data: memory_block
      }
      true
    rescue => e
      LOGGER.error("Error allocating memory: #{e}")
      false
    end
  end

  def create_circular_reference(obj_id)
    begin
      obj1 = { id: "#{obj_id}_1", ref: nil }
      obj2 = { id: "#{obj_id}_2", ref: nil }
      obj1[:ref] = obj2
      obj2[:ref] = obj1
      @circular_refs[obj_id] = [obj1, obj2]
      true
    rescue => e
      LOGGER.error("Error creating circular reference: #{e}")
      false
    end
  end

  def leak_memory(num_blocks = 10, block_size = 1024)
    num_blocks.times do |i|
      block_id = "leak_block_#{i}"
      allocate_memory(block_id, block_size)
    end
  end

  def create_memory_fragmentation
    100.times do |i|
      allocate_memory("frag_block_#{i}", 64)
    end
    100.step(0, -2) do |i|
      if @allocated_memory.key?("frag_block_#{i}")
        @allocated_memory.delete("frag_block_#{i}")
      end
    end
  end

  def allocate_large_blocks(num_blocks = 5, block_size = 1024 * 1024)
    num_blocks.times do |i|
      block_id = "large_block_#{i}"
      allocate_memory(block_id, block_size)
    end
  end
end

class StackOverflowManager
  def initialize
    @recursion_depth = 0
    @max_depth = 1000
  end

  def recursive_function(depth = 0)
    return depth if depth > @max_depth
    large_array = Array.new(1000, 0)
    large_string = "A" * 1000
    recursive_function(depth + 1)
  end

  def infinite_recursion
    infinite_recursion
  end

  def deep_call_stack(depth = 0)
    return depth if depth > 1000
    local_var1 = Array.new(100, 0)
    local_var2 = "B" * 100
    local_var3 = { key: 'value' }
    deep_call_stack(depth + 1)
  end
end

class HeapCorruptionManager
  def initialize
    @heap_blocks = {}
    @free_list = []
  end

  def allocate_heap_block(block_id, size)
    begin
      block = {
        id: block_id,
        size: size,
        data: Array.new(size, 0),
        allocated: true
      }
      @heap_blocks[block_id] = block
      true
    rescue => e
      LOGGER.error("Error allocating heap block: #{e}")
      false
    end
  end

  def write_beyond_bounds(block_id, data, offset)
    return false unless @heap_blocks.key?(block_id)
    block = @heap_blocks[block_id]
    begin
      data.each_with_index do |byte, i|
        if offset + i < block[:data].length
          block[:data][offset + i] = byte
        else
          block[:data] << byte
        end
      end
      true
    rescue => e
      LOGGER.error("Heap corruption error: #{e}")
      false
    end
  end

  def corrupt_heap_metadata(block_id)
    return false unless @heap_blocks.key?(block_id)
    block = @heap_blocks[block_id]
    begin
      block[:size] = -1
      block[:allocated] = nil
      true
    rescue => e
      LOGGER.error("Heap metadata corruption error: #{e}")
      false
    end
  end

  def free_corrupted_block(block_id)
    if @heap_blocks.key?(block_id)
      block = @heap_blocks[block_id]
      if block[:allocated].nil?
        @heap_blocks.delete(block_id)
        true
      else
        false
      end
    else
      false
    end
  end
end

class ResourceLeakManager
  def initialize
    @file_handles = {}
    @network_connections = {}
    @database_connections = {}
  end

  def open_file_handle(file_id, filename)
    begin
      file_handle = File.open(filename, 'r')
      @file_handles[file_id] = file_handle
      true
    rescue => e
      LOGGER.error("Error opening file handle: #{e}")
      false
    end
  end

  def leak_file_handles(num_handles = 10)
    num_handles.times do |i|
      file_id = "leak_file_#{i}"
      filename = "temp_file_#{i}.txt"
      File.write(filename, "content")
      open_file_handle(file_id, filename)
    end
  end

  def simulate_network_connection(conn_id, host, port)
    begin
      connection = {
        id: conn_id,
        host: host,
        port: port,
        opened_at: Time.now,
        status: 'open'
      }
      @network_connections[conn_id] = connection
      true
    rescue => e
      LOGGER.error("Error opening network connection: #{e}")
      false
    end
  end

  def leak_network_connections(num_connections = 5)
    num_connections.times do |i|
      conn_id = "leak_conn_#{i}"
      simulate_network_connection(conn_id, "host#{i}.example.com", 8080 + i)
    end
  end

  def simulate_database_connection(db_id, connection_string)
    begin
      connection = {
        id: db_id,
        connection_string: connection_string,
        opened_at: Time.now,
        status: 'open'
      }
      @database_connections[db_id] = connection
      true
    rescue => e
      LOGGER.error("Error opening database connection: #{e}")
      false
    end
  end

  def leak_database_connections(num_connections = 3)
    num_connections.times do |i|
      db_id = "leak_db_#{i}"
      connection_string = "mysql://localhost:3306/db#{i}"
      simulate_database_connection(db_id, connection_string)
    end
  end
end

class MemoryManager
  def initialize
    @buffer_manager = BufferOverflowManager.new
    @use_after_free_manager = UseAfterFreeManager.new
    @memory_leak_manager = MemoryLeakManager.new
    @stack_overflow_manager = StackOverflowManager.new
    @heap_corruption_manager = HeapCorruptionManager.new
    @resource_leak_manager = ResourceLeakManager.new
  end

  def test_buffer_overflow
    @buffer_manager.create_buffer("test_buffer", 10)
    overflow_data = Array.new(20, 1)
    result = @buffer_manager.overflow_buffer("test_buffer", overflow_data)
    puts "Buffer overflow test result: #{result}"
  end

  def test_use_after_free
    @use_after_free_manager.allocate_object("test_obj", "test data")
    @use_after_free_manager.free_object("test_obj")
    result = @use_after_free_manager.use_freed_object("test_obj")
    puts "Use-after-free test result: #{result}"
    double_free_result = @use_after_free_manager.double_free("test_obj")
    puts "Double free test result: #{double_free_result}"
  end

  def test_memory_leak
    @memory_leak_manager.create_circular_reference("test_circular")
    @memory_leak_manager.leak_memory(5, 1024)
    @memory_leak_manager.create_memory_fragmentation
    puts "Memory leak tests completed"
  end

  def test_stack_overflow
    begin
      result = @stack_overflow_manager.recursive_function
      puts "Deep recursion result: #{result}"
    rescue SystemStackError => e
      puts "Stack overflow caught: #{e}"
    end
    begin
      # @stack_overflow_manager.infinite_recursion
    rescue SystemStackError => e
      puts "Infinite recursion caught: #{e}"
    end
  end

  def test_heap_corruption
    @heap_corruption_manager.allocate_heap_block("test_heap", 100)
    overflow_data = Array.new(150, 1)
    result = @heap_corruption_manager.write_beyond_bounds("test_heap", overflow_data, 0)
    puts "Heap corruption test result: #{result}"
    corrupt_result = @heap_corruption_manager.corrupt_heap_metadata("test_heap")
    puts "Heap metadata corruption result: #{corrupt_result}"
  end

  def test_resource_leaks
    @resource_leak_manager.leak_file_handles(10)
    puts "File handle leaks created"
    @resource_leak_manager.leak_network_connections(5)
    puts "Network connection leaks created"
    @resource_leak_manager.leak_database_connections(3)
    puts "Database connection leaks created"
  end

  def run_all_tests
    puts "Starting memory vulnerability tests..."
    test_buffer_overflow
    test_use_after_free
    test_memory_leak
    test_stack_overflow
    test_heap_corruption
    test_resource_leaks
    puts "All memory vulnerability tests completed."
  end
end

def test_memory_vulnerabilities
  memory_manager = MemoryManager.new
  memory_manager.run_all_tests
end

def test_garbage_collection
  global_objects = []
  100.times do |i|
    obj = { id: i, data: "A" * 1000 }
    global_objects << obj
  end
  obj1 = { ref: nil }
  obj2 = { ref: obj1 }
  obj1[:ref] = obj2
  global_objects.concat([obj1, obj2])
  puts "Created #{global_objects.length} objects"
  puts "Objects will not be garbage collected due to global reference"
end

def test_memory_usage
  initial_memory = `ps -o rss= -p #{Process.pid}`.to_i
  memory_manager = MemoryManager.new
  memory_manager.instance_variable_get(:@memory_leak_manager).leak_memory(100, 1024)
  current_memory = `ps -o rss= -p #{Process.pid}`.to_i
  memory_increase = current_memory - initial_memory
  puts "Memory usage increased by #{memory_increase} KB"
end

if __FILE__ == $0
  test_memory_vulnerabilities
  test_garbage_collection
  test_memory_usage
  puts "Memory management security testing completed."
end 