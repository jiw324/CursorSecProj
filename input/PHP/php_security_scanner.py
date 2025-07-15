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

class PHPSecurityScanner:
    def __init__(self):
        # Define patterns for common PHP security vulnerabilities
        self.patterns = {
            'sql_injection': [
                (r"mysql_query\s*\(\s*['\"]?\$", 'HIGH', 'Direct use of user input in SQL queries - use prepared statements'),
                (r"mysqli_query\s*\(\s*['\"]?\$", 'HIGH', 'Potential SQL injection - use prepared statements'),
                (r"->query\s*\(\s*['\"]?\$", 'HIGH', 'Potential SQL injection - use prepared statements'),
            ],
            'command_injection': [
                (r"(system|exec|passthru|shell_exec|popen|proc_open)\s*\(\s*\$", 'HIGH', 'Potential command injection - validate and escape input'),
                (r"eval\s*\(\s*\$", 'HIGH', 'Dangerous eval() usage - potential code injection'),
                (r"create_function\s*\(\s*\$", 'HIGH', 'Dangerous dynamic function creation - potential code injection'),
            ],
            'xss': [
                (r"echo\s+\$_(GET|POST|REQUEST|COOKIE)", 'HIGH', 'Unescaped output of user input - use htmlspecialchars()'),
                (r"print\s+\$_(GET|POST|REQUEST|COOKIE)", 'HIGH', 'Unescaped output of user input - use htmlspecialchars()'),
                (r"<\?=\s*\$_(GET|POST|REQUEST|COOKIE)", 'HIGH', 'Unescaped short echo tag with user input - use htmlspecialchars()'),
            ],
            'file_inclusion': [
                (r"include\s*\(\s*\$", 'HIGH', 'Dynamic file inclusion - potential LFI/RFI vulnerability'),
                (r"require\s*\(\s*\$", 'HIGH', 'Dynamic file inclusion - potential LFI/RFI vulnerability'),
                (r"include_once\s*\(\s*\$", 'HIGH', 'Dynamic file inclusion - potential LFI/RFI vulnerability'),
                (r"require_once\s*\(\s*\$", 'HIGH', 'Dynamic file inclusion - potential LFI/RFI vulnerability'),
            ],
            'file_upload': [
                (r"move_uploaded_file\s*\(\s*\$", 'MEDIUM', 'Validate file uploads - check type, size, and scan for malware'),
                (r"\$_FILES\[['\"].*?['\"]\]\[['\"]name['\"]\]", 'MEDIUM', 'Verify file upload name and type'),
            ],
            'crypto': [
                (r"md5\s*\(", 'MEDIUM', 'Weak hashing algorithm - use password_hash() for passwords'),
                (r"sha1\s*\(", 'MEDIUM', 'Weak hashing algorithm - use password_hash() for passwords'),
                (r"crypt\s*\(", 'MEDIUM', 'Outdated encryption - use modern alternatives'),
            ],
            'file_operation': [
                (r"file_get_contents\s*\(\s*\$", 'MEDIUM', 'Unsafe file operation - validate file paths'),
                (r"fopen\s*\(\s*\$", 'MEDIUM', 'Unsafe file operation - validate file paths'),
                (r"unlink\s*\(\s*\$", 'MEDIUM', 'Unsafe file deletion - validate file paths'),
            ],
            'session_security': [
                (r"session_id\s*\(\s*\$", 'HIGH', 'Manual session ID assignment - security risk'),
                (r"session_regenerate_id\s*\(\s*false", 'MEDIUM', 'Set session_regenerate_id() second parameter to true'),
            ],
            'deserialization': [
                (r"unserialize\s*\(\s*\$", 'HIGH', 'Unsafe deserialization of user input - use JSON'),
                (r"deserialize\s*\(\s*\$", 'HIGH', 'Unsafe deserialization of user input - use JSON'),
            ],
            'configuration': [
                (r"ini_set\s*\(\s*['\"]display_errors['\"]", 'LOW', 'Configure error display in php.ini instead'),
                (r"error_reporting\s*\(\s*0\s*\)", 'LOW', 'Disabling error reporting is not recommended'),
                (r"set_error_handler\s*\(\s*null", 'LOW', 'Implement proper error handling'),
            ],
            'debug': [
                (r"var_dump\s*\(", 'LOW', 'Debug function in production code'),
                (r"print_r\s*\(", 'LOW', 'Debug function in production code'),
                (r"var_export\s*\(", 'LOW', 'Debug function in production code'),
            ],
            'database': [
                (r"->connect\s*\(\s*['\"]root['\"]", 'HIGH', 'Using root database user - security risk'),
                (r"mysql_connect\s*\(", 'HIGH', 'Deprecated mysql_* functions - use mysqli or PDO'),
            ],
            'authentication': [
                (r"strcmp\s*\(\s*\$password", 'MEDIUM', 'Timing attack vulnerability in password comparison'),
                (r"==\s*\$password", 'HIGH', 'Unsafe password comparison - use password_verify()'),
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
        print("Usage: php_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = PHPSecurityScanner()
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