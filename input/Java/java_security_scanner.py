#!/usr/bin/env python3

import os
import sys
import json
import subprocess
import re
from datetime import datetime
from typing import List, Dict, Any
import html
from pathlib import Path
import xml.etree.ElementTree as ET
import tempfile
import shutil

class JavaSecurityScanner:
    def __init__(self, source_dir: str):
        self.source_dir = Path(source_dir)
        # Get root directory (2 levels up from source_dir)
        root_dir = self.source_dir.parent.parent
        self.build_dir = root_dir / "build" / "Java"
        self.output_dir = root_dir / "output" / "Java_security_scan"
        self.issues: List[Dict[str, Any]] = []
        self.temp_dir = None
        
    def setup_environment(self) -> bool:
        """Verify and setup required tools."""
        try:
            # Check if Java is installed
            subprocess.run(['java', '-version'], check=True, capture_output=True)
            
            # Create temporary directory for tools
            self.temp_dir = tempfile.mkdtemp()
            
            # Download SpotBugs
            spotbugs_url = "https://github.com/spotbugs/spotbugs/releases/download/4.2.3/spotbugs-4.2.3.tgz"
            spotbugs_tgz = os.path.join(self.temp_dir, 'spotbugs.tgz')
            subprocess.run(['curl', '-L', spotbugs_url, '-o', spotbugs_tgz], check=True)
            
            # Extract SpotBugs
            subprocess.run(['tar', 'xzf', spotbugs_tgz, '-C', self.temp_dir], check=True)
            
            # Download PMD (using stable version 6.55.0)
            pmd_url = "https://github.com/pmd/pmd/releases/download/pmd_releases%2F6.55.0/pmd-bin-6.55.0.zip"
            pmd_zip = os.path.join(self.temp_dir, 'pmd.zip')
            subprocess.run(['curl', '-L', pmd_url, '-o', pmd_zip], check=True)
            
            # Create PMD directory and extract
            pmd_dir = os.path.join(self.temp_dir, 'pmd')
            os.makedirs(pmd_dir, exist_ok=True)
            subprocess.run(['unzip', '-q', pmd_zip, '-d', pmd_dir], check=True)
            
            return True
        except Exception as e:
            print(f"Error setting up environment: {e}")
            if self.temp_dir and os.path.exists(self.temp_dir):
                shutil.rmtree(self.temp_dir)
            return False
        
    def cleanup(self):
        """Clean up temporary files."""
        if self.temp_dir and os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)

    def run_spotbugs(self, class_dir: str) -> None:
        """Run SpotBugs analysis."""
        try:
            spotbugs_dir = next(d for d in os.listdir(self.temp_dir) if d.startswith('spotbugs'))
            spotbugs_path = os.path.join(self.temp_dir, spotbugs_dir, 'lib', 'spotbugs.jar')
            
            output_file = os.path.join(self.temp_dir, 'spotbugs-output.xml')
            
            subprocess.run([
                'java', '-jar', spotbugs_path,
                '-textui',
                '-xml:withMessages',
                '-output', output_file,
                class_dir
            ], check=True, capture_output=True)
            
            if os.path.exists(output_file):
                tree = ET.parse(output_file)
                root = tree.getroot()
                
                for bug in root.findall('.//BugInstance'):
                    source_line = bug.find('.//SourceLine')
                    if source_line is not None:
                        self.issues.append({
                            'file': source_line.get('sourcepath', 'unknown'),
                            'line': int(source_line.get('start', 0)),
                            'severity': bug.get('priority', '3'),
                            'type': 'Security',
                            'message': bug.find('LongMessage').text if bug.find('LongMessage') is not None else 'Unknown issue',
                            'tool': 'SpotBugs'
                        })
                        
        except Exception as e:
            print(f"Error running SpotBugs: {e}")

    def run_pmd(self, java_file: str) -> None:
        """Run PMD analysis."""
        try:
            # Find the PMD directory and binary
            pmd_dir = os.path.join(self.temp_dir, 'pmd')
            pmd_bin_dir = next(d for d in os.listdir(pmd_dir) if d.startswith('pmd-bin'))
            pmd_home = os.path.join(pmd_dir, pmd_bin_dir)
            
            # Use run.sh on macOS, pmd on other platforms
            if sys.platform == 'darwin':
                pmd_script = 'run.sh'
            else:
                pmd_script = 'pmd'
                
            pmd_path = os.path.join(pmd_home, 'bin', pmd_script)
            
            # Make the PMD script executable
            os.chmod(pmd_path, 0o755)
            
            output_file = os.path.join(self.temp_dir, 'pmd-output.xml')
            
            # On macOS, we need to pass 'pmd' as the first argument to run.sh
            cmd = [pmd_path]
            if sys.platform == 'darwin':
                cmd.append('pmd')
                
            cmd.extend([
                '-d', java_file,
                '-R', 'rulesets/java/quickstart.xml',
                '-f', 'xml',
                '-r', output_file
            ])
            
            # Set up environment variables
            env = os.environ.copy()
            env.update({
                'PMD_HOME': pmd_home,
                'JAVA_HOME': '/opt/homebrew/Cellar/openjdk/24.0.1/libexec/openjdk.jdk/Contents/Home'
            })
            
            result = subprocess.run(cmd, capture_output=True, env=env)
            if result.returncode != 0 and result.returncode != 4:  # PMD returns 4 when it finds violations
                print(f"PMD stderr: {result.stderr.decode()}")
                raise Exception(f"PMD failed with return code {result.returncode}")
            
            if os.path.exists(output_file):
                tree = ET.parse(output_file)
                root = tree.getroot()
                
                for violation in root.findall('.//violation'):
                    severity = violation.get('priority', '3')
                    # Convert PMD priority (1-5) to severity
                    if severity == '1':
                        severity = 'HIGH'
                    elif severity == '2':
                        severity = 'MEDIUM'
                    else:
                        severity = 'LOW'
                        
                    self.issues.append({
                        'file': java_file,
                        'line': int(violation.get('beginline', 0)),
                        'severity': severity,
                        'type': 'Security',
                        'message': violation.text.strip() if violation.text else 'Unknown issue',
                        'tool': 'PMD'
                    })
                    
        except Exception as e:
            print(f"Error running PMD: {e}")

    def check_custom_patterns(self, file_path: str) -> None:
        """Perform custom security pattern checks."""
        patterns = {
            r'Runtime\.getRuntime\(\)\.exec\(': {
                'message': 'Command execution detected. Ensure proper input validation.',
                'severity': 'HIGH'
            },
            r'Class\.forName\(': {
                'message': 'Dynamic class loading detected. Validate class names.',
                'severity': 'MEDIUM'
            },
            r'\.printStackTrace\(\)': {
                'message': 'Stack trace exposure detected. Use proper logging.',
                'severity': 'LOW'
            },
            r'new File\(': {
                'message': 'File operation detected. Validate file paths and permissions.',
                'severity': 'MEDIUM'
            },
            r'javax\.crypto\.Cipher': {
                'message': 'Cryptographic operation detected. Ensure proper algorithm and key management.',
                'severity': 'HIGH'
            },
            r'java\.security\.SecureRandom': {
                'message': 'Random number generation detected. Ensure proper seeding.',
                'severity': 'MEDIUM'
            }
        }

        try:
            with open(file_path, 'r') as f:
                content = f.read()
                for pattern, info in patterns.items():
                    for match in re.finditer(pattern, content):
                        line_number = content[:match.start()].count('\n') + 1
                        self.issues.append({
                            'file': file_path,
                            'line': line_number,
                            'severity': info['severity'],
                            'type': 'Custom Check',
                            'message': info['message'],
                            'tool': 'custom'
                        })
        except Exception as e:
            print(f"Error in custom pattern check for {file_path}: {e}")

    def scan_directory(self) -> None:
        """Scan all Java files in the input directory."""
        if not self.setup_environment():
            print("Failed to set up scanning environment")
            return

        try:
            # First pass: Run custom pattern checks on source files
            source_dir = os.path.join(self.source_dir, 'src', 'main', 'java')
            for root, _, files in os.walk(source_dir):
                for file in files:
                    if file.endswith('.java'):
                        file_path = os.path.join(root, file)
                        print(f"Scanning {file_path}...")
                        self.check_custom_patterns(file_path)
                        self.run_pmd(file_path)

            # Second pass: Run SpotBugs on compiled classes
            target_classes = os.path.join(self.source_dir, 'target', 'classes')
            if os.path.exists(target_classes):
                self.run_spotbugs(target_classes)

        except Exception as e:
            print(f"Error scanning directory: {e}")
        finally:
            self.cleanup()

    def generate_report(self) -> None:
        """Generate HTML and JSON reports."""
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Generate JSON report
        json_report = {
            'scanner': 'Java Security Scanner',
            'timestamp': datetime.now().isoformat(),
            'total_issues': len(self.issues),
            'issues': self.issues
        }
        
        json_path = os.path.join(self.output_dir, 'java_security_report.json')
        with open(json_path, 'w') as f:
            json.dump(json_report, f, indent=2)

        # Generate HTML report
        html_content = self._generate_html_report()
        html_path = os.path.join(self.output_dir, 'java_security_report.html')
        with open(html_path, 'w') as f:
            f.write(html_content)

    def _generate_html_report(self) -> str:
        """Generate HTML report content."""
        severity_colors = {
            'HIGH': 'red',
            'MEDIUM': 'orange',
            'LOW': 'yellow',
            'UNKNOWN': 'gray'
        }

        issues_by_severity = {
            'HIGH': 0,
            'MEDIUM': 0,
            'LOW': 0,
            'UNKNOWN': 0
        }

        for issue in self.issues:
            severity = issue['severity']
            if isinstance(severity, str):
                severity = severity.upper()
            elif isinstance(severity, int):
                severity = 'HIGH' if severity <= 1 else 'MEDIUM' if severity == 2 else 'LOW'
            issues_by_severity[severity] = issues_by_severity.get(severity, 0) + 1

        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Java Security Scan Report</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .summary {{ margin-bottom: 20px; }}
                .issue {{ margin-bottom: 10px; padding: 10px; border: 1px solid #ddd; }}
                .HIGH {{ background-color: #ffe6e6; }}
                .MEDIUM {{ background-color: #fff3e6; }}
                .LOW {{ background-color: #ffffee; }}
                .UNKNOWN {{ background-color: #f5f5f5; }}
            </style>
        </head>
        <body>
            <h1>Java Security Scan Report</h1>
            <div class="summary">
                <h2>Summary</h2>
                <p>Total Issues: {len(self.issues)}</p>
                <ul>
        """

        for severity, count in issues_by_severity.items():
            if count > 0:
                html_content += f'<li style="color: {severity_colors[severity]}">{severity}: {count}</li>'

        html_content += """
                </ul>
            </div>
            <h2>Issues</h2>
        """

        for issue in sorted(self.issues, key=lambda x: x['severity']):
            severity = issue['severity']
            if isinstance(severity, str):
                severity = severity.upper()
            elif isinstance(severity, int):
                severity = 'HIGH' if severity <= 1 else 'MEDIUM' if severity == 2 else 'LOW'
            
            html_content += f"""
            <div class="issue {severity}">
                <h3>Issue in {html.escape(issue['file'])} (Line {issue['line']})</h3>
                <p><strong>Severity:</strong> {severity}</p>
                <p><strong>Type:</strong> {html.escape(issue['type'])}</p>
                <p><strong>Tool:</strong> {html.escape(issue['tool'])}</p>
                <p><strong>Message:</strong> {html.escape(str(issue['message']))}</p>
            </div>
            """

        html_content += """
        </body>
        </html>
        """

        return html_content

def main():
    if len(sys.argv) != 3:
        print("Usage: python java_security_scanner.py <input_dir> <output_dir>")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]

    scanner = JavaSecurityScanner(input_dir)
    scanner.scan_directory()
    scanner.generate_report()

if __name__ == "__main__":
    main() 