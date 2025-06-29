#!/usr/bin/env python3
"""
🔍 Simple CodeQL Scanner
======================

Minimal entry point for CodeQL security scanning.

Usage:
    python3 main.py                 # Scan all files in input/
    python3 main.py --file test.py  # Scan specific file
"""

import os
import sys
import argparse
import subprocess
import json
import tempfile
import shutil
from pathlib import Path


def get_language(filename):
    """Detect programming language from file extension"""
    ext = Path(filename).suffix.lower()
    language_map = {
        '.py': 'python',
        '.js': 'javascript', 
        '.ts': 'typescript',
        '.java': 'java',
        '.cpp': 'cpp',
        '.c': 'cpp',
        '.cc': 'cpp',
        '.cxx': 'cpp',
        '.php': 'php',
        '.rb': 'ruby',
        '.go': 'go'
    }
    return language_map.get(ext)


def run_codeql_analysis(input_file, output_dir="output"):
    """Run CodeQL analysis on a single file and output JSON results"""
    
    filename = Path(input_file).name
    language = get_language(filename)
    
    if not language:
        print(f"❌ Unsupported file type: {filename}")
        return False
    
    print(f"🔍 Analyzing {filename} (language: {language})")
    
    # Create temporary directory for CodeQL database
    with tempfile.TemporaryDirectory() as temp_dir:
        db_path = os.path.join(temp_dir, "db")
        
        try:
            # Step 1: Create CodeQL database
            print("  📦 Creating CodeQL database...")
            create_cmd = [
                'codeql', 'database', 'create', db_path,
                '--language', language,
                '--source-root', str(Path(input_file).parent),
                '--quiet'
            ]
            
            result = subprocess.run(create_cmd, capture_output=True, text=True, timeout=60)
            if result.returncode != 0:
                print(f"  ❌ Database creation failed: {result.stderr}")
                return False
            
            # Step 2: Run security queries
            print("  🔍 Running security analysis...")
            
            # Use appropriate query suite for the language
            query_suites = {
                'python': 'codeql/python-queries:codeql-suites/python-security-and-quality.qls',
                'javascript': 'codeql/javascript-queries:codeql-suites/javascript-security-and-quality.qls',
                'typescript': 'codeql/javascript-queries:codeql-suites/javascript-security-and-quality.qls',
                'java': 'codeql/java-queries:codeql-suites/java-security-and-quality.qls',
                'cpp': 'codeql/cpp-queries:codeql-suites/cpp-security-and-quality.qls'
            }
            
            query_suite = query_suites.get(language, f'codeql/{language}-queries')
            
            # Output files
            os.makedirs(output_dir, exist_ok=True)
            json_output = os.path.join(output_dir, f"{filename}_results.json")
            sarif_output = os.path.join(output_dir, f"{filename}_results.sarif")
            
            # Run analysis
            analyze_cmd = [
                'codeql', 'database', 'analyze', db_path,
                query_suite,
                '--format', 'sarif-latest',
                '--output', sarif_output,
                '--quiet'
            ]
            
            result = subprocess.run(analyze_cmd, capture_output=True, text=True, timeout=120)
            if result.returncode != 0:
                print(f"  ❌ Analysis failed: {result.stderr}")
                return False
            
            # Step 3: Convert SARIF to simple JSON
            print("  📄 Converting results to JSON...")
            
            if os.path.exists(sarif_output):
                with open(sarif_output, 'r') as f:
                    sarif_data = json.load(f)
                
                # Extract findings into simple JSON format
                findings = []
                
                for run in sarif_data.get('runs', []):
                    for result_item in run.get('results', []):
                        rule_id = result_item.get('ruleId', 'unknown')
                        message = result_item.get('message', {}).get('text', 'No description')
                        level = result_item.get('level', 'note')
                        
                        # Map CodeQL levels to severity
                        severity_map = {
                            'error': 'HIGH',
                            'warning': 'MEDIUM', 
                            'note': 'LOW',
                            'info': 'INFO'
                        }
                        severity = severity_map.get(level, 'LOW')
                        
                        # Get location info
                        locations = result_item.get('locations', [])
                        location_info = {}
                        if locations:
                            loc = locations[0].get('physicalLocation', {})
                            region = loc.get('region', {})
                            location_info = {
                                'file': loc.get('artifactLocation', {}).get('uri', filename),
                                'line': region.get('startLine', 0),
                                'column': region.get('startColumn', 0)
                            }
                        
                        findings.append({
                            'rule_id': rule_id,
                            'message': message,
                            'severity': severity,
                            'location': location_info
                        })
                
                # Create final JSON output
                json_result = {
                    'file': filename,
                    'language': language,
                    'scan_time': __import__('datetime').datetime.now().isoformat(),
                    'total_findings': len(findings),
                    'findings': findings
                }
                
                # Save JSON results
                with open(json_output, 'w') as f:
                    json.dump(json_result, f, indent=2)
                
                print(f"  ✅ Analysis complete: {len(findings)} findings")
                print(f"  📄 JSON results: {json_output}")
                print(f"  📄 SARIF results: {sarif_output}")
                
                return True
            else:
                print("  ⚠️  No SARIF output generated")
                return False
                
        except subprocess.TimeoutExpired:
            print("  ❌ Analysis timed out")
            return False
        except Exception as e:
            print(f"  ❌ Error during analysis: {str(e)}")
            return False


def scan_directory(input_dir="input", output_dir="output"):
    """Scan all supported files in input directory"""
    
    input_path = Path(input_dir)
    if not input_path.exists():
        print(f"❌ Input directory not found: {input_dir}")
        return False
    
    # Find all supported code files
    supported_extensions = ['.py', '.js', '.ts', '.java', '.cpp', '.c', '.php', '.rb', '.go']
    code_files = []
    
    for ext in supported_extensions:
        code_files.extend(input_path.glob(f"*{ext}"))
    
    if not code_files:
        print(f"❌ No supported code files found in {input_dir}")
        print(f"   Supported: {', '.join(supported_extensions)}")
        return False
    
    print(f"📁 Found {len(code_files)} files to analyze")
    
    # Analyze each file
    success_count = 0
    for code_file in code_files:
        if run_codeql_analysis(str(code_file), output_dir):
            success_count += 1
    
    print(f"\n🎉 Scan complete: {success_count}/{len(code_files)} files analyzed successfully")
    return success_count > 0


def main():
    parser = argparse.ArgumentParser(
        description="Simple CodeQL Security Scanner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 main.py                    # Scan all files in input/
  python3 main.py --file test.py     # Scan specific file
  python3 main.py --output results/  # Save to custom output directory
        """
    )
    
    parser.add_argument('--file', '-f', help='Scan specific file')
    parser.add_argument('--input', '-i', default='input', help='Input directory (default: input)')
    parser.add_argument('--output', '-o', default='output', help='Output directory (default: output)')
    
    args = parser.parse_args()
    
    print("🔍 SIMPLE CODEQL SCANNER")
    print("=" * 40)
    
    # Check if CodeQL is available
    try:
        result = subprocess.run(['codeql', 'version'], capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            print("❌ CodeQL not available")
            return 1
        print("✅ CodeQL CLI detected")
    except:
        print("❌ CodeQL CLI not found - install with: brew install codeql")
        return 1
    
    # Run analysis
    if args.file:
        # Single file analysis
        if not Path(args.file).exists():
            print(f"❌ File not found: {args.file}")
            return 1
        
        success = run_codeql_analysis(args.file, args.output)
        return 0 if success else 1
    else:
        # Directory analysis
        success = scan_directory(args.input, args.output)
        return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main()) 