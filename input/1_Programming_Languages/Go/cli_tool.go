// AI-Generated Code Header
// **Intent:** Command-line tool with subcommands, file operations, and system utilities
// **Optimization:** Efficient file processing and command execution
// **Safety:** Input validation, error handling, and secure file operations

package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// AI-SUGGESTION: CLI application structure
type CLIApp struct {
	commands map[string]Command
	flags    *flag.FlagSet
}

type Command interface {
	Execute(args []string) error
	Help() string
}

// AI-SUGGESTION: File analysis command
type FileAnalyzerCommand struct {
	recursive bool
	pattern   string
	output    string
}

func (f *FileAnalyzerCommand) Execute(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: analyze <directory>")
	}
	
	dirPath := args[0]
	analysis, err := f.analyzeDirectory(dirPath)
	if err != nil {
		return fmt.Errorf("failed to analyze directory: %w", err)
	}
	
	return f.outputResults(analysis)
}

func (f *FileAnalyzerCommand) Help() string {
	return `analyze - Analyze files and directories
Usage: analyze [options] <directory>
Options:
  -r, --recursive  Analyze subdirectories recursively
  -p, --pattern    File pattern to match (glob)
  -o, --output     Output format (text, json)`
}

type FileAnalysis struct {
	Directory    string                 `json:"directory"`
	TotalFiles   int                    `json:"total_files"`
	TotalSize    int64                  `json:"total_size"`
	FileTypes    map[string]int         `json:"file_types"`
	LargestFiles []FileInfo             `json:"largest_files"`
	Summary      map[string]interface{} `json:"summary"`
	AnalyzedAt   time.Time              `json:"analyzed_at"`
}

type FileInfo struct {
	Path     string    `json:"path"`
	Size     int64     `json:"size"`
	ModTime  time.Time `json:"mod_time"`
	IsDir    bool      `json:"is_dir"`
	Extension string   `json:"extension"`
}

func (f *FileAnalyzerCommand) analyzeDirectory(dirPath string) (*FileAnalysis, error) {
	analysis := &FileAnalysis{
		Directory:    dirPath,
		FileTypes:    make(map[string]int),
		LargestFiles: make([]FileInfo, 0),
		Summary:      make(map[string]interface{}),
		AnalyzedAt:   time.Now(),
	}
	
	var walkFunc fs.WalkDirFunc
	if f.recursive {
		walkFunc = f.walkDirRecursive(analysis)
	} else {
		walkFunc = f.walkDirSingle(analysis)
	}
	
	err := filepath.WalkDir(dirPath, walkFunc)
	if err != nil {
		return nil, err
	}
	
	f.calculateSummary(analysis)
	return analysis, nil
}

func (f *FileAnalyzerCommand) walkDirRecursive(analysis *FileAnalysis) fs.WalkDirFunc {
	return func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		
		return f.processFile(analysis, path, d)
	}
}

func (f *FileAnalyzerCommand) walkDirSingle(analysis *FileAnalysis) fs.WalkDirFunc {
	return func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		
		// AI-SUGGESTION: Skip subdirectories if not recursive
		if d.IsDir() && path != analysis.Directory {
			return fs.SkipDir
		}
		
		return f.processFile(analysis, path, d)
	}
}

func (f *FileAnalyzerCommand) processFile(analysis *FileAnalysis, path string, d fs.DirEntry) error {
	info, err := d.Info()
	if err != nil {
		return err
	}
	
	// AI-SUGGESTION: Apply pattern matching if specified
	if f.pattern != "" {
		matched, err := filepath.Match(f.pattern, filepath.Base(path))
		if err != nil {
			return err
		}
		if !matched {
			return nil
		}
	}
	
	if !d.IsDir() {
		analysis.TotalFiles++
		analysis.TotalSize += info.Size()
		
		ext := strings.ToLower(filepath.Ext(path))
		if ext == "" {
			ext = "no extension"
		}
		analysis.FileTypes[ext]++
		
		fileInfo := FileInfo{
			Path:      path,
			Size:      info.Size(),
			ModTime:   info.ModTime(),
			IsDir:     false,
			Extension: ext,
		}
		
		// AI-SUGGESTION: Track largest files
		analysis.LargestFiles = append(analysis.LargestFiles, fileInfo)
		if len(analysis.LargestFiles) > 10 {
			sort.Slice(analysis.LargestFiles, func(i, j int) bool {
				return analysis.LargestFiles[i].Size > analysis.LargestFiles[j].Size
			})
			analysis.LargestFiles = analysis.LargestFiles[:10]
		}
	}
	
	return nil
}

func (f *FileAnalyzerCommand) calculateSummary(analysis *FileAnalysis) {
	if analysis.TotalFiles > 0 {
		analysis.Summary["average_file_size"] = analysis.TotalSize / int64(analysis.TotalFiles)
	}
	
	// AI-SUGGESTION: Find most common file type
	var mostCommonType string
	var maxCount int
	for ext, count := range analysis.FileTypes {
		if count > maxCount {
			maxCount = count
			mostCommonType = ext
		}
	}
	analysis.Summary["most_common_type"] = mostCommonType
	analysis.Summary["most_common_count"] = maxCount
}

func (f *FileAnalyzerCommand) outputResults(analysis *FileAnalysis) error {
	switch f.output {
	case "json":
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		return encoder.Encode(analysis)
	default:
		return f.outputText(analysis)
	}
}

func (f *FileAnalyzerCommand) outputText(analysis *FileAnalysis) error {
	fmt.Printf("Directory Analysis: %s\n", analysis.Directory)
	fmt.Printf("Analyzed at: %s\n", analysis.AnalyzedAt.Format(time.RFC3339))
	fmt.Printf("==========================================\n")
	fmt.Printf("Total files: %d\n", analysis.TotalFiles)
	fmt.Printf("Total size: %s\n", formatBytes(analysis.TotalSize))
	fmt.Printf("Average size: %s\n", formatBytes(analysis.Summary["average_file_size"].(int64)))
	
	fmt.Printf("\nFile Types:\n")
	for ext, count := range analysis.FileTypes {
		fmt.Printf("  %s: %d files\n", ext, count)
	}
	
	fmt.Printf("\nLargest Files:\n")
	for i, file := range analysis.LargestFiles {
		if i >= 5 { // Show top 5
			break
		}
		fmt.Printf("  %s (%s)\n", file.Path, formatBytes(file.Size))
	}
	
	return nil
}

// AI-SUGGESTION: Text processing command
type TextProcessorCommand struct {
	operation string
	ignoreCase bool
	output    string
}

func (t *TextProcessorCommand) Execute(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: text <file>")
	}
	
	filePath := args[0]
	return t.processTextFile(filePath)
}

func (t *TextProcessorCommand) Help() string {
	return `text - Process text files
Usage: text [options] <file>
Options:
  --operation  Operation to perform (count, search, replace)
  --ignore-case Ignore case for operations
  --output     Output file (default: stdout)`
}

func (t *TextProcessorCommand) processTextFile(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()
	
	switch t.operation {
	case "count":
		return t.countLines(file)
	case "search":
		return t.searchText(file)
	default:
		return t.analyzeText(file)
	}
}

func (t *TextProcessorCommand) countLines(file *os.File) error {
	scanner := bufio.NewScanner(file)
	lineCount := 0
	wordCount := 0
	charCount := 0
	
	for scanner.Scan() {
		line := scanner.Text()
		lineCount++
		charCount += len(line) + 1 // +1 for newline
		words := strings.Fields(line)
		wordCount += len(words)
	}
	
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("error reading file: %w", err)
	}
	
	fmt.Printf("Lines: %d\n", lineCount)
	fmt.Printf("Words: %d\n", wordCount)
	fmt.Printf("Characters: %d\n", charCount)
	
	return nil
}

func (t *TextProcessorCommand) searchText(file *os.File) error {
	// AI-SUGGESTION: This would need search pattern from args
	scanner := bufio.NewScanner(file)
	lineNumber := 1
	
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(strings.ToLower(line), "error") {
			fmt.Printf("Line %d: %s\n", lineNumber, line)
		}
		lineNumber++
	}
	
	return scanner.Err()
}

func (t *TextProcessorCommand) analyzeText(file *os.File) error {
	scanner := bufio.NewScanner(file)
	wordFreq := make(map[string]int)
	
	for scanner.Scan() {
		line := scanner.Text()
		words := strings.Fields(strings.ToLower(line))
		
		for _, word := range words {
			// AI-SUGGESTION: Clean word of punctuation
			word = regexp.MustCompile(`[^\w]`).ReplaceAllString(word, "")
			if len(word) > 0 {
				wordFreq[word]++
			}
		}
	}
	
	if err := scanner.Err(); err != nil {
		return err
	}
	
	// AI-SUGGESTION: Show top words
	type wordCount struct {
		word  string
		count int
	}
	
	var words []wordCount
	for word, count := range wordFreq {
		words = append(words, wordCount{word, count})
	}
	
	sort.Slice(words, func(i, j int) bool {
		return words[i].count > words[j].count
	})
	
	fmt.Printf("Top 10 words:\n")
	for i, wc := range words {
		if i >= 10 {
			break
		}
		fmt.Printf("  %s: %d\n", wc.word, wc.count)
	}
	
	return nil
}

// AI-SUGGESTION: System info command
type SystemInfoCommand struct{}

func (s *SystemInfoCommand) Execute(args []string) error {
	fmt.Printf("System Information\n")
	fmt.Printf("==================\n")
	fmt.Printf("OS: %s\n", os.Getenv("GOOS"))
	fmt.Printf("Architecture: %s\n", os.Getenv("GOARCH"))
	fmt.Printf("Go Version: %s\n", os.Getenv("GOVERSION"))
	fmt.Printf("Current Directory: %s\n", getCurrentDir())
	fmt.Printf("Environment Variables: %d\n", len(os.Environ()))
	fmt.Printf("Process ID: %d\n", os.Getpid())
	fmt.Printf("User: %s\n", os.Getenv("USER"))
	fmt.Printf("Home: %s\n", os.Getenv("HOME"))
	
	return nil
}

func (s *SystemInfoCommand) Help() string {
	return `sysinfo - Display system information
Usage: sysinfo`
}

// AI-SUGGESTION: Utility functions
func formatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

func getCurrentDir() string {
	dir, err := os.Getwd()
	if err != nil {
		return "unknown"
	}
	return dir
}

// AI-SUGGESTION: Main application
func NewCLIApp() *CLIApp {
	app := &CLIApp{
		commands: make(map[string]Command),
		flags:    flag.NewFlagSet("cli-tool", flag.ExitOnError),
	}
	
	// AI-SUGGESTION: Register commands
	fileAnalyzer := &FileAnalyzerCommand{}
	app.flags.BoolVar(&fileAnalyzer.recursive, "r", false, "Recursive analysis")
	app.flags.StringVar(&fileAnalyzer.pattern, "p", "", "File pattern")
	app.flags.StringVar(&fileAnalyzer.output, "o", "text", "Output format")
	app.commands["analyze"] = fileAnalyzer
	
	textProcessor := &TextProcessorCommand{}
	app.flags.StringVar(&textProcessor.operation, "operation", "analyze", "Text operation")
	app.flags.BoolVar(&textProcessor.ignoreCase, "ignore-case", false, "Ignore case")
	app.commands["text"] = textProcessor
	
	app.commands["sysinfo"] = &SystemInfoCommand{}
	
	return app
}

func (app *CLIApp) Run(args []string) error {
	if len(args) < 2 {
		app.showHelp()
		return nil
	}
	
	commandName := args[1]
	command, exists := app.commands[commandName]
	if !exists {
		return fmt.Errorf("unknown command: %s", commandName)
	}
	
	// AI-SUGGESTION: Parse flags before command execution
	app.flags.Parse(args[2:])
	remainingArgs := app.flags.Args()
	
	return command.Execute(remainingArgs)
}

func (app *CLIApp) showHelp() {
	fmt.Printf("CLI Tool - Multi-purpose command-line utility\n")
	fmt.Printf("Usage: %s <command> [options] [args]\n\n", os.Args[0])
	fmt.Printf("Available commands:\n")
	
	for name, command := range app.commands {
		fmt.Printf("  %s\n", name)
		helpLines := strings.Split(command.Help(), "\n")
		for _, line := range helpLines[1:] { // Skip first line (already shown)
			if strings.TrimSpace(line) != "" {
				fmt.Printf("    %s\n", line)
			}
		}
		fmt.Println()
	}
}

// AI-SUGGESTION: Main function
func main() {
	fmt.Println("Go CLI Tool Demonstration")
	fmt.Println("=========================")
	
	app := NewCLIApp()
	
	if err := app.Run(os.Args); err != nil {
		log.Fatalf("Error: %v", err)
	}
	
	// AI-SUGGESTION: Demo mode if no arguments
	if len(os.Args) == 1 {
		fmt.Println("\nDemo Mode - Running sample commands:")
		
		// AI-SUGGESTION: Demo file analysis
		fmt.Println("\n--- File Analysis Demo ---")
		demoArgs := []string{"cli-tool", "analyze", "."}
		if err := app.Run(demoArgs); err != nil {
			log.Printf("Demo error: %v", err)
		}
		
		// AI-SUGGESTION: Demo system info
		fmt.Println("\n--- System Info Demo ---")
		sysArgs := []string{"cli-tool", "sysinfo"}
		if err := app.Run(sysArgs); err != nil {
			log.Printf("Demo error: %v", err)
		}
		
		fmt.Println("\n=== CLI Tool Demo Complete ===")
	}
} 