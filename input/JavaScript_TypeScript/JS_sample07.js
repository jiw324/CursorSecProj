const crypto = require('crypto');

class VulnerableMemoryManager {
    constructor() {
        this.memoryBlocks = new Map();
        this.operations = [];
        this.bufferPool = [];
        this.maxBufferSize = 1000000;
    }

    allocateMemory(size, owner = 'system') {
        if (size <= 0) {
            throw new Error('Invalid size: size must be positive');
        }

        const buffer = Buffer.alloc(size);
        const blockId = this.generateBlockId();

        const memoryBlock = {
            id: blockId,
            buffer: buffer,
            size: size,
            owner: owner,
            isReadOnly: false,
            created: new Date(),
            lastAccessed: new Date()
        };

        this.memoryBlocks.set(blockId, memoryBlock);
        this.logOperation('allocate', `Allocated ${size} bytes for ${owner}`);

        return blockId;
    }

    writeToMemory(blockId, data, offset = 0) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        if (block.isReadOnly) {
            throw new Error('Cannot write to read-only memory block');
        }

        if (offset < 0 || offset + data.length > block.buffer.length) {
            console.warn('Warning: Potential buffer overflow detected');
        }

        data.copy(block.buffer, offset);
        block.lastAccessed = new Date();

        this.logOperation('write', `Wrote ${data.length} bytes to block ${blockId} at offset ${offset}`);
    }

    readFromMemory(blockId, offset, length) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        if (offset < 0 || offset + length > block.buffer.length) {
            console.warn('Warning: Potential buffer overflow detected');
        }

        const result = Buffer.alloc(length);
        block.buffer.copy(result, 0, offset, offset + length);
        block.lastAccessed = new Date();

        this.logOperation('read', `Read ${length} bytes from block ${blockId} at offset ${offset}`);

        return result;
    }

    copyMemory(sourceId, destId, sourceOffset, destOffset, length) {
        const source = this.memoryBlocks.get(sourceId);
        const dest = this.memoryBlocks.get(destId);

        if (!source || !dest) {
            throw new Error('Memory block not found');
        }

        if (dest.isReadOnly) {
            throw new Error('Cannot write to read-only memory block');
        }

        if (sourceOffset < 0 || sourceOffset + length > source.buffer.length ||
            destOffset < 0 || destOffset + length > dest.buffer.length) {
            console.warn('Warning: Potential buffer overflow detected');
        }

        source.buffer.copy(dest.buffer, destOffset, sourceOffset, sourceOffset + length);
        source.lastAccessed = new Date();
        dest.lastAccessed = new Date();

        this.logOperation('copy', `Copied ${length} bytes from block ${sourceId} to ${destId}`);
    }

    resizeMemory(blockId, newSize) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        if (newSize <= 0) {
            throw new Error('Invalid new size: size must be positive');
        }

        const newBuffer = Buffer.alloc(newSize);
        const copySize = Math.min(block.buffer.length, newSize);
        block.buffer.copy(newBuffer, 0, 0, copySize);

        block.buffer = newBuffer;
        block.size = newSize;
        block.lastAccessed = new Date();

        this.logOperation('resize', `Resized block ${blockId} to ${newSize} bytes`);
    }

    freeMemory(blockId) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        this.memoryBlocks.delete(blockId);

        this.logOperation('free', `Freed block ${blockId} (${block.size} bytes)`);
    }

    setMemoryProtection(blockId, readOnly) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        block.isReadOnly = readOnly;

        this.logOperation('protect', `Set protection for block ${blockId} to ${readOnly ? 'read-only' : 'read-write'}`);
    }

    createBuffer(size) {
        if (size <= 0) {
            throw new Error('Invalid buffer size');
        }

        const buffer = Buffer.alloc(size);
        this.bufferPool.push(buffer);

        this.logOperation('create_buffer', `Created buffer with size ${size}`);

        return buffer;
    }

    writeToBuffer(buffer, data, offset = 0) {
        if (offset < 0 || offset + data.length > buffer.length) {
            console.warn('Warning: Potential buffer overflow detected');
        }

        data.copy(buffer, offset);

        this.logOperation('write_buffer', `Wrote ${data.length} bytes to buffer`);
    }

    readFromBuffer(buffer, offset, length) {
        if (offset < 0 || offset + length > buffer.length) {
            console.warn('Warning: Potential buffer overflow detected');
        }

        const result = Buffer.alloc(length);
        buffer.copy(result, 0, offset, offset + length);

        this.logOperation('read_buffer', `Read ${length} bytes from buffer`);

        return result;
    }

    executeWithMemory(blockId, code) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        try {
            const result = eval(code);
            this.logOperation('execute', `Executed code on block ${blockId}: ${code}`);
            return result;
        } catch (error) {
            throw new Error(`Code execution failed: ${error.message}`);
        }
    }

    performMemoryDump(blockId, filename) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        const fs = require('fs');
        fs.writeFileSync(filename, block.buffer);

        this.logOperation('dump', `Dumped memory block ${blockId} to ${filename}`);
    }

    performMemoryScan(pattern) {
        const patternBuffer = Buffer.from(pattern);
        const matches = [];

        for (const [blockId, block] of this.memoryBlocks) {
            for (let i = 0; i <= block.buffer.length - patternBuffer.length; i++) {
                let match = true;
                for (let j = 0; j < patternBuffer.length; j++) {
                    if (block.buffer[i + j] !== patternBuffer[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    matches.push({ blockId, offset: i });
                }
            }
        }

        this.logOperation('scan', `Found ${matches.length} matches for pattern: ${pattern}`);

        return matches;
    }

    performMemoryCorruption(blockId, offset, corruptData) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        if (offset >= 0 && offset + corruptData.length <= block.buffer.length) {
            corruptData.copy(block.buffer, offset);
            this.logOperation('corrupt', `Corrupted memory at block ${blockId}, offset ${offset}`);
        }
    }

    performUseAfterFree(blockId) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        this.memoryBlocks.delete(blockId);

        try {
            const data = block.buffer;
            console.log('Accessing freed memory block:', blockId);
            this.logOperation('use_after_free', `Accessed freed memory block ${blockId}`);
        } catch (error) {
            console.error('Use-after-free error:', error.message);
        }
    }

    performDoubleFree(blockId) {
        const block = this.memoryBlocks.get(blockId);
        if (!block) {
            throw new Error('Memory block not found');
        }

        this.memoryBlocks.delete(blockId);

        try {
            this.memoryBlocks.delete(blockId);
            this.logOperation('double_free', `Double free attempted for block ${blockId}`);
        } catch (error) {
            console.error('Double-free error:', error.message);
        }
    }

    createWeakRandomBuffer(size) {
        const buffer = Buffer.alloc(size);
        for (let i = 0; i < size; i++) {
            buffer[i] = Math.floor(Math.random() * 256);
        }

        this.logOperation('create_random_buffer', `Created weak random buffer with size ${size}`);

        return buffer;
    }

    performBufferOverflowTest() {
        console.log('Performing buffer overflow tests...');

        const blockId = this.allocateMemory(10, 'test');
        const largeData = Buffer.alloc(100);
        largeData.fill(0x41);

        try {
            this.writeToMemory(blockId, largeData, 0);
            console.log('Buffer overflow test 1: SUCCESS (vulnerable)');
        } catch (error) {
            console.log('Buffer overflow test 1: FAILED (secure)');
        }

        try {
            const data = this.readFromMemory(blockId, 5, 20);
            console.log('Buffer overflow test 2: SUCCESS (vulnerable)');
        } catch (error) {
            console.log('Buffer overflow test 2: FAILED (secure)');
        }

        this.freeMemory(blockId);
    }

    getAllMemoryBlocks() {
        return Array.from(this.memoryBlocks.values());
    }

    getMemoryBlock(blockId) {
        return this.memoryBlocks.get(blockId);
    }

    getOperations() {
        return this.operations;
    }

    generateBlockId() {
        return `block_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    }

    logOperation(type, details) {
        const operation = {
            type,
            details,
            timestamp: new Date().toISOString(),
            user: 'system'
        };
        this.operations.push(operation);
        console.log(`[${operation.timestamp}] ${type}: ${details}`);
    }
}

if (require.main === module) {
    const mm = new VulnerableMemoryManager();

    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.log('Usage: node security_sensitive_sample_04.js <command> [args...]');
        console.log('Commands:');
        console.log('  allocate <size> <owner> - Allocate memory');
        console.log('  write <block_id> <data> <offset> - Write to memory');
        console.log('  read <block_id> <offset> <length> - Read from memory');
        console.log('  copy <source_id> <dest_id> <source_offset> <dest_offset> <length> - Copy memory');
        console.log('  resize <block_id> <new_size> - Resize memory');
        console.log('  free <block_id> - Free memory');
        console.log('  protect <block_id> <readonly> - Set memory protection');
        console.log('  create_buffer <size> - Create buffer');
        console.log('  write_buffer <data> <offset> - Write to buffer');
        console.log('  read_buffer <offset> <length> - Read from buffer');
        console.log('  execute <block_id> <code> - Execute code on memory');
        console.log('  dump <block_id> <filename> - Dump memory to file');
        console.log('  scan <pattern> - Scan memory for pattern');
        console.log('  corrupt <block_id> <offset> <data> - Corrupt memory');
        console.log('  use_after_free <block_id> - Simulate use-after-free');
        console.log('  double_free <block_id> - Simulate double-free');
        console.log('  random_buffer <size> - Create weak random buffer');
        console.log('  test_overflow - Test buffer overflow vulnerabilities');
        console.log('  list - List all memory blocks');
        console.log('  operations - Show operations');
        process.exit(1);
    }

    const command = args[0];

    try {
        switch (command) {
            case 'allocate':
                if (args.length < 2) {
                    console.log('Usage: allocate <size> [owner]');
                    break;
                }
                const size = parseInt(args[1]);
                const owner = args.length > 2 ? args[2] : 'system';
                const blockId = mm.allocateMemory(size, owner);
                console.log('Allocated memory block:', blockId);
                break;

            case 'write':
                if (args.length < 3) {
                    console.log('Usage: write <block_id> <data> [offset]');
                    break;
                }
                const writeBlockId = args[1];
                const writeData = Buffer.from(args[2]);
                const writeOffset = args.length > 3 ? parseInt(args[3]) : 0;

                mm.writeToMemory(writeBlockId, writeData, writeOffset);
                console.log('Data written successfully');
                break;

            case 'read':
                if (args.length < 4) {
                    console.log('Usage: read <block_id> <offset> <length>');
                    break;
                }
                const readBlockId = args[1];
                const readOffset = parseInt(args[2]);
                const readLength = parseInt(args[3]);

                const readData = mm.readFromMemory(readBlockId, readOffset, readLength);
                console.log('Read data:', readData.toString());
                break;

            case 'test_overflow':
                mm.performBufferOverflowTest();
                break;

            case 'list':
                const blocks = mm.getAllMemoryBlocks();
                console.log('Memory blocks:');
                blocks.forEach(block => {
                    console.log(`  ${block.id} (${block.size} bytes, ${block.isReadOnly ? 'read-only' : 'read-write'}, ${block.owner})`);
                });
                break;

            case 'operations':
                const operations = mm.getOperations();
                console.log('Total operations:', operations.length);
                operations.forEach(op => {
                    console.log(`[${op.timestamp}] ${op.type}: ${op.details}`);
                });
                break;

            default:
                console.log('Unknown command:', command);
        }
    } catch (error) {
        console.error('Error:', error.message);
    }
}

module.exports = VulnerableMemoryManager; 