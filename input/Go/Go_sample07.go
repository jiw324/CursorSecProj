package main

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type FileManager struct {
	rootDir    string
	uploadDir  string
	tempDir    string
	fileCache  map[string]FileInfo
	operations []Operation
}

type FileInfo struct {
	Name         string    `json:"name"`
	Path         string    `json:"path"`
	Size         int64     `json:"size"`
	ModTime      time.Time `json:"mod_time"`
	IsDir        bool      `json:"is_dir"`
	Permissions  string    `json:"permissions"`
	MD5Hash      string    `json:"md5_hash"`
	ContentType  string    `json:"content_type"`
}

type Operation struct {
	Type      string    `json:"type"`
	Path      string    `json:"path"`
	User      string    `json:"user"`
	Timestamp time.Time `json:"timestamp"`
	Details   string    `json:"details"`
}

type SearchResult struct {
	Query   string     `json:"query"`
	Results []FileInfo `json:"results"`
	Count   int        `json:"count"`
}

func NewFileManager(rootDir string) *FileManager {
	return &FileManager{
		rootDir:    rootDir,
		uploadDir:  filepath.Join(rootDir, "uploads"),
		tempDir:    filepath.Join(rootDir, "temp"),
		fileCache:  make(map[string]FileInfo),
		operations: make([]Operation, 0),
	}
}

func (fm *FileManager) Initialize() error {
	dirs := []string{fm.rootDir, fm.uploadDir, fm.tempDir}
	
	for _, dir := range dirs {
		err := os.MkdirAll(dir, 0755)
		if err != nil {
			return fmt.Errorf("failed to create directory %s: %v", dir, err)
		}
	}
	
	return nil
}

func (fm *FileManager) ReadFile(path string) ([]byte, error) {
	fullPath := filepath.Join(fm.rootDir, path)
	
	content, err := os.ReadFile(fullPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read file %s: %v", path, err)
	}
	
	fm.logOperation("read", path, "anonymous", fmt.Sprintf("Read %d bytes", len(content)))
	
	return content, nil
}

func (fm *FileManager) WriteFile(path string, content []byte) error {
	fullPath := filepath.Join(fm.rootDir, path)
	
	parentDir := filepath.Dir(fullPath)
	err := os.MkdirAll(parentDir, 0755)
	if err != nil {
		return fmt.Errorf("failed to create parent directory: %v", err)
	}
	
	err = os.WriteFile(fullPath, content, 0644)
	if err != nil {
		return fmt.Errorf("failed to write file %s: %v", path, err)
	}
	
	fm.logOperation("write", path, "anonymous", fmt.Sprintf("Wrote %d bytes", len(content)))
	
	return nil
}

func (fm *FileManager) CopyFile(source, destination string) error {
	sourcePath := filepath.Join(fm.rootDir, source)
	destPath := filepath.Join(fm.rootDir, destination)
	
	sourceFile, err := os.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("failed to open source file: %v", err)
	}
	defer sourceFile.Close()
	
	parentDir := filepath.Dir(destPath)
	err = os.MkdirAll(parentDir, 0755)
	if err != nil {
		return fmt.Errorf("failed to create parent directory: %v", err)
	}
	
	destFile, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %v", err)
	}
	defer destFile.Close()
	
	_, err = io.Copy(destFile, sourceFile)
	if err != nil {
		return fmt.Errorf("failed to copy file: %v", err)
	}
	
	fm.logOperation("copy", fmt.Sprintf("%s -> %s", source, destination), "anonymous", "File copied")
	
	return nil
}

func (fm *FileManager) MoveFile(source, destination string) error {
	sourcePath := filepath.Join(fm.rootDir, source)
	destPath := filepath.Join(fm.rootDir, destination)
	
	parentDir := filepath.Dir(destPath)
	err := os.MkdirAll(parentDir, 0755)
	if err != nil {
		return fmt.Errorf("failed to create parent directory: %v", err)
	}
	
	err = os.Rename(sourcePath, destPath)
	if err != nil {
		return fmt.Errorf("failed to move file: %v", err)
	}
	
	fm.logOperation("move", fmt.Sprintf("%s -> %s", source, destination), "anonymous", "File moved")
	
	return nil
}

func (fm *FileManager) DeleteFile(path string) error {
	fullPath := filepath.Join(fm.rootDir, path)
	
	err := os.Remove(fullPath)
	if err != nil {
		return fmt.Errorf("failed to delete file %s: %v", path, err)
	}
	
	fm.logOperation("delete", path, "anonymous", "File deleted")
	
	return nil
}

func (fm *FileManager) CreateDirectory(path string) error {
	fullPath := filepath.Join(fm.rootDir, path)
	
	err := os.MkdirAll(fullPath, 0755)
	if err != nil {
		return fmt.Errorf("failed to create directory %s: %v", path, err)
	}
	
	fm.logOperation("create_dir", path, "anonymous", "Directory created")
	
	return nil
}

func (fm *FileManager) ListDirectory(path string) ([]FileInfo, error) {
	fullPath := filepath.Join(fm.rootDir, path)
	
	entries, err := os.ReadDir(fullPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read directory %s: %v", path, err)
	}
	
	var files []FileInfo
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			continue
		}
		
		filePath := filepath.Join(path, entry.Name())
		fileInfo := FileInfo{
			Name:        entry.Name(),
			Path:        filePath,
			Size:        info.Size(),
			ModTime:     info.ModTime(),
			IsDir:       entry.IsDir(),
			Permissions: info.Mode().String(),
		}
		
		if !entry.IsDir() {
			hash, err := fm.calculateMD5(filePath)
			if err == nil {
				fileInfo.MD5Hash = hash
			}
		}
		
		files = append(files, fileInfo)
	}
	
	fm.logOperation("list", path, "anonymous", fmt.Sprintf("Listed %d items", len(files)))
	
	return files, nil
}

func (fm *FileManager) SearchFiles(query string, rootPath string) (*SearchResult, error) {
	var results []FileInfo
	
	err := filepath.Walk(filepath.Join(fm.rootDir, rootPath), func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		if strings.Contains(strings.ToLower(info.Name()), strings.ToLower(query)) {
			relativePath, _ := filepath.Rel(fm.rootDir, path)
			fileInfo := FileInfo{
				Name:        info.Name(),
				Path:        relativePath,
				Size:        info.Size(),
				ModTime:     info.ModTime(),
				IsDir:       info.IsDir(),
				Permissions: info.Mode().String(),
			}
			
			if !info.IsDir() {
				hash, err := fm.calculateMD5(relativePath)
				if err == nil {
					fileInfo.MD5Hash = hash
				}
			}
			
			results = append(results, fileInfo)
		}
		
		return nil
	})
	
	if err != nil {
		return nil, fmt.Errorf("failed to search files: %v", err)
	}
	
	searchResult := &SearchResult{
		Query:   query,
		Results: results,
		Count:   len(results),
	}
	
	fm.logOperation("search", rootPath, "anonymous", fmt.Sprintf("Found %d files matching '%s'", len(results), query))
	
	return searchResult, nil
}

func (fm *FileManager) GetFileInfo(path string) (*FileInfo, error) {
	fullPath := filepath.Join(fm.rootDir, path)
	
	info, err := os.Stat(fullPath)
	if err != nil {
		return nil, fmt.Errorf("failed to get file info for %s: %v", path, err)
	}
	
	fileInfo := &FileInfo{
		Name:        info.Name(),
		Path:        path,
		Size:        info.Size(),
		ModTime:     info.ModTime(),
		IsDir:       info.IsDir(),
		Permissions: info.Mode().String(),
	}
	
	if !info.IsDir() {
		hash, err := fm.calculateMD5(path)
		if err == nil {
			fileInfo.MD5Hash = hash
		}
	}
	
	fm.logOperation("info", path, "anonymous", "File info retrieved")
	
	return fileInfo, nil
}

func (fm *FileManager) UploadFile(filename string, content []byte) error {
	uploadPath := filepath.Join(fm.uploadDir, filename)
	
	err := os.WriteFile(uploadPath, content, 0644)
	if err != nil {
		return fmt.Errorf("failed to upload file: %v", err)
	}
	
	fm.logOperation("upload", filename, "anonymous", fmt.Sprintf("Uploaded %d bytes", len(content)))
	
	return nil
}

func (fm *FileManager) calculateMD5(path string) (string, error) {
	fullPath := filepath.Join(fm.rootDir, path)
	
	file, err := os.Open(fullPath)
	if err != nil {
		return "", err
	}
	defer file.Close()
	
	hash := md5.New()
	_, err = io.Copy(hash, file)
	if err != nil {
		return "", err
	}
	
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func (fm *FileManager) logOperation(opType, path, user, details string) {
	operation := Operation{
		Type:      opType,
		Path:      path,
		User:      user,
		Timestamp: time.Now(),
		Details:   details,
	}
	
	fm.operations = append(fm.operations, operation)
	
	fm.writeLogEntry(operation)
}

func (fm *FileManager) writeLogEntry(operation Operation) {
	logFile := filepath.Join(fm.rootDir, "file_operations.log")
	
	entry := fmt.Sprintf("[%s] %s: %s by %s - %s\n",
		operation.Timestamp.Format("2006-01-02 15:04:05"),
		operation.Type,
		operation.Path,
		operation.User,
		operation.Details)
	
	file, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer file.Close()
	
	file.WriteString(entry)
}

func (fm *FileManager) GetOperations() []Operation {
	return fm.operations
}

func (fm *FileManager) ExportOperations() ([]byte, error) {
	return json.MarshalIndent(fm.operations, "", "  ")
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <command> [args...]")
		fmt.Println("Commands:")
		fmt.Println("  read <path> - Read file")
		fmt.Println("  write <path> <content> - Write file")
		fmt.Println("  copy <source> <destination> - Copy file")
		fmt.Println("  move <source> <destination> - Move file")
		fmt.Println("  delete <path> - Delete file")
		fmt.Println("  mkdir <path> - Create directory")
		fmt.Println("  list <path> - List directory")
		fmt.Println("  search <query> [root_path] - Search files")
		fmt.Println("  info <path> - Get file info")
		fmt.Println("  upload <filename> <content> - Upload file")
		fmt.Println("  operations - Show operations")
		fmt.Println("  export - Export operations")
		return
	}
	
	fm := NewFileManager(".")
	err := fm.Initialize()
	if err != nil {
		log.Fatal(err)
	}
	
	command := os.Args[1]
	
	switch command {
	case "read":
		if len(os.Args) < 3 {
			fmt.Println("Usage: read <path>")
			return
		}
		
		path := os.Args[2]
		content, err := fm.ReadFile(path)
		if err != nil {
			fmt.Printf("Error reading file: %v\n", err)
		} else {
			fmt.Printf("File content:\n%s\n", string(content))
		}
		
	case "write":
		if len(os.Args) < 4 {
			fmt.Println("Usage: write <path> <content>")
			return
		}
		
		path := os.Args[2]
		content := os.Args[3]
		
		err := fm.WriteFile(path, []byte(content))
		if err != nil {
			fmt.Printf("Error writing file: %v\n", err)
		} else {
			fmt.Println("File written successfully")
		}
		
	case "copy":
		if len(os.Args) < 4 {
			fmt.Println("Usage: copy <source> <destination>")
			return
		}
		
		source := os.Args[2]
		destination := os.Args[3]
		
		err := fm.CopyFile(source, destination)
		if err != nil {
			fmt.Printf("Error copying file: %v\n", err)
		} else {
			fmt.Println("File copied successfully")
		}
		
	case "move":
		if len(os.Args) < 4 {
			fmt.Println("Usage: move <source> <destination>")
			return
		}
		
		source := os.Args[2]
		destination := os.Args[3]
		
		err := fm.MoveFile(source, destination)
		if err != nil {
			fmt.Printf("Error moving file: %v\n", err)
		} else {
			fmt.Println("File moved successfully")
		}
		
	case "delete":
		if len(os.Args) < 3 {
			fmt.Println("Usage: delete <path>")
			return
		}
		
		path := os.Args[2]
		
		err := fm.DeleteFile(path)
		if err != nil {
			fmt.Printf("Error deleting file: %v\n", err)
		} else {
			fmt.Println("File deleted successfully")
		}
		
	case "mkdir":
		if len(os.Args) < 3 {
			fmt.Println("Usage: mkdir <path>")
			return
		}
		
		path := os.Args[2]
		
		err := fm.CreateDirectory(path)
		if err != nil {
			fmt.Printf("Error creating directory: %v\n", err)
		} else {
			fmt.Println("Directory created successfully")
		}
		
	case "list":
		if len(os.Args) < 3 {
			fmt.Println("Usage: list <path>")
			return
		}
		
		path := os.Args[2]
		
		files, err := fm.ListDirectory(path)
		if err != nil {
			fmt.Printf("Error listing directory: %v\n", err)
		} else {
			for _, file := range files {
				fmt.Printf("%s\t%d\t%s\t%s\n", file.Name, file.Size, file.ModTime.Format("2006-01-02 15:04:05"), file.Permissions)
			}
		}
		
	case "search":
		if len(os.Args) < 3 {
			fmt.Println("Usage: search <query> [root_path]")
			return
		}
		
		query := os.Args[2]
		rootPath := "."
		if len(os.Args) > 3 {
			rootPath = os.Args[3]
		}
		
		results, err := fm.SearchFiles(query, rootPath)
		if err != nil {
			fmt.Printf("Error searching files: %v\n", err)
		} else {
			fmt.Printf("Found %d files matching '%s':\n", results.Count, query)
			for _, file := range results.Results {
				fmt.Printf("  %s\n", file.Path)
			}
		}
		
	case "info":
		if len(os.Args) < 3 {
			fmt.Println("Usage: info <path>")
			return
		}
		
		path := os.Args[2]
		
		info, err := fm.GetFileInfo(path)
		if err != nil {
			fmt.Printf("Error getting file info: %v\n", err)
		} else {
			infoJSON, _ := json.MarshalIndent(info, "", "  ")
			fmt.Println(string(infoJSON))
		}
		
	case "upload":
		if len(os.Args) < 4 {
			fmt.Println("Usage: upload <filename> <content>")
			return
		}
		
		filename := os.Args[2]
		content := os.Args[3]
		
		err := fm.UploadFile(filename, []byte(content))
		if err != nil {
			fmt.Printf("Error uploading file: %v\n", err)
		} else {
			fmt.Println("File uploaded successfully")
		}
		
	case "operations":
		operations := fm.GetOperations()
		fmt.Printf("Total operations: %d\n", len(operations))
		for _, op := range operations {
			fmt.Printf("[%s] %s: %s by %s - %s\n",
				op.Timestamp.Format("2006-01-02 15:04:05"),
				op.Type, op.Path, op.User, op.Details)
		}
		
	case "export":
		data, err := fm.ExportOperations()
		if err != nil {
			fmt.Printf("Error exporting operations: %v\n", err)
		} else {
			fmt.Println(string(data))
		}
		
	default:
		fmt.Println("Unknown command:", command)
	}
} 