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

class RubySecurityScanner:
    def __init__(self):
        # Define patterns for common Ruby security vulnerabilities
        self.patterns = {
            'command_injection': [
                (r"`[^`]*#\{", 'HIGH', 'Command injection risk in backticks - use escape methods'),
                (r"system\s*\([^)]*#\{", 'HIGH', 'Command injection risk in system() - use escape methods'),
                (r"exec\s*\([^)]*#\{", 'HIGH', 'Command injection risk in exec() - use escape methods'),
                (r"%x\[[^\]]*#\{", 'HIGH', 'Command injection risk in %x[] - use escape methods'),
            ],
            'sql_injection': [
                (r"\.where\s*\([^)]*#\{", 'HIGH', 'SQL injection risk - use parameterized queries'),
                (r"\.find_by\s*\([^)]*#\{", 'HIGH', 'SQL injection risk - use parameterized queries'),
                (r"execute\s*\([^)]*#\{", 'HIGH', 'SQL injection risk - use parameterized queries'),
                (r"\.select\s*\([^)]*#\{", 'HIGH', 'SQL injection risk - use parameterized queries'),
            ],
            'mass_assignment': [
                (r"\.create\s*\(params\[", 'HIGH', 'Mass assignment vulnerability - use strong parameters'),
                (r"\.update\s*\(params\[", 'HIGH', 'Mass assignment vulnerability - use strong parameters'),
                (r"\.new\s*\(params\[", 'HIGH', 'Mass assignment vulnerability - use strong parameters'),
                (r"attr_accessible\s+:all", 'HIGH', 'Unsafe mass assignment - specify attributes explicitly'),
            ],
            'file_operation': [
                (r"File\.(read|write|delete)\s*\([^)]*#\{", 'MEDIUM', 'Path traversal risk - validate file paths'),
                (r"IO\.(read|write)\s*\([^)]*#\{", 'MEDIUM', 'Path traversal risk - validate file paths'),
                (r"Dir\.(glob|mkdir|rmdir)\s*\([^)]*#\{", 'MEDIUM', 'Path traversal risk - validate paths'),
                (r"require\s*['\"][^'\"]+#\{", 'HIGH', 'Dynamic require - potential code injection'),
            ],
            'serialization': [
                (r"YAML\.load\s*\(", 'HIGH', 'Unsafe YAML loading - use YAML.safe_load'),
                (r"Marshal\.(load|restore)\s*\(", 'HIGH', 'Unsafe deserialization - use JSON instead'),
                (r"JSON\.load\s*\(", 'MEDIUM', 'Use JSON.parse instead of JSON.load'),
                (r"\.deserialize\s*\(", 'MEDIUM', 'Verify deserialization security'),
            ],
            'crypto': [
                (r"Digest::MD5", 'MEDIUM', 'Weak hash algorithm - use SHA-256 or better'),
                (r"Digest::SHA1", 'MEDIUM', 'Weak hash algorithm - use SHA-256 or better'),
                (r"OpenSSL::Cipher\.new\s*\(['\"]DES", 'HIGH', 'Weak encryption - use AES'),
                (r"SecureRandom\.rand", 'LOW', 'Use SecureRandom.random_bytes for better entropy'),
            ],
            'authentication': [
                (r"\.authenticate\s*\(params\[", 'MEDIUM', 'Verify authentication implementation'),
                (r"\.devise_parameter_sanitizer\.permit\s*\(:sign_up", 'LOW', 'Verify permitted parameters'),
                (r"\.devise_parameter_sanitizer\.permit\s*\(:account_update", 'LOW', 'Verify permitted parameters'),
                (r"has_secure_password", 'LOW', 'Verify password security configuration'),
            ],
            'rails_security': [
                (r"skip_before_action\s+:verify_authenticity_token", 'HIGH', 'CSRF protection disabled'),
                (r"config\.action_controller\.permit_all_parameters\s*=\s*true", 'HIGH', 'Mass assignment protection disabled'),
                (r"\.html_safe", 'MEDIUM', 'XSS risk - verify HTML safety'),
                (r"raw\s*\(", 'MEDIUM', 'XSS risk - verify HTML safety'),
            ],
            'template_injection': [
                (r"ERB\.new\s*\([^)]*#\{", 'HIGH', 'Template injection risk - validate input'),
                (r"render\s*\(inline:", 'MEDIUM', 'Template injection risk - avoid inline rendering'),
                (r"render\s*\(text:", 'MEDIUM', 'Consider using render plain: for better security'),
                (r"\.gsub\s*\([^)]*#\{", 'LOW', 'Potential string injection - validate input'),
            ],
            'debug': [
                (r"config\.consider_all_requests_local\s*=\s*true", 'MEDIUM', 'Debug information exposure'),
                (r"Rails\.logger\.debug\s*\([^)]*password", 'MEDIUM', 'Sensitive data in logs'),
                (r"puts\s+['\"][^'\"]*password", 'MEDIUM', 'Sensitive data exposure'),
                (r"byebug", 'LOW', 'Debug code in production'),
            ],
            'logging': [
                (r"Rails\.logger\.(info|debug|warn|error)\s*\([^)]*#\{", 'LOW', 'Validate logged data'),
                (r"logger\.(info|debug|warn|error)\s*\([^)]*#\{", 'LOW', 'Validate logged data'),
                (r"\.logger\.(info|debug|warn|error)\s*\([^)]*password", 'MEDIUM', 'Sensitive data in logs'),
                (r"\.logger\.(info|debug|warn|error)\s*\([^)]*secret", 'MEDIUM', 'Sensitive data in logs'),
            ],
            'http_security': [
                (r"config\.force_ssl\s*=\s*false", 'HIGH', 'SSL/TLS disabled'),
                (r"config\.ssl_options\s*=\s*\{", 'MEDIUM', 'Verify SSL configuration'),
                (r"request\.headers\[['\"]Origin['\"]\]", 'LOW', 'Verify CORS implementation'),
                (r"response\.headers\[['\"]Access-Control-Allow-Origin['\"]\]\s*=\s*['\"]\\*['\"]", 'HIGH', 'Overly permissive CORS'),
            ],
            'active_storage': [
                (r"\.attach\s*\(params\[", 'MEDIUM', 'Validate file uploads'),
                (r"\.attach\s*\(io:", 'MEDIUM', 'Validate file uploads'),
                (r"\.service_url", 'LOW', 'Verify URL security'),
                (r"\.purge", 'LOW', 'Verify deletion authorization'),
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
        print("Usage: ruby_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = RubySecurityScanner()
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