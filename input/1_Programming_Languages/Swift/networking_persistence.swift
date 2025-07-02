// AI-SUGGESTION: This file demonstrates networking and data persistence
// including URLSession, JSON parsing, UserDefaults, and file management.
// Perfect for learning data handling in Swift applications.

import Foundation
import Combine

// =============================================================================
// NETWORKING SERVICE
// =============================================================================

// AI-SUGGESTION: Modern networking with async/await
class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let baseURL = "https://jsonplaceholder.typicode.com"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    func fetchData<T: Codable>(from endpoint: String, type: T.Type) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    func postData<T: Codable, U: Codable>(_ data: T, to endpoint: String, responseType: U.Type) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(data)
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(U.self, from: responseData)
    }
    
    func downloadImage(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .decodingError: return "Decoding error"
        case .noData: return "No data"
        }
    }
}

// =============================================================================
// DATA MODELS
// =============================================================================

// AI-SUGGESTION: Data models for API responses
struct Post: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let phone: String
    let website: String
    let address: Address
    let company: Company
}

struct Address: Codable {
    let street: String
    let suite: String
    let city: String
    let zipcode: String
    let geo: Geo
}

struct Geo: Codable {
    let lat: String
    let lng: String
}

struct Company: Codable {
    let name: String
    let catchPhrase: String
    let bs: String
}

struct Comment: Codable, Identifiable {
    let id: Int
    let postId: Int
    let name: String
    let email: String
    let body: String
}

// =============================================================================
// PERSISTENCE MANAGER
// =============================================================================

// AI-SUGGESTION: File-based persistence manager
class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let documentsDirectory: URL
    private let userDefaults = UserDefaults.standard
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                     in: .userDomainMask).first!
    }
    
    // MARK: - UserDefaults Operations
    func save<T: Codable>(_ object: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(object)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Failed to save to UserDefaults: \(error)")
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to load from UserDefaults: \(error)")
            return nil
        }
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    // MARK: - File System Operations
    func saveToFile<T: Codable>(_ object: T, fileName: String) throws {
        let url = documentsDirectory.appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(object)
        try data.write(to: url)
    }
    
    func loadFromFile<T: Codable>(_ type: T.Type, fileName: String) throws -> T {
        let url = documentsDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
    
    func deleteFile(fileName: String) throws {
        let url = documentsDirectory.appendingPathComponent(fileName)
        try FileManager.default.removeItem(at: url)
    }
    
    func fileExists(fileName: String) -> Bool {
        let url = documentsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // MARK: - Image Cache
    func saveImage(_ data: Data, fileName: String) throws {
        let url = documentsDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
    }
    
    func loadImage(fileName: String) -> Data? {
        let url = documentsDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }
    
    // MARK: - Directory Operations
    func createDirectory(name: String) throws {
        let url = documentsDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, 
                                              withIntermediateDirectories: true)
    }
    
    func listFiles(in directory: String = "") -> [String] {
        let url = directory.isEmpty ? documentsDirectory : 
                  documentsDirectory.appendingPathComponent(directory)
        
        do {
            return try FileManager.default.contentsOfDirectory(atPath: url.path)
        } catch {
            print("Failed to list files: \(error)")
            return []
        }
    }
}

// =============================================================================
// DATA SERVICE
// =============================================================================

// AI-SUGGESTION: Combined networking and persistence service
class DataService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var users: [User] = []
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    private let persistenceManager = PersistenceManager.shared
    
    // MARK: - Posts
    func fetchPosts(useCache: Bool = true) async {
        await setLoading(true)
        
        // Try to load from cache first
        if useCache, let cachedPosts: [Post] = persistenceManager.load([Post].self, forKey: "posts") {
            await MainActor.run {
                self.posts = cachedPosts
            }
        }
        
        do {
            let fetchedPosts = try await networkManager.fetchData(from: "/posts", type: [Post].self)
            
            await MainActor.run {
                self.posts = fetchedPosts
                self.errorMessage = nil
            }
            
            // Cache the results
            persistenceManager.save(fetchedPosts, forKey: "posts")
            
            // Also save to file
            try? persistenceManager.saveToFile(fetchedPosts, fileName: "posts.json")
            
        } catch {
            await setError(error.localizedDescription)
        }
        
        await setLoading(false)
    }
    
    func createPost(title: String, body: String, userId: Int) async {
        let newPost = Post(id: 0, userId: userId, title: title, body: body)
        
        do {
            let createdPost = try await networkManager.postData(newPost, 
                                                              to: "/posts", 
                                                              responseType: Post.self)
            
            await MainActor.run {
                self.posts.append(createdPost)
            }
            
            // Update cache
            persistenceManager.save(posts, forKey: "posts")
            
        } catch {
            await setError(error.localizedDescription)
        }
    }
    
    // MARK: - Users
    func fetchUsers() async {
        await setLoading(true)
        
        do {
            let fetchedUsers = try await networkManager.fetchData(from: "/users", type: [User].self)
            
            await MainActor.run {
                self.users = fetchedUsers
                self.errorMessage = nil
            }
            
            // Cache users
            persistenceManager.save(fetchedUsers, forKey: "users")
            
        } catch {
            // Try to load from cache
            if let cachedUsers: [User] = persistenceManager.load([User].self, forKey: "users") {
                await MainActor.run {
                    self.users = cachedUsers
                }
            }
            
            await setError(error.localizedDescription)
        }
        
        await setLoading(false)
    }
    
    // MARK: - Comments
    func fetchComments(for postId: Int) async {
        do {
            let fetchedComments = try await networkManager.fetchData(
                from: "/posts/\(postId)/comments", 
                type: [Comment].self
            )
            
            await MainActor.run {
                self.comments = fetchedComments
            }
            
        } catch {
            await setError(error.localizedDescription)
        }
    }
    
    // MARK: - Image Handling
    func downloadAndCacheImage(from urlString: String, fileName: String) async -> Data? {
        // Check cache first
        if let cachedData = persistenceManager.loadImage(fileName: fileName) {
            return cachedData
        }
        
        do {
            let imageData = try await networkManager.downloadImage(from: urlString)
            
            // Cache the image
            try? persistenceManager.saveImage(imageData, fileName: fileName)
            
            return imageData
        } catch {
            await setError(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Helper Methods
    @MainActor
    private func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
    }
    
    // MARK: - Cache Management
    func clearCache() {
        persistenceManager.remove(forKey: "posts")
        persistenceManager.remove(forKey: "users")
        
        // Clear file cache
        try? persistenceManager.deleteFile(fileName: "posts.json")
        
        // Clear image cache
        let files = persistenceManager.listFiles()
        for file in files where file.hasSuffix(".jpg") || file.hasSuffix(".png") {
            try? persistenceManager.deleteFile(fileName: file)
        }
    }
    
    func getCacheSize() -> String {
        var totalSize: Int64 = 0
        let files = persistenceManager.listFiles()
        
        for file in files {
            let url = persistenceManager.documentsDirectory.appendingPathComponent(file)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// =============================================================================
// OFFLINE QUEUE MANAGER
// =============================================================================

// AI-SUGGESTION: Queue for offline operations
class OfflineQueueManager {
    static let shared = OfflineQueueManager()
    
    private var operationQueue: [OfflineOperation] = []
    private let persistenceManager = PersistenceManager.shared
    private let queueKey = "offline_operations"
    
    private init() {
        loadQueue()
    }
    
    func addOperation(_ operation: OfflineOperation) {
        operationQueue.append(operation)
        saveQueue()
    }
    
    func processQueue() async {
        guard !operationQueue.isEmpty else { return }
        
        let networkManager = NetworkManager.shared
        var processedOperations: [OfflineOperation] = []
        
        for operation in operationQueue {
            do {
                switch operation.type {
                case .createPost:
                    if let postData = operation.data as? [String: Any],
                       let title = postData["title"] as? String,
                       let body = postData["body"] as? String,
                       let userId = postData["userId"] as? Int {
                        
                        let post = Post(id: 0, userId: userId, title: title, body: body)
                        _ = try await networkManager.postData(post, to: "/posts", responseType: Post.self)
                        processedOperations.append(operation)
                    }
                    
                case .updatePost:
                    // Handle update operations
                    processedOperations.append(operation)
                    
                case .deletePost:
                    // Handle delete operations
                    processedOperations.append(operation)
                }
            } catch {
                print("Failed to process operation: \(error)")
            }
        }
        
        // Remove processed operations
        operationQueue.removeAll { operation in
            processedOperations.contains { $0.id == operation.id }
        }
        
        saveQueue()
    }
    
    private func saveQueue() {
        persistenceManager.save(operationQueue, forKey: queueKey)
    }
    
    private func loadQueue() {
        operationQueue = persistenceManager.load([OfflineOperation].self, forKey: queueKey) ?? []
    }
}

struct OfflineOperation: Codable, Identifiable {
    let id = UUID()
    let type: OperationType
    let data: [String: Any]
    let timestamp: Date
    
    enum OperationType: String, Codable {
        case createPost
        case updatePost
        case deletePost
    }
    
    enum CodingKeys: CodingKey {
        case id, type, timestamp
    }
    
    init(type: OperationType, data: [String: Any]) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(OperationType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        data = [:] // Simplified for this example
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// =============================================================================
// EXAMPLE USAGE
// =============================================================================

class NetworkingPersistenceExamples {
    static func demonstrateFeatures() async {
        print("=== Networking and Persistence Examples ===")
        
        let dataService = DataService()
        
        // Fetch posts with caching
        await dataService.fetchPosts()
        print("Loaded \(dataService.posts.count) posts")
        
        // Fetch users
        await dataService.fetchUsers()
        print("Loaded \(dataService.users.count) users")
        
        // Create a new post
        await dataService.createPost(
            title: "New Post",
            body: "This is a new post content",
            userId: 1
        )
        
        // Download and cache an image
        let imageData = await dataService.downloadAndCacheImage(
            from: "https://via.placeholder.com/150",
            fileName: "placeholder.jpg"
        )
        
        if imageData != nil {
            print("Image downloaded and cached")
        }
        
        // Demonstrate persistence operations
        let persistence = PersistenceManager.shared
        
        // Save to UserDefaults
        let userPreferences = ["theme": "dark", "notifications": true] as [String : Any]
        persistence.save(userPreferences, forKey: "preferences")
        
        // Load from UserDefaults
        if let prefs: [String: Any] = persistence.load([String: Any].self, forKey: "preferences") {
            print("Loaded preferences: \(prefs)")
        }
        
        // File operations
        do {
            try persistence.saveToFile(dataService.posts, fileName: "posts_backup.json")
            let loadedPosts: [Post] = try persistence.loadFromFile([Post].self, fileName: "posts_backup.json")
            print("Saved and loaded \(loadedPosts.count) posts from file")
        } catch {
            print("File operation error: \(error)")
        }
        
        // Cache management
        let cacheSize = dataService.getCacheSize()
        print("Current cache size: \(cacheSize)")
        
        print("=== Examples Completed ===")
        print("Demonstrated:")
        print("  - Modern networking with async/await")
        print("  - JSON encoding/decoding")
        print("  - UserDefaults persistence")
        print("  - File system operations")
        print("  - Image caching")
        print("  - Offline operation queuing")
        print("  - Cache management")
    }
} 