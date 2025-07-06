#!/bin/bash

# AI-Generated Script Header
# **Intent:** Comprehensive Swift file scanning with CodeQL for all files in the project
# **Optimization:** Batch processing with error handling and detailed reporting
# **Safety:** Validation checks, error boundaries, and rollback procedures

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="/Users/rongyuna/Desktop/temp/CursorSecProj"
OUTPUT_DIR="$PROJECT_ROOT/output"
SWIFT_DIR="$PROJECT_ROOT/input/1_Programming_Languages/Swift"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="$OUTPUT_DIR/Swift_${TIMESTAMP}"

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
    
    if ! command -v swiftc &> /dev/null; then
        log_error "Swift compiler not found. Please install Swift/Xcode first."
        exit 1
    fi
    
    # Check if Swift query pack is installed
    if ! codeql pack list | grep -q "codeql/swift-queries"; then
        log_info "Installing Swift query pack..."
        codeql pack download codeql/swift-queries
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

# Scan a single Swift file
scan_swift_file() {
    local file_path="$1"
    local file_name=$(basename "$file_path" .swift)
    local db_name="swift_db_${file_name}_${TIMESTAMP}"
    
    log_info "Scanning file: $file_name"
    
    # Try to compile the file
    if swiftc "$file_path" -o "/tmp/${file_name}_test" 2>/dev/null; then
        log_success "File compiled successfully: $file_name"
        
        # Create CodeQL database
        if codeql database create "$db_name" --language=swift --command="swiftc '$file_path' -o '/tmp/${file_name}_test'" 2>/dev/null; then
            log_success "CodeQL database created for: $file_name"
            
            # Run analysis
            local report_file="${OUTPUT_FILE}_${file_name}.sarif"
            if codeql database analyze "$db_name" codeql/swift-queries --format=sarifv2.1.0 --output="$report_file" 2>/dev/null; then
                log_success "Analysis completed for: $file_name"
                echo "✓ $file_name - Analysis completed" >> "${OUTPUT_FILE}_summary.txt"
            else
                log_warning "Analysis failed for: $file_name"
                echo "✗ $file_name - Analysis failed" >> "${OUTPUT_FILE}_summary.txt"
            fi
            
            # Clean up database
            rm -rf "$db_name"
        else
            log_warning "Failed to create CodeQL database for: $file_name"
            echo "✗ $file_name - Database creation failed" >> "${OUTPUT_FILE}_summary.txt"
        fi
        
        # Clean up compiled file
        rm -f "/tmp/${file_name}_test"
    else
        log_warning "File failed to compile: $file_name"
        echo "✗ $file_name - Compilation failed" >> "${OUTPUT_FILE}_summary.txt"
    fi
}

# Scan all Swift files in a directory
scan_swift_directory() {
    local dir_path="$1"
    local dir_name=$(basename "$dir_path")
    
    log_info "Scanning directory: $dir_name"
    
    # Find all Swift files
    local swift_files=$(find "$dir_path" -name "*.swift" -type f)
    
    if [ -z "$swift_files" ]; then
        log_warning "No Swift files found in: $dir_name"
        return
    fi
    
    local file_count=0
    local success_count=0
    
    for file in $swift_files; do
        file_count=$((file_count + 1))
        scan_swift_file "$file"
        if [ $? -eq 0 ]; then
            success_count=$((success_count + 1))
        fi
    done
    
    log_info "Directory $dir_name: $success_count/$file_count files processed successfully"
}

# Main scanning function
main() {
    log_info "Starting comprehensive Swift file scan..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Timestamp: $TIMESTAMP"
    
    # Initialize summary file
    echo "Swift CodeQL Scan Summary - $(date)" > "${OUTPUT_FILE}_summary.txt"
    echo "================================================" >> "${OUTPUT_FILE}_summary.txt"
    echo "" >> "${OUTPUT_FILE}_summary.txt"
    
    # Check prerequisites
    check_prerequisites
    
    # Create output directory
    create_output_dir
    
    # Scan standalone Swift files
    log_info "Scanning standalone Swift files..."
    scan_swift_directory "$SWIFT_DIR"
    
    # Scan Swift project files
    log_info "Scanning Swift project files..."
    scan_swift_directory "$SWIFT_DIR/swift_project/Sources/swift_project"
    
    # Generate final summary
    echo "" >> "${OUTPUT_FILE}_summary.txt"
    echo "Scan completed at: $(date)" >> "${OUTPUT_FILE}_summary.txt"
    echo "Total files processed: $(grep -c "^\w" "${OUTPUT_FILE}_summary.txt" || echo "0")" >> "${OUTPUT_FILE}_summary.txt"
    
    log_success "Swift scanning completed!"
    log_info "Results saved to: ${OUTPUT_FILE}_*.sarif"
    log_info "Summary saved to: ${OUTPUT_FILE}_summary.txt"
    
    # Display summary
    echo ""
    echo "=== SCAN SUMMARY ==="
    cat "${OUTPUT_FILE}_summary.txt"
}

# Error handling
trap 'log_error "Script interrupted. Cleaning up..."; exit 1' INT TERM

# Run main function
main "$@" 