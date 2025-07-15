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

class JavaSecurityScanner:
    def __init__(self):
        # Define patterns for common Java security vulnerabilities
        self.patterns = {
            'sql_injection': [
                (r'Statement\.executeQuery\s*\([^)]*\+', 'HIGH', 'Potential SQL injection - use PreparedStatement'),
                (r'Statement\.execute\s*\([^)]*\+', 'HIGH', 'Potential SQL injection - use PreparedStatement'),
                (r'createStatement\s*\(', 'MEDIUM', 'Consider using PreparedStatement for SQL queries'),
            ],
            'xss': [
                (r'response\.getWriter\(\)\.print\([^)]*request\.getParameter', 'HIGH', 'Potential XSS - sanitize user input'),
                (r'response\.getWriter\(\)\.write\([^)]*request\.getParameter', 'HIGH', 'Potential XSS - sanitize user input'),
            ],
            'file_handling': [
                (r'new\s+File\s*\([^)]*\+', 'MEDIUM', 'Potential path manipulation - validate file paths'),
                (r'\.createTempFile\s*\(', 'LOW', 'Ensure temp files are properly secured'),
            ],
            'command_injection': [
                (r'Runtime\.getRuntime\(\)\.exec\s*\([^)]*\+', 'HIGH', 'Potential command injection - validate input'),
                (r'ProcessBuilder\s*\([^)]*\+', 'HIGH', 'Potential command injection - validate input'),
            ],
            'crypto': [
                (r'MD5', 'HIGH', 'MD5 is cryptographically broken - use SHA-256 or better'),
                (r'SHA1', 'MEDIUM', 'SHA1 is weak - use SHA-256 or better'),
                (r'DES', 'HIGH', 'DES is cryptographically broken - use AES'),
                (r'Random\s*\(', 'MEDIUM', 'Use SecureRandom for cryptographic operations'),
            ],
            'serialization': [
                (r'implements\s+Serializable', 'LOW', 'Ensure secure serialization handling'),
                (r'ObjectInputStream', 'MEDIUM', 'Validate ObjectInputStream data'),
                (r'readObject', 'MEDIUM', 'Ensure proper validation in readObject'),
            ],
            'logging': [
                (r'\.printStackTrace\s*\(', 'LOW', 'Use proper logging instead of printStackTrace'),
                (r'System\.out\.print', 'LOW', 'Use proper logging framework instead of System.out'),
                (r'System\.err\.print', 'LOW', 'Use proper logging framework instead of System.err'),
            ],
            'authentication': [
                (r'equals\s*\([^)]*password', 'MEDIUM', 'Use constant-time comparison for passwords'),
                (r'\.contains\s*\([^)]*password', 'MEDIUM', 'Use constant-time comparison for passwords'),
            ],
            'session': [
                (r'getSession\s*\(\s*false\s*\)', 'LOW', 'Check session handling logic'),
                (r'setSecure\s*\(\s*false\s*\)', 'HIGH', 'Session cookie without secure flag'),
            ],
            'error_handling': [
                (r'catch\s*\(\s*Exception\s+\w+\s*\)', 'LOW', 'Catching generic Exception - consider specific exceptions'),
                (r'throw\s+new\s+Exception\s*\(', 'LOW', 'Throwing generic Exception - consider specific exceptions'),
            ],
            'spring_security': [
                (r'@PreAuthorize\s*\([^)]*\+', 'HIGH', 'Potential SpEL injection in @PreAuthorize'),
                (r'antMatchers\s*\([^)]*\)\.permitAll\s*\(\s*\)', 'MEDIUM', 'Check if permitAll is necessary'),
            ],
            'reflection': [
                (r'Class\.forName\s*\([^)]*\+', 'MEDIUM', 'Potential unsafe reflection - validate class names'),
                (r'\.getMethod\s*\([^)]*\+', 'MEDIUM', 'Potential unsafe reflection - validate method names'),
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
        print("Usage: java_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = JavaSecurityScanner()
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