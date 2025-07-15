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

class JSTSSecurityScanner:
    def __init__(self):
        # Define patterns for common JavaScript/TypeScript security vulnerabilities
        self.patterns = {
            'xss': [
                (r'innerHTML\s*=', 'HIGH', 'Potential XSS - use textContent or sanitize HTML'),
                (r'outerHTML\s*=', 'HIGH', 'Potential XSS - use textContent or sanitize HTML'),
                (r'document\.write\s*\(', 'HIGH', 'Potential XSS - avoid document.write'),
                (r'eval\s*\(', 'HIGH', 'Dangerous eval() usage - potential code injection'),
            ],
            'dom_manipulation': [
                (r'insertAdjacentHTML\s*\(', 'MEDIUM', 'Validate and sanitize HTML before insertion'),
                (r'createRange\(\)\.createContextualFragment\s*\(', 'MEDIUM', 'Validate and sanitize HTML fragments'),
            ],
            'sql_injection': [
                (r'executeQuery\s*\([^)]*\+', 'HIGH', 'Potential SQL injection - use parameterized queries'),
                (r'query\s*\([^)]*\+', 'HIGH', 'Potential SQL injection - use parameterized queries'),
            ],
            'command_injection': [
                (r'exec\s*\([^)]*\+', 'HIGH', 'Potential command injection - validate input'),
                (r'spawn\s*\([^)]*\+', 'HIGH', 'Potential command injection - validate input'),
            ],
            'crypto': [
                (r'Math\.random\s*\(', 'MEDIUM', 'Use crypto.getRandomValues() for cryptographic operations'),
                (r'createHash\s*\(\s*[\'"]md5[\'"]\s*\)', 'HIGH', 'MD5 is cryptographically broken - use SHA-256'),
                (r'createHash\s*\(\s*[\'"]sha1[\'"]\s*\)', 'MEDIUM', 'SHA1 is weak - use SHA-256'),
            ],
            'authentication': [
                (r'localStorage\s*\.\s*setItem\s*\([^)]*token', 'MEDIUM', 'Sensitive data in localStorage - use sessionStorage'),
                (r'localStorage\s*\.\s*setItem\s*\([^)]*password', 'HIGH', 'Never store passwords in localStorage'),
                (r'sessionStorage\s*\.\s*setItem\s*\([^)]*password', 'HIGH', 'Never store passwords in sessionStorage'),
            ],
            'cors': [
                (r'Access-Control-Allow-Origin\s*:\s*\*', 'HIGH', 'Overly permissive CORS policy'),
                (r'Access-Control-Allow-Credentials\s*:\s*true', 'MEDIUM', 'Verify CORS credentials policy'),
            ],
            'input_validation': [
                (r'parse(?:Int|Float)\s*\([^,)]+\)', 'LOW', 'Add radix parameter to parseInt/parseFloat'),
                (r'JSON\.parse\s*\([^)]+\)', 'LOW', 'Wrap JSON.parse in try-catch'),
            ],
            'error_handling': [
                (r'catch\s*\(\s*e\s*\)\s*{\s*}', 'MEDIUM', 'Empty catch block - handle or log errors'),
                (r'catch\s*\(\s*e\s*\)\s*{\s*console', 'LOW', 'Consider proper error handling/logging'),
            ],
            'typescript_specific': [
                (r'as\s+any', 'LOW', 'Avoid using "any" type - specify exact types'),
                (r'//@ts-ignore', 'MEDIUM', 'Avoid @ts-ignore - fix type issues'),
                (r'//@ts-nocheck', 'HIGH', 'Avoid @ts-nocheck - enable type checking'),
            ],
            'react_security': [
                (r'dangerouslySetInnerHTML', 'HIGH', 'Dangerous DOM manipulation - ensure HTML is sanitized'),
                (r'useEffect\s*\(\s*\([^)]*\)\s*=>\s*{\s*fetch\s*\(', 'LOW', 'Add cleanup to fetch in useEffect'),
            ],
            'node_security': [
                (r'child_process', 'MEDIUM', 'Validate and sanitize command execution'),
                (r'fs\.readFile\s*\([^)]*\+', 'MEDIUM', 'Potential path traversal - validate file paths'),
                (r'require\s*\([^)]*\+', 'HIGH', 'Dynamic require - potential code injection'),
            ],
            'express_security': [
                (r'app\.use\s*\(\s*express\.static\s*\(', 'LOW', 'Verify express.static directory access'),
                (r'res\.send\s*\([^)]*req', 'MEDIUM', 'Validate user input before sending response'),
            ],
            'jwt_security': [
                (r'jwt\.sign\s*\([^)]*,\s*[\'"]HS256[\'"]', 'LOW', 'Consider using stronger JWT algorithms'),
                (r'jwt\.verify\s*\([^)]*{algorithms:\s*\[[^\]]*none', 'HIGH', 'Never accept "none" algorithm'),
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
        print("Usage: js_ts_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = JSTSSecurityScanner()
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