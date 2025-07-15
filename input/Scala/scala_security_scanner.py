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

class ScalaSecurityScanner:
    def __init__(self):
        # Define patterns for common Scala security vulnerabilities
        self.patterns = {
            'sql_injection': [
                (r"sql\"[^\"]*\$", 'HIGH', 'SQL injection risk - use prepared statements'),
                (r"anorm.SQL\([^)]*\$", 'HIGH', 'SQL injection risk - use prepared statements'),
                (r"db.run\([^)]*\$", 'HIGH', 'SQL injection risk - use prepared statements'),
                (r"executeQuery\([^)]*\+", 'HIGH', 'SQL injection risk - use prepared statements'),
            ],
            'command_injection': [
                (r"Runtime\.getRuntime\(\)\.exec\(", 'HIGH', 'Command injection risk - validate input'),
                (r"Process\([^)]*\$", 'HIGH', 'Command injection risk - validate input'),
                (r"sys.process", 'MEDIUM', 'Command execution - verify input safety'),
                (r"scala.sys.process", 'MEDIUM', 'Command execution - verify input safety'),
            ],
            'deserialization': [
                (r"ObjectInputStream", 'HIGH', 'Unsafe deserialization - validate input'),
                (r"readObject", 'HIGH', 'Unsafe deserialization - validate input'),
                (r"Json\.parse\([^)]*\$", 'MEDIUM', 'JSON parsing - validate input'),
                (r"fromJson\([^)]*\$", 'MEDIUM', 'JSON parsing - validate input'),
            ],
            'file_operations': [
                (r"scala.io.Source.fromFile", 'MEDIUM', 'File operation - validate paths'),
                (r"new File\([^)]*\$", 'MEDIUM', 'File operation - validate paths'),
                (r"Files\.(write|read)", 'MEDIUM', 'File operation - validate paths'),
                (r"\.getResource\([^)]*\$", 'MEDIUM', 'Resource loading - validate paths'),
            ],
            'play_framework': [
                (r"Ok\(views.html", 'LOW', 'Verify template XSS protection'),
                (r"Action\s*\{\s*implicit\s+request", 'LOW', 'Verify request handling security'),
                (r"withHeaders\([^)]*\$", 'MEDIUM', 'Header injection risk - validate input'),
                (r"Redirect\([^)]*\$", 'MEDIUM', 'Open redirect risk - validate URLs'),
            ],
            'akka_security': [
                (r"actorSelection\([^)]*\$", 'MEDIUM', 'Actor path injection risk'),
                (r"\.tell\([^)]*\$", 'LOW', 'Verify message safety'),
                (r"akka.http.scaladsl.server.Directives", 'LOW', 'Verify route security'),
                (r"complete\([^)]*\$", 'LOW', 'Verify response safety'),
            ],
            'authentication': [
                (r"setSession\([^)]*\$", 'MEDIUM', 'Session manipulation - validate data'),
                (r"withSession\([^)]*\$", 'MEDIUM', 'Session manipulation - validate data'),
                (r"setCookie\([^)]*\$", 'MEDIUM', 'Cookie setting - verify security flags'),
                (r"withCookies\([^)]*\$", 'MEDIUM', 'Cookie setting - verify security flags'),
            ],
            'crypto': [
                (r"MessageDigest\.getInstance\(['\"]MD5['\"]", 'HIGH', 'Weak hash algorithm - use SHA-256'),
                (r"MessageDigest\.getInstance\(['\"]SHA-1['\"]", 'MEDIUM', 'Weak hash algorithm - use SHA-256'),
                (r"new SecureRandom\(\)", 'LOW', 'Verify seed management'),
                (r"Random\(\)", 'MEDIUM', 'Use SecureRandom for security'),
            ],
            'logging': [
                (r"println\([^)]*password", 'MEDIUM', 'Sensitive data exposure'),
                (r"logger\.(info|debug|warn|error)\([^)]*password", 'MEDIUM', 'Sensitive data in logs'),
                (r"System\.out\.println", 'LOW', 'Use proper logging framework'),
                (r"e\.printStackTrace", 'LOW', 'Sensitive data in stack trace'),
            ],
            'input_validation': [
                (r"request\.body\.asJson", 'LOW', 'Validate JSON input'),
                (r"request\.getQueryString", 'LOW', 'Validate query parameters'),
                (r"request\.body\.asFormUrlEncoded", 'LOW', 'Validate form input'),
                (r"request\.body\.asText", 'LOW', 'Validate text input'),
            ],
            'csrf': [
                (r"@CSRFCheck", 'LOW', 'Verify CSRF protection'),
                (r"withHeaders\(CSRF", 'LOW', 'Verify CSRF token handling'),
                (r"CSRFFilter", 'LOW', 'Verify CSRF filter configuration'),
                (r"csrf\s*=\s*false", 'HIGH', 'CSRF protection disabled'),
            ],
            'error_handling': [
                (r"Try\s*\{[^}]*\}\.get", 'MEDIUM', 'Unsafe Try.get usage'),
                (r"Option\s*\([^)]*\)\.get", 'MEDIUM', 'Unsafe Option.get usage'),
                (r"Either\s*\{[^}]*\}\.right\.get", 'MEDIUM', 'Unsafe Either.right.get usage'),
                (r"throw\s+new", 'LOW', 'Consider using Either or Try'),
            ],
            'configuration': [
                (r"config\.getString\([^)]*\)\.get", 'MEDIUM', 'Unsafe configuration access'),
                (r"application\.conf", 'LOW', 'Verify configuration security'),
                (r"reference\.conf", 'LOW', 'Verify configuration security'),
                (r"\.getConfig\([^)]*\)\.get", 'MEDIUM', 'Unsafe configuration access'),
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
        print("Usage: scala_security_scanner.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    scanner = ScalaSecurityScanner()
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