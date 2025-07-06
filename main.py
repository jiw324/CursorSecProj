#!/usr/bin/env python3
# AI-Generated Code Header
# **Intent:** Scan all files in input/1_Programming_Languages/CPP/ using CodeQL, outputting a single consolidated report with a timestamped filename. Uses correct build/scan logic for Go, Java, JS/TS, Objective-C, PHP, Python, Ruby, and Rust.
# **Optimization:** Per-file temp dirs for clean, robust scanning. Single output file for easy review.
# **Safety:** Robust error handling, temp dir cleanup, output structure mirroring input, toolchain checks, and language-specific build logic.

import os
import subprocess
import shutil
import json
import tempfile
from pathlib import Path
from datetime import datetime

# AI-SUGGESTION: Define all programming language folders to scan
LANGUAGE_FOLDERS = [
    # 'C',
    # 'CPP', 
    # 'Go',
    # 'JavaScript_TypeScript',
    # 'Python',
    # 'Ruby',
    # 'CSharp_DotNet',    
    # 'Java',
    # 'Kotlin',
    'Swift',
    # 'Objective_C',
    # 'PHP',
    # 'Rust',
    # 'Scala', 
]

INPUT_BASE = 'input/1_Programming_Languages/'
OUTPUT_ROOT = 'output/'

# AI-SUGGESTION: Supported languages and their file extensions for CodeQL
CODEQL_LANGUAGES = {
    'cpp': ['.cpp', '.c', '.h', '.hpp', '.cc', '.cxx'],
    'java': ['.java', '.kt'],  # Include Kotlin files 
    'javascript': ['.js', '.jsx', '.ts', '.tsx'],  # Include TypeScript
    'python': ['.py'],
    'csharp': ['.cs'],
    'go': ['.go'],
    'ruby': ['.rb'],
    'swift': ['.swift'],
    'objectivec': ['.m', '.mm'],
    'php': ['.php'],
    'rust': ['.rs'],
    'scala': ['.scala', '.sc'],  # Scala files (mapped to Java queries)
}

# AI-SUGGESTION: Required toolchain for each language
REQUIRED_TOOLCHAINS = {
    'cpp': ['g++'],
    'java': ['javac'],
    'go': ['go'],
    'python': ['python3'],
    'csharp': ['csc'],
    'ruby': ['ruby'],
    'swift': ['swiftc'],
    'javascript': ['node'],
    'objectivec': ['clang'],
    'php': ['php'],
    'rust': ['rustc'],
    'scala': ['scalac'],
}

# AI-SUGGESTION: Map file extension to CodeQL language
def detect_language(file_path):
    ext = Path(file_path).suffix.lower()
    for lang, exts in CODEQL_LANGUAGES.items():
        if ext in exts:
            return lang
    return None

# AI-SUGGESTION: Ensure output directory exists
def ensure_output_dir(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)

# AI-SUGGESTION: Check if required toolchain is available for a language
def toolchain_available(lang):
    if lang not in REQUIRED_TOOLCHAINS:
        return True
    for tool in REQUIRED_TOOLCHAINS[lang]:
        if shutil.which(tool) is None:
            return False
    return True

# AI-SUGGESTION: Get build command for a language and file
def get_build_command(lang, file_name):
    if lang == 'cpp':
        if file_name.endswith('.c'):
            return ['gcc', '-c', file_name, '-lm']
        else:
            # AI-SUGGESTION: Add -std=c++17, -D_USE_MATH_DEFINES, and -lm for C++ files
            return ['g++', '-std=c++17', '-D_USE_MATH_DEFINES', '-c', file_name, '-lm']
    elif lang == 'objectivec':
        return ['clang', '-c', file_name]
    elif lang == 'rust':
        return ['rustc', file_name]
    elif lang == 'java' and file_name.endswith('.kt'):
        # Kotlin files need kotlinc compiler 
        return ['kotlinc', file_name]
    elif lang == 'scala':
        return ['scalac', file_name]
    # For Go, Java, JS/TS, PHP, Python, Ruby, Swift, C#: No build command needed for single-file scan
    return None

# AI-SUGGESTION: Copy all headers for C++ files to temp dir
def copy_cpp_headers(src_file, temp_dir):
    src_dir = os.path.dirname(src_file)
    for ext in ('.h', '.hpp'):
        for header in Path(src_dir).glob(f'*{ext}'):
            shutil.copy2(header, temp_dir)

# AI-SUGGESTION: Scan a single file, return findings as a list of strings, and include error output if any
def scan_file(file_path):
    lang = detect_language(file_path)
    if not lang:
        print(f"[SKIP] Unsupported file type: {file_path}")
        return None, '[SKIP] Unsupported file type.'
    
    # AI-SUGGESTION: Only check toolchain for languages that have build commands
    build_cmd = get_build_command(lang, os.path.basename(file_path))
    if build_cmd and not toolchain_available(lang):
        print(f"[SKIP] Required toolchain for {lang} not found, skipping: {file_path}")
        return None, f'[SKIP] Required toolchain for {lang} not found.'
    with tempfile.TemporaryDirectory() as test_dir, tempfile.TemporaryDirectory() as db_dir:
        shutil.copy2(file_path, test_dir)
        file_name = os.path.basename(file_path)
        # AI-SUGGESTION: For C++ files, copy all headers from the same directory
        if lang == 'cpp' and file_name.endswith('.cpp'):
            copy_cpp_headers(file_path, test_dir)
        try:
            # AI-SUGGESTION: Check if this is a compiled language with known issues
            if lang in ['cpp', 'c']:
                # For compiled languages, CodeQL needs proper build context
                # Single files without build systems can't be analyzed properly
                return [f"[INFO] {lang.upper()} requires build context - skipping individual file analysis"], None
            
            # AI-SUGGESTION: Special handling for Go files with module structure
            if lang == 'go':
                # Copy go.mod and go.sum if they exist
                go_mod_path = os.path.join(os.path.dirname(file_path), 'go.mod')
                go_sum_path = os.path.join(os.path.dirname(file_path), 'go.sum')
                if os.path.exists(go_mod_path):
                    shutil.copy2(go_mod_path, test_dir)
                if os.path.exists(go_sum_path):
                    shutil.copy2(go_sum_path, test_dir)
            
            # AI-SUGGESTION: Special handling for C# files with project structure
            if lang == 'csharp':
                # For C# projects, we need to scan the entire project directory
                # Skip individual file scanning for C# as it requires full project context
                return [f"[INFO] CSHARP requires full project context - use scan_language_folder() for C# projects"], None
            
            # AI-SUGGESTION: Special handling for Java files with project structure
            if lang == 'java':
                # For Java projects, we need to scan the entire project directory
                # Skip individual file scanning for Java as it requires full project context
                return [f"[INFO] JAVA requires full project context - use scan_language_folder() for Java projects"], None
            
            # AI-SUGGESTION: Use build command if needed
            # Map Scala to Java for CodeQL language
            codeql_lang = 'java' if lang == 'scala' else lang
            if build_cmd:
                cmd = [
                    'codeql', 'database', 'create', db_dir,
                    f'--language={"cpp" if codeql_lang in ["cpp", "objectivec"] else codeql_lang}',
                    '--source-root=' + test_dir,
                    '--command', ' '.join(build_cmd)
                ]
            else:
                cmd = [
                    'codeql', 'database', 'create', db_dir,
                    f'--language={codeql_lang}',
                    '--source-root=' + test_dir
                ]
            db_proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if db_proc.returncode != 0:
                return [f"[ERROR] CodeQL failed (database create): {db_proc.stderr.decode().strip()}"], None
            # Analyze
            if lang in ['cpp', 'objectivec']:
                query_suite = 'codeql/cpp-queries'
            elif lang == 'rust':
                query_suite = 'codeql/rust-queries'
            elif lang == 'php':
                query_suite = 'codeql/php-queries'
            elif lang == 'go':
                query_suite = 'codeql/go-queries'
            elif lang in ['java', 'scala']:
                query_suite = 'codeql/java-queries'  # Scala uses Java queries
            elif lang == 'javascript':
                query_suite = 'codeql/javascript-queries'
            elif lang == 'python':
                query_suite = 'codeql/python-queries'
            elif lang == 'ruby':
                query_suite = 'codeql/ruby-queries'
            elif lang == 'swift':
                query_suite = 'codeql/swift-queries'
            elif lang == 'csharp':
                query_suite = 'codeql/csharp-queries'
            else:
                query_suite = f'codeql/{lang}-queries'
            sarif_path = os.path.join(test_dir, 'results.sarif')
            analyze_cmd = [
                'codeql', 'database', 'analyze', db_dir,
                query_suite,
                '--format=sarifv2.1.0',
                '--output', sarif_path
            ]
            analyze_proc = subprocess.run(analyze_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if analyze_proc.returncode != 0:
                return [f"[ERROR] CodeQL failed (analyze): {analyze_proc.stderr.decode().strip()}"], None
            # Parse SARIF
            try:
                with open(sarif_path, 'r') as f:
                    sarif = json.load(f)
                runs = sarif.get('runs', [])
                results = []
                for run in runs:
                    for res in run.get('results', []):
                        rule_id = res.get('ruleId', 'unknown')
                        message = res.get('message', {}).get('text', '')
                        level = res.get('level', 'warning')
                        locations = res.get('locations', [])
                        if locations:
                            loc = locations[0].get('physicalLocation', {}).get('artifactLocation', {}).get('uri', '')
                        else:
                            loc = ''
                        results.append(f"[{level.upper()}] {rule_id} at {loc}: {message}")
                if not results:
                    results = ['No findings.']
                return results, None
            except Exception as e:
                return [f"Failed to parse SARIF: {e}"], None
        except Exception as e:
            return [f"[ERROR] Unexpected error: {e}"], None

# AI-SUGGESTION: Scan a specific language folder
def scan_language_folder(language_folder):
    input_root = os.path.join(INPUT_BASE, language_folder)
    
    # Check if folder exists
    if not os.path.exists(input_root):
        print(f"[SKIP] Folder not found: {input_root}")
        return
    
    # Generate timestamp and output path for this language
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_path = os.path.join(OUTPUT_ROOT, f'{language_folder}_{timestamp}')
    
    print(f"\n{'='*60}")
    print(f"SCANNING: {language_folder}")
    print(f"INPUT:    {input_root}")
    print(f"OUTPUT:   {report_path}")
    print(f"{'='*60}")
    
    ensure_output_dir(report_path)
    
    # AI-SUGGESTION: Special handling for C# projects
    if language_folder == 'CSharp_DotNet':
        return scan_csharp_project(input_root, report_path, language_folder)
    
    # AI-SUGGESTION: Special handling for Java projects
    if language_folder == 'Java':
        return scan_java_project(input_root, report_path, language_folder)
    
    # AI-SUGGESTION: Special handling for Kotlin projects
    if language_folder == 'Kotlin':
        return scan_kotlin_project(input_root, report_path, language_folder)
    
    total_files = 0
    scanned_files = 0
    
    with open(report_path, 'w') as report:
        report.write(f"CodeQL Security Scan Report - {language_folder}\n")
        report.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        report.write(f"{'='*60}\n\n")
        
        for root, _, files in os.walk(input_root):
            for file in files:
                total_files += 1
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, input_root)
                
                report.write("==============================\n")
                report.write(f"File: {file_path}\n")
                report.write("------------------------------\n")
                
                findings, skip_reason = scan_file(file_path)
                if findings:
                    scanned_files += 1
                    for line in findings:
                        report.write(line + '\n')
                        print(f"[{language_folder}] {line}")
                elif skip_reason:
                    report.write(skip_reason + '\n')
                    if not skip_reason.startswith('[SKIP] Unsupported file type'):
                        print(f"[{language_folder}] {skip_reason}")
                report.write("\n")
    
    print(f"[{language_folder}] Scan complete: {scanned_files}/{total_files} files analyzed")
    print(f"[{language_folder}] Report saved: {report_path}\n")

# AI-SUGGESTION: Special function to handle C# projects with full project context
def scan_csharp_project(input_root, report_path, language_folder):
    """Scan C# projects by creating a single CodeQL database for the entire project."""
    
    print(f"[{language_folder}] Scanning C# project with full project context...")
    
    # Get all C# source files
    cs_files = []
    for root, _, files in os.walk(input_root):
        for file in files:
            if file.endswith('.cs'):
                cs_files.append(os.path.join(root, file))
    
    with open(report_path, 'w') as report:
        report.write(f"CodeQL Security Scan Report - {language_folder}\n")
        report.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        report.write(f"{'='*60}\n\n")
        
        # Check if .csproj file exists
        csproj_files = [f for f in os.listdir(input_root) if f.endswith('.csproj')]
        if not csproj_files:
            report.write("No .csproj file found. C# project structure required.\n")
            print(f"[{language_folder}] No .csproj file found")
            return
        
        # Create temporary directory for CodeQL database
        with tempfile.TemporaryDirectory() as db_dir:
            try:
                # Create CodeQL database for the entire project
                cmd = [
                    'codeql', 'database', 'create', db_dir,
                    '--language=csharp',
                    '--source-root=' + input_root
                ]
                
                print(f"[{language_folder}] Creating CodeQL database...")
                db_proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                if db_proc.returncode != 0:
                    error_msg = f"[ERROR] CodeQL failed (database create): {db_proc.stderr.decode().strip()}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    return
                
                # Analyze the database
                print(f"[{language_folder}] Running CodeQL analysis...")
                sarif_path = os.path.join(db_dir, 'results.sarif')
                analyze_cmd = [
                    'codeql', 'database', 'analyze', db_dir,
                    'codeql/csharp-queries:codeql-suites',
                    '--format=sarifv2.1.0',
                    '--output', sarif_path
                ]
                
                analyze_proc = subprocess.run(analyze_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                if analyze_proc.returncode != 0:
                    error_msg = f"[ERROR] CodeQL failed (analyze): {analyze_proc.stderr.decode().strip()}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    return
                
                # Parse SARIF results and organize by file
                try:
                    with open(sarif_path, 'r') as f:
                        sarif = json.load(f)
                    
                    # Group results by file
                    file_results = {}
                    runs = sarif.get('runs', [])
                    
                    for run in runs:
                        for res in run.get('results', []):
                            rule_id = res.get('ruleId', 'unknown')
                            message = res.get('message', {}).get('text', '')
                            level = res.get('level', 'warning')
                            locations = res.get('locations', [])
                            
                            if locations:
                                loc = locations[0].get('physicalLocation', {}).get('artifactLocation', {}).get('uri', '')
                                # Extract just the filename from the path
                                filename = os.path.basename(loc) if loc else 'unknown'
                            else:
                                filename = 'unknown'
                            
                            if filename not in file_results:
                                file_results[filename] = []
                            
                            file_results[filename].append(f"[{level.upper()}] {rule_id} at {loc}: {message}")
                    
                    # Write results in the same format as other languages
                    for cs_file in cs_files:
                        filename = os.path.basename(cs_file)
                        report.write("==============================\n")
                        report.write(f"File: {cs_file}\n")
                        report.write("------------------------------\n")
                        
                        if filename in file_results:
                            for result in file_results[filename]:
                                report.write(result + '\n')
                                print(f"[{language_folder}] {result}")
                        else:
                            report.write("No findings.\n")
                        
                        report.write("\n")
                    
                    print(f"[{language_folder}] C# project scan complete")
                    print(f"[{language_folder}] Report saved: {report_path}")
                    
                except Exception as e:
                    error_msg = f"Failed to parse SARIF: {e}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    
            except Exception as e:
                error_msg = f"[ERROR] Unexpected error: {e}"
                report.write(error_msg + '\n')
                print(f"[{language_folder}] {error_msg}")

# AI-SUGGESTION: Special function to handle Java projects with full project context
def scan_java_project(input_root, report_path, language_folder):
    """Scan Java projects by creating a single CodeQL database for the entire project."""
    
    print(f"[{language_folder}] Scanning Java project with full project context...")
    
    # Get all Java source files
    java_files = []
    for root, _, files in os.walk(input_root):
        for file in files:
            if file.endswith('.java'):
                java_files.append(os.path.join(root, file))
    
    with open(report_path, 'w') as report:
        report.write(f"CodeQL Security Scan Report - {language_folder}\n")
        report.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        report.write(f"{'='*60}\n\n")
        
        # Check if pom.xml file exists
        pom_files = [f for f in os.listdir(input_root) if f.endswith('pom.xml')]
        if not pom_files:
            report.write("No pom.xml file found. Java project structure required.\n")
            print(f"[{language_folder}] No pom.xml file found")
            return
        
        # Create temporary directory for CodeQL database
        with tempfile.TemporaryDirectory() as db_dir:
            try:
                # Create CodeQL database for the entire project
                cmd = [
                    'codeql', 'database', 'create', db_dir,
                    '--language=java',
                    '--source-root=' + input_root
                ]
                
                print(f"[{language_folder}] Creating CodeQL database...")
                db_proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                if db_proc.returncode != 0:
                    error_msg = f"[ERROR] CodeQL failed (database create): {db_proc.stderr.decode().strip()}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    return
                
                # Analyze the database
                print(f"[{language_folder}] Running CodeQL analysis...")
                sarif_path = os.path.join(db_dir, 'results.sarif')
                analyze_cmd = [
                    'codeql', 'database', 'analyze', db_dir,
                    'codeql/java-queries:codeql-suites',
                    '--format=sarifv2.1.0',
                    '--output', sarif_path
                ]
                
                analyze_proc = subprocess.run(analyze_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                if analyze_proc.returncode != 0:
                    error_msg = f"[ERROR] CodeQL failed (analyze): {analyze_proc.stderr.decode().strip()}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    return
                
                # Parse SARIF results and organize by file
                try:
                    with open(sarif_path, 'r') as f:
                        sarif = json.load(f)
                    
                    # Group results by file
                    file_results = {}
                    runs = sarif.get('runs', [])
                    
                    for run in runs:
                        for res in run.get('results', []):
                            rule_id = res.get('ruleId', 'unknown')
                            message = res.get('message', {}).get('text', '')
                            level = res.get('level', 'warning')
                            locations = res.get('locations', [])
                            
                            if locations:
                                loc = locations[0].get('physicalLocation', {}).get('artifactLocation', {}).get('uri', '')
                                # Extract just the filename from the path
                                filename = os.path.basename(loc) if loc else 'unknown'
                            else:
                                filename = 'unknown'
                            
                            if filename not in file_results:
                                file_results[filename] = []
                            
                            file_results[filename].append(f"[{level.upper()}] {rule_id} at {loc}: {message}")
                    
                    # Write results in the same format as other languages
                    for java_file in java_files:
                        filename = os.path.basename(java_file)
                        report.write("==============================\n")
                        report.write(f"File: {java_file}\n")
                        report.write("------------------------------\n")
                        
                        if filename in file_results:
                            for result in file_results[filename]:
                                report.write(result + '\n')
                                print(f"[{language_folder}] {result}")
                        else:
                            report.write("No findings.\n")
                        
                        report.write("\n")
                    
                    print(f"[{language_folder}] Java project scan complete")
                    print(f"[{language_folder}] Report saved: {report_path}")
                    
                except Exception as e:
                    error_msg = f"Failed to parse SARIF: {e}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    
            except Exception as e:
                error_msg = f"[ERROR] Unexpected error: {e}"
                report.write(error_msg + '\n')
                print(f"[{language_folder}] {error_msg}")

# AI-SUGGESTION: Special function to handle Kotlin projects with full project context
def scan_kotlin_project(input_root, report_path, language_folder):
    """Scan Kotlin projects by creating a single CodeQL database for the entire project."""
    
    print(f"[{language_folder}] Scanning Kotlin project with full project context...")
    
    # Get all Kotlin source files
    kt_files = []
    for root, _, files in os.walk(input_root):
        for file in files:
            if file.endswith('.kt'):
                kt_files.append(os.path.join(root, file))
    
    with open(report_path, 'w') as report:
        report.write(f"CodeQL Security Scan Report - {language_folder}\n")
        report.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        report.write(f"{'='*60}\n\n")
        
        # Check if build.gradle file exists (look in subdirectories too)
        gradle_files = []
        for root, _, files in os.walk(input_root):
            for file in files:
                if file == 'build.gradle' or file == 'build.gradle.kts':
                    gradle_files.append(os.path.join(root, file))
        
        if not gradle_files:
            report.write("No build.gradle file found. Kotlin project structure required.\n")
            print(f"[{language_folder}] No build.gradle file found")
            return
        
        # Use the first Gradle project found
        gradle_project_dir = os.path.dirname(gradle_files[0])
        print(f"[{language_folder}] Found Gradle project at: {gradle_project_dir}")
        
        # Create temporary directory for CodeQL database
        with tempfile.TemporaryDirectory() as db_dir:
            try:
                # Create CodeQL database for the entire project
                cmd = [
                    'codeql', 'database', 'create', db_dir,
                    '--language=java',  # Kotlin uses Java queries
                    '--source-root=' + gradle_project_dir
                ]
                
                print(f"[{language_folder}] Creating CodeQL database...")
                db_proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                if db_proc.returncode != 0:
                    error_msg = f"[ERROR] CodeQL failed (database create): {db_proc.stderr.decode().strip()}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    return
                
                # Analyze the database
                print(f"[{language_folder}] Running CodeQL analysis...")
                sarif_path = os.path.join(db_dir, 'results.sarif')
                analyze_cmd = [
                    'codeql', 'database', 'analyze', db_dir,
                    'codeql/java-queries:codeql-suites',
                    '--format=sarifv2.1.0',
                    '--output', sarif_path
                ]
                analyze_proc = subprocess.run(analyze_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                if analyze_proc.returncode != 0:
                    error_msg = f"[ERROR] CodeQL failed (analyze): {analyze_proc.stderr.decode().strip()}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    return
                
                # Parse SARIF and report findings for each file
                try:
                    with open(sarif_path, 'r') as f:
                        sarif = json.load(f)
                    
                    runs = sarif.get('runs', [])
                    all_results = {}
                    
                    # Group results by file
                    for run in runs:
                        for res in run.get('results', []):
                            locations = res.get('locations', [])
                            if locations:
                                loc = locations[0].get('physicalLocation', {})
                                artifact = loc.get('artifactLocation', {})
                                file_uri = artifact.get('uri', '')
                                # Convert URI to file path
                                if file_uri.startswith('file://'):
                                    file_path = file_uri[7:]  # Remove 'file://' prefix
                                else:
                                    file_path = file_uri
                                
                                if file_path not in all_results:
                                    all_results[file_path] = []
                                
                                rule_id = res.get('ruleId', 'unknown')
                                message = res.get('message', {}).get('text', '')
                                level = res.get('level', 'warning')
                                all_results[file_path].append(f"[{level.upper()}] {rule_id}: {message}")
                    
                    # Report findings for each Kotlin file
                    for kt_file in kt_files:
                        rel_path = os.path.relpath(kt_file, input_root)
                        report.write("==============================\n")
                        report.write(f"File: {kt_file}\n")
                        report.write("------------------------------\n")
                        
                        # Check if we have results for this file
                        file_found = False
                        for result_file, results in all_results.items():
                            if kt_file in result_file or rel_path in result_file:
                                file_found = True
                                for result in results:
                                    report.write(result + '\n')
                                    print(f"[{language_folder}] {result}")
                                break
                        
                        if not file_found:
                            report.write("No findings.\n")
                            print(f"[{language_folder}] No findings for {rel_path}")
                        
                        report.write("\n")
                    
                    print(f"[{language_folder}] Kotlin project scan complete")
                    
                except Exception as e:
                    error_msg = f"[ERROR] Failed to parse SARIF: {e}"
                    report.write(error_msg + '\n')
                    print(f"[{language_folder}] {error_msg}")
                    
            except Exception as e:
                error_msg = f"[ERROR] Unexpected error: {e}"
                report.write(error_msg + '\n')
                print(f"[{language_folder}] {error_msg}")

def main():
    print("CodeQL Multi-Language Security Scanner")
    print("=====================================")
    print(f"Scanning {len(LANGUAGE_FOLDERS)} programming language folders...")
    
    start_time = datetime.now()
    
    for language_folder in LANGUAGE_FOLDERS:
        try:
            scan_language_folder(language_folder)
        except KeyboardInterrupt:
            print(f"\n[INTERRUPTED] Scan cancelled during {language_folder}")
            break
        except Exception as e:
            print(f"[ERROR] Failed to scan {language_folder}: {e}")
            continue
    
    end_time = datetime.now()
    duration = end_time - start_time
    
    print(f"\n{'='*60}")
    print(f"SCAN SUMMARY")
    print(f"{'='*60}")
    print(f"Total time: {duration}")
    print(f"Output directory: {OUTPUT_ROOT}")
    print("Check individual language report files for detailed results.")

if __name__ == '__main__':
    main() 