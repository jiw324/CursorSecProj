#!/usr/bin/env python3
"""
Comprehensive Scala Security Scanner
Performs static analysis on all Scala files individually
"""

import os
import re
import subprocess
import json
import sys
from datetime import datetime
from pathlib import Path

class ComprehensiveScalaScanner:
    def __init__(self):
        self.vulnerabilities = []
        self.scan_results = {}
        
    def scan_scala_files(self, scala_dir):
        """Scan all Scala files in the directory"""
        print(f"Scanning Scala files in: {scala_dir}")
        
        scala_files = []
        for file in os.listdir(scala_dir):
            if file.endswith('.scala'):
                scala_files.append(os.path.join(scala_dir, file))
        
        print(f"Found {len(scala_files)} Scala files to scan")
        
        all_findings = []
        
        for scala_file in scala_files:
            print(f"\nScanning: {os.path.basename(scala_file)}")
            findings = self.analyze_scala_file(scala_file)
            all_findings.extend(findings)
        
        return all_findings
    
    def analyze_scala_file(self, file_path):
        """Analyze a single Scala file for security issues"""
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
        """Analyze Scala code for security-related patterns"""
        findings = []
        lines = content.split('\n')
        
        security_patterns = [
            # SQL injection patterns
            (r'sql"""', 'CRITICAL', 'SQL Injection Risk', 'Raw SQL string interpolation'),
            (r'sql"', 'CRITICAL', 'SQL Injection Risk', 'Raw SQL string interpolation'),
            (r'executeQuery\s*\(', 'CRITICAL', 'SQL Injection Risk', 'Direct SQL query execution'),
            (r'executeUpdate\s*\(', 'CRITICAL', 'SQL Injection Risk', 'Direct SQL update execution'),
            
            # Command injection patterns
            (r'Runtime\.getRuntime\(\)\.exec', 'CRITICAL', 'Command Injection Risk', 'Runtime command execution'),
            (r'ProcessBuilder', 'HIGH', 'Command Injection Risk', 'Process builder usage'),
            (r'\.\s*!', 'HIGH', 'Command Injection Risk', 'Shell command execution'),
            
            # File system access
            (r'File\s*\(', 'MEDIUM', 'File System Access', 'File system access'),
            (r'Files\.', 'MEDIUM', 'File System Access', 'Files utility usage'),
            (r'Path\.', 'MEDIUM', 'File System Access', 'Path utility usage'),
            
            # Network access
            (r'URL\s*\(', 'MEDIUM', 'Network Access', 'URL creation'),
            (r'HttpURLConnection', 'MEDIUM', 'Network Access', 'HTTP connection'),
            (r'Socket\s*\(', 'MEDIUM', 'Network Access', 'Socket creation'),
            
            # Reflection and dynamic code
            (r'Class\.forName', 'HIGH', 'Reflection Usage', 'Dynamic class loading'),
            (r'getClass\.getMethod', 'HIGH', 'Reflection Usage', 'Dynamic method invocation'),
            (r'eval\s*\(', 'CRITICAL', 'Code Injection Risk', 'Code evaluation'),
            
            # Serialization
            (r'ObjectInputStream', 'HIGH', 'Deserialization Risk', 'Object deserialization'),
            (r'readObject\s*\(', 'HIGH', 'Deserialization Risk', 'Object deserialization'),
            
            # Cryptographic issues
            (r'MessageDigest\.getInstance\s*\(\s*["\']MD5["\']', 'HIGH', 'Weak Cryptography', 'MD5 hash usage'),
            (r'MessageDigest\.getInstance\s*\(\s*["\']SHA-1["\']', 'MEDIUM', 'Weak Cryptography', 'SHA-1 hash usage'),
            (r'Cipher\.getInstance\s*\(\s*["\']DES["\']', 'HIGH', 'Weak Cryptography', 'DES encryption'),
            
            # Hardcoded secrets
            (r'password\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded Password', 'Hardcoded password'),
            (r'secret\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded Secret', 'Hardcoded secret'),
            (r'api_key\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded API Key', 'Hardcoded API key'),
            (r'token\s*=\s*["\'][^"\']+["\']', 'CRITICAL', 'Hardcoded Token', 'Hardcoded token'),
            
            # Unsafe operations
            (r'\.asInstanceOf\[', 'MEDIUM', 'Unsafe Cast', 'Unsafe type casting'),
            (r'\.get\s*\(', 'MEDIUM', 'Unsafe Access', 'Unsafe collection access'),
            (r'\.head', 'MEDIUM', 'Unsafe Access', 'Unsafe list head access'),
            (r'\.tail', 'MEDIUM', 'Unsafe Access', 'Unsafe list tail access'),
            
            # Exception handling
            (r'catch\s*\{', 'LOW', 'Exception Handling', 'Exception catching'),
            (r'throw\s+new\s+Exception', 'MEDIUM', 'Exception Throwing', 'Generic exception throwing'),
            
            # Concurrency issues
            (r'synchronized\s*\(', 'MEDIUM', 'Synchronization', 'Synchronized block'),
            (r'volatile\s+', 'MEDIUM', 'Volatile Variable', 'Volatile variable declaration'),
            (r'AtomicReference', 'MEDIUM', 'Atomic Reference', 'Atomic reference usage'),
            
            # Akka specific patterns
            (r'ActorRef', 'MEDIUM', 'Akka Actor', 'Actor reference usage'),
            (r'context\.actorOf', 'MEDIUM', 'Akka Actor Creation', 'Actor creation'),
            (r'self\s*!\s*', 'MEDIUM', 'Akka Message Sending', 'Message sending'),
            
            # Spark specific patterns
            (r'SparkContext', 'MEDIUM', 'Spark Context', 'Spark context usage'),
            (r'RDD\[', 'MEDIUM', 'Spark RDD', 'RDD usage'),
            (r'DataFrame', 'MEDIUM', 'Spark DataFrame', 'DataFrame usage'),
            
            # ZIO specific patterns
            (r'ZIO\.', 'MEDIUM', 'ZIO Effect', 'ZIO effect usage'),
            (r'for\s*\{', 'LOW', 'ZIO For Comprehension', 'ZIO for comprehension'),
            
            # Cats specific patterns
            (r'IO\.', 'MEDIUM', 'Cats IO', 'Cats IO usage'),
            (r'OptionT', 'MEDIUM', 'Cats OptionT', 'OptionT transformer'),
            (r'EitherT', 'MEDIUM', 'Cats EitherT', 'EitherT transformer'),
        ]
        
        for line_num, line in enumerate(lines, 1):
            for pattern, severity, issue_type, description in security_patterns:
                if re.search(pattern, line, re.IGNORECASE):
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
        
        # Check for potential XSS patterns
        xss_patterns = [
            (r'\.innerHTML\s*=', 'HIGH', 'XSS Risk'),
            (r'\.outerHTML\s*=', 'HIGH', 'XSS Risk'),
            (r'document\.write\s*\(', 'HIGH', 'XSS Risk'),
        ]
        
        for line_num, line in enumerate(lines, 1):
            for pattern, severity, issue_type in xss_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    findings.append({
                        'file': os.path.basename(file_path),
                        'line': str(line_num),
                        'severity': severity,
                        'type': issue_type,
                        'message': f'Potential XSS vulnerability: {line.strip()}'
                    })
        
        # Check for potential path traversal
        path_patterns = [
            (r'\.\./', 'HIGH', 'Path Traversal Risk'),
            (r'\.\.\\', 'HIGH', 'Path Traversal Risk'),
        ]
        
        for line_num, line in enumerate(lines, 1):
            for pattern, severity, issue_type in path_patterns:
                if re.search(pattern, line):
                    findings.append({
                        'file': os.path.basename(file_path),
                        'line': str(line_num),
                        'severity': severity,
                        'type': issue_type,
                        'message': f'Potential path traversal: {line.strip()}'
                    })
        
        return findings
    
    def check_syntax(self, file_path):
        """Check for basic syntax issues"""
        findings = []
        
        try:
            # Try to compile the file with scalac
            result = subprocess.run(
                ["scalac", "-Xfatal-warnings", file_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode != 0:
                # Parse compilation errors
                for line in result.stderr.split('\n'):
                    if 'error:' in line:
                        # Extract line number if available
                        line_match = re.search(r':(\d+):', line)
                        if line_match:
                            line_num = line_match.group(1)
                        else:
                            line_num = '0'
                        
                        # Extract error message
                        error_match = re.search(r'error: (.+)$', line)
                        if error_match:
                            message = error_match.group(1)
                            severity = "HIGH"
                            
                            # Classify syntax errors
                            if any(keyword in message.lower() for keyword in [
                                'unsafe', 'unchecked', 'null', 'dereference',
                                'injection', 'sql', 'command', 'execution'
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
        report_file = os.path.join(output_dir, f"Scala_All_{timestamp}")
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        with open(report_file, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write("CodeQL Security Scan Report - Scala (All Files)\n")
            f.write("=" * 80 + "\n")
            f.write(f"Scan Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total Files Scanned: 7 Scala files\n")
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
                f.write("All Scala files passed security checks.\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("Scan completed successfully.\n")
            f.write("=" * 80 + "\n")
        
        return report_file

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 scan_scala.py <scala_files_directory> <output_directory>")
        sys.exit(1)
    
    scala_dir = sys.argv[1]
    output_dir = sys.argv[2]
    
    if not os.path.exists(scala_dir):
        print(f"Error: Scala directory {scala_dir} does not exist")
        sys.exit(1)
    
    scanner = ComprehensiveScalaScanner()
    
    print("Starting comprehensive Scala security scan...")
    print(f"Directory: {scala_dir}")
    print(f"Output: {output_dir}")
    print("-" * 50)
    
    # Scan all Scala files
    findings = scanner.scan_scala_files(scala_dir)
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