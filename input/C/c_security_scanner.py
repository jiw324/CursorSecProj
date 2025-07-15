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

class CSecurityScanner:
    def __init__(self):
        # Define patterns for common C security vulnerabilities
        self.patterns = {
            'buffer_overflow': [
                (r'gets\s*\([^)]*\)', 'HIGH', 'Use of unsafe gets() function'),
                (r'strcpy\s*\([^)]*\)', 'MEDIUM', 'Use of unsafe strcpy() - consider strncpy'),
                (r'strcat\s*\([^)]*\)', 'MEDIUM', 'Use of unsafe strcat() - consider strncat'),
                (r'sprintf\s*\([^)]*\)', 'MEDIUM', 'Use of unsafe sprintf() - consider snprintf'),
            ],
            'format_string': [
                (r'printf\s*\([^,)]*\)', 'HIGH', 'Potential format string vulnerability'),
                (r'scanf\s*\([^,)]*\)', 'HIGH', 'Potential format string vulnerability'),
            ],
            'integer_overflow': [
                (r'(?<!\w)(unsigned\s+)?int\s+\w+\s*=\s*\w+\s*\+\s*\w+', 'MEDIUM', 'Potential integer overflow'),
                (r'(?<!\w)(unsigned\s+)?int\s+\w+\s*\+=', 'MEDIUM', 'Potential integer overflow'),
            ],
            'memory_leaks': [
                (r'malloc\s*\([^)]*\)', 'LOW', 'Check for proper memory deallocation'),
                (r'calloc\s*\([^)]*\)', 'LOW', 'Check for proper memory deallocation'),
            ],
            'command_injection': [
                (r'system\s*\([^)]*\)', 'HIGH', 'Potential command injection vulnerability'),
                (r'popen\s*\([^)]*\)', 'HIGH', 'Potential command injection vulnerability'),
            ],
            'crypto': [
                (r'rand\s*\(\s*\)', 'MEDIUM', 'Use of weak random number generator'),
                (r'srand\s*\(\s*\)', 'MEDIUM', 'Use of weak random seed'),
            ],
            'file_operation': [
                (r'fopen\s*\([^)]*\)', 'LOW', 'Check file operation security'),
                (r'freopen\s*\([^)]*\)', 'LOW', 'Check file operation security'),
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
        print("Usage: c_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = CSecurityScanner()
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