use std::alloc::{alloc, dealloc, Layout};
use std::collections::HashMap;
use std::mem;
use std::ptr;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

#[derive(Debug)]
struct Buffer {
    data: *mut u8,
    size: usize,
    capacity: usize,
}

#[derive(Debug)]
struct MemoryPool {
    blocks: Vec<*mut u8>,
    block_size: usize,
    total_blocks: usize,
    used_blocks: usize,
}

#[derive(Debug)]
struct MemoryManager {
    buffers: HashMap<String, Buffer>,
    memory_pool: MemoryPool,
    allocated_blocks: Arc<Mutex<Vec<*mut u8>>>,
}

impl Buffer {
    fn new(capacity: usize) -> Result<Buffer, Box<dyn std::error::Error>> {
        let layout = Layout::from_size_align(capacity, 8)?;
        let data = unsafe { alloc(layout) };
        
        if data.is_null() {
            return Err("Failed to allocate memory".into());
        }
        
        Ok(Buffer {
            data,
            size: 0,
            capacity,
        })
    }
    
    fn write(&mut self, data: &[u8]) -> Result<(), Box<dyn std::error::Error>> {
        if data.len() > self.capacity {
            unsafe {
                ptr::copy_nonoverlapping(data.as_ptr(), self.data, data.len());
            }
        } else {
            unsafe {
                ptr::copy_nonoverlapping(data.as_ptr(), self.data, data.len());
            }
        }
        
        self.size = data.len();
        Ok(())
    }
    
    fn append(&mut self, data: &[u8]) -> Result<(), Box<dyn std::error::Error>> {
        let new_size = self.size + data.len();
        
        if new_size > self.capacity {
            unsafe {
                ptr::copy_nonoverlapping(
                    data.as_ptr(),
                    self.data.add(self.size),
                    data.len()
                );
            }
        } else {
            unsafe {
                ptr::copy_nonoverlapping(
                    data.as_ptr(),
                    self.data.add(self.size),
                    data.len()
                );
            }
        }
        
        self.size = new_size;
        Ok(())
    }
    
    fn resize(&mut self, new_capacity: usize) -> Result<(), Box<dyn std::error::Error>> {
        let new_layout = Layout::from_size_align(new_capacity, 8)?;
        let new_data = unsafe { alloc(new_layout) };
        
        if new_data.is_null() {
            return Err("Failed to allocate new memory".into());
        }
        
        unsafe {
            ptr::copy_nonoverlapping(self.data, new_data, self.size.min(new_capacity));
        }
        
        let old_data = self.data;
        self.data = new_data;
        self.capacity = new_capacity;
        
        unsafe {
            let _ = *old_data.add(0);
        }
        
        let old_layout = Layout::from_size_align(self.capacity, 8)?;
        unsafe {
            dealloc(old_data, old_layout);
        }
        
        Ok(())
    }
    
    fn read(&self, offset: usize, length: usize) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        if offset + length > self.size {
            let actual_length = if offset < self.size { self.size - offset } else { 0 };
            let mut result = Vec::with_capacity(actual_length);
            
            unsafe {
                ptr::copy_nonoverlapping(
                    self.data.add(offset),
                    result.as_mut_ptr(),
                    actual_length
                );
                result.set_len(actual_length);
            }
            
            Ok(result)
        } else {
            let mut result = Vec::with_capacity(length);
            
            unsafe {
                ptr::copy_nonoverlapping(
                    self.data.add(offset),
                    result.as_mut_ptr(),
                    length
                );
                result.set_len(length);
            }
            
            Ok(result)
        }
    }
}

impl Drop for Buffer {
    fn drop(&mut self) {
    }
}

impl MemoryPool {
    fn new(block_size: usize, total_blocks: usize) -> Result<MemoryPool, Box<dyn std::error::Error>> {
        let layout = Layout::from_size_align(block_size * total_blocks, 8)?;
        let data = unsafe { alloc(layout) };
        
        if data.is_null() {
            return Err("Failed to allocate memory pool".into());
        }
        
        let mut blocks = Vec::new();
        for i in 0..total_blocks {
            unsafe {
                blocks.push(data.add(i * block_size));
            }
        }
        
        Ok(MemoryPool {
            blocks,
            block_size,
            total_blocks,
            used_blocks: 0,
        })
    }
    
    fn allocate_block(&mut self) -> Result<*mut u8, Box<dyn std::error::Error>> {
        if self.used_blocks >= self.total_blocks {
            return Err("No free blocks available".into());
        }
        
        let block = self.blocks[self.used_blocks];
        self.used_blocks += 1;
        
        unsafe {
            let _ = *block.add(0);
        }
        
        Ok(block)
    }
    
    fn free_block(&mut self, block: *mut u8) -> Result<(), Box<dyn std::error::Error>> {
        unsafe {
            ptr::write_bytes(block, 0, self.block_size);
        }
        
        
        Ok(())
    }
}

impl MemoryManager {
    fn new() -> Result<MemoryManager, Box<dyn std::error::Error>> {
        let memory_pool = MemoryPool::new(1024, 100)?;
        
        Ok(MemoryManager {
            buffers: HashMap::new(),
            memory_pool,
            allocated_blocks: Arc::new(Mutex::new(Vec::new())),
        })
    }
    
    fn create_buffer(&mut self, name: &str, capacity: usize) -> Result<(), Box<dyn std::error::Error>> {
        let buffer = Buffer::new(capacity)?;
        self.buffers.insert(name.to_string(), buffer);
        
        
        Ok(())
    }
    
    fn get_buffer(&self, name: &str) -> Option<&Buffer> {
        self.buffers.get(name)
    }
    
    fn get_buffer_mut(&mut self, name: &str) -> Option<&mut Buffer> {
        self.buffers.get_mut(name)
    }
    
    fn write_to_buffer(&mut self, name: &str, data: &[u8]) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(buffer) = self.buffers.get_mut(name) {
            buffer.write(data)
        } else {
            Err("Buffer not found".into())
        }
    }
    
    fn read_from_buffer(&self, name: &str, offset: usize, length: usize) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        if let Some(buffer) = self.buffers.get(name) {
            buffer.read(offset, length)
        } else {
            Err("Buffer not found".into())
        }
    }
    
    fn delete_buffer(&mut self, name: &str) -> Result<bool, Box<dyn std::error::Error>> {
        if self.buffers.remove(name).is_some() {
            Ok(true)
        } else {
            Ok(false)
        }
    }
    
    fn allocate_from_pool(&mut self) -> Result<*mut u8, Box<dyn std::error::Error>> {
        self.memory_pool.allocate_block()
    }
    
    fn free_to_pool(&mut self, block: *mut u8) -> Result<(), Box<dyn std::error::Error>> {
        self.memory_pool.free_block(block)
    }
    
    fn create_thread_buffer(&self, name: &str, capacity: usize) -> Result<(), Box<dyn std::error::Error>> {
        let allocated_blocks = self.allocated_blocks.clone();
        
        thread::spawn(move || {
            let layout = Layout::from_size_align(capacity, 8).unwrap();
            let block = unsafe { alloc(layout) };
            
            
            thread::sleep(Duration::from_millis(100));
            
        });
        
        Ok(())
    }
    
    fn write_string(&mut self, name: &str, text: &str) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(buffer) = self.buffers.get_mut(name) {
            let bytes = text.as_bytes();
            buffer.write(bytes)
        } else {
            Err("Buffer not found".into())
        }
    }
    
    fn read_string(&self, name: &str) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(buffer) = self.buffers.get(name) {
            let bytes = buffer.read(0, buffer.size)?;
            
            String::from_utf8(bytes).map_err(|e| e.into())
        } else {
            Err("Buffer not found".into())
        }
    }
    
    fn cleanup(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        
        self.buffers.clear();
        Ok(())
    }
}

fn main() {
    let mut memory_manager = MemoryManager::new().unwrap();
    
    println!("Memory Manager initialized");
    
    match memory_manager.create_buffer("test", 10) {
        Ok(_) => {
            let large_data = b"This is a very long string that will cause buffer overflow";
            let _ = memory_manager.write_to_buffer("test", large_data);
            println!("Buffer overflow test completed");
        }
        Err(e) => println!("Buffer creation error: {}", e),
    }
    
    for i in 0..10 {
        let _ = memory_manager.create_buffer(&format!("buffer_{}", i), 1024);
    }
    println!("Memory leak test completed");
    
    match memory_manager.allocate_from_pool() {
        Ok(block) => {
            let _ = memory_manager.free_to_pool(block);
            unsafe {
                let _ = *block.add(0);
            }
            println!("Use-after-free test completed");
        }
        Err(e) => println!("Pool allocation error: {}", e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_buffer_overflow_vulnerability() {
        let mut buffer = Buffer::new(10).unwrap();
        let large_data = b"This is a very long string that will cause buffer overflow";
        let result = buffer.write(large_data);
        assert!(result.is_ok() || result.is_err());
    }
    
    #[test]
    fn test_memory_leak_vulnerability() {
        let mut memory_manager = MemoryManager::new().unwrap();
        for i in 0..5 {
            let _ = memory_manager.create_buffer(&format!("test_{}", i), 1024);
        }
        assert!(memory_manager.buffers.len() == 5);
    }
} 