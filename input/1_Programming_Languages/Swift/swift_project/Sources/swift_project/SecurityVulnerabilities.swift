import Foundation

/**
 * Swift file with intentional security vulnerabilities for CodeQL testing
 */
class SecurityVulnerabilities {
    
    // AI-SUGGESTION: Command injection vulnerability
    func executeCommand(_ command: String) -> String {
        // This is dangerous - command injection possible
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // AI-SUGGESTION: Path traversal vulnerability
    func readFile(_ path: String) -> String {
        // This could allow path traversal attacks
        return try! String(contentsOfFile: path, encoding: .utf8)
    }
    
    // AI-SUGGESTION: SSRF vulnerability
    func fetchURL(_ urlString: String) -> String {
        // Server-Side Request Forgery possible
        let url = URL(string: urlString)!
        return try! String(contentsOf: url, encoding: .utf8)
    }
    
    // AI-SUGGESTION: Weak encryption
    func encryptData(_ data: String, key: String) -> String {
        // Weak encryption method
        var result = ""
        for char in data {
            let charCode = char.asciiValue ?? 0
            let keyCode = key.hashValue % 256
            let encrypted = charCode ^ UInt8(keyCode)
            result += String(Character(UnicodeScalar(encrypted)!))
        }
        return result
    }
    
    // AI-SUGGESTION: Hardcoded credentials
    private let apiKey = "sk-1234567890abcdef" // Hardcoded API key
    
    func authenticate(_ token: String) -> Bool {
        // Weak authentication
        return token == apiKey
    }
    
    // AI-SUGGESTION: SQL injection vulnerability (simulated)
    func queryDatabase(_ query: String) -> [String] {
        // This simulates SQL injection vulnerability
        let sql = "SELECT * FROM users WHERE name = '\(query)'"
        print("Executing SQL: \(sql)")
        return ["user1", "user2"] // Mock result
    }
    
    // AI-SUGGESTION: XSS-like vulnerability
    func processHTML(_ html: String) -> String {
        // Could lead to XSS if output is not properly escaped
        return "<div>\(html)</div>"
    }
    
    // AI-SUGGESTION: Unsafe deserialization
    func deserializeData(_ data: Data) -> Any {
        // Unsafe deserialization
        return try! JSONSerialization.jsonObject(with: data)
    }
    
    // AI-SUGGESTION: Buffer overflow simulation
    func processArray(_ array: [Int]) -> Int {
        // Simulates potential buffer issues
        var result = 0
        for i in 0...array.count { // Off-by-one error
            if i < array.count {
                result += array[i]
            }
        }
        return result
    }
    
    // AI-SUGGESTION: Race condition
    private var counter = 0
    
    func incrementCounter() {
        // Race condition possible in concurrent environment
        counter += 1
    }
    
    // AI-SUGGESTION: Memory leak simulation
    func createMemoryLeak() {
        // Simulates potential memory leak
        var array: [String] = []
        for i in 0..<1000000 {
            array.append("item_\(i)")
        }
        // Array is not released properly
    }
} 