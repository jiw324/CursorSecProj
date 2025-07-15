import java.io.*;
import java.nio.*;
import java.util.*;
import java.security.*;
import java.lang.reflect.*;
import java.util.concurrent.*;

public class VulnerableMemoryManager {
    
    private static final int DEFAULT_BUFFER_SIZE = 1024;
    private static final int MAX_BUFFER_SIZE = 1000000;
    
    private Map<String, MemoryBlock> memoryBlocks;
    private List<MemoryOperation> operations;
    private Random random;
    private ExecutorService executor;
    
    public VulnerableMemoryManager() {
        this.memoryBlocks = new HashMap<>();
        this.operations = new ArrayList<>();
        this.random = new Random();
        this.executor = Executors.newFixedThreadPool(4);
    }
    
    private static class MemoryBlock {
        String id;
        byte[] data;
        int size;
        boolean isReadOnly;
        Date created;
        String owner;
        
        MemoryBlock(String id, byte[] data, boolean isReadOnly, String owner) {
            this.id = id;
            this.data = data;
            this.size = data.length;
            this.isReadOnly = isReadOnly;
            this.created = new Date();
            this.owner = owner;
        }
    }
    
    private static class MemoryOperation {
        String type, blockId, user;
        int dataSize;
        Date timestamp;
        String details;
        
        MemoryOperation(String type, String blockId, String user, int dataSize, String details) {
            this.type = type;
            this.blockId = blockId;
            this.user = user;
            this.dataSize = dataSize;
            this.details = details;
            this.timestamp = new Date();
        }
    }
    
    private static class BufferInfo {
        String id;
        int capacity, position, limit;
        boolean isDirect;
        String type;
        
        BufferInfo(String id, int capacity, int position, int limit, boolean isDirect, String type) {
            this.id = id;
            this.capacity = capacity;
            this.position = position;
            this.limit = limit;
            this.isDirect = isDirect;
            this.type = type;
        }
    }
    
    public String allocateMemory(int size, String owner) {
        if (size <= 0) {
            throw new IllegalArgumentException("Invalid size: " + size);
        }
        
        byte[] data = new byte[size];
        String blockId = generateBlockId();
        
        MemoryBlock block = new MemoryBlock(blockId, data, false, owner);
        memoryBlocks.put(blockId, block);
        
        logOperation("allocate", blockId, owner, size, "Allocated " + size + " bytes");
        
        return blockId;
    }
    
    public void writeToMemory(String blockId, byte[] data, int offset) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        if (block.isReadOnly) {
            throw new SecurityException("Cannot write to read-only memory block");
        }
        
        if (offset < 0 || offset + data.length > block.data.length) {
            System.err.println("Warning: Potential buffer overflow detected");
        }
        
        System.arraycopy(data, 0, block.data, offset, data.length);
        
        logOperation("write", blockId, block.owner, data.length, "Wrote " + data.length + " bytes at offset " + offset);
    }
    
    public byte[] readFromMemory(String blockId, int offset, int length) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        if (offset < 0 || offset + length > block.data.length) {
            System.err.println("Warning: Potential buffer overflow detected");
        }
        
        byte[] result = new byte[length];
        System.arraycopy(block.data, offset, result, 0, length);
        
        logOperation("read", blockId, block.owner, length, "Read " + length + " bytes from offset " + offset);
        
        return result;
    }
    
    public void copyMemory(String sourceId, String destId, int sourceOffset, int destOffset, int length) {
        MemoryBlock source = memoryBlocks.get(sourceId);
        MemoryBlock dest = memoryBlocks.get(destId);
        
        if (source == null || dest == null) {
            throw new IllegalArgumentException("Memory block not found");
        }
        
        if (dest.isReadOnly) {
            throw new SecurityException("Cannot write to read-only memory block");
        }
        
        if (sourceOffset < 0 || sourceOffset + length > source.data.length ||
            destOffset < 0 || destOffset + length > dest.data.length) {
            System.err.println("Warning: Potential buffer overflow detected");
        }
        
        System.arraycopy(source.data, sourceOffset, dest.data, destOffset, length);
        
        logOperation("copy", sourceId + " -> " + destId, dest.owner, length, "Copied " + length + " bytes");
    }
    
    public void resizeMemory(String blockId, int newSize) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        if (newSize <= 0) {
            throw new IllegalArgumentException("Invalid new size: " + newSize);
        }
        
        byte[] newData = new byte[newSize];
        int copySize = Math.min(block.data.length, newSize);
        System.arraycopy(block.data, 0, newData, 0, copySize);
        
        block.data = newData;
        block.size = newSize;
        
        logOperation("resize", blockId, block.owner, newSize, "Resized to " + newSize + " bytes");
    }
    
    public void freeMemory(String blockId) {
        MemoryBlock block = memoryBlocks.remove(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        logOperation("free", blockId, block.owner, 0, "Freed " + block.size + " bytes");
    }
    
    public void setMemoryProtection(String blockId, boolean readOnly) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        block.isReadOnly = readOnly;
        
        logOperation("protect", blockId, block.owner, 0, "Set protection to " + (readOnly ? "read-only" : "read-write"));
    }
    
    public ByteBuffer createDirectBuffer(int capacity) {
        if (capacity <= 0) {
            throw new IllegalArgumentException("Invalid capacity: " + capacity);
        }
        
        ByteBuffer buffer = ByteBuffer.allocateDirect(capacity);
        
        logOperation("create_buffer", "direct_" + System.currentTimeMillis(), "system", capacity, "Created direct buffer with capacity " + capacity);
        
        return buffer;
    }
    
    public void writeToBuffer(ByteBuffer buffer, byte[] data, int offset) {
        if (offset < 0 || offset + data.length > buffer.capacity()) {
            System.err.println("Warning: Potential buffer overflow detected");
        }
        
        buffer.position(offset);
        buffer.put(data);
        
        logOperation("write_buffer", "buffer_" + System.identityHashCode(buffer), "system", data.length, "Wrote " + data.length + " bytes to buffer");
    }
    
    public byte[] readFromBuffer(ByteBuffer buffer, int offset, int length) {
        if (offset < 0 || offset + length > buffer.capacity()) {
            System.err.println("Warning: Potential buffer overflow detected");
        }
        
        byte[] result = new byte[length];
        buffer.position(offset);
        buffer.get(result);
        
        logOperation("read_buffer", "buffer_" + System.identityHashCode(buffer), "system", length, "Read " + length + " bytes from buffer");
        
        return result;
    }
    
    public void executeWithMemory(String blockId, String code) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        executor.submit(() -> {
            try {
                System.out.println("Executing code on memory block: " + blockId);
                System.out.println("Code: " + code);
                
                logOperation("execute", blockId, block.owner, 0, "Executed code: " + code);
            } catch (Exception e) {
                System.err.println("Error executing code: " + e.getMessage());
            }
        });
    }
    
    public void performMemoryDump(String blockId, String filename) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        try (FileOutputStream fos = new FileOutputStream(filename)) {
            fos.write(block.data);
            logOperation("dump", blockId, block.owner, block.size, "Dumped memory to " + filename);
        } catch (IOException e) {
            System.err.println("Error dumping memory: " + e.getMessage());
        }
    }
    
    public void performMemoryScan(String pattern) {
        byte[] patternBytes = pattern.getBytes();
        List<String> matches = new ArrayList<>();
        
        for (Map.Entry<String, MemoryBlock> entry : memoryBlocks.entrySet()) {
            MemoryBlock block = entry.getValue();
            
            for (int i = 0; i <= block.data.length - patternBytes.length; i++) {
                boolean match = true;
                for (int j = 0; j < patternBytes.length; j++) {
                    if (block.data[i + j] != patternBytes[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    matches.add(entry.getKey() + ":" + i);
                }
            }
        }
        
        logOperation("scan", "all", "system", matches.size(), "Found " + matches.size() + " matches for pattern: " + pattern);
        
        for (String match : matches) {
            System.out.println("Match found: " + match);
        }
    }
    
    public void performMemoryCorruption(String blockId, int offset, byte[] corruptData) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        if (offset >= 0 && offset + corruptData.length <= block.data.length) {
            System.arraycopy(corruptData, 0, block.data, offset, corruptData.length);
            logOperation("corrupt", blockId, block.owner, corruptData.length, "Corrupted memory at offset " + offset);
        }
    }
    
    public void performUseAfterFree(String blockId) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        memoryBlocks.remove(blockId);
        
        try {
            byte[] data = block.data;
            System.out.println("Accessing freed memory block: " + blockId);
            logOperation("use_after_free", blockId, block.owner, 0, "Accessed freed memory");
        } catch (Exception e) {
            System.err.println("Use-after-free error: " + e.getMessage());
        }
    }
    
    public void performDoubleFree(String blockId) {
        MemoryBlock block = memoryBlocks.get(blockId);
        if (block == null) {
            throw new IllegalArgumentException("Memory block not found: " + blockId);
        }
        
        memoryBlocks.remove(blockId);
        
        try {
            memoryBlocks.remove(blockId);
            logOperation("double_free", blockId, block.owner, 0, "Double free attempted");
        } catch (Exception e) {
            System.err.println("Double-free error: " + e.getMessage());
        }
    }
    
    public List<MemoryBlock> getAllMemoryBlocks() {
        return new ArrayList<>(memoryBlocks.values());
    }
    
    public MemoryBlock getMemoryBlock(String blockId) {
        return memoryBlocks.get(blockId);
    }
    
    public List<MemoryOperation> getOperations() {
        return new ArrayList<>(operations);
    }
    
    private String generateBlockId() {
        return "block_" + System.currentTimeMillis() + "_" + random.nextInt(10000);
    }
    
    private void logOperation(String type, String blockId, String user, int dataSize, String details) {
        MemoryOperation operation = new MemoryOperation(type, blockId, user, dataSize, details);
        operations.add(operation);
        
        System.out.println("[" + operation.timestamp + "] " + type + ": " + blockId + " by " + user + " - " + details);
    }
    
    public void shutdown() {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
        }
    }
    
    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java VulnerableMemoryManager <command> [args...]");
            System.out.println("Commands:");
            System.out.println("  allocate <size> <owner> - Allocate memory");
            System.out.println("  write <block_id> <data> <offset> - Write to memory");
            System.out.println("  read <block_id> <offset> <length> - Read from memory");
            System.out.println("  copy <source_id> <dest_id> <source_offset> <dest_offset> <length> - Copy memory");
            System.out.println("  resize <block_id> <new_size> - Resize memory");
            System.out.println("  free <block_id> - Free memory");
            System.out.println("  protect <block_id> <readonly> - Set memory protection");
            System.out.println("  create_buffer <capacity> - Create direct buffer");
            System.out.println("  write_buffer <data> <offset> - Write to buffer");
            System.out.println("  read_buffer <offset> <length> - Read from buffer");
            System.out.println("  execute <block_id> <code> - Execute code on memory");
            System.out.println("  dump <block_id> <filename> - Dump memory to file");
            System.out.println("  scan <pattern> - Scan memory for pattern");
            System.out.println("  corrupt <block_id> <offset> <data> - Corrupt memory");
            System.out.println("  use_after_free <block_id> - Simulate use-after-free");
            System.out.println("  double_free <block_id> - Simulate double-free");
            System.out.println("  list - List all memory blocks");
            System.out.println("  operations - Show operations");
            return;
        }
        
        VulnerableMemoryManager mm = new VulnerableMemoryManager();
        
        try {
            String command = args[0];
            
            switch (command) {
                case "allocate":
                    if (args.length < 3) {
                        System.out.println("Usage: allocate <size> <owner>");
                        return;
                    }
                    
                    int size = Integer.parseInt(args[1]);
                    String owner = args[2];
                    String blockId = mm.allocateMemory(size, owner);
                    System.out.println("Allocated memory block: " + blockId);
                    break;
                    
                case "write":
                    if (args.length < 4) {
                        System.out.println("Usage: write <block_id> <data> <offset>");
                        return;
                    }
                    
                    String writeBlockId = args[1];
                    byte[] writeData = args[2].getBytes();
                    int writeOffset = Integer.parseInt(args[3]);
                    
                    mm.writeToMemory(writeBlockId, writeData, writeOffset);
                    System.out.println("Data written successfully");
                    break;
                    
                case "read":
                    if (args.length < 4) {
                        System.out.println("Usage: read <block_id> <offset> <length>");
                        return;
                    }
                    
                    String readBlockId = args[1];
                    int readOffset = Integer.parseInt(args[2]);
                    int readLength = Integer.parseInt(args[3]);
                    
                    byte[] readData = mm.readFromMemory(readBlockId, readOffset, readLength);
                    System.out.println("Read data: " + new String(readData));
                    break;
                    
                case "list":
                    List<MemoryBlock> blocks = mm.getAllMemoryBlocks();
                    System.out.println("Memory blocks:");
                    for (MemoryBlock block : blocks) {
                        System.out.println("  " + block.id + " (" + block.size + " bytes, " + (block.isReadOnly ? "read-only" : "read-write") + ")");
                    }
                    break;
                    
                case "operations":
                    List<MemoryOperation> operations = mm.getOperations();
                    System.out.println("Total operations: " + operations.size());
                    for (MemoryOperation op : operations) {
                        System.out.println("[" + op.timestamp + "] " + op.type + ": " + op.blockId + " by " + op.user + " - " + op.details);
                    }
                    break;
                    
                default:
                    System.out.println("Unknown command: " + command);
            }
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
        } finally {
            mm.shutdown();
        }
    }
} 