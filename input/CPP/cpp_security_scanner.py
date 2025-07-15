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

class CPPSecurityScanner:
    def __init__(self):
        # Define patterns for common C++ security vulnerabilities
        self.patterns = {
            'buffer_overflow': [
                (r'strcpy\s*\([^)]*\)', 'HIGH', 'Use of unsafe strcpy() - consider std::string'),
                (r'strcat\s*\([^)]*\)', 'HIGH', 'Use of unsafe strcat() - consider std::string'),
                (r'sprintf\s*\([^)]*\)', 'MEDIUM', 'Use of unsafe sprintf() - consider std::stringstream'),
                (r'gets\s*\([^)]*\)', 'HIGH', 'Use of unsafe gets() - consider std::getline'),
            ],
            'memory_management': [
                (r'new\s+\w+\s*\[[^]]+\]', 'MEDIUM', 'Raw array allocation - consider std::vector'),
                (r'delete\s*\[[^]]*\]', 'LOW', 'Manual array deletion - consider smart pointers'),
                (r'malloc\s*\([^)]*\)', 'HIGH', 'C-style memory allocation - use new or smart pointers'),
                (r'free\s*\([^)]*\)', 'HIGH', 'C-style memory deallocation - use delete or smart pointers'),
            ],
            'exception_handling': [
                (r'catch\s*\(\s*\.\.\.\s*\)', 'MEDIUM', 'Catching all exceptions may hide critical issues'),
                (r'throw\s+\"[^\"]*\"', 'LOW', 'Throwing string literals - consider std::exception'),
            ],
            'input_validation': [
                (r'cin\s*>>\s*[^;]+;', 'LOW', 'Check input validation and buffer limits'),
                (r'scanf\s*\([^)]*\)', 'HIGH', 'Use of unsafe scanf() - consider std::cin'),
            ],
            'type_safety': [
                (r'reinterpret_cast', 'MEDIUM', 'Dangerous type casting - ensure type safety'),
                (r'const_cast', 'MEDIUM', 'Removing const qualifier - potential safety issue'),
                (r'static_cast<void\s*\*>', 'MEDIUM', 'Unsafe void* casting'),
            ],
            'concurrency': [
                (r'pthread_', 'LOW', 'Consider using std::thread instead of pthreads'),
                (r'volatile', 'MEDIUM', 'Volatile may not be appropriate for concurrency'),
            ],
            'resource_management': [
                (r'fopen\s*\([^)]*\)', 'MEDIUM', 'Use RAII with std::fstream instead'),
                (r'FILE\s*\*', 'MEDIUM', 'Use std::fstream instead of C-style file handling'),
            ],
            'stl_usage': [
                (r'vector\s*\.\s*at\s*\([^)]*\)', 'LOW', 'Consider bounds checking or iterator usage'),
                (r'auto_ptr', 'HIGH', 'Deprecated auto_ptr usage - use unique_ptr'),
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
        print("Usage: cpp_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = CPPSecurityScanner()
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