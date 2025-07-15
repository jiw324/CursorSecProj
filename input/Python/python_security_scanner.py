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

class PythonSecurityScanner:
    def __init__(self):
        # Define patterns for common Python security vulnerabilities
        self.patterns = {
            'command_injection': [
                (r"os\.system\s*\(", 'HIGH', 'Command injection risk - validate and escape input'),
                (r"subprocess\.(call|run|Popen)\s*\(", 'HIGH', 'Command injection risk - validate and escape input'),
                (r"eval\s*\(", 'HIGH', 'Dangerous eval() usage - potential code injection'),
                (r"exec\s*\(", 'HIGH', 'Dangerous exec() usage - potential code injection'),
            ],
            'sql_injection': [
                (r"execute\s*\([^)]*%", 'HIGH', 'SQL injection risk - use parameterized queries'),
                (r"execute\s*\([^)]*format", 'HIGH', 'SQL injection risk - use parameterized queries'),
                (r"execute\s*\([^)]*\+", 'HIGH', 'SQL injection risk - use parameterized queries'),
                (r"executemany\s*\([^)]*%", 'HIGH', 'SQL injection risk - use parameterized queries'),
            ],
            'file_operation': [
                (r"open\s*\([^)]*\+", 'MEDIUM', 'Path traversal risk - validate file paths'),
                (r"__import__\s*\(", 'HIGH', 'Dynamic import - potential code injection'),
                (r"importlib\.import_module\s*\(", 'MEDIUM', 'Dynamic import - validate module names'),
                (r"shutil\.(copy|move|rmtree)\s*\(", 'MEDIUM', 'Unsafe file operation - validate paths'),
            ],
            'serialization': [
                (r"pickle\.(loads|load)\s*\(", 'HIGH', 'Unsafe deserialization - use JSON instead'),
                (r"yaml\.load\s*\(", 'HIGH', 'Unsafe YAML loading - use yaml.safe_load()'),
                (r"marshal\.(loads|load)\s*\(", 'HIGH', 'Unsafe deserialization - use JSON instead'),
                (r"shelve\.open\s*\(", 'MEDIUM', 'Unsafe serialization - validate data'),
            ],
            'crypto': [
                (r"random\.", 'MEDIUM', 'Use secrets module for cryptographic operations'),
                (r"hashlib\.md5\s*\(", 'MEDIUM', 'Weak hash algorithm - use SHA-256 or better'),
                (r"hashlib\.sha1\s*\(", 'MEDIUM', 'Weak hash algorithm - use SHA-256 or better'),
                (r"Crypto\.Cipher\.DES", 'HIGH', 'Weak encryption - use AES'),
            ],
            'input_validation': [
                (r"input\s*\(", 'LOW', 'Validate and sanitize user input'),
                (r"raw_input\s*\(", 'LOW', 'Validate and sanitize user input'),
                (r"type\s*\([^)]+\)", 'LOW', 'Type conversion without validation'),
                (r"ast\.literal_eval\s*\(", 'MEDIUM', 'Validate input before evaluation'),
            ],
            'authentication': [
                (r"pwd_context\.verify\s*\(", 'MEDIUM', 'Use constant-time password comparison'),
                (r"check_password\s*\(", 'MEDIUM', 'Use constant-time password comparison'),
                (r"\.password\s*=", 'MEDIUM', 'Ensure secure password storage'),
                (r"\.authenticate\s*\(", 'LOW', 'Verify authentication implementation'),
            ],
            'template_injection': [
                (r"render_template_string\s*\(", 'HIGH', 'Template injection risk - validate input'),
                (r"Template\s*\(", 'MEDIUM', 'Template injection risk - validate input'),
                (r"Markup\s*\(", 'MEDIUM', 'XSS risk - validate HTML'),
                (r"\.format\s*\([^)]*__", 'HIGH', 'Format string vulnerability'),
            ],
            'debug': [
                (r"print\s*\([^)]*password", 'MEDIUM', 'Sensitive data exposure'),
                (r"print\s*\([^)]*secret", 'MEDIUM', 'Sensitive data exposure'),
                (r"debug\s*=\s*True", 'LOW', 'Debug enabled in code'),
                (r"pdb\.", 'LOW', 'Debug code in production'),
            ],
            'logging': [
                (r"logging\.debug\s*\([^)]*password", 'MEDIUM', 'Sensitive data in logs'),
                (r"logging\.info\s*\([^)]*secret", 'MEDIUM', 'Sensitive data in logs'),
                (r"traceback\.print_exc\s*\(", 'LOW', 'Detailed error exposure'),
                (r"\.exception\s*\([^)]*secret", 'MEDIUM', 'Sensitive data in exception logs'),
            ],
            'flask_security': [
                (r"FLASK_DEBUG\s*=\s*True", 'MEDIUM', 'Debug mode enabled'),
                (r"app\.run\s*\([^)]*debug\s*=\s*True", 'MEDIUM', 'Debug mode enabled'),
                (r"@app\.route\s*\([^)]*methods\s*=\s*['\"][^'\"]*GET[^'\"]*POST", 'LOW', 'Verify CSRF protection'),
                (r"jsonify\s*\([^)]*error", 'LOW', 'Sensitive data in error responses'),
            ],
            'django_security': [
                (r"DEBUG\s*=\s*True", 'MEDIUM', 'Debug mode enabled'),
                (r"ALLOWED_HOSTS\s*=\s*\[\s*['\"][*]['\"]", 'MEDIUM', 'Overly permissive hosts'),
                (r"csrf_exempt", 'HIGH', 'CSRF protection disabled'),
                (r"mark_safe\s*\(", 'MEDIUM', 'XSS risk - validate HTML'),
            ],
            'fastapi_security': [
                (r"@app\.get\s*\([^)]*response_model", 'LOW', 'Verify response data exposure'),
                (r"@app\.post\s*\([^)]*response_model", 'LOW', 'Verify response data exposure'),
                (r"HTTPException\s*\([^)]*detail", 'LOW', 'Verify error information exposure'),
                (r"oauth2_scheme", 'LOW', 'Verify OAuth2 implementation'),
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
        print("Usage: python_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = PythonSecurityScanner()
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