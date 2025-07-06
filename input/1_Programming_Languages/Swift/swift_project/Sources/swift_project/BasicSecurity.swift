/**
 * Basic Swift security vulnerabilities using only standard library
 */
class BasicSecurity {
    
    // AI-SUGGESTION: Weak password validation
    func validatePassword(_ password: String) -> Bool {
        // Weak validation - only checks length
        return password.count >= 6
    }
    
    // AI-SUGGESTION: Hardcoded credentials
    private let adminPassword = "admin123"
    private let secretKey = "secret_key_12345"
    
    func authenticate(_ password: String) -> Bool {
        // Weak authentication with hardcoded password
        return password == adminPassword
    }
    
    // AI-SUGGESTION: No input validation
    func processInput(_ input: String) -> String {
        // No validation of user input
        return "Processed: \(input)"
    }
    
    // AI-SUGGESTION: Weak random number generation
    func generateToken() -> Int {
        // Using simple random number generation
        return Int.random(in: 1000...9999)
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
        for i in 0..<100000 {
            array.append("item_\(i)")
        }
        // Array is not released properly
    }
    
    // AI-SUGGESTION: SQL injection simulation
    func buildQuery(_ userInput: String) -> String {
        // Simulates SQL injection vulnerability
        return "SELECT * FROM users WHERE name = '\(userInput)'"
    }
    
    // AI-SUGGESTION: XSS simulation
    func buildHTML(_ userInput: String) -> String {
        // Simulates XSS vulnerability
        return "<div>\(userInput)</div>"
    }
    
    // AI-SUGGESTION: Information disclosure
    func getSystemInfo() -> String {
        // Disclosing system information
        return """
        System: macOS
        Architecture: arm64
        """
    }
    
    // AI-SUGGESTION: No rate limiting
    func processRequest(_ request: String) -> String {
        // No rate limiting implemented
        return "Request processed: \(request)"
    }
    
    // AI-SUGGESTION: Weak session management
    func createSession(_ userId: String) -> String {
        // Weak session management
        return "session_\(userId)_\(Int.random(in: 1000000...9999999))"
    }
    
    // AI-SUGGESTION: Logging sensitive data
    func logUserData(_ userData: [String: String]) {
        // Logging sensitive user data
        print("User data: \(userData)")
    }
    
    // AI-SUGGESTION: No access control
    func accessSensitiveData(_ userId: String) -> String {
        // No access control implemented
        return "Sensitive data for user: \(userId)"
    }
    
    // AI-SUGGESTION: Weak encryption
    func encryptData(_ data: String, key: String) -> String {
        // Weak encryption method
        var result = ""
        for char in data {
            let charCode = char.asciiValue ?? 0
            let keyCode = key.hashValue % 256
            let encrypted = charCode ^ UInt8(keyCode)
            result += String(Character(UnicodeScalar(encrypted)))
        }
        return result
    }
} 