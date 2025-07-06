#!/usr/bin/env python3
"""
C Security Scanner
Scans C source files for security vulnerabilities and code quality issues.
Similar to CodeQL but using static analysis and pattern matching.
"""

import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Tuple, Optional
import json

class CSecurityScanner:
    def __init__(self):
        self.issues = []
        self.total_files = 0
        self.files_with_issues = 0
        
        # Security patterns to detect
        self.security_patterns = {
            'critical': {
                'buffer_overflow': [
                    (r'\bstrcpy\s*\([^)]*\)', 'Unsafe strcpy - potential buffer overflow'),
                    (r'\bstrcat\s*\([^)]*\)', 'Unsafe strcat - potential buffer overflow'),
                    (r'\bgets\s*\([^)]*\)', 'Unsafe gets - always vulnerable to buffer overflow'),
                    (r'\bsprintf\s*\([^)]*\)', 'Unsafe sprintf - potential buffer overflow'),
                    (r'\bvsprintf\s*\([^)]*\)', 'Unsafe vsprintf - potential buffer overflow'),
                ],
                'memory_management': [
                    (r'\bmalloc\s*\([^)]*\)\s*(?!\s*if\s*\([^)]*==\s*NULL)', 'Unchecked malloc return - potential NULL pointer dereference'),
                    (r'\bfree\s*\([^)]*\)\s*;\s*[^;]*\s*=\s*NULL', 'Double free potential - variable not set to NULL after free'),
                    (r'\bfree\s*\([^)]*\)\s*;\s*[^;]*\s*=\s*NULL\s*;', 'Good practice - setting pointer to NULL after free'),
                ],
                'format_string': [
                    (r'\bprintf\s*\([^)]*\)', 'Unsafe printf - potential format string vulnerability'),
                    (r'\bfprintf\s*\([^)]*\)', 'Unsafe fprintf - potential format string vulnerability'),
                    (r'\bsprintf\s*\([^)]*\)', 'Unsafe sprintf - potential format string vulnerability'),
                ],
                'command_injection': [
                    (r'\bsystem\s*\([^)]*\)', 'Command injection risk - system() call'),
                    (r'\bpopen\s*\([^)]*\)', 'Command injection risk - popen() call'),
                    (r'\bexecl\s*\([^)]*\)', 'Command injection risk - execl() call'),
                    (r'\bexecv\s*\([^)]*\)', 'Command injection risk - execv() call'),
                ],
                'sql_injection': [
                    (r'\bsqlite3_exec\s*\([^)]*\)', 'Potential SQL injection - sqlite3_exec with user input'),
                    (r'\bmysql_query\s*\([^)]*\)', 'Potential SQL injection - mysql_query with user input'),
                    (r'\bpg_query\s*\([^)]*\)', 'Potential SQL injection - pg_query with user input'),
                ],
                'integer_overflow': [
                    (r'\bint\s+\w+\s*=\s*\w+\s*\*\s*\w+', 'Potential integer overflow in multiplication'),
                    (r'\blong\s+\w+\s*=\s*\w+\s*\*\s*\w+', 'Potential integer overflow in multiplication'),
                ],
                'race_condition': [
                    (r'\baccess\s*\([^)]*\)\s*.*\s*open\s*\([^)]*\)', 'TOCTOU race condition - access() followed by open()'),
                    (r'\bstat\s*\([^)]*\)\s*.*\s*open\s*\([^)]*\)', 'TOCTOU race condition - stat() followed by open()'),
                ],
                'hardcoded_secrets': [
                    (r'password\s*=\s*["\'][^"\']+["\']', 'Hardcoded password detected'),
                    (r'secret\s*=\s*["\'][^"\']+["\']', 'Hardcoded secret detected'),
                    (r'api_key\s*=\s*["\'][^"\']+["\']', 'Hardcoded API key detected'),
                    (r'token\s*=\s*["\'][^"\']+["\']', 'Hardcoded token detected'),
                ],
            },
            'high': {
                'unsafe_functions': [
                    (r'\bstrncpy\s*\([^)]*\)', 'strncpy may not null-terminate - use strlcpy or ensure null termination'),
                    (r'\bstrncat\s*\([^)]*\)', 'strncat may not null-terminate - use strlcat or ensure null termination'),
                    (r'\bscanf\s*\([^)]*\)', 'Unsafe scanf - use fgets or scanf with width limits'),
                    (r'\bfscanf\s*\([^)]*\)', 'Unsafe fscanf - use fgets or fscanf with width limits'),
                    (r'\bsscanf\s*\([^)]*\)', 'Unsafe sscanf - use strtok or sscanf with width limits'),
                ],
                'pointer_issues': [
                    (r'\bvoid\s*\*\s*\w+\s*=', 'Void pointer usage - type safety concern'),
                    (r'\bchar\s*\*\s*\w+\s*=\s*[^;]*\w+\[[^]]*\]', 'Array to pointer conversion - potential buffer overflow'),
                ],
                'unchecked_returns': [
                    (r'\bopen\s*\([^)]*\)\s*(?!\s*if\s*\([^)]*==\s*-1)', 'Unchecked open() return - potential file operation failure'),
                    (r'\bread\s*\([^)]*\)\s*(?!\s*if\s*\([^)]*==\s*-1)', 'Unchecked read() return - potential I/O failure'),
                    (r'\bwrite\s*\([^)]*\)\s*(?!\s*if\s*\([^)]*==\s*-1)', 'Unchecked write() return - potential I/O failure'),
                    (r'\bclose\s*\([^)]*\)\s*(?!\s*if\s*\([^)]*==\s*-1)', 'Unchecked close() return - potential file descriptor leak'),
                ],
                'memory_leaks': [
                    (r'\bmalloc\s*\([^)]*\)\s*;', 'Potential memory leak - malloc without corresponding free'),
                    (r'\bcalloc\s*\([^)]*\)\s*;', 'Potential memory leak - calloc without corresponding free'),
                    (r'\brealloc\s*\([^)]*\)\s*;', 'Potential memory leak - realloc without corresponding free'),
                ],
                'type_safety': [
                    (r'\bint\s+\w+\s*=\s*\w+\s*\+\s*\w+', 'Potential integer overflow in addition'),
                    (r'\bint\s+\w+\s*=\s*\w+\s*-\s*\w+', 'Potential integer underflow in subtraction'),
                ],
            },
            'medium': {
                'deprecated_functions': [
                    (r'\bbzero\s*\([^)]*\)', 'Deprecated bzero - use memset'),
                    (r'\bbcopy\s*\([^)]*\)', 'Deprecated bcopy - use memcpy or memmove'),
                    (r'\bindex\s*\([^)]*\)', 'Deprecated index - use strchr'),
                    (r'\brindex\s*\([^)]*\)', 'Deprecated rindex - use strrchr'),
                ],
                'magic_numbers': [
                    (r'\bif\s*\([^)]*==\s*\d{3,}\)', 'Magic number in condition - consider using named constant'),
                    (r'\bfor\s*\([^)]*;\s*[^;]*;\s*[^)]*\)\s*{\s*[^}]*\d{3,}[^}]*}', 'Magic number in loop - consider using named constant'),
                ],
                'unused_variables': [
                    (r'\bint\s+\w+\s*=\s*\d+;', 'Potential unused variable - check if used'),
                    (r'\bchar\s+\w+\s*\[[^]]*\];', 'Potential unused array - check if used'),
                ],
                'naming_conventions': [
                    (r'\bint\s+[a-z]+\w*[A-Z]', 'Mixed case variable name - consider consistent naming'),
                    (r'\bchar\s+[A-Z]+\w*[a-z]', 'Mixed case variable name - consider consistent naming'),
                ],
            },
            'low': {
                'style_issues': [
                    (r';\s*$', 'Trailing semicolon - style issue'),
                    (r'\s{2,}', 'Multiple spaces - style issue'),
                    (r'\t', 'Tab character - consider using spaces for consistency'),
                ],
                'comments': [
                    (r'//.*TODO', 'TODO comment found - should be addressed'),
                    (r'//.*FIXME', 'FIXME comment found - should be addressed'),
                    (r'//.*HACK', 'HACK comment found - should be reviewed'),
                ],
            }
        }
        
        # Compilation patterns
        self.compilation_patterns = {
            'error': [
                (r'error:', 'Compilation error'),
                (r'undefined reference', 'Linker error - undefined reference'),
                (r'expected \';\'', 'Syntax error - missing semicolon'),
                (r'expected \'{\'', 'Syntax error - missing brace'),
                (r'expected \')\'', 'Syntax error - missing parenthesis'),
            ],
            'warning': [
                (r'warning:', 'Compilation warning'),
                (r'unused variable', 'Unused variable warning'),
                (r'unused parameter', 'Unused parameter warning'),
                (r'implicit declaration', 'Implicit function declaration'),
                (r'conversion from', 'Type conversion warning'),
            ]
        }

    def scan_file(self, file_path: str) -> List[Dict]:
        """Scan a single C file for security issues."""
        issues = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
            
            # Scan for security patterns
            for severity, categories in self.security_patterns.items():
                for category, patterns in categories.items():
                    for pattern, description in patterns:
                        matches = re.finditer(pattern, content, re.IGNORECASE | re.MULTILINE)
                        for match in matches:
                            line_num = content[:match.start()].count('\n') + 1
                            line_content = lines[line_num - 1] if line_num <= len(lines) else ''
                            
                            issues.append({
                                'severity': severity,
                                'category': category,
                                'description': description,
                                'file': file_path,
                                'line': line_num,
                                'column': match.start() - content.rfind('\n', 0, match.start()) if '\n' in content[:match.start()] else match.start(),
                                'line_content': line_content.strip(),
                                'pattern': pattern
                            })
            
            # Try to compile the file to catch compilation errors
            compilation_issues = self.check_compilation(file_path)
            issues.extend(compilation_issues)
            
        except Exception as e:
            issues.append({
                'severity': 'error',
                'category': 'file_error',
                'description': f'Error reading file: {str(e)}',
                'file': file_path,
                'line': 0,
                'column': 0,
                'line_content': '',
                'pattern': ''
            })
        
        return issues

    def check_compilation(self, file_path: str) -> List[Dict]:
        """Check if the C file compiles without errors."""
        issues = []
        
        try:
            # Try to compile with gcc
            result = subprocess.run([
                'gcc', '-c', '-Wall', '-Wextra', '-std=c99', 
                '-o', '/tmp/temp.o', file_path
            ], capture_output=True, text=True, timeout=30)
            
            # Parse compilation output
            output = result.stdout + result.stderr
            
            for severity, patterns in self.compilation_patterns.items():
                for pattern, description in patterns:
                    matches = re.finditer(pattern, output, re.IGNORECASE)
                    for match in matches:
                        # Try to extract line number from compilation output
                        line_match = re.search(r':(\d+):', output[max(0, match.start()-50):match.start()+50])
                        line_num = int(line_match.group(1)) if line_match else 0
                        
                        issues.append({
                            'severity': severity,
                            'category': 'compilation',
                            'description': f'{description}: {match.group()}',
                            'file': file_path,
                            'line': line_num,
                            'column': 0,
                            'line_content': '',
                            'pattern': pattern
                        })
            
            # Clean up temporary file
            if os.path.exists('/tmp/temp.o'):
                os.remove('/tmp/temp.o')
                
        except subprocess.TimeoutExpired:
            issues.append({
                'severity': 'error',
                'category': 'compilation',
                'description': 'Compilation timeout - file may be too complex or have infinite loops',
                'file': file_path,
                'line': 0,
                'column': 0,
                'line_content': '',
                'pattern': ''
            })
        except FileNotFoundError:
            issues.append({
                'severity': 'warning',
                'category': 'compilation',
                'description': 'gcc not found - compilation check skipped',
                'file': file_path,
                'line': 0,
                'column': 0,
                'line_content': '',
                'pattern': ''
            })
        except Exception as e:
            issues.append({
                'severity': 'error',
                'category': 'compilation',
                'description': f'Compilation check failed: {str(e)}',
                'file': file_path,
                'line': 0,
                'column': 0,
                'line_content': '',
                'pattern': ''
            })
        
        return issues

    def scan_directory(self, directory: str) -> Dict:
        """Scan all C files in a directory."""
        c_files = []
        
        # Find all .c files
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.endswith('.c'):
                    c_files.append(os.path.join(root, file))
        
        print(f"Found {len(c_files)} C files to scan...")
        
        all_issues = []
        self.total_files = len(c_files)
        
        for file_path in c_files:
            print(f"Scanning: {file_path}")
            file_issues = self.scan_file(file_path)
            all_issues.extend(file_issues)
            
            if file_issues:
                self.files_with_issues += 1
        
        # Count issues by severity
        severity_counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0, 'error': 0, 'warning': 0}
        for issue in all_issues:
            severity_counts[issue['severity']] += 1
        
        return {
            'summary': {
                'total_files': self.total_files,
                'files_with_issues': self.files_with_issues,
                'total_issues': len(all_issues),
                'severity_counts': severity_counts
            },
            'issues': all_issues
        }

    def generate_report(self, scan_results: Dict, output_file: str = None):
        """Generate a comprehensive security report."""
        summary = scan_results['summary']
        issues = scan_results['issues']
        
        # Create output directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = f"output/C_{timestamp}"
        os.makedirs(output_dir, exist_ok=True)
        
        # Generate text report
        report_file = os.path.join(output_dir, "security_report.txt")
        with open(report_file, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write("C SECURITY SCAN REPORT\n")
            f.write("=" * 80 + "\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total files scanned: {summary['total_files']}\n")
            f.write(f"Files with issues: {summary['files_with_issues']}\n")
            f.write(f"Total issues found: {summary['total_issues']}\n\n")
            
            f.write("ISSUE SUMMARY BY SEVERITY:\n")
            f.write("-" * 40 + "\n")
            for severity, count in summary['severity_counts'].items():
                if count > 0:
                    f.write(f"{severity.upper()}: {count}\n")
            f.write("\n")
            
            # Group issues by severity
            issues_by_severity = {}
            for issue in issues:
                severity = issue['severity']
                if severity not in issues_by_severity:
                    issues_by_severity[severity] = []
                issues_by_severity[severity].append(issue)
            
            # Report issues by severity (critical first)
            severity_order = ['critical', 'high', 'medium', 'low', 'error', 'warning']
            for severity in severity_order:
                if severity in issues_by_severity and issues_by_severity[severity]:
                    f.write(f"\n{severity.upper()} ISSUES ({len(issues_by_severity[severity])}):\n")
                    f.write("=" * 50 + "\n")
                    
                    # Group by file
                    issues_by_file = {}
                    for issue in issues_by_severity[severity]:
                        file = issue['file']
                        if file not in issues_by_file:
                            issues_by_file[file] = []
                        issues_by_file[file].append(issue)
                    
                    for file, file_issues in issues_by_file.items():
                        f.write(f"\nFile: {file}\n")
                        f.write("-" * 30 + "\n")
                        
                        for issue in file_issues:
                            f.write(f"Line {issue['line']}: {issue['description']}\n")
                            if issue['line_content']:
                                f.write(f"  Code: {issue['line_content']}\n")
                            f.write(f"  Category: {issue['category']}\n")
                            f.write("\n")
        
        # Generate JSON report
        json_file = os.path.join(output_dir, "security_report.json")
        with open(json_file, 'w') as f:
            json.dump(scan_results, f, indent=2)
        
        # Generate summary file
        summary_file = os.path.join(output_dir, "summary.txt")
        with open(summary_file, 'w') as f:
            f.write(f"C Security Scan Summary\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"Total files scanned: {summary['total_files']}\n")
            f.write(f"Files with issues: {summary['files_with_issues']}\n")
            f.write(f"Total issues found: {summary['total_issues']}\n\n")
            
            f.write("Issues by severity:\n")
            for severity, count in summary['severity_counts'].items():
                if count > 0:
                    f.write(f"  {severity}: {count}\n")
        
        print(f"\nScan completed!")
        print(f"Total files: {summary['total_files']}")
        print(f"Files with issues: {summary['files_with_issues']}")
        print(f"Total issues: {summary['total_issues']}")
        print(f"Critical: {summary['severity_counts']['critical']}")
        print(f"High: {summary['severity_counts']['high']}")
        print(f"Medium: {summary['severity_counts']['medium']}")
        print(f"Low: {summary['severity_counts']['low']}")
        print(f"Errors: {summary['severity_counts']['error']}")
        print(f"Warnings: {summary['severity_counts']['warning']}")
        print(f"\nReports saved to: {output_dir}")
        
        return output_dir

def main():
    if len(sys.argv) != 2:
        print("Usage: python scan_c.py <directory>")
        print("Example: python scan_c.py input/1_Programming_Languages/C")
        sys.exit(1)
    
    directory = sys.argv[1]
    
    if not os.path.exists(directory):
        print(f"Error: Directory '{directory}' does not exist.")
        sys.exit(1)
    
    scanner = CSecurityScanner()
    print(f"Starting C security scan of: {directory}")
    
    # Scan the directory
    results = scanner.scan_directory(directory)
    
    # Generate report
    output_dir = scanner.generate_report(results)
    
    print(f"\nDetailed reports available in: {output_dir}")
    print("  - security_report.txt: Full text report")
    print("  - security_report.json: JSON format")
    print("  - summary.txt: Quick summary")

if __name__ == "__main__":
    main() 