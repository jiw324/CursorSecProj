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

INPUT_ROOT = 'input/1_Programming_Languages/CPP/'
OUTPUT_ROOT = 'output/'
# AI-SUGGESTION: Add timestamp to output report filename
TIMESTAMP = datetime.now().strftime('%Y%m%d_%H%M%S')
REPORT_PATH = os.path.join(OUTPUT_ROOT, f'scan_report_{TIMESTAMP}.txt')

# AI-SUGGESTION: Supported languages and their file extensions for CodeQL
CODEQL_LANGUAGES = {
    'cpp': ['.cpp', '.c', '.h', '.hpp'],
    'java': ['.java'],
    'javascript': ['.js'],
    'typescript': ['.ts'],
    'python': ['.py'],
    'csharp': ['.cs'],
    'go': ['.go'],
    'ruby': ['.rb'],
    'swift': ['.swift'],
    'objectivec': ['.m'],
    'php': ['.php'],
    'rust': ['.rs'],
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
    'typescript': ['tsc'],
    'objectivec': ['clang'],
    'php': ['php'],
    'rust': ['rustc'],
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
    # For Go, Java, JS, TS, PHP, Python, Ruby: No build command needed for single-file scan
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
    if not toolchain_available(lang):
        print(f"[SKIP] Required toolchain for {lang} not found, skipping: {file_path}")
        return None, f'[SKIP] Required toolchain for {lang} not found.'
    with tempfile.TemporaryDirectory() as test_dir, tempfile.TemporaryDirectory() as db_dir:
        shutil.copy2(file_path, test_dir)
        file_name = os.path.basename(file_path)
        build_cmd = get_build_command(lang, file_name)
        # AI-SUGGESTION: For C++ files, copy all headers from the same directory
        if lang == 'cpp' and file_name.endswith('.cpp'):
            copy_cpp_headers(file_path, test_dir)
        try:
            # AI-SUGGESTION: Use build command if needed
            if build_cmd:
                cmd = [
                    'codeql', 'database', 'create', db_dir,
                    f'--language={"cpp" if lang in ["cpp", "objectivec"] else lang}',
                    '--source-root=' + test_dir,
                    '--command', ' '.join(build_cmd)
                ]
            else:
                cmd = [
                    'codeql', 'database', 'create', db_dir,
                    f'--language={lang}',
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
            elif lang == 'java':
                query_suite = 'codeql/java-queries'
            elif lang in ['javascript', 'typescript']:
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

def main():
    ensure_output_dir(REPORT_PATH)
    with open(REPORT_PATH, 'w') as report:
        for root, _, files in os.walk(INPUT_ROOT):
            for file in files:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, INPUT_ROOT)
                report.write("==============================\n")
                report.write(f"File: {file_path}\n")
                report.write("------------------------------\n")
                findings, skip_reason = scan_file(file_path)
                if findings:
                    for line in findings:
                        report.write(line + '\n')
                        print(line)
                elif skip_reason:
                    report.write(skip_reason + '\n')
                    print(skip_reason)
                report.write("\n")
    print(f"\n[INFO] Scan complete. See {REPORT_PATH}")

if __name__ == '__main__':
    main() 