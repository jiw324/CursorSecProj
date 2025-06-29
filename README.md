# 🔍 Simple CodeQL Scanner

Minimal security scanner using CodeQL for analyzing code files.

## 🚀 Quick Start

### 1. **Install CodeQL**
```bash
brew install codeql
```

### 2. **Put code files in input/ folder**
```bash
# Copy your code files to analyze
cp your_code.py input/
cp your_script.js input/
```

### 3. **Run the scanner**
```bash
python3 main.py                    # Scan all files in input/
python3 main.py --file test.py     # Scan specific file
```

### 4. **View JSON results**
```bash
ls output/                         # See generated files
cat output/your_code.py_results.json  # View security findings
```

## 📁 Directory Structure

```
CursorSecProj/
├── input/          # Place code files here (.py, .js, .java, etc.)
├── output/         # JSON and SARIF results appear here
└── main.py         # The scanner
```

## 📄 Output Format

Each scanned file produces two outputs:

1. **`filename_results.json`** - Simple JSON with security findings
2. **`filename_results.sarif`** - Standard SARIF format for tools

### Example JSON Output:
```json
{
  "file": "example.py",
  "language": "python", 
  "scan_time": "2025-06-29T22:52:23",
  "total_findings": 2,
  "findings": [
    {
      "rule_id": "py/command-line-injection",
      "message": "This command depends on a user-provided value",
      "severity": "HIGH",
      "location": {
        "file": "example.py",
        "line": 15,
        "column": 8
      }
    }
  ]
}
```

## 🎯 Supported Languages

- Python (`.py`)
- JavaScript/TypeScript (`.js`, `.ts`)
- Java (`.java`)
- C/C++ (`.c`, `.cpp`, `.cc`, `.cxx`)
- PHP (`.php`)
- Ruby (`.rb`)
- Go (`.go`)

## 💡 Usage Examples

```bash
# Scan all files in input/
python3 main.py

# Scan specific file
python3 main.py --file suspicious_code.py

# Save results to custom directory
python3 main.py --output security_results/

# Get help
python3 main.py --help
```

---

🎉 **That's it! Simple CodeQL scanning with JSON output.** 