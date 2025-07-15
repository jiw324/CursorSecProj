package main

import (
	"bufio"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
	"unsafe"
)

type MemoryManager struct {
	blocks     map[string]*MemoryBlock
	mutex      sync.RWMutex
	allocated  int64
	maxSize    int64
	blockCount int
}

type MemoryBlock struct {
	ID        string    `json:"id"`
	Data      []byte    `json:"data"`
	Size      int       `json:"size"`
	Allocated time.Time `json:"allocated"`
	Accessed  time.Time `json:"accessed"`
	Freed     bool      `json:"freed"`
}

type MemoryStats struct {
	TotalAllocated int64  `json:"total_allocated"`
	MaxSize        int64  `json:"max_size"`
	BlockCount     int    `json:"block_count"`
	FreeMemory     uint64 `json:"free_memory"`
	TotalMemory    uint64 `json:"total_memory"`
}

type MemoryOperation struct {
	Type      string    `json:"type"`
	BlockID   string    `json:"block_id"`
	Size      int       `json:"size"`
	Timestamp time.Time `json:"timestamp"`
	Details   string    `json:"details"`
}

func NewMemoryManager(maxSize int64) *MemoryManager {
	return &MemoryManager{
		blocks:    make(map[string]*MemoryBlock),
		maxSize:   maxSize,
		allocated: 0,
	}
}

func (mm *MemoryManager) AllocateMemory(blockID string, size int) (*MemoryBlock, error) {
	if size <= 0 {
		return nil, fmt.Errorf("invalid size: %d", size)
	}
	
	if mm.allocated+int64(size) > mm.maxSize {
		return nil, fmt.Errorf("insufficient memory: requested %d, available %d", size, mm.maxSize-mm.allocated)
	}
	
	data := make([]byte, size)
	
	_, err := rand.Read(data)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize memory: %v", err)
	}
	
	block := &MemoryBlock{
		ID:        blockID,
		Data:      data,
		Size:      size,
		Allocated: time.Now(),
		Accessed:  time.Now(),
		Freed:     false,
	}
	
	mm.mutex.Lock()
	mm.blocks[blockID] = block
	mm.allocated += int64(size)
	mm.blockCount++
	mm.mutex.Unlock()
	
	mm.logOperation("allocate", blockID, size, fmt.Sprintf("Allocated %d bytes", size))
	
	return block, nil
}

func (mm *MemoryManager) ReadMemory(blockID string, offset, length int) ([]byte, error) {
	mm.mutex.RLock()
	block, exists := mm.blocks[blockID]
	mm.mutex.RUnlock()
	
	if !exists {
		return nil, fmt.Errorf("block not found: %s", blockID)
	}
	
	if block.Freed {
		return nil, fmt.Errorf("block already freed: %s", blockID)
	}
	
	if offset < 0 || length < 0 || offset+length > len(block.Data) {
		return nil, fmt.Errorf("invalid read: offset=%d, length=%d, data_size=%d", offset, length, len(block.Data))
	}
	
	result := make([]byte, length)
	copy(result, block.Data[offset:offset+length])
	
	block.Accessed = time.Now()
	
	mm.logOperation("read", blockID, length, fmt.Sprintf("Read %d bytes from offset %d", length, offset))
	
	return result, nil
}

func (mm *MemoryManager) WriteMemory(blockID string, offset int, data []byte) error {
	mm.mutex.RLock()
	block, exists := mm.blocks[blockID]
	mm.mutex.RUnlock()
	
	if !exists {
		return fmt.Errorf("block not found: %s", blockID)
	}
	
	if block.Freed {
		return fmt.Errorf("block already freed: %s", blockID)
	}
	
	if offset < 0 || offset+len(data) > len(block.Data) {
		return fmt.Errorf("invalid write: offset=%d, data_length=%d, block_size=%d", offset, len(data), len(block.Data))
	}
	
	copy(block.Data[offset:], data)
	
	block.Accessed = time.Now()
	
	mm.logOperation("write", blockID, len(data), fmt.Sprintf("Wrote %d bytes at offset %d", len(data), offset))
	
	return nil
}

func (mm *MemoryManager) FreeMemory(blockID string) error {
	mm.mutex.Lock()
	block, exists := mm.blocks[blockID]
	if !exists {
		mm.mutex.Unlock()
		return fmt.Errorf("block not found: %s", blockID)
	}
	
	if block.Freed {
		mm.mutex.Unlock()
		return fmt.Errorf("block already freed: %s", blockID)
	}
	
	block.Freed = true
	mm.allocated -= int64(block.Size)
	mm.blockCount--
	
	mm.mutex.Unlock()
	
	mm.logOperation("free", blockID, block.Size, fmt.Sprintf("Freed %d bytes", block.Size))
	
	return nil
}

func (mm *MemoryManager) ResizeMemory(blockID string, newSize int) error {
	mm.mutex.Lock()
	block, exists := mm.blocks[blockID]
	if !exists {
		mm.mutex.Unlock()
		return fmt.Errorf("block not found: %s", blockID)
	}
	
	if block.Freed {
		mm.mutex.Unlock()
		return fmt.Errorf("block already freed: %s", blockID)
	}
	
	if newSize <= 0 {
		mm.mutex.Unlock()
		return fmt.Errorf("invalid new size: %d", newSize)
	}
	
	sizeDiff := newSize - block.Size
	if mm.allocated+int64(sizeDiff) > mm.maxSize {
		mm.mutex.Unlock()
		return fmt.Errorf("insufficient memory for resize: requested %d, available %d", sizeDiff, mm.maxSize-mm.allocated)
	}
	
	newData := make([]byte, newSize)
	copy(newData, block.Data)
	
	block.Data = newData
	block.Size = newSize
	mm.allocated += int64(sizeDiff)
	
	mm.mutex.Unlock()
	
	mm.logOperation("resize", blockID, newSize, fmt.Sprintf("Resized from %d to %d bytes", block.Size-sizeDiff, newSize))
	
	return nil
}

func (mm *MemoryManager) GetMemoryStats() *MemoryStats {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	
	mm.mutex.RLock()
	stats := &MemoryStats{
		TotalAllocated: mm.allocated,
		MaxSize:        mm.maxSize,
		BlockCount:     mm.blockCount,
		FreeMemory:     m.Frees,
		TotalMemory:    m.TotalAlloc,
	}
	mm.mutex.RUnlock()
	
	return stats
}

func (mm *MemoryManager) ListBlocks() []*MemoryBlock {
	mm.mutex.RLock()
	blocks := make([]*MemoryBlock, 0, len(mm.blocks))
	for _, block := range mm.blocks {
		blocks = append(blocks, block)
	}
	mm.mutex.RUnlock()
	
	return blocks
}

func (mm *MemoryManager) SearchMemory(pattern []byte) []*MemoryBlock {
	var results []*MemoryBlock
	
	mm.mutex.RLock()
	for _, block := range mm.blocks {
		if block.Freed {
			continue
		}
		
		if bytesContains(block.Data, pattern) {
			results = append(results, block)
		}
	}
	mm.mutex.RUnlock()
	
	return results
}

func (mm *MemoryManager) CopyMemory(sourceID, destID string, sourceOffset, destOffset, length int) error {
	mm.mutex.RLock()
	sourceBlock, exists := mm.blocks[sourceID]
	if !exists {
		mm.mutex.RUnlock()
		return fmt.Errorf("source block not found: %s", sourceID)
	}
	
	destBlock, exists := mm.blocks[destID]
	if !exists {
		mm.mutex.RUnlock()
		return fmt.Errorf("destination block not found: %s", destID)
	}
	
	if sourceBlock.Freed || destBlock.Freed {
		mm.mutex.RUnlock()
		return fmt.Errorf("block already freed")
	}
	
	if sourceOffset < 0 || destOffset < 0 || length < 0 ||
		sourceOffset+length > len(sourceBlock.Data) ||
		destOffset+length > len(destBlock.Data) {
		mm.mutex.RUnlock()
		return fmt.Errorf("invalid copy: source_offset=%d, dest_offset=%d, length=%d", sourceOffset, destOffset, length)
	}
	
	copy(destBlock.Data[destOffset:], sourceBlock.Data[sourceOffset:sourceOffset+length])
	
	sourceBlock.Accessed = time.Now()
	destBlock.Accessed = time.Now()
	
	mm.mutex.RUnlock()
	
	mm.logOperation("copy", fmt.Sprintf("%s->%s", sourceID, destID), length, fmt.Sprintf("Copied %d bytes", length))
	
	return nil
}

func (mm *MemoryManager) SetMemory(blockID string, offset int, value byte, count int) error {
	mm.mutex.RLock()
	block, exists := mm.blocks[blockID]
	mm.mutex.RUnlock()
	
	if !exists {
		return fmt.Errorf("block not found: %s", blockID)
	}
	
	if block.Freed {
		return fmt.Errorf("block already freed: %s", blockID)
	}
	
	if offset < 0 || count < 0 || offset+count > len(block.Data) {
		return fmt.Errorf("invalid set: offset=%d, count=%d, block_size=%d", offset, count, len(block.Data))
	}
	
	for i := 0; i < count; i++ {
		block.Data[offset+i] = value
	}
	
	block.Accessed = time.Now()
	
	mm.logOperation("set", blockID, count, fmt.Sprintf("Set %d bytes to %d at offset %d", count, value, offset))
	
	return nil
}

func (mm *MemoryManager) CompareMemory(blockID1, blockID2 string, offset1, offset2, length int) (bool, error) {
	mm.mutex.RLock()
	block1, exists := mm.blocks[blockID1]
	if !exists {
		mm.mutex.RUnlock()
		return false, fmt.Errorf("block1 not found: %s", blockID1)
	}
	
	block2, exists := mm.blocks[blockID2]
	if !exists {
		mm.mutex.RUnlock()
		return false, fmt.Errorf("block2 not found: %s", blockID2)
	}
	
	if block1.Freed || block2.Freed {
		mm.mutex.RUnlock()
		return false, fmt.Errorf("block already freed")
	}
	
	if offset1 < 0 || offset2 < 0 || length < 0 ||
		offset1+length > len(block1.Data) ||
		offset2+length > len(block2.Data) {
		mm.mutex.RUnlock()
		return false, fmt.Errorf("invalid compare: offset1=%d, offset2=%d, length=%d", offset1, offset2, length)
	}
	
	equal := bytesEqual(block1.Data[offset1:offset1+length], block2.Data[offset2:offset2+length])
	
	block1.Accessed = time.Now()
	block2.Accessed = time.Now()
	
	mm.mutex.RUnlock()
	
	mm.logOperation("compare", fmt.Sprintf("%s-%s", blockID1, blockID2), length, fmt.Sprintf("Compared %d bytes", length))
	
	return equal, nil
}

func (mm *MemoryManager) logOperation(opType, blockID string, size int, details string) {
	operation := MemoryOperation{
		Type:      opType,
		BlockID:   blockID,
		Size:      size,
		Timestamp: time.Now(),
		Details:   details,
	}
	
	fmt.Printf("[%s] %s: %s (size=%d) - %s\n",
		operation.Timestamp.Format("2006-01-02 15:04:05"),
		operation.Type, operation.BlockID, operation.Size, operation.Details)
}

func bytesContains(data, pattern []byte) bool {
	return strings.Contains(string(data), string(pattern))
}

func bytesEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <command> [args...]")
		fmt.Println("Commands:")
		fmt.Println("  allocate <block_id> <size> - Allocate memory block")
		fmt.Println("  read <block_id> <offset> <length> - Read from memory")
		fmt.Println("  write <block_id> <offset> <data> - Write to memory")
		fmt.Println("  free <block_id> - Free memory block")
		fmt.Println("  resize <block_id> <new_size> - Resize memory block")
		fmt.Println("  list - List all memory blocks")
		fmt.Println("  stats - Show memory statistics")
		fmt.Println("  search <pattern> - Search memory for pattern")
		fmt.Println("  copy <source_id> <dest_id> <source_offset> <dest_offset> <length> - Copy memory")
		fmt.Println("  set <block_id> <offset> <value> <count> - Set memory bytes")
		fmt.Println("  compare <block_id1> <block_id2> <offset1> <offset2> <length> - Compare memory")
		return
	}
	
	mm := NewMemoryManager(1024 * 1024 * 100)
	
	command := os.Args[1]
	
	switch command {
	case "allocate":
		if len(os.Args) < 4 {
			fmt.Println("Usage: allocate <block_id> <size>")
			return
		}
		
		blockID := os.Args[2]
		size, err := strconv.Atoi(os.Args[3])
		if err != nil {
			fmt.Println("Invalid size")
			return
		}
		
		block, err := mm.AllocateMemory(blockID, size)
		if err != nil {
			fmt.Printf("Error allocating memory: %v\n", err)
		} else {
			fmt.Printf("Allocated block %s with %d bytes\n", block.ID, block.Size)
		}
		
	case "read":
		if len(os.Args) < 5 {
			fmt.Println("Usage: read <block_id> <offset> <length>")
			return
		}
		
		blockID := os.Args[2]
		offset, err := strconv.Atoi(os.Args[3])
		if err != nil {
			fmt.Println("Invalid offset")
			return
		}
		length, err := strconv.Atoi(os.Args[4])
		if err != nil {
			fmt.Println("Invalid length")
			return
		}
		
		data, err := mm.ReadMemory(blockID, offset, length)
		if err != nil {
			fmt.Printf("Error reading memory: %v\n", err)
		} else {
			fmt.Printf("Read %d bytes: %x\n", len(data), data)
		}
		
	case "write":
		if len(os.Args) < 5 {
			fmt.Println("Usage: write <block_id> <offset> <data>")
			return
		}
		
		blockID := os.Args[2]
		offset, err := strconv.Atoi(os.Args[3])
		if err != nil {
			fmt.Println("Invalid offset")
			return
		}
		data := []byte(os.Args[4])
		
		err = mm.WriteMemory(blockID, offset, data)
		if err != nil {
			fmt.Printf("Error writing memory: %v\n", err)
		} else {
			fmt.Printf("Wrote %d bytes to block %s\n", len(data), blockID)
		}
		
	case "free":
		if len(os.Args) < 3 {
			fmt.Println("Usage: free <block_id>")
			return
		}
		
		blockID := os.Args[2]
		
		err := mm.FreeMemory(blockID)
		if err != nil {
			fmt.Printf("Error freeing memory: %v\n", err)
		} else {
			fmt.Printf("Freed block %s\n", blockID)
		}
		
	case "resize":
		if len(os.Args) < 4 {
			fmt.Println("Usage: resize <block_id> <new_size>")
			return
		}
		
		blockID := os.Args[2]
		newSize, err := strconv.Atoi(os.Args[3])
		if err != nil {
			fmt.Println("Invalid new size")
			return
		}
		
		err = mm.ResizeMemory(blockID, newSize)
		if err != nil {
			fmt.Printf("Error resizing memory: %v\n", err)
		} else {
			fmt.Printf("Resized block %s to %d bytes\n", blockID, newSize)
		}
		
	case "list":
		blocks := mm.ListBlocks()
		fmt.Printf("Total blocks: %d\n", len(blocks))
		for _, block := range blocks {
			fmt.Printf("ID: %s, Size: %d, Freed: %v, Allocated: %s\n",
				block.ID, block.Size, block.Freed, block.Allocated.Format("2006-01-02 15:04:05"))
		}
		
	case "stats":
		stats := mm.GetMemoryStats()
		statsJSON, _ := json.MarshalIndent(stats, "", "  ")
		fmt.Println(string(statsJSON))
		
	case "search":
		if len(os.Args) < 3 {
			fmt.Println("Usage: search <pattern>")
			return
		}
		
		pattern := []byte(os.Args[2])
		
		results := mm.SearchMemory(pattern)
		fmt.Printf("Found %d blocks containing pattern\n", len(results))
		for _, block := range results {
			fmt.Printf("  Block: %s, Size: %d\n", block.ID, block.Size)
		}
		
	default:
		fmt.Println("Unknown command:", command)
	}
} 