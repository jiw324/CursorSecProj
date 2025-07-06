import Foundation

/**
 * Network security vulnerabilities for CodeQL testing
 */
class NetworkSecurity {
    
    // AI-SUGGESTION: Insecure URL construction
    func buildURL(_ host: String, _ path: String) -> URL {
        // Insecure URL construction - no validation
        return URL(string: "http://\(host)/\(path)")!
    }
    
    // AI-SUGGESTION: Weak SSL/TLS configuration
    func createInsecureConnection(_ url: URL) -> URLSession {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv10 // Weak TLS version
        return URLSession(configuration: config)
    }
    
    // AI-SUGGESTION: No certificate validation
    func makeRequestWithoutValidation(_ urlString: String) -> String {
        let url = URL(string: urlString)!
        let session = URLSession(configuration: .default)
        
        let semaphore = DispatchSemaphore(value: 0)
        var result = ""
        
        let task = session.dataTask(with: url) { data, response, error in
            if let data = data {
                result = String(data: data, encoding: .utf8) ?? ""
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        return result
    }
    
    // AI-SUGGESTION: Hardcoded passwords
    private let databasePassword = "admin123" // Hardcoded password
    private let apiSecret = "secret_key_12345" // Hardcoded secret
    
    func connectToDatabase() -> String {
        // Using hardcoded credentials
        return "Connected with password: \(databasePassword)"
    }
    
    // AI-SUGGESTION: No input validation
    func processUserInput(_ input: String) -> String {
        // No validation of user input
        return "Processed: \(input)"
    }
    
    // AI-SUGGESTION: Information disclosure
    func getSystemInfo() -> String {
        // Disclosing sensitive system information
        let hostname = ProcessInfo.processInfo.hostName
        let username = NSUserName()
        let homeDir = NSHomeDirectory()
        
        return """
        Hostname: \(hostname)
        Username: \(username)
        Home Directory: \(homeDir)
        """
    }
    
    // AI-SUGGESTION: Weak random number generation
    func generateToken() -> String {
        // Using weak random number generation
        let random = Int.random(in: 1000...9999)
        return "token_\(random)"
    }
    
    // AI-SUGGESTION: No rate limiting
    func processRequest(_ request: String) -> String {
        // No rate limiting implemented
        return "Request processed: \(request)"
    }
    
    // AI-SUGGESTION: Logging sensitive data
    func logUserData(_ userData: [String: Any]) {
        // Logging sensitive user data
        print("User data: \(userData)")
    }
    
    // AI-SUGGESTION: No session management
    func createSession(_ userId: String) -> String {
        // No proper session management
        return "session_\(userId)_\(Date().timeIntervalSince1970)"
    }
    
    // AI-SUGGESTION: Directory traversal
    func readFileFromPath(_ path: String) -> String {
        // Potential directory traversal
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        let fullPath = "\(currentPath)/\(path)"
        
        return try! String(contentsOfFile: fullPath, encoding: .utf8)
    }
} 