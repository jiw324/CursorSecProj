#!/usr/bin/env python3
"""
PHP Security Scanner
Performs static analysis on PHP files for common security vulnerabilities
"""

import os
import re
import subprocess
import json
import sys
from datetime import datetime
from pathlib import Path

class PHPSecurityScanner:
    def __init__(self):
        self.vulnerabilities = []
        self.scan_results = {}
        
    def scan_php_file(self, file_path):
        """Scan a single PHP file for security vulnerabilities"""
        print(f"Scanning: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return []
        
        findings = []
        
        # 1. SQL Injection vulnerabilities
        sql_patterns = [
            (r'\$_GET\[[\'"]([^\'"]+)[\'"]\]', 'SQL Injection via $_GET'),
            (r'\$_POST\[[\'"]([^\'"]+)[\'"]\]', 'SQL Injection via $_POST'),
            (r'\$_REQUEST\[[\'"]([^\'"]+)[\'"]\]', 'SQL Injection via $_REQUEST'),
            (r'mysql_query\s*\(\s*\$', 'SQL Injection via mysql_query'),
            (r'mysqli_query\s*\(\s*\$', 'SQL Injection via mysqli_query'),
            (r'query\s*\(\s*\$', 'SQL Injection via query method'),
        ]
        
        for pattern, description in sql_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'SQL Injection',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'HIGH'
                })
        
        # 2. XSS vulnerabilities
        xss_patterns = [
            (r'echo\s+\$_GET\[[\'"]([^\'"]+)[\'"]\]', 'XSS via echo $_GET'),
            (r'echo\s+\$_POST\[[\'"]([^\'"]+)[\'"]\]', 'XSS via echo $_POST'),
            (r'print\s+\$_GET\[[\'"]([^\'"]+)[\'"]\]', 'XSS via print $_GET'),
            (r'print\s+\$_POST\[[\'"]([^\'"]+)[\'"]\]', 'XSS via print $_POST'),
            (r'<\?php\s+echo\s+\$_', 'XSS via direct echo of user input'),
        ]
        
        for pattern, description in xss_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'Cross-Site Scripting (XSS)',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'HIGH'
                })
        
        # 3. File inclusion vulnerabilities
        file_inclusion_patterns = [
            (r'include\s*\(\s*\$', 'File Inclusion via include'),
            (r'require\s*\(\s*\$', 'File Inclusion via require'),
            (r'include_once\s*\(\s*\$', 'File Inclusion via include_once'),
            (r'require_once\s*\(\s*\$', 'File Inclusion via require_once'),
        ]
        
        for pattern, description in file_inclusion_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'File Inclusion',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'HIGH'
                })
        
        # 4. Command injection vulnerabilities
        cmd_patterns = [
            (r'exec\s*\(\s*\$', 'Command Injection via exec'),
            (r'system\s*\(\s*\$', 'Command Injection via system'),
            (r'shell_exec\s*\(\s*\$', 'Command Injection via shell_exec'),
            (r'passthru\s*\(\s*\$', 'Command Injection via passthru'),
            (r'`.*\$.*`', 'Command Injection via backticks'),
        ]
        
        for pattern, description in cmd_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'Command Injection',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'CRITICAL'
                })
        
        # 5. Weak cryptography
        crypto_patterns = [
            (r'md5\s*\(\s*\$', 'Weak cryptography: MD5'),
            (r'sha1\s*\(\s*\$', 'Weak cryptography: SHA1'),
            (r'base64_encode\s*\(\s*\$', 'Weak encoding: base64'),
        ]
        
        for pattern, description in crypto_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'Weak Cryptography',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'MEDIUM'
                })
        
        # 6. Error disclosure
        error_patterns = [
            (r'error_reporting\s*\(\s*E_ALL\s*\)', 'Error disclosure: E_ALL enabled'),
            (r'display_errors\s*\(\s*true\s*\)', 'Error disclosure: display_errors enabled'),
            (r'ini_set\s*\(\s*[\'"]display_errors[\'"]\s*,\s*true\s*\)', 'Error disclosure: display_errors set to true'),
        ]
        
        for pattern, description in error_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'Error Disclosure',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'MEDIUM'
                })
        
        # 7. Insecure file operations
        file_patterns = [
            (r'fopen\s*\(\s*\$', 'Insecure file operation: fopen with variable'),
            (r'file_get_contents\s*\(\s*\$', 'Insecure file operation: file_get_contents with variable'),
            (r'file_put_contents\s*\(\s*\$', 'Insecure file operation: file_put_contents with variable'),
        ]
        
        for pattern, description in file_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'Insecure File Operation',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'HIGH'
                })
        
        # 8. Session security issues
        session_patterns = [
            (r'session_start\s*\(\s*\)', 'Session security: session_start without parameters'),
            (r'\$_SESSION\[[\'"]([^\'"]+)[\'"]\]\s*=\s*\$', 'Session security: direct assignment to $_SESSION'),
        ]
        
        for pattern, description in session_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                findings.append({
                    'type': 'Session Security',
                    'description': description,
                    'line': line_num,
                    'code': match.group(0),
                    'severity': 'MEDIUM'
                })
        
        return findings
    
    def check_php_syntax(self, file_path):
        """Check PHP syntax using php -l"""
        try:
            result = subprocess.run(['php', '-l', file_path], 
                                  capture_output=True, text=True, timeout=30)
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", "Syntax check timed out"
        except Exception as e:
            return False, "", str(e)
    
    def scan_directory(self, input_dir, output_dir):
        """Scan all PHP files in a directory"""
        php_files = list(Path(input_dir).rglob("*.php"))
        
        if not php_files:
            print(f"No PHP files found in {input_dir}")
            return
        
        print(f"Found {len(php_files)} PHP files to scan")
        
        total_findings = 0
        syntax_errors = 0
        
        for php_file in php_files:
            print(f"\nProcessing: {php_file}")
            
            # Check syntax first
            syntax_ok, syntax_out, syntax_err = self.check_php_syntax(str(php_file))
            if not syntax_ok:
                print(f"Syntax error in {php_file}: {syntax_err}")
                syntax_errors += 1
                continue
            
            # Perform security scan
            findings = self.scan_php_file(str(php_file))
            
            if findings:
                self.scan_results[str(php_file)] = {
                    'findings': findings,
                    'count': len(findings)
                }
                total_findings += len(findings)
                print(f"Found {len(findings)} security issues")
            else:
                self.scan_results[str(php_file)] = {
                    'findings': [],
                    'count': 0
                }
                print("No security issues found")
        
        # Generate report
        self.generate_report(output_dir, total_findings, syntax_errors)
    
    def generate_report(self, output_dir, total_findings, syntax_errors):
        """Generate a comprehensive security report in CodeQL format"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(output_dir, f"PHP_{timestamp}")
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        with open(report_file, 'w') as f:
            f.write("CodeQL Security Scan Report - PHP\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("=" * 60 + "\n\n")
            
            for file_path, result in self.scan_results.items():
                # Get just the filename for display
                filename = os.path.basename(file_path)
                f.write("=" * 30 + "\n")
                f.write(f"File: {file_path}\n")
                f.write("-" * 30 + "\n")
                
                if result['findings']:
                    for finding in result['findings']:
                        severity = finding['severity']
                        vuln_type = finding['type'].replace(' ', '-').lower()
                        description = finding['description']
                        line = finding['line']
                        
                        f.write(f"[{severity}] {vuln_type} at {filename}:{line}: {description}\n")
                else:
                    f.write("No findings.\n")
                
                f.write("\n")
        
        print(f"\nReport generated: {report_file}")
        print(f"Total security issues found: {total_findings}")
        print(f"Files with syntax errors: {syntax_errors}")

def main():
    if len(sys.argv) != 3:
        print("Usage: python scan_php.py <input_directory> <output_directory>")
        sys.exit(1)
    
    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    
    if not os.path.exists(input_dir):
        print(f"Input directory does not exist: {input_dir}")
        sys.exit(1)
    
    scanner = PHPSecurityScanner()
    scanner.scan_directory(input_dir, output_dir)

if __name__ == "__main__":
    main() 