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
import shutil

def find_tool_path(tool_name):
    # Check in GOBIN first
    gobin = os.path.expanduser("~/go/bin")
    tool_path = os.path.join(gobin, tool_name)
    if os.path.exists(tool_path):
        return tool_path
    
    # Try finding in PATH
    tool_path = shutil.which(tool_name)
    if tool_path:
        return tool_path
    
    return None

def run_security_scan(source_dir, output_dir):
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Find tool paths
    gosec_path = find_tool_path("gosec")
    staticcheck_path = find_tool_path("staticcheck")
    
    if not gosec_path or not staticcheck_path:
        print("Error: Required tools not found. Please run 'make install-tools' first.")
        sys.exit(1)
    
    findings = []
    go_files = [f for f in os.listdir(source_dir) if f.endswith('.go')]
    
    for file in go_files:
        file_path = os.path.join(source_dir, file)
        print(f"Scanning {file_path}...")
        
        try:
            # Run gosec
            gosec_output = subprocess.run(
                [gosec_path, "-fmt=json", file_path],
                capture_output=True,
                text=True,
                check=False
            )
            
            if gosec_output.stdout:
                try:
                    gosec_findings = json.loads(gosec_output.stdout)
                    if "Issues" in gosec_findings:
                        for issue in gosec_findings["Issues"]:
                            findings.append({
                                "file": file,
                                "tool": "gosec",
                                "severity": issue.get("severity", "UNKNOWN"),
                                "type": issue.get("rule_id", "UNKNOWN"),
                                "message": issue.get("details", "No details provided"),
                                "line": issue.get("line", "0")
                            })
                except json.JSONDecodeError:
                    print(f"Warning: Could not parse gosec output for {file}")
            
            # Run staticcheck
            staticcheck_output = subprocess.run(
                [staticcheck_path, "-f=json", file_path],
                capture_output=True,
                text=True,
                check=False
            )
            
            if staticcheck_output.stdout:
                for line in staticcheck_output.stdout.splitlines():
                    try:
                        issue = json.loads(line)
                        findings.append({
                            "file": file,
                            "tool": "staticcheck",
                            "severity": "WARNING",
                            "type": issue.get("code", "UNKNOWN"),
                            "message": issue.get("message", "No message provided"),
                            "line": str(issue.get("position", {}).get("line", "0"))
                        })
                    except json.JSONDecodeError:
                        print(f"Warning: Could not parse staticcheck output line for {file}")
                        
        except subprocess.CalledProcessError as e:
            print(f"Error scanning file {file_path}: {str(e)}")
            continue
    
    # Generate JSON report
    report = {
        "summary": {
            "total_files": len(go_files),
            "total_findings": len(findings),
            "findings_by_severity": {},
            "findings_by_tool": {}
        },
        "findings": findings
    }
    
    # Calculate statistics
    for finding in findings:
        # Count by severity
        severity = finding["severity"]
        report["summary"]["findings_by_severity"][severity] = \
            report["summary"]["findings_by_severity"].get(severity, 0) + 1
        
        # Count by tool
        tool = finding["tool"]
        report["summary"]["findings_by_tool"][tool] = \
            report["summary"]["findings_by_tool"].get(tool, 0) + 1
    
    # Save JSON report
    json_report_path = os.path.join(output_dir, "go_security_scan_report.json")
    with open(json_report_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\nSecurity scan completed. Report generated at: {json_report_path}")
    
    # Print summary
    print("\nScan Summary:")
    print(f"Files Scanned: {report['summary']['total_files']}")
    print(f"Total Findings: {report['summary']['total_findings']}")
    
    print("\nFindings by Severity:")
    for severity, count in report["summary"]["findings_by_severity"].items():
        print(f"  {severity}: {count}")
    
    print("\nFindings by Tool:")
    for tool, count in report["summary"]["findings_by_tool"].items():
        print(f"  {tool}: {count}")
    
    # Generate HTML report
    html_report_path = os.path.join(output_dir, "security_report.html")
    generate_html_report(report, html_report_path)
    print(f"\nHTML report generated at: {html_report_path}")

def generate_html_report(report, output_path):
    html_template = """<!DOCTYPE html>
<html>
<head>
    <title>Go Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { margin: 20px 0; }
        .finding { border: 1px solid #ddd; margin: 10px 0; padding: 10px; }
        .high { border-left: 5px solid #ff4444; }
        .medium { border-left: 5px solid #ffbb33; }
        .low { border-left: 5px solid #00C851; }
    </style>
</head>
<body>
    <h1>Go Security Scan Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Files Scanned: %d</p>
        <p>Total Findings: %d</p>
        
        <h3>Findings by Severity</h3>
        <ul>
            %s
        </ul>
        
        <h3>Findings by Tool</h3>
        <ul>
            %s
        </ul>
    </div>
    
    <h2>Detailed Findings</h2>
    <div class="findings">
        %s
    </div>
</body>
</html>"""
    
    # Generate severity summary
    severity_items = []
    for severity, count in report["summary"]["findings_by_severity"].items():
        severity_items.append(f"<li>{severity}: {count}</li>")
    severity_summary = "\n".join(severity_items)
    
    # Generate tool summary
    tool_items = []
    for tool, count in report["summary"]["findings_by_tool"].items():
        tool_items.append(f"<li>{tool}: {count}</li>")
    tool_summary = "\n".join(tool_items)
    
    # Generate findings
    finding_items = []
    for finding in report["findings"]:
        severity_class = finding["severity"].lower()
        finding_html = f"""
        <div class="finding {severity_class}">
            <h3>{finding["file"]} - Line {finding["line"]}</h3>
            <p><strong>Tool:</strong> {finding["tool"]}</p>
            <p><strong>Severity:</strong> {finding["severity"]}</p>
            <p><strong>Type:</strong> {finding["type"]}</p>
            <p><strong>Message:</strong> {finding["message"]}</p>
        </div>
        """
        finding_items.append(finding_html)
    findings_html = "\n".join(finding_items)
    
    # Fill template
    html_content = html_template % (
        report["summary"]["total_files"],
        report["summary"]["total_findings"],
        severity_summary,
        tool_summary,
        findings_html
    )
    
    # Write HTML report
    with open(output_path, "w") as f:
        f.write(html_content)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 go_security_scanner.py <source_dir> <output_dir>")
        sys.exit(1)
    
    source_dir = sys.argv[1]
    output_dir = sys.argv[2]
    run_security_scan(source_dir, output_dir) 