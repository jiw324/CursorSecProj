#!/bin/bash

# AI-Generated Script Header
# **Intent:** Comprehensive scanning of PHP, Rust, and Scala files with CodeQL
# **Optimization:** Batch processing with detailed reporting in consistent format
# **Safety:** Enhanced validation, proper error handling, and formatted output

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="/Users/rongyuna/Desktop/temp/CursorSecProj"
OUTPUT_DIR="$PROJECT_ROOT/output"
INPUT_DIR="$PROJECT_ROOT/input/1_Programming_Languages"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Sanity checks
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v codeql &> /dev/null; then
        log_error "CodeQL CLI not found. Please install CodeQL CLI first."
        exit 1
    fi
    
    # Check for language-specific tools
    if ! command -v php &> /dev/null; then
        log_warning "PHP not found. Some PHP scans may fail."
    fi
    
    if ! command -v cargo &> /dev/null; then
        log_warning "Cargo (Rust) not found. Some Rust scans may fail."
    fi
    
    if ! command -v sbt &> /dev/null; then
        log_warning "SBT (Scala) not found. Some Scala scans may fail."
    fi
    
    # Install required query packs
    log_info "Installing required CodeQL query packs..."
    
    # PHP
    if ! codeql pack list 2>/dev/null | grep -q "codeql/php-queries"; then
        log_info "Installing PHP query pack..."
        codeql pack download codeql/php-queries
    fi
    
    # Rust
    if ! codeql pack list 2>/dev/null | grep -q "codeql/rust-queries"; then
        log_info "Installing Rust query pack..."
        codeql pack download codeql/rust-queries
    fi
    
    # Scala (uses Java queries)
    if ! codeql pack list 2>/dev/null | grep -q "codeql/java-queries"; then
        log_info "Installing Java query pack for Scala..."
        codeql pack download codeql/java-queries
    fi
    
    log_success "Prerequisites check passed"
}

# Create output directory if it doesn't exist
create_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        log_info "Created output directory: $OUTPUT_DIR"
    fi
}

# Parse SARIF file and extract findings
parse_sarif_findings() {
    local sarif_file="$1"
    local findings=""
    
    if [ -f "$sarif_file" ]; then
        # Extract rule IDs and messages from SARIF
        findings=$(grep -A 5 '"ruleId"' "$sarif_file" 2>/dev/null | grep -E '"ruleId"|"message"' | head -10 || true)
        
        if [ -n "$findings" ]; then
            echo "$findings" | while IFS= read -r line; do
                if [[ "$line" == *"ruleId"* ]]; then
                    local rule_id=$(echo "$line" | sed 's/.*"ruleId": "\([^"]*\)".*/\1/')
                    echo "Rule: $rule_id"
                elif [[ "$line" == *"message"* ]]; then
                    local message=$(echo "$line" | sed 's/.*"text": "\([^"]*\)".*/\1/')
                    echo "  - $message"
                fi
            done
        else
            echo "No findings."
        fi
    else
        echo "No findings."
    fi
}

# Scan PHP files
scan_php_files() {
    local output_file="$OUTPUT_DIR/PHP_${TIMESTAMP}"
    local php_dir="$INPUT_DIR/PHP"
    
    log_info "Starting PHP file scan..."
    
    # Initialize report file
    echo "CodeQL Security Scan Report - PHP" > "$output_file"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
    echo "============================================================" >> "$output_file"
    echo "" >> "$output_file"
    
    # Find all PHP files
    local php_files=$(find "$php_dir" -name "*.php" -type f 2>/dev/null || true)
    
    if [ -z "$php_files" ]; then
        log_warning "No PHP files found"
        echo "No PHP files found." >> "$output_file"
        return
    fi
    
    local file_count=0
    local success_count=0
    
    for file in $php_files; do
        file_count=$((file_count + 1))
        local file_name=$(basename "$file")
        local db_name="php_db_${file_name}_${TIMESTAMP}"
        
        log_info "Processing PHP file: $file_name"
        
        # Create CodeQL database for PHP
        if codeql database create "$db_name" --language=php --command="php -l $file" 2>/dev/null; then
            log_success "CodeQL database created for: $file_name"
            
            # Run analysis
            local report_file="${output_file}_${file_name}.sarif"
            if codeql database analyze "$db_name" codeql/php-queries --format=sarifv2.1.0 --output="$report_file" 2>/dev/null; then
                log_success "Analysis completed for: $file_name"
                success_count=$((success_count + 1))
                
                # Add to report
                echo "" >> "$output_file"
                echo "==============================" >> "$output_file"
                echo "File: $file" >> "$output_file"
                echo "------------------------------" >> "$output_file"
                
                # Parse and add findings
                parse_sarif_findings "$report_file" >> "$output_file"
                
            else
                log_warning "Analysis failed for: $file_name"
                echo "" >> "$output_file"
                echo "==============================" >> "$output_file"
                echo "File: $file" >> "$output_file"
                echo "------------------------------" >> "$output_file"
                echo "Analysis failed." >> "$output_file"
            fi
            
            # Clean up database
            rm -rf "$db_name"
        else
            log_warning "Failed to create CodeQL database for: $file_name"
            echo "" >> "$output_file"
            echo "==============================" >> "$output_file"
            echo "File: $file" >> "$output_file"
            echo "------------------------------" >> "$output_file"
            echo "Database creation failed." >> "$output_file"
        fi
    done
    
    log_info "PHP scan completed: $success_count/$file_count files processed successfully"
    echo "" >> "$output_file"
    echo "PHP scan completed: $success_count/$file_count files processed successfully" >> "$output_file"
    
    # Display PHP report
    echo ""
    echo "=== PHP SCAN REPORT ==="
    cat "$output_file"
}

# Scan Rust files
scan_rust_files() {
    local output_file="$OUTPUT_DIR/Rust_${TIMESTAMP}"
    local rust_dir="$INPUT_DIR/Rust"
    
    log_info "Starting Rust file scan..."
    
    # Initialize report file
    echo "CodeQL Security Scan Report - Rust" > "$output_file"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
    echo "============================================================" >> "$output_file"
    echo "" >> "$output_file"
    
    # Find all Rust files
    local rust_files=$(find "$rust_dir" -name "*.rs" -type f 2>/dev/null || true)
    
    if [ -z "$rust_files" ]; then
        log_warning "No Rust files found"
        echo "No Rust files found." >> "$output_file"
        return
    fi
    
    local file_count=0
    local success_count=0
    
    for file in $rust_files; do
        file_count=$((file_count + 1))
        local file_name=$(basename "$file")
        local db_name="rust_db_${file_name}_${TIMESTAMP}"
        
        log_info "Processing Rust file: $file_name"
        
        # Create CodeQL database for Rust
        if codeql database create "$db_name" --language=rust --command="rustc --crate-type lib $file" 2>/dev/null; then
            log_success "CodeQL database created for: $file_name"
            
            # Run analysis
            local report_file="${output_file}_${file_name}.sarif"
            if codeql database analyze "$db_name" codeql/rust-queries --format=sarifv2.1.0 --output="$report_file" 2>/dev/null; then
                log_success "Analysis completed for: $file_name"
                success_count=$((success_count + 1))
                
                # Add to report
                echo "" >> "$output_file"
                echo "==============================" >> "$output_file"
                echo "File: $file" >> "$output_file"
                echo "------------------------------" >> "$output_file"
                
                # Parse and add findings
                parse_sarif_findings "$report_file" >> "$output_file"
                
            else
                log_warning "Analysis failed for: $file_name"
                echo "" >> "$output_file"
                echo "==============================" >> "$output_file"
                echo "File: $file" >> "$output_file"
                echo "------------------------------" >> "$output_file"
                echo "Analysis failed." >> "$output_file"
            fi
            
            # Clean up database
            rm -rf "$db_name"
        else
            log_warning "Failed to create CodeQL database for: $file_name"
            echo "" >> "$output_file"
            echo "==============================" >> "$output_file"
            echo "File: $file" >> "$output_file"
            echo "------------------------------" >> "$output_file"
            echo "Database creation failed." >> "$output_file"
        fi
    done
    
    log_info "Rust scan completed: $success_count/$file_count files processed successfully"
    echo "" >> "$output_file"
    echo "Rust scan completed: $success_count/$file_count files processed successfully" >> "$output_file"
    
    # Display Rust report
    echo ""
    echo "=== RUST SCAN REPORT ==="
    cat "$output_file"
}

# Scan Scala files
scan_scala_files() {
    local output_file="$OUTPUT_DIR/Scala_${TIMESTAMP}"
    local scala_dir="$INPUT_DIR/Scala"
    
    log_info "Starting Scala file scan..."
    
    # Initialize report file
    echo "CodeQL Security Scan Report - Scala" > "$output_file"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
    echo "============================================================" >> "$output_file"
    echo "" >> "$output_file"
    
    # Find all Scala files
    local scala_files=$(find "$scala_dir" -name "*.scala" -type f 2>/dev/null || true)
    
    if [ -z "$scala_files" ]; then
        log_warning "No Scala files found"
        echo "No Scala files found." >> "$output_file"
        return
    fi
    
    local file_count=0
    local success_count=0
    
    for file in $scala_files; do
        file_count=$((file_count + 1))
        local file_name=$(basename "$file")
        local db_name="scala_db_${file_name}_${TIMESTAMP}"
        
        log_info "Processing Scala file: $file_name"
        
        # Create CodeQL database for Scala (using Java language)
        if codeql database create "$db_name" --language=java --command="scalac $file" 2>/dev/null; then
            log_success "CodeQL database created for: $file_name"
            
            # Run analysis
            local report_file="${output_file}_${file_name}.sarif"
            if codeql database analyze "$db_name" codeql/java-queries --format=sarifv2.1.0 --output="$report_file" 2>/dev/null; then
                log_success "Analysis completed for: $file_name"
                success_count=$((success_count + 1))
                
                # Add to report
                echo "" >> "$output_file"
                echo "==============================" >> "$output_file"
                echo "File: $file" >> "$output_file"
                echo "------------------------------" >> "$output_file"
                
                # Parse and add findings
                parse_sarif_findings "$report_file" >> "$output_file"
                
            else
                log_warning "Analysis failed for: $file_name"
                echo "" >> "$output_file"
                echo "==============================" >> "$output_file"
                echo "File: $file" >> "$output_file"
                echo "------------------------------" >> "$output_file"
                echo "Analysis failed." >> "$output_file"
            fi
            
            # Clean up database
            rm -rf "$db_name"
        else
            log_warning "Failed to create CodeQL database for: $file_name"
            echo "" >> "$output_file"
            echo "==============================" >> "$output_file"
            echo "File: $file" >> "$output_file"
            echo "------------------------------" >> "$output_file"
            echo "Database creation failed." >> "$output_file"
        fi
    done
    
    log_info "Scala scan completed: $success_count/$file_count files processed successfully"
    echo "" >> "$output_file"
    echo "Scala scan completed: $success_count/$file_count files processed successfully" >> "$output_file"
    
    # Display Scala report
    echo ""
    echo "=== SCALA SCAN REPORT ==="
    cat "$output_file"
}

# Main scanning function
main() {
    log_info "Starting comprehensive scan of PHP, Rust, and Scala files..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Timestamp: $TIMESTAMP"
    
    # Check prerequisites
    check_prerequisites
    
    # Create output directory
    create_output_dir
    
    # Scan each language
    scan_php_files
    scan_rust_files
    scan_scala_files
    
    log_success "All scans completed!"
    log_info "Reports saved to: $OUTPUT_DIR"
}

# Error handling
trap 'log_error "Script interrupted. Cleaning up..."; exit 1' INT TERM

# Run main function
main "$@" 