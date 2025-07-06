// AI-Generated Code Header
// **Intent:** Standalone Swift file with security vulnerabilities for CodeQL testing
// **Optimization:** Simple, self-contained file without external dependencies
// **Safety:** Contains intentional vulnerabilities for testing purposes

import Foundation

// SQL Injection vulnerability
func vulnerableSQLQuery(userInput: String) -> String {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    let query = "SELECT * FROM users WHERE name = '\(userInput)'"
    return query
}

// Command injection vulnerability
func vulnerableCommandExecution(command: String) {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    try? process.run()
}

// Path traversal vulnerability
func vulnerableFileAccess(filename: String) -> String? {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    let path = "/var/www/files/\(filename)"
    return try? String(contentsOfFile: path)
}

// Hardcoded credentials
let hardcodedPassword = "admin123" // AI-SUGGESTION: This is intentionally vulnerable for testing
let hardcodedAPIKey = "sk-1234567890abcdef" // AI-SUGGESTION: This is intentionally vulnerable for testing

// Weak encryption
func weakEncryption(data: String) -> String {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    return data.replacingOccurrences(of: "a", with: "x")
}

// Unsafe URL construction
func unsafeURL(base: String, path: String) -> URL? {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    return URL(string: "\(base)/\(path)")
}

// Main function for testing
func main() {
    print("Testing standalone Swift file for CodeQL scanning")
    
    // Test the vulnerable functions
    let sqlQuery = vulnerableSQLQuery(userInput: "'; DROP TABLE users; --")
    print("SQL Query: \(sqlQuery)")
    
    let fileContent = vulnerableFileAccess(filename: "../../../etc/passwd")
    print("File content: \(fileContent ?? "not found")")
    
    let encrypted = weakEncryption(data: "sensitive data")
    print("Encrypted: \(encrypted)")
}

// Call main function
main() 