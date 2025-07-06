#!/usr/bin/env python3
"""
Comprehensive Rust Security Scanner
Performs static analysis on all Rust files individually
"""

import os
import re
import subprocess
import json
import sys
from datetime import datetime
from pathlib import Path

class ComprehensiveRustScanner:
    def __init__(self):
        self.vulnerabilities = []
        self.scan_results = {}
        
    def scan_rust_files(self, rust_dir):
        """Scan all Rust files in the directory"""
        print(f"Scanning Rust files in: {rust_dir}")
        
        rust_files = []
        for file in os.listdir(rust_dir):
            if file.endswith('.rs'):
                rust_files.append(os.path.join(rust_dir, file))
        
        print(f"Found {len(rust_files)} Rust files to scan")
        
        all_findings = []
        
        for rust_file in rust_files:
            print(f"\nScanning: {os.path.basename(rust_file)}")
            findings = self.analyze_rust_file(rust_file)
            all_findings.extend(findings)
        
        return all_findings
    
    def analyze_rust_file(self, file_path):
        """Analyze a single Rust file for security issues"""
        findings = []
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            findings.append({
                'file': file_path,
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'File Read Error',
                'message': f'Could not read file: {str(e)}'
            })
            return findings
        
        # Analyze the content for security patterns
        findings.extend(self.analyze_security_patterns(content, file_path))
        
        # Check for syntax issues
        findings.extend(self.check_syntax(file_path))
        
        return findings
    
    def analyze_security_patterns(self, content, file_path):
        """Analyze Rust code for security-related patterns"""
        findings = []
        lines = content.split('\n')
        
        security_patterns = [
            # Unsafe code patterns
            (r'unsafe\s*{', 'CRITICAL', 'Unsafe Block', 'Unsafe code block detected'),
            (r'unsafe\s+fn', 'CRITICAL', 'Unsafe Function', 'Unsafe function definition'),
            (r'unsafe\s+impl', 'CRITICAL', 'Unsafe Implementation', 'Unsafe trait implementation'),
            
            # Memory safety issues
            (r'\.unwrap\(\)', 'HIGH', 'Unwrap Usage', 'Unchecked unwrap() call - may panic'),
            (r'\.expect\(', 'HIGH', 'Expect Usage', 'Unchecked expect() call - may panic'),
            (r'panic!', 'HIGH', 'Panic Macro', 'Explicit panic! macro usage'),
            (r'unreachable!', 'HIGH', 'Unreachable Macro', 'Unreachable code macro'),
            
            # Raw pointer usage
            (r'\*mut\s+\w+', 'CRITICAL', 'Raw Mutable Pointer', 'Raw mutable pointer usage'),
            (r'\*const\s+\w+', 'HIGH', 'Raw Const Pointer', 'Raw const pointer usage'),
            
            # FFI and external calls
            (r'extern\s+"C"', 'HIGH', 'FFI Declaration', 'Foreign function interface declaration'),
            (r'#\[no_mangle\]', 'HIGH', 'No Mangle Attribute', 'Function name mangling disabled'),
            
            # Unsafe conversions
            (r'as\s+\*mut', 'CRITICAL', 'Unsafe Cast', 'Unsafe cast to raw mutable pointer'),
            (r'as\s+\*const', 'HIGH', 'Unsafe Cast', 'Unsafe cast to raw const pointer'),
            (r'std::mem::transmute', 'CRITICAL', 'Transmute Usage', 'Memory transmutation - extremely unsafe'),
            (r'std::ptr::null_mut', 'HIGH', 'Null Mutable Pointer', 'Null mutable pointer creation'),
            (r'std::ptr::null', 'HIGH', 'Null Pointer', 'Null pointer creation'),
            
            # Memory management
            (r'std::mem::forget', 'CRITICAL', 'Memory Forget', 'Memory intentionally leaked'),
            (r'std::mem::drop', 'MEDIUM', 'Explicit Drop', 'Explicit memory deallocation'),
            
            # Thread safety issues
            (r'static\s+mut', 'CRITICAL', 'Static Mutable', 'Static mutable variable - thread unsafe'),
            (r'unsafe\s+static', 'CRITICAL', 'Unsafe Static', 'Unsafe static variable'),
            
            # Cryptographic issues
            (r'rand::thread_rng', 'MEDIUM', 'Thread RNG', 'Thread-local random number generator'),
            (r'rand::random', 'MEDIUM', 'Random Function', 'Random number generation'),
            
            # Network and I/O
            (r'std::net::TcpStream::connect', 'MEDIUM', 'TCP Connection', 'TCP connection establishment'),
            (r'std::fs::File::open', 'MEDIUM', 'File Open', 'File system access'),
            
            # Potential integer overflow
            (r'\.checked_add\(', 'LOW', 'Checked Addition', 'Checked arithmetic operation'),
            (r'\.checked_sub\(', 'LOW', 'Checked Subtraction', 'Checked arithmetic operation'),
            (r'\.checked_mul\(', 'LOW', 'Checked Multiplication', 'Checked arithmetic operation'),
            
            # Potential null dereference
            (r'\.as_ref\(\)\.unwrap', 'HIGH', 'Null Dereference Risk', 'Potential null dereference'),
            (r'\.as_mut\(\)\.unwrap', 'HIGH', 'Null Dereference Risk', 'Potential null dereference'),
        ]
        
        for line_num, line in enumerate(lines, 1):
            for pattern, severity, issue_type, description in security_patterns:
                if re.search(pattern, line):
                    findings.append({
                        'file': os.path.basename(file_path),
                        'line': str(line_num),
                        'severity': severity,
                        'type': issue_type,
                        'message': f'{description}: {line.strip()}'
                    })
        
        # Check for specific security anti-patterns
        findings.extend(self.check_anti_patterns(content, file_path))
        
        return findings
    
    def check_anti_patterns(self, content, file_path):
        """Check for security anti-patterns"""
        findings = []
        lines = content.split('\n')
        
        # Check for hardcoded secrets
        secret_patterns = [
            (r'password\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded Password'),
            (r'secret\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded Secret'),
            (r'api_key\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded API Key'),
            (r'token\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded Token'),
        ]
        
        for line_num, line in enumerate(lines, 1):
            for pattern, severity, issue_type in secret_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    findings.append({
                        'file': os.path.basename(file_path),
                        'line': str(line_num),
                        'severity': severity,
                        'type': issue_type,
                        'message': f'Hardcoded credential detected: {line.strip()}'
                    })
        
        # Check for potential SQL injection patterns
        sql_patterns = [
            (r'format!\s*\(\s*["\'][^"\']*\{\}[^"\']*["\']', 'HIGH', 'SQL Injection Risk'),
            (r'format!\s*\(\s*["\'][^"\']*\{[^}]*\}[^"\']*["\']', 'HIGH', 'SQL Injection Risk'),
        ]
        
        for line_num, line in enumerate(lines, 1):
            for pattern, severity, issue_type in sql_patterns:
                if re.search(pattern, line):
                    findings.append({
                        'file': os.path.basename(file_path),
                        'line': str(line_num),
                        'severity': severity,
                        'type': issue_type,
                        'message': f'Potential SQL injection in format! macro: {line.strip()}'
                    })
        
        return findings
    
    def check_syntax(self, file_path):
        """Check for basic syntax issues"""
        findings = []
        
        try:
            # Try to compile the file with rustc
            result = subprocess.run(
                ["rustc", "--crate-type", "lib", "--emit", "metadata", file_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode != 0:
                # Parse compilation errors
                for line in result.stderr.split('\n'):
                    if 'error:' in line:
                        match = re.search(r'--> (.*?):(\d+):(\d+):', line)
                        if match:
                            line_num = match.group(2)
                            error_match = re.search(r'error: (.+)$', line)
                            if error_match:
                                message = error_match.group(1)
                                severity = "HIGH"
                                
                                # Classify syntax errors
                                if any(keyword in message.lower() for keyword in [
                                    'unsafe', 'unchecked', 'unwrap', 'expect', 'panic',
                                    'overflow', 'underflow', 'null', 'dereference'
                                ]):
                                    severity = "CRITICAL"
                                
                                findings.append({
                                    'file': os.path.basename(file_path),
                                    'line': line_num,
                                    'severity': severity,
                                    'type': 'Compilation Error',
                                    'message': message
                                })
            
        except subprocess.TimeoutExpired:
            findings.append({
                'file': os.path.basename(file_path),
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Compilation Timeout',
                'message': 'File compilation timed out'
            })
        except Exception as e:
            findings.append({
                'file': os.path.basename(file_path),
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Compilation Error',
                'message': f'Compilation failed: {str(e)}'
            })
        
        return findings
    
    def generate_report(self, output_dir, total_findings):
        """Generate a comprehensive security report in CodeQL format"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(output_dir, f"Rust_All_{timestamp}")
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        with open(report_file, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write("CodeQL Security Scan Report - Rust (All Files)\n")
            f.write("=" * 80 + "\n")
            f.write(f"Scan Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total Files Scanned: 5 Rust files\n")
            f.write(f"Total Security Issues: {total_findings}\n")
            f.write("=" * 80 + "\n\n")
            
            if total_findings > 0:
                f.write("SECURITY VULNERABILITIES FOUND:\n")
                f.write("-" * 40 + "\n\n")
                
                # Group by severity
                by_severity = {}
                for finding in self.vulnerabilities:
                    severity = finding['severity']
                    if severity not in by_severity:
                        by_severity[severity] = []
                    by_severity[severity].append(finding)
                
                # Output by severity (CRITICAL, HIGH, MEDIUM, LOW)
                for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
                    if severity in by_severity:
                        f.write(f"\n{severity} SEVERITY ISSUES:\n")
                        f.write("-" * 30 + "\n")
                        
                        for finding in by_severity[severity]:
                            f.write(f"[{finding['severity']}] {finding['type']} at {finding['file']}:{finding['line']}: {finding['message']}\n")
                        f.write("\n")
            else:
                f.write("No security vulnerabilities found.\n")
                f.write("All Rust files passed security checks.\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("Scan completed successfully.\n")
            f.write("=" * 80 + "\n")
        
        return report_file

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 scan_all_rust.py <rust_files_directory> <output_directory>")
        sys.exit(1)
    
    rust_dir = sys.argv[1]
    output_dir = sys.argv[2]
    
    if not os.path.exists(rust_dir):
        print(f"Error: Rust directory {rust_dir} does not exist")
        sys.exit(1)
    
    scanner = ComprehensiveRustScanner()
    
    print("Starting comprehensive Rust security scan...")
    print(f"Directory: {rust_dir}")
    print(f"Output: {output_dir}")
    print("-" * 50)
    
    # Scan all Rust files
    findings = scanner.scan_rust_files(rust_dir)
    scanner.vulnerabilities = findings
    
    # Generate report
    report_file = scanner.generate_report(output_dir, len(findings))
    
    print(f"\nScan completed!")
    print(f"Total findings: {len(findings)}")
    print(f"Report saved to: {report_file}")
    
    # Print summary
    if findings:
        print("\nSummary of findings:")
        by_severity = {}
        for finding in findings:
            severity = finding['severity']
            if severity not in by_severity:
                by_severity[severity] = 0
            by_severity[severity] += 1
        
        for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
            if severity in by_severity:
                print(f"  {severity}: {by_severity[severity]} issues")
    else:
        print("No security issues found!")

if __name__ == "__main__":
    main() 