# Multi-Language Security Scanner Project

A comprehensive security scanning system that analyzes code across multiple programming languages for potential security vulnerabilities, coding issues, and best practice violations.

## Project Overview

This project provides a suite of security scanners for different programming languages, with each scanner tailored to identify language-specific security concerns and common vulnerabilities.

### Currently Implemented Scanners

- **C Language Scanner**
  - Uses Clang Static Analyzer
  - Custom pattern matching for security vulnerabilities
  - Comprehensive security flags for compilation
  - Detailed HTML and JSON reporting

### Project Structure

```
CursorSecProj/
├── build/                      # Centralized build directory
│   ├── C/                     # C build artifacts
│   ├── CPP/                   # C++ build artifacts
│   └── ...                    # Other language build artifacts
├── output/                    # Scan results and reports
│   ├── C_security_scan/      # C scanner output
│   ├── CPP_security_scan/    # C++ scanner output
│   └── ...                   # Other scanner outputs
├── input/                     # Source code and scanners
│   ├── C/                    # C scanner and test files
│   ├── CPP/                  # C++ scanner and test files
│   ├── Go/                   # Go scanner and test files
│   ├── Java/                 # Java scanner and test files
│   ├── JavaScript_TypeScript/ # JS/TS scanner and test files
│   ├── PHP/                  # PHP scanner and test files
│   ├── Python/               # Python scanner and test files
│   ├── Ruby/                 # Ruby scanner and test files
│   ├── Rust/                 # Rust scanner and test files
│   └── Scala/                # Scala scanner and test files
├── Makefile                  # Root build system
└── README.md                 # This file
```

## Features

### C Security Scanner

The C scanner checks for:

1. **Memory Safety**
   - Buffer overflows
   - Memory leaks
   - Use-after-free
   - Double free
   - Null pointer dereferences

2. **Input Validation**
   - Command injection
   - Format string vulnerabilities
   - Integer overflows
   - Input sanitization

3. **Dangerous Functions**
   - gets()
   - sprintf()
   - strcpy()
   - strcat()
   - scanf() without limits
   - system()
   - popen()
   - exec* family

4. **File Operations**
   - Path traversal
   - File permission issues
   - Race conditions
   - Insecure temporary files

5. **Code Patterns**
   - Hardcoded credentials
   - Insecure random numbers
   - Weak cryptography
   - Unsafe multithreading

## Build System

The project uses a hierarchical build system:

### Root Level

```bash
make              # Build all language scanners
make clean        # Clean all build and output directories
make input/C      # Build specific language scanner (e.g., C)
```

### Language Level

```bash
cd input/C        # Navigate to language directory
make              # Build scanner for that language
make clean        # Clean language-specific files
```

## Output and Reports

Each scanner generates:

1. **JSON Report** (`output/<LANG>_security_scan/security_scan_report.json`)
   - Detailed findings
   - File locations
   - Severity levels
   - Tool-specific information
   - Statistics and metrics

2. **HTML Report** (`output/<LANG>_security_scan/security_report.html`)
   - User-friendly interface
   - Syntax highlighting
   - Severity-based coloring
   - Filtering and navigation
   - Summary statistics

## Requirements

### C Scanner
- Clang
- Python 3.x
- scan-build (Clang Static Analyzer)

### Build System
- GNU Make
- Bash-compatible shell

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd CursorSecProj
   ```

2. Install dependencies:
   ```bash
   # For C scanner
   brew install llvm    # macOS
   # or
   apt-get install clang # Ubuntu/Debian
   ```

## Usage

1. **Full System Scan**
   ```bash
   make
   ```

2. **Single Language Scan**
   ```bash
   make input/C    # For C code
   ```

3. **View Reports**
   - Open `output/C_security_scan/security_report.html` in a web browser
   - Check `output/C_security_scan/c_security_scan_report.json` for detailed data

## Development Status

- ✅ C Scanner: Fully implemented
- 🚧 Other Languages: In development

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[Insert License Information]

## Authors

[Insert Author Information]

## Acknowledgments

- Clang Static Analyzer team
- [Other acknowledgments] 