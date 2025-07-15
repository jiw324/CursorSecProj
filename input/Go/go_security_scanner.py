#!/usr/bin/env python3

import os
import re
import sys
from typing import List, Dict, Tuple
from dataclasses import dataclass
from pathlib import Path

@dataclass
class SecurityIssue:
    file: str
    line: int
    severity: str  # 'HIGH', 'MEDIUM', 'LOW'
    category: str
    description: str
    code: str

class GoSecurityScanner:
    def __init__(self):
        # Define patterns for common Go security vulnerabilities
        self.patterns = {
            'sql_injection': [
                (r'db\.Query\s*\([^)]*\+', 'HIGH', 'Potential SQL injection - use parameterized queries'),
                (r'db\.Exec\s*\([^)]*\+', 'HIGH', 'Potential SQL injection - use parameterized queries'),
            ],
            'command_injection': [
                (r'exec\.Command\s*\([^)]*\+', 'HIGH', 'Potential command injection - validate input'),
                (r'os\.StartProcess\s*\([^)]*\+', 'HIGH', 'Potential command injection - validate input'),
            ],
            'crypto': [
                (r'math/rand\.', 'HIGH', 'Use crypto/rand for secure random numbers'),
                (r'MD5\.', 'HIGH', 'MD5 is cryptographically broken - use SHA-256 or better'),
                (r'\.Write\s*\(\s*\[\]byte\s*\(\s*password\s*\)', 'MEDIUM', 'Potential plaintext password handling'),
            ],
            'error_handling': [
                (r'_\s*=\s*err', 'MEDIUM', 'Ignoring error return value'),
                (r'panic\s*\(', 'LOW', 'Panic usage - consider error handling'),
                (r'log\.Fatal', 'LOW', 'Fatal error stops program - consider graceful handling'),
            ],
            'file_handling': [
                (r'ioutil\.ReadFile\s*\([^)]*\)', 'LOW', 'Consider using os.Open for large files'),
                (r'os\.Open\s*\([^)]*\+', 'MEDIUM', 'Potential path manipulation - validate input'),
            ],
            'http_security': [
                (r'http\.ListenAndServe\s*\([^)]*\)', 'LOW', 'Consider using ListenAndServeTLS'),
                (r'w\.Header\(\)\.Set\s*\(\s*"Access-Control-Allow-Origin"\s*,\s*"\*"', 'MEDIUM', 'Overly permissive CORS'),
                (r'Cookie\{[^}]*Secure:\s*false', 'MEDIUM', 'Cookie without Secure flag'),
                (r'Cookie\{[^}]*HttpOnly:\s*false', 'MEDIUM', 'Cookie without HttpOnly flag'),
            ],
            'template_injection': [
                (r'template\.HTML\s*\(', 'HIGH', 'Potential XSS - ensure input is trusted'),
                (r'template\.URL\s*\(', 'HIGH', 'Potential XSS - ensure input is trusted'),
            ],
            'logging_sensitive': [
                (r'log\.Print.*password', 'HIGH', 'Potential sensitive data logging'),
                (r'log\.Print.*token', 'HIGH', 'Potential sensitive data logging'),
                (r'log\.Print.*secret', 'HIGH', 'Potential sensitive data logging'),
            ],
            'goroutine_safety': [
                (r'go\s+func\s*\([^)]*\)\s*{[^}]*defer', 'LOW', 'Deferred call in goroutine - ensure cleanup'),
                (r'sync\.Mutex\s*[^{]*{\s*[^}]*go\s+', 'MEDIUM', 'Check mutex usage across goroutines'),
            ],
            'input_validation': [
                (r'json\.Unmarshal\s*\([^)]*interface\{\}', 'LOW', 'Consider using specific types instead of interface{}'),
                (r'strconv\.Atoi\s*\([^)]*\)', 'LOW', 'Check for conversion errors'),
            ]
        }

    def scan_file(self, file_path: str) -> List[SecurityIssue]:
        issues = []
        try:
            with open(file_path, 'r') as f:
                content = f.readlines()
            
            for line_num, line in enumerate(content, 1):
                for category, patterns in self.patterns.items():
                    for pattern, severity, desc in patterns:
                        if re.search(pattern, line):
                            issues.append(SecurityIssue(
                                file=file_path,
                                line=line_num,
                                severity=severity,
                                category=category,
                                description=desc,
                                code=line.strip()
                            ))
        except Exception as e:
            print(f"Error scanning file {file_path}: {str(e)}", file=sys.stderr)
        
        return issues

def main():
    if len(sys.argv) != 3:
        print("Usage: go_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = GoSecurityScanner()
    issues = scanner.scan_file(input_file)
    
    # Create output directory if it doesn't exist
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        f.write(f"Security Scan Report for {input_file}\n")
        f.write("=" * 50 + "\n\n")
        
        if not issues:
            f.write("No security issues found.\n")
        else:
            for issue in issues:
                f.write(f"SEVERITY: {issue.severity}\n")
                f.write(f"CATEGORY: {issue.category}\n")
                f.write(f"LINE: {issue.line}\n")
                f.write(f"DESCRIPTION: {issue.description}\n")
                f.write(f"CODE: {issue.code}\n")
                f.write("-" * 50 + "\n\n")

if __name__ == "__main__":
    main() 