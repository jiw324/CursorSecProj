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

class RustSecurityScanner:
    def __init__(self):
        # Define patterns for common Rust security vulnerabilities
        self.patterns = {
            'unsafe_code': [
                (r"unsafe\s*{", 'HIGH', 'Unsafe block usage - verify memory safety'),
                (r"unsafe\s+fn", 'HIGH', 'Unsafe function declaration - verify memory safety'),
                (r"unsafe\s+trait", 'HIGH', 'Unsafe trait declaration - verify implementation safety'),
                (r"unsafe\s+impl", 'HIGH', 'Unsafe implementation - verify trait safety'),
            ],
            'memory_safety': [
                (r"std::mem::transmute", 'HIGH', 'Unsafe memory transmutation - verify type safety'),
                (r"std::ptr::(read|write)", 'HIGH', 'Raw pointer manipulation - verify memory safety'),
                (r"Box::into_raw", 'MEDIUM', 'Raw pointer creation - ensure proper cleanup'),
                (r"std::mem::forget", 'MEDIUM', 'Memory leak risk - ensure resource cleanup'),
            ],
            'concurrency': [
                (r"std::sync::Mutex::new\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled mutex creation failure'),
                (r"\.lock\(\)\.unwrap\(\)", 'MEDIUM', 'Unhandled mutex lock failure'),
                (r"std::thread::spawn\s*\(\s*move\s*\|\|", 'LOW', 'Verify thread safety and resource sharing'),
                (r"Arc::new\(Mutex::new\([^)]*\)\)", 'LOW', 'Verify thread-safe resource sharing'),
            ],
            'error_handling': [
                (r"unwrap\(\)", 'MEDIUM', 'Potential panic - handle errors explicitly'),
                (r"expect\([^\)]+\)", 'MEDIUM', 'Potential panic - handle errors explicitly'),
                (r"panic!\s*\(", 'LOW', 'Explicit panic - consider error handling'),
                (r"assert!", 'LOW', 'Runtime assertion - verify necessity'),
            ],
            'input_validation': [
                (r"String::from_utf8_unchecked", 'HIGH', 'Unsafe UTF-8 conversion - use checked version'),
                (r"str::from_utf8_unchecked", 'HIGH', 'Unsafe UTF-8 conversion - use checked version'),
                (r"\.parse::<[^>]+>\(\)\.unwrap\(\)", 'MEDIUM', 'Unhandled parse error'),
                (r"from_str\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled string conversion'),
            ],
            'file_operations': [
                (r"std::fs::(read|write)", 'LOW', 'Verify file operation safety'),
                (r"File::open\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled file operation error'),
                (r"std::fs::remove", 'MEDIUM', 'Verify file deletion safety'),
                (r"std::path::Path::new\([^)]*\.\.[^)]*\)", 'HIGH', 'Path traversal risk - validate paths'),
            ],
            'crypto': [
                (r"rand::random", 'LOW', 'Verify cryptographic security requirements'),
                (r"rand::thread_rng", 'LOW', 'Verify random number generator security'),
                (r"md5::compute", 'HIGH', 'Weak hash algorithm - use SHA-256 or better'),
                (r"sha1::Sha1::new", 'MEDIUM', 'Weak hash algorithm - use SHA-256 or better'),
            ],
            'serialization': [
                (r"serde_json::from_str\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled JSON parsing error'),
                (r"serde_yaml::from_str", 'MEDIUM', 'Verify YAML parsing safety'),
                (r"bincode::deserialize", 'MEDIUM', 'Verify binary deserialization safety'),
                (r"::deserialize\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled deserialization error'),
            ],
            'network': [
                (r"TcpListener::bind\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled network binding error'),
                (r"TcpStream::connect\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled connection error'),
                (r"UdpSocket::bind\([^)]*\)\.unwrap\(\)", 'MEDIUM', 'Unhandled socket binding error'),
                (r"\.set_nonblocking\(", 'LOW', 'Verify non-blocking socket handling'),
            ],
            'command_execution': [
                (r"std::process::Command::new\([^)]*\)\.output\(\)\.unwrap\(\)", 'HIGH', 'Unhandled command execution error'),
                (r"::spawn\(\)\.unwrap\(\)", 'MEDIUM', 'Unhandled process spawn error'),
                (r"\.args\(&\[.*\$.*\]\)", 'HIGH', 'Command injection risk - validate input'),
                (r"\.arg\(format!", 'HIGH', 'Command injection risk - validate input'),
            ],
            'logging': [
                (r"println!\s*\([^)]*\{[^}]*\}", 'LOW', 'Debug print - use proper logging'),
                (r"debug!\s*\([^)]*\{[^}]*\}", 'LOW', 'Verify debug log content'),
                (r"error!\s*\([^)]*\{[^}]*\}", 'LOW', 'Verify error log content'),
                (r"trace!\s*\([^)]*\{[^}]*\}", 'LOW', 'Verify trace log content'),
            ],
            'unsafe_traits': [
                (r"#\[derive\(Copy\)\]", 'LOW', 'Verify Copy trait implementation safety'),
                (r"impl\s+Send\s+for", 'MEDIUM', 'Verify Send trait implementation safety'),
                (r"impl\s+Sync\s+for", 'MEDIUM', 'Verify Sync trait implementation safety'),
                (r"std::marker::PhantomData", 'LOW', 'Verify phantom data usage'),
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
        print("Usage: rust_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = RustSecurityScanner()
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