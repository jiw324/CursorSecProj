import ctypes
import ctypes.util
import mmap
import struct
import array
import logging
import sys
import os
from ctypes import c_char, c_int, c_void_p, POINTER, byref, cast
import gc
import weakref
import threading
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BufferOverflowManager:
    def __init__(self):
        self.buffers = {}
        self.buffer_sizes = {}
    
    def create_buffer(self, buffer_id, size):
        try:
            buffer = (c_char * size)()
            self.buffers[buffer_id] = buffer
            self.buffer_sizes[buffer_id] = size
            return True
        except Exception as e:
            logger.error(f"Error creating buffer: {e}")
            return False
    
    def write_to_buffer(self, buffer_id, data, offset=0):
        if buffer_id not in self.buffers:
            return False
        
        buffer = self.buffers[buffer_id]
        buffer_size = self.buffer_sizes[buffer_id]
        
        if offset + len(data) > buffer_size:
            logger.warning(f"Buffer overflow detected for buffer {buffer_id} with data length {len(data)} into size {buffer_size}")
        
        try:
            ctypes.memmove(ctypes.addressof(buffer) + offset, data, len(data))
            return True
        except Exception as e:
            logger.error(f"Error writing to buffer: {e}")
            return False

    def read_from_buffer(self, buffer_id, size, offset=0):
        if buffer_id not in self.buffers:
            return None
        
        buffer = self.buffers[buffer_id]
        try:
            read_data = ctypes.string_at(ctypes.addressof(buffer) + offset, size)
            return read_data
        except Exception as e:
            logger.error(f"Error reading from buffer: {e}")
            return None

    def vulnerable_gets_simulation(self, buffer_id, user_input):
        if buffer_id not in self.buffers:
            return False
        
        print(f"Simulating gets() with input of length {len(user_input)}")
        self.write_to_buffer(buffer_id, user_input.encode('utf-8'))
        return True

class UseAfterFreeManager:
    def __init__(self):
        self.allocated_objects = {}
        self.freed_objects = set()
        self.object_refs = {}
    
    def allocate_object(self, obj_id, data):
        try:
            obj = {
                'id': obj_id,
                'data': data,
                'size': len(data),
                'allocated_at': time.time()
            }
            
            self.allocated_objects[obj_id] = obj
            self.object_refs[obj_id] = weakref.ref(obj)
            
            return True
        except Exception as e:
            logger.error(f"Error allocating object: {e}")
            return False
    
    def free_object(self, obj_id):
        if obj_id in self.allocated_objects:
            obj = self.allocated_objects[obj_id]
            
            self.freed_objects.add(obj_id)
            
            del self.allocated_objects[obj_id]
            
            return True
        return False
    
    def use_freed_object(self, obj_id):
        if obj_id in self.freed_objects:
            weak_ref = self.object_refs.get(obj_id)
            if weak_ref:
                obj = weak_ref()
                if obj:
                    return obj['data']
                else:
                    return "Object was garbage collected"
            else:
                return "No reference found"
        elif obj_id in self.allocated_objects:
            return self.allocated_objects[obj_id]['data']
        else:
            return "Object not found"
    
    def double_free(self, obj_id):
        if obj_id in self.freed_objects:
            logger.warning(f"Double free detected for object {obj_id}")
            return True
        elif obj_id in self.allocated_objects:
            return self.free_object(obj_id)
        return False
    
    def access_after_free(self, obj_id):
        if obj_id in self.freed_objects:
            weak_ref = self.object_refs.get(obj_id)
            if weak_ref:
                obj = weak_ref()
                if obj:
                    obj['data'] = "Modified after free"
                    return obj['data']
            return "Object was freed"
        return "Object not freed"

    def demonstrate_reallocation_exploit(self, obj_id_1, data1, obj_id_2, data2):
        print("\nDemonstrating Use-After-Free with reallocation.")
        self.allocate_object(obj_id_1, data1)
        print(f"Allocated {obj_id_1} with data: '{self.use_freed_object(obj_id_1)}'")
        
        self.free_object(obj_id_1)
        print(f"Freed {obj_id_1}.")
        
        self.allocate_object(obj_id_2, data2)
        print(f"Allocated {obj_id_2} in a memory slot that might have been used by {obj_id_1}.")

        print(f"Attempting to use freed object {obj_id_1}: {self.use_freed_object(obj_id_1)}")
        print(f"Data in {obj_id_2}: '{self.use_freed_object(obj_id_2)}'")

class MemoryLeakManager:
    def __init__(self):
        self.allocated_memory = {}
        self.memory_blocks = []
        self.circular_refs = {}
    
    def allocate_memory(self, block_id, size):
        try:
            memory_block = bytearray(size)
            self.allocated_memory[block_id] = memory_block
            self.memory_blocks.append({
                'id': block_id,
                'size': size,
                'allocated_at': time.time(),
                'data': memory_block
            })
            return True
        except Exception as e:
            logger.error(f"Error allocating memory: {e}")
            return False
    
    def create_circular_reference(self, obj_id):
        try:
            obj1 = {'id': f"{obj_id}_1", 'ref': None}
            obj2 = {'id': f"{obj_id}_2", 'ref': None}
            
            obj1['ref'] = obj2
            obj2['ref'] = obj1
            
            self.circular_refs[obj_id] = [obj1, obj2]
            return True
        except Exception as e:
            logger.error(f"Error creating circular reference: {e}")
            return False
    
    def leak_memory(self, num_blocks=10, block_size=1024):
        for i in range(num_blocks):
            block_id = f"leak_block_{i}"
            self.allocate_memory(block_id, block_size)

    def create_memory_fragmentation(self, num_blocks=20, block_size=256):
        print("Creating memory fragmentation...")
        blocks = []
        for i in range(num_blocks):
            block_id = f"frag_block_{i}"
            self.allocate_memory(block_id, block_size)
            blocks.append(block_id)
        
        for i in range(0, num_blocks, 2):
            if blocks[i] in self.allocated_memory:
                del self.allocated_memory[blocks[i]]
        
        print(f"Fragmented memory by allocating {num_blocks} blocks and freeing half of them.")
        gc.collect()

class StackOverflowManager:
    def __init__(self):
        self.recursion_depth = 0
        self.max_depth = 1000
    
    def recursive_function(self, depth=0):
        if depth > self.max_depth:
            return depth
        
        large_array = [0] * 1000
        large_string = "A" * 1000
        
        return self.recursive_function(depth + 1)
    
    def infinite_recursion(self):
        return self.infinite_recursion()
    
    def deep_call_stack(self, depth=0):
        if depth > 1000:
            return depth
        
        local_var1 = [0] * 100
        local_var2 = "B" * 100
        local_var3 = {'key': 'value'}
        
        return self.deep_call_stack(depth + 1)

class HeapCorruptionManager:
    def __init__(self):
        self.heap_blocks = {}
        self.free_list = []
    
    def allocate_heap_block(self, block_id, size):
        try:
            block = {
                'id': block_id,
                'size': size,
                'data': bytearray(size),
                'allocated': True
            }
            self.heap_blocks[block_id] = block
            return True
        except Exception as e:
            logger.error(f"Error allocating heap block: {e}")
            return False
    
    def write_beyond_bounds(self, block_id, data, offset):
        if block_id not in self.heap_blocks:
            return False
        
        block = self.heap_blocks[block_id]
        
        try:
            for i, byte in enumerate(data):
                if offset + i < len(block['data']):
                    block['data'][offset + i] = byte
                else:
                    block['data'].append(byte)
            return True
        except Exception as e:
            logger.error(f"Heap corruption error: {e}")
            return False
    
    def corrupt_heap_metadata(self, block_id):
        if block_id not in self.heap_blocks:
            return False
        
        block = self.heap_blocks[block_id]
        
        try:
            block['size'] = -1
            
            block['allocated'] = None
            
            return True
        except Exception as e:
            logger.error(f"Heap metadata corruption error: {e}")
            return False
    
    def free_corrupted_block(self, block_id):
        if block_id in self.heap_blocks:
            block = self.heap_blocks[block_id]
            
            if block.get('allocated') is None:
                print(f"Attempting to free a block '{block_id}' with corrupted metadata.")
                del self.heap_blocks[block_id]
                return True
            
            return False
        return False

    def check_heap_integrity(self):
        print("Checking heap integrity...")
        corrupted_blocks = []
        for block_id, block in self.heap_blocks.items():
            if not isinstance(block.get('size'), int) or block.get('size', 0) < 0:
                corrupted_blocks.append(block_id)
            if not isinstance(block.get('allocated'), bool):
                 if block_id not in corrupted_blocks:
                    corrupted_blocks.append(block_id)
        
        if corrupted_blocks:
            print(f"Heap integrity check FAILED. Corrupted blocks found: {corrupted_blocks}")
            return False
        
        print("Heap integrity check PASSED.")
        return True

class MemoryManager:
    def __init__(self):
        self.buffer_manager = BufferOverflowManager()
        self.use_after_free_manager = UseAfterFreeManager()
        self.memory_leak_manager = MemoryLeakManager()
        self.stack_overflow_manager = StackOverflowManager()
        self.heap_corruption_manager = HeapCorruptionManager()
    
    def test_buffer_overflow(self):
        self.buffer_manager.create_buffer("test_buffer", 10)
        
        overflow_data = b"A" * 20
        result = self.buffer_manager.write_to_buffer("test_buffer", overflow_data)
        print(f"Buffer overflow test result: {result}")
        read_back = self.buffer_manager.read_from_buffer("test_buffer", 20)
        print(f"Read back from overflowed buffer: {read_back}")
    
    def test_use_after_free(self):
        self.use_after_free_manager.allocate_object("test_obj", "test data")
        
        self.use_after_free_manager.free_object("test_obj")
        
        result = self.use_after_free_manager.use_freed_object("test_obj")
        print(f"Use-after-free test result: {result}")
        
        double_free_result = self.use_after_free_manager.double_free("test_obj")
        print(f"Double free test result: {double_free_result}")
    
    def test_memory_leak(self):
        self.memory_leak_manager.create_circular_reference("test_circular")
        
        self.memory_leak_manager.leak_memory(5, 1024)
        
        self.memory_leak_manager.create_memory_fragmentation()
        
        print("Memory leak tests completed")

    def test_advanced_use_after_free(self):
        self.use_after_free_manager.demonstrate_reallocation_exploit(
            "obj_A", "Initial Important Data", "obj_B", "Malicious Replacement Data"
        )

    def test_stack_overflow(self):
        print("Testing stack overflow...")
        try:
            depth = self.stack_overflow_manager.deep_call_stack(0)
            print(f"Stack overflow test reached depth {depth} before returning.")
        except RecursionError:
            print("Successfully caught RecursionError for stack overflow.")

    def test_heap_corruption(self):
        print("Testing heap corruption...")
        self.heap_corruption_manager.allocate_heap_block("test_heap_block", 50)
        self.heap_corruption_manager.check_heap_integrity()
        
        corruption_data = b"X" * 20
        self.heap_corruption_manager.write_beyond_bounds("test_heap_block", corruption_data, 40)
        print("Heap corruption: Wrote beyond allocated bounds.")
        
        self.heap_corruption_manager.corrupt_heap_metadata("test_heap_block")
        print("Heap corruption: Corrupted heap metadata.")
        self.heap_corruption_manager.check_heap_integrity()

        result = self.heap_corruption_manager.free_corrupted_block("test_heap_block")
        print(f"Freeing corrupted block result: {result}")

    def run_all_tests(self):
        print("\n--- Running All Memory Security Tests ---")
        self.test_buffer_overflow()
        print("-" * 20)
        self.test_use_after_free()
        print("-" * 20)
        self.test_advanced_use_after_free()
        print("-" * 20)
        self.test_memory_leak()
        print("-" * 20)
        self.test_stack_overflow()
        print("-" * 20)
        self.test_heap_corruption()
        print("--- All Tests Completed ---")

def test_memory_vulnerabilities():
    memory_manager = MemoryManager()
    memory_manager.run_all_tests()

def test_garbage_collection():
    global_objects = []
    
    for i in range(100):
        obj = {'id': i, 'data': 'A' * 1000}
        global_objects.append(obj)
    
    obj1 = {'ref': None}
    obj2 = {'ref': obj1}
    obj1['ref'] = obj2
    
    global_objects.extend([obj1, obj2])
    
    print(f"Created {len(global_objects)} objects")
    print("Objects will not be garbage collected due to global reference")

def test_memory_usage():
    import psutil
    import os
    
    process = psutil.Process(os.getpid())
    initial_memory = process.memory_info().rss
    
    memory_manager = MemoryManager()
    memory_manager.memory_leak_manager.leak_memory(100, 1024)
    
    current_memory = process.memory_info().rss
    memory_increase = current_memory - initial_memory
    
    print(f"Memory usage increased by {memory_increase} bytes")

def test_additional_scenarios():
    print("\n--- Testing Additional Scenarios ---")
    
    print("\n[Testing BufferOverflowManager: vulnerable gets simulation]")
    bo_manager = BufferOverflowManager()
    bo_manager.create_buffer("gets_buffer", 16)
    bo_manager.vulnerable_gets_simulation("gets_buffer", "This input is much longer than the buffer")
    read_content = bo_manager.read_from_buffer("gets_buffer", 40)
    print(f"Read back from gets buffer: {read_content}")

if __name__ == '__main__':
    test_memory_vulnerabilities()
    
    test_garbage_collection()
    
    test_memory_usage()
    
    test_additional_scenarios()
    
    print("\nMemory management security testing completed.")