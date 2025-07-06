// AI-Generated Code Header
// Intent: Demonstrate Rust CLI tool development with argument parsing and file operations
// Optimization: Efficient file I/O, streaming processing, and resource management
// Safety: Error handling, input validation, and secure file operations

use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::{self, BufRead, BufReader, Write, BufWriter, stdin, stdout};
use std::path::{Path, PathBuf};
use std::process;
use std::env;
use std::time::{Instant, SystemTime, UNIX_EPOCH};
use std::thread;
use std::sync::{Arc, Mutex};

use serde::{Deserialize, Serialize};
use regex::Regex;

// AI-SUGGESTION: Command-line argument structure
#[derive(Debug, Clone)]
pub struct CliArgs {
    pub command: String,
    pub input_file: Option<PathBuf>,
    pub output_file: Option<PathBuf>,
    pub verbose: bool,
    pub recursive: bool,
    pub pattern: Option<String>,
    pub count: usize,
    pub format: OutputFormat,
    pub extra_args: HashMap<String, String>,
}

#[derive(Debug, Clone)]
pub enum OutputFormat {
    Plain,
    Json,
    Csv,
    Table,
}

impl Default for CliArgs {
    fn default() -> Self {
        Self {
            command: String::new(),
            input_file: None,
            output_file: None,
            verbose: false,
            recursive: false,
            pattern: None,
            count: 10,
            format: OutputFormat::Plain,
            extra_args: HashMap::new(),
        }
    }
}

// AI-SUGGESTION: Argument parser
pub struct ArgumentParser;

impl ArgumentParser {
    pub fn parse() -> Result<CliArgs, String> {
        let args: Vec<String> = env::args().collect();
        
        if args.len() < 2 {
            return Err("No command specified. Use --help for usage information.".to_string());
        }
        
        let mut cli_args = CliArgs::default();
        cli_args.command = args[1].clone();
        
        let mut i = 2;
        while i < args.len() {
            match args[i].as_str() {
                "--help" | "-h" => {
                    Self::print_help();
                    process::exit(0);
                }
                "--verbose" | "-v" => {
                    cli_args.verbose = true;
                }
                "--recursive" | "-r" => {
                    cli_args.recursive = true;
                }
                "--input" | "-i" => {
                    i += 1;
                    if i >= args.len() {
                        return Err("Missing value for --input".to_string());
                    }
                    cli_args.input_file = Some(PathBuf::from(&args[i]));
                }
                "--output" | "-o" => {
                    i += 1;
                    if i >= args.len() {
                        return Err("Missing value for --output".to_string());
                    }
                    cli_args.output_file = Some(PathBuf::from(&args[i]));
                }
                "--pattern" | "-p" => {
                    i += 1;
                    if i >= args.len() {
                        return Err("Missing value for --pattern".to_string());
                    }
                    cli_args.pattern = Some(args[i].clone());
                }
                "--count" | "-c" => {
                    i += 1;
                    if i >= args.len() {
                        return Err("Missing value for --count".to_string());
                    }
                    cli_args.count = args[i].parse()
                        .map_err(|_| "Invalid count value".to_string())?;
                }
                "--format" | "-f" => {
                    i += 1;
                    if i >= args.len() {
                        return Err("Missing value for --format".to_string());
                    }
                    cli_args.format = match args[i].as_str() {
                        "plain" => OutputFormat::Plain,
                        "json" => OutputFormat::Json,
                        "csv" => OutputFormat::Csv,
                        "table" => OutputFormat::Table,
                        _ => return Err("Invalid format. Use: plain, json, csv, or table".to_string()),
                    };
                }
                arg if arg.starts_with("--") => {
                    i += 1;
                    if i >= args.len() {
                        return Err(format!("Missing value for {}", arg));
                    }
                    let key = arg.trim_start_matches("--").to_string();
                    cli_args.extra_args.insert(key, args[i].clone());
                }
                _ => {
                    return Err(format!("Unknown argument: {}", args[i]));
                }
            }
            i += 1;
        }
        
        Ok(cli_args)
    }
    
    fn print_help() {
        println!("Rust CLI Tool - Advanced File Processing Utility");
        println!();
        println!("USAGE:");
        println!("    cli_tool <COMMAND> [OPTIONS]");
        println!();
        println!("COMMANDS:");
        println!("    search       Search for patterns in files");
        println!("    count        Count lines, words, or characters");
        println!("    transform    Transform file content");
        println!("    analyze      Analyze file statistics");
        println!("    watch        Watch files for changes");
        println!();
        println!("OPTIONS:");
        println!("    -i, --input <FILE>      Input file path");
        println!("    -o, --output <FILE>     Output file path");
        println!("    -p, --pattern <REGEX>   Search pattern (regex)");
        println!("    -c, --count <NUM>       Number of results to show");
        println!("    -f, --format <FORMAT>   Output format (plain, json, csv, table)");
        println!("    -v, --verbose           Verbose output");
        println!("    -r, --recursive         Process directories recursively");
        println!("    -h, --help              Show this help message");
        println!();
        println!("EXAMPLES:");
        println!("    cli_tool search -i data.txt -p \"error\" -f json");
        println!("    cli_tool count -i document.txt --words");
        println!("    cli_tool analyze -i /path/to/directory -r");
    }
}

// AI-SUGGESTION: File search functionality
pub struct FileSearcher {
    pattern: Regex,
    case_sensitive: bool,
}

impl FileSearcher {
    pub fn new(pattern: &str, case_sensitive: bool) -> Result<Self, String> {
        let flags = if case_sensitive { "" } else { "(?i)" };
        let full_pattern = format!("{}{}", flags, pattern);
        
        let regex = Regex::new(&full_pattern)
            .map_err(|e| format!("Invalid regex pattern: {}", e))?;
        
        Ok(Self {
            pattern: regex,
            case_sensitive,
        })
    }
    
    pub fn search_file(&self, file_path: &Path) -> io::Result<Vec<SearchResult>> {
        let file = File::open(file_path)?;
        let reader = BufReader::new(file);
        let mut results = Vec::new();
        
        for (line_number, line) in reader.lines().enumerate() {
            let line = line?;
            
            for mat in self.pattern.find_iter(&line) {
                results.push(SearchResult {
                    file_path: file_path.to_path_buf(),
                    line_number: line_number + 1,
                    column: mat.start() + 1,
                    line_content: line.clone(),
                    matched_text: mat.as_str().to_string(),
                });
            }
        }
        
        Ok(results)
    }
    
    pub fn search_directory(&self, dir_path: &Path, recursive: bool) -> io::Result<Vec<SearchResult>> {
        let mut all_results = Vec::new();
        
        if recursive {
            self.search_directory_recursive(dir_path, &mut all_results)?;
        } else {
            for entry in std::fs::read_dir(dir_path)? {
                let entry = entry?;
                let path = entry.path();
                
                if path.is_file() {
                    if let Ok(results) = self.search_file(&path) {
                        all_results.extend(results);
                    }
                }
            }
        }
        
        Ok(all_results)
    }
    
    fn search_directory_recursive(&self, dir_path: &Path, results: &mut Vec<SearchResult>) -> io::Result<()> {
        for entry in std::fs::read_dir(dir_path)? {
            let entry = entry?;
            let path = entry.path();
            
            if path.is_file() {
                if let Ok(file_results) = self.search_file(&path) {
                    results.extend(file_results);
                }
            } else if path.is_dir() {
                self.search_directory_recursive(&path, results)?;
            }
        }
        Ok(())
    }
}

#[derive(Debug, Serialize)]
pub struct SearchResult {
    pub file_path: PathBuf,
    pub line_number: usize,
    pub column: usize,
    pub line_content: String,
    pub matched_text: String,
}

// AI-SUGGESTION: File statistics analyzer
#[derive(Debug, Serialize)]
pub struct FileStats {
    pub file_path: PathBuf,
    pub size_bytes: u64,
    pub line_count: usize,
    pub word_count: usize,
    pub char_count: usize,
    pub empty_lines: usize,
    pub average_line_length: f64,
    pub longest_line: usize,
    pub file_type: String,
}

pub struct FileAnalyzer;

impl FileAnalyzer {
    pub fn analyze_file(file_path: &Path) -> io::Result<FileStats> {
        let metadata = std::fs::metadata(file_path)?;
        let file = File::open(file_path)?;
        let reader = BufReader::new(file);
        
        let mut line_count = 0;
        let mut word_count = 0;
        let mut char_count = 0;
        let mut empty_lines = 0;
        let mut longest_line = 0;
        let mut total_line_length = 0;
        
        for line in reader.lines() {
            let line = line?;
            line_count += 1;
            char_count += line.len();
            total_line_length += line.len();
            
            if line.trim().is_empty() {
                empty_lines += 1;
            }
            
            if line.len() > longest_line {
                longest_line = line.len();
            }
            
            word_count += line.split_whitespace().count();
        }
        
        let average_line_length = if line_count > 0 {
            total_line_length as f64 / line_count as f64
        } else {
            0.0
        };
        
        let file_type = Self::detect_file_type(file_path);
        
        Ok(FileStats {
            file_path: file_path.to_path_buf(),
            size_bytes: metadata.len(),
            line_count,
            word_count,
            char_count,
            empty_lines,
            average_line_length,
            longest_line,
            file_type,
        })
    }
    
    fn detect_file_type(file_path: &Path) -> String {
        if let Some(extension) = file_path.extension() {
            match extension.to_str().unwrap_or("").to_lowercase().as_str() {
                "rs" => "Rust".to_string(),
                "py" => "Python".to_string(),
                "js" => "JavaScript".to_string(),
                "html" => "HTML".to_string(),
                "css" => "CSS".to_string(),
                "json" => "JSON".to_string(),
                "xml" => "XML".to_string(),
                "txt" => "Text".to_string(),
                "md" => "Markdown".to_string(),
                _ => "Unknown".to_string(),
            }
        } else {
            "No extension".to_string()
        }
    }
    
    pub fn analyze_directory(dir_path: &Path, recursive: bool) -> io::Result<Vec<FileStats>> {
        let mut all_stats = Vec::new();
        
        if recursive {
            Self::analyze_directory_recursive(dir_path, &mut all_stats)?;
        } else {
            for entry in std::fs::read_dir(dir_path)? {
                let entry = entry?;
                let path = entry.path();
                
                if path.is_file() {
                    if let Ok(stats) = Self::analyze_file(&path) {
                        all_stats.push(stats);
                    }
                }
            }
        }
        
        Ok(all_stats)
    }
    
    fn analyze_directory_recursive(dir_path: &Path, stats: &mut Vec<FileStats>) -> io::Result<()> {
        for entry in std::fs::read_dir(dir_path)? {
            let entry = entry?;
            let path = entry.path();
            
            if path.is_file() {
                if let Ok(file_stats) = Self::analyze_file(&path) {
                    stats.push(file_stats);
                }
            } else if path.is_dir() {
                Self::analyze_directory_recursive(&path, stats)?;
            }
        }
        Ok(())
    }
}

// AI-SUGGESTION: Output formatter
pub struct OutputFormatter;

impl OutputFormatter {
    pub fn format_search_results(results: &[SearchResult], format: &OutputFormat) -> String {
        match format {
            OutputFormat::Plain => Self::format_search_plain(results),
            OutputFormat::Json => Self::format_search_json(results),
            OutputFormat::Csv => Self::format_search_csv(results),
            OutputFormat::Table => Self::format_search_table(results),
        }
    }
    
    pub fn format_file_stats(stats: &[FileStats], format: &OutputFormat) -> String {
        match format {
            OutputFormat::Plain => Self::format_stats_plain(stats),
            OutputFormat::Json => Self::format_stats_json(stats),
            OutputFormat::Csv => Self::format_stats_csv(stats),
            OutputFormat::Table => Self::format_stats_table(stats),
        }
    }
    
    fn format_search_plain(results: &[SearchResult]) -> String {
        let mut output = String::new();
        for result in results {
            output.push_str(&format!(
                "{}:{}:{}: {}\n",
                result.file_path.display(),
                result.line_number,
                result.column,
                result.line_content.trim()
            ));
        }
        output
    }
    
    fn format_search_json(results: &[SearchResult]) -> String {
        serde_json::to_string_pretty(results).unwrap_or_else(|_| "[]".to_string())
    }
    
    fn format_search_csv(results: &[SearchResult]) -> String {
        let mut output = String::from("file_path,line_number,column,matched_text\n");
        for result in results {
            output.push_str(&format!(
                "{},{},{},{}\n",
                result.file_path.display(),
                result.line_number,
                result.column,
                result.matched_text
            ));
        }
        output
    }
    
    fn format_search_table(results: &[SearchResult]) -> String {
        let mut output = String::from("┌────────────────────────────────────────┬──────┬────────┬────────────────────────────────────────┐\n");
        output.push_str("│ File                                   │ Line │ Column │ Match                                  │\n");
        output.push_str("├────────────────────────────────────────┼──────┼────────┼────────────────────────────────────────┤\n");
        
        for result in results {
            let file_name = result.file_path.file_name()
                .unwrap_or_default()
                .to_string_lossy();
            
            output.push_str(&format!(
                "│ {:<38} │ {:>4} │ {:>6} │ {:<38} │\n",
                Self::truncate(&file_name, 38),
                result.line_number,
                result.column,
                Self::truncate(&result.matched_text, 38)
            ));
        }
        
        output.push_str("└────────────────────────────────────────┴──────┴────────┴────────────────────────────────────────┘\n");
        output
    }
    
    fn format_stats_plain(stats: &[FileStats]) -> String {
        let mut output = String::new();
        for stat in stats {
            output.push_str(&format!(
                "File: {}\n  Size: {} bytes\n  Lines: {}\n  Words: {}\n  Characters: {}\n\n",
                stat.file_path.display(),
                stat.size_bytes,
                stat.line_count,
                stat.word_count,
                stat.char_count
            ));
        }
        output
    }
    
    fn format_stats_json(stats: &[FileStats]) -> String {
        serde_json::to_string_pretty(stats).unwrap_or_else(|_| "[]".to_string())
    }
    
    fn format_stats_csv(stats: &[FileStats]) -> String {
        let mut output = String::from("file_path,size_bytes,line_count,word_count,char_count,file_type\n");
        for stat in stats {
            output.push_str(&format!(
                "{},{},{},{},{},{}\n",
                stat.file_path.display(),
                stat.size_bytes,
                stat.line_count,
                stat.word_count,
                stat.char_count,
                stat.file_type
            ));
        }
        output
    }
    
    fn format_stats_table(stats: &[FileStats]) -> String {
        let mut output = String::from("┌────────────────────────┬──────────┬───────┬───────┬──────────┬──────────┐\n");
        output.push_str("│ File                   │ Size     │ Lines │ Words │ Chars    │ Type     │\n");
        output.push_str("├────────────────────────┼──────────┼───────┼───────┼──────────┼──────────┤\n");
        
        for stat in stats {
            let file_name = stat.file_path.file_name()
                .unwrap_or_default()
                .to_string_lossy();
            
            output.push_str(&format!(
                "│ {:<22} │ {:>8} │ {:>5} │ {:>5} │ {:>8} │ {:<8} │\n",
                Self::truncate(&file_name, 22),
                stat.size_bytes,
                stat.line_count,
                stat.word_count,
                stat.char_count,
                Self::truncate(&stat.file_type, 8)
            ));
        }
        
        output.push_str("└────────────────────────┴──────────┴───────┴───────┴──────────┴──────────┘\n");
        output
    }
    
    fn truncate(s: &str, max_len: usize) -> String {
        if s.len() > max_len {
            format!("{}...", &s[..max_len.saturating_sub(3)])
        } else {
            s.to_string()
        }
    }
}

// AI-SUGGESTION: Main CLI application
pub struct CliApp;

impl CliApp {
    pub fn run() -> Result<(), Box<dyn std::error::Error>> {
        let args = ArgumentParser::parse()?;
        
        if args.verbose {
            println!("Running command: {}", args.command);
            println!("Arguments: {:?}", args);
        }
        
        match args.command.as_str() {
            "search" => Self::handle_search(args),
            "analyze" => Self::handle_analyze(args),
            "count" => Self::handle_count(args),
            "transform" => Self::handle_transform(args),
            _ => Err(format!("Unknown command: {}", args.command).into()),
        }
    }
    
    fn handle_search(args: CliArgs) -> Result<(), Box<dyn std::error::Error>> {
        let pattern = args.pattern.ok_or("Pattern is required for search command")?;
        let searcher = FileSearcher::new(&pattern, true)?;
        
        let results = if let Some(input_file) = &args.input_file {
            if input_file.is_file() {
                searcher.search_file(input_file)?
            } else if input_file.is_dir() {
                searcher.search_directory(input_file, args.recursive)?
            } else {
                return Err("Input path does not exist".into());
            }
        } else {
            return Err("Input file or directory is required".into());
        };
        
        let output = OutputFormatter::format_search_results(&results, &args.format);
        Self::write_output(&output, args.output_file)?;
        
        if args.verbose {
            println!("Found {} matches", results.len());
        }
        
        Ok(())
    }
    
    fn handle_analyze(args: CliArgs) -> Result<(), Box<dyn std::error::Error>> {
        let input_path = args.input_file.ok_or("Input file or directory is required")?;
        
        let stats = if input_path.is_file() {
            vec![FileAnalyzer::analyze_file(&input_path)?]
        } else if input_path.is_dir() {
            FileAnalyzer::analyze_directory(&input_path, args.recursive)?
        } else {
            return Err("Input path does not exist".into());
        };
        
        let output = OutputFormatter::format_file_stats(&stats, &args.format);
        Self::write_output(&output, args.output_file)?;
        
        if args.verbose {
            println!("Analyzed {} files", stats.len());
        }
        
        Ok(())
    }
    
    fn handle_count(args: CliArgs) -> Result<(), Box<dyn std::error::Error>> {
        let input_file = args.input_file.ok_or("Input file is required")?;
        let stats = FileAnalyzer::analyze_file(&input_file)?;
        
        let count_type = args.extra_args.get("type").unwrap_or(&"lines".to_string()).clone();
        
        let result = match count_type.as_str() {
            "lines" => stats.line_count,
            "words" => stats.word_count,
            "chars" => stats.char_count,
            _ => return Err("Invalid count type. Use: lines, words, or chars".into()),
        };
        
        println!("{}", result);
        Ok(())
    }
    
    fn handle_transform(args: CliArgs) -> Result<(), Box<dyn std::error::Error>> {
        let input_file = args.input_file.ok_or("Input file is required")?;
        let output_file = args.output_file.ok_or("Output file is required")?;
        
        let transform_type = args.extra_args.get("type").unwrap_or(&"uppercase".to_string()).clone();
        
        let input = std::fs::read_to_string(&input_file)?;
        let output = match transform_type.as_str() {
            "uppercase" => input.to_uppercase(),
            "lowercase" => input.to_lowercase(),
            "reverse" => input.chars().rev().collect(),
            _ => return Err("Invalid transform type. Use: uppercase, lowercase, or reverse".into()),
        };
        
        std::fs::write(&output_file, output)?;
        
        if args.verbose {
            println!("Transformed {} to {}", input_file.display(), output_file.display());
        }
        
        Ok(())
    }
    
    fn write_output(content: &str, output_file: Option<PathBuf>) -> io::Result<()> {
        match output_file {
            Some(path) => {
                let mut file = File::create(path)?;
                file.write_all(content.as_bytes())?;
            }
            None => {
                print!("{}", content);
                stdout().flush()?;
            }
        }
        Ok(())
    }
}

// Main function
fn main() {
    match CliApp::run() {
        Ok(()) => process::exit(0),
        Err(e) => {
            eprintln!("Error: {}", e);
            process::exit(1);
        }
    }
} 