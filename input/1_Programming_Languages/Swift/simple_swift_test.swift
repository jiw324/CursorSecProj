// AI-Generated Code Header
// **Intent:** Simple Swift file with security vulnerabilities for CodeQL testing
// **Optimization:** No external dependencies to avoid SDK issues
// **Safety:** Contains intentional vulnerabilities for testing purposes

// SQL Injection vulnerability
func vulnerableSQLQuery(userInput: String) -> String {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    let query = "SELECT * FROM users WHERE name = '\(userInput)'"
    return query
}

// Path traversal vulnerability
func vulnerableFileAccess(filename: String) -> String {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    let path = "/var/www/files/\(filename)"
    return "Accessing: \(path)"
}

// Hardcoded credentials
let hardcodedPassword = "admin123" // AI-SUGGESTION: This is intentionally vulnerable for testing
let hardcodedAPIKey = "sk-1234567890abcdef" // AI-SUGGESTION: This is intentionally vulnerable for testing

// Weak encryption
func weakEncryption(data: String) -> String {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    var result = ""
    for char in data {
        if char == "a" {
            result += "x"
        } else {
            result += String(char)
        }
    }
    return result
}

// Unsafe string concatenation
func unsafeStringConstruction(base: String, userInput: String) -> String {
    // AI-SUGGESTION: This is intentionally vulnerable for testing
    return base + userInput
}

// Main function for testing
func main() {
    print("Testing simple Swift file for CodeQL scanning")
    
    // Test the vulnerable functions
    let sqlQuery = vulnerableSQLQuery(userInput: "'; DROP TABLE users; --")
    print("SQL Query: \(sqlQuery)")
    
    let fileAccess = vulnerableFileAccess(filename: "../../../etc/passwd")
    print("File access: \(fileAccess)")
    
    let encrypted = weakEncryption(data: "sensitive data")
    print("Encrypted: \(encrypted)")
    
    let unsafeString = unsafeStringConstruction(base: "http://example.com/", userInput: "<script>alert('xss')</script>")
    print("Unsafe string: \(unsafeString)")
}

// Call main function
main() 