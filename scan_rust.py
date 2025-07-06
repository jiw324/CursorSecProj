#!/usr/bin/env python3
"""
Rust Security Scanner
Performs static analysis on Rust files using cargo clippy and cargo audit
"""

import os
import re
import subprocess
import json
import sys
from datetime import datetime
from pathlib import Path

class RustSecurityScanner:
    def __init__(self):
        self.vulnerabilities = []
        self.scan_results = {}
        
    def scan_rust_project(self, project_path):
        """Scan a Rust project for security vulnerabilities"""
        print(f"Scanning Rust project: {project_path}")
        
        # Change to project directory
        original_dir = os.getcwd()
        os.chdir(project_path)
        
        try:
            # Run cargo clippy for static analysis
            clippy_results = self.run_cargo_clippy()
            
            # Run cargo audit for dependency vulnerabilities
            audit_results = self.run_cargo_audit()
            
            # Run cargo check for compilation issues
            check_results = self.run_cargo_check()
            
            # Combine all results
            all_findings = clippy_results + audit_results + check_results
            
            return all_findings
            
        finally:
            os.chdir(original_dir)
    
    def run_cargo_clippy(self):
        """Run cargo clippy and parse results"""
        findings = []
        try:
            result = subprocess.run(
                ["cargo", "clippy", "--all-targets", "--all-features", "--", "-D", "warnings"],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            if result.returncode != 0:
                # Parse clippy warnings and errors
                for line in result.stderr.split('\n'):
                    if line.strip():
                        # Extract file, line, and message
                        match = re.search(r'--> (.*?):(\d+):(\d+):', line)
                        if match:
                            file_path = match.group(1)
                            line_num = match.group(2)
                            col_num = match.group(3)
                            
                            # Extract the warning/error message
                            message_match = re.search(r'warning: (.+)$', line)
                            if message_match:
                                message = message_match.group(1)
                                severity = "MEDIUM"
                                
                                # Classify security-related warnings
                                if any(keyword in message.lower() for keyword in [
                                    'unsafe', 'unchecked', 'unwrap', 'expect', 'panic',
                                    'overflow', 'underflow', 'null', 'dereference'
                                ]):
                                    severity = "HIGH"
                                
                                findings.append({
                                    'file': file_path,
                                    'line': line_num,
                                    'severity': severity,
                                    'type': 'Clippy Warning',
                                    'message': message
                                })
            
        except subprocess.TimeoutExpired:
            findings.append({
                'file': 'cargo_clippy',
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Analysis Timeout',
                'message': 'Cargo clippy analysis timed out'
            })
        except Exception as e:
            findings.append({
                'file': 'cargo_clippy',
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Analysis Error',
                'message': f'Cargo clippy failed: {str(e)}'
            })
        
        return findings
    
    def run_cargo_audit(self):
        """Run cargo audit and parse results"""
        findings = []
        try:
            result = subprocess.run(
                ["cargo", "audit", "--json"],
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode != 0:
                try:
                    audit_data = json.loads(result.stdout)
                    if 'vulnerabilities' in audit_data:
                        for vuln in audit_data['vulnerabilities']:
                            findings.append({
                                'file': 'Cargo.toml',
                                'line': '0',
                                'severity': 'CRITICAL',
                                'type': 'Dependency Vulnerability',
                                'message': f"{vuln.get('package', {}).get('name', 'Unknown')}: {vuln.get('advisory', {}).get('title', 'Unknown vulnerability')}"
                            })
                except json.JSONDecodeError:
                    # Parse text output if JSON fails
                    for line in result.stdout.split('\n'):
                        if 'Vulnerability found' in line or 'Security vulnerability' in line:
                            findings.append({
                                'file': 'Cargo.toml',
                                'line': '0',
                                'severity': 'CRITICAL',
                                'type': 'Dependency Vulnerability',
                                'message': line.strip()
                            })
            
        except subprocess.TimeoutExpired:
            findings.append({
                'file': 'cargo_audit',
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Analysis Timeout',
                'message': 'Cargo audit analysis timed out'
            })
        except Exception as e:
            findings.append({
                'file': 'cargo_audit',
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Analysis Error',
                'message': f'Cargo audit failed: {str(e)}'
            })
        
        return findings
    
    def run_cargo_check(self):
        """Run cargo check for compilation issues"""
        findings = []
        try:
            result = subprocess.run(
                ["cargo", "check"],
                capture_output=True,
                text=True,
                timeout=180
            )
            
            if result.returncode != 0:
                # Parse compilation errors
                for line in result.stderr.split('\n'):
                    if 'error:' in line:
                        # Extract file and line information
                        match = re.search(r'--> (.*?):(\d+):(\d+):', line)
                        if match:
                            file_path = match.group(1)
                            line_num = match.group(2)
                            
                            # Extract error message
                            error_match = re.search(r'error: (.+)$', line)
                            if error_match:
                                message = error_match.group(1)
                                severity = "HIGH"
                                
                                # Classify security-related errors
                                if any(keyword in message.lower() for keyword in [
                                    'unsafe', 'unchecked', 'unwrap', 'expect', 'panic',
                                    'overflow', 'underflow', 'null', 'dereference',
                                    'borrow', 'lifetime', 'move'
                                ]):
                                    severity = "CRITICAL"
                                
                                findings.append({
                                    'file': file_path,
                                    'line': line_num,
                                    'severity': severity,
                                    'type': 'Compilation Error',
                                    'message': message
                                })
            
        except subprocess.TimeoutExpired:
            findings.append({
                'file': 'cargo_check',
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Analysis Timeout',
                'message': 'Cargo check analysis timed out'
            })
        except Exception as e:
            findings.append({
                'file': 'cargo_check',
                'line': '0',
                'severity': 'MEDIUM',
                'type': 'Analysis Error',
                'message': f'Cargo check failed: {str(e)}'
            })
        
        return findings
    
    def generate_report(self, output_dir, total_findings):
        """Generate a comprehensive security report in CodeQL format"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(output_dir, f"Rust_{timestamp}")
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        with open(report_file, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write("CodeQL Security Scan Report - Rust\n")
            f.write("=" * 80 + "\n")
            f.write(f"Scan Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total Files Scanned: 1 Rust project\n")
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
                f.write("The Rust project passed all security checks.\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("Scan completed successfully.\n")
            f.write("=" * 80 + "\n")
        
        return report_file

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 scan_rust.py <rust_project_path> <output_directory>")
        sys.exit(1)
    
    project_path = sys.argv[1]
    output_dir = sys.argv[2]
    
    if not os.path.exists(project_path):
        print(f"Error: Project path {project_path} does not exist")
        sys.exit(1)
    
    scanner = RustSecurityScanner()
    
    print("Starting Rust security scan...")
    print(f"Project: {project_path}")
    print(f"Output: {output_dir}")
    print("-" * 50)
    
    # Scan the Rust project
    findings = scanner.scan_rust_project(project_path)
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