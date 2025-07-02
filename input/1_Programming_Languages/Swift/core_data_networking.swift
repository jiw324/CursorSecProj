// AI-SUGGESTION: This file demonstrates Core Data persistence and networking
// including URLSession, JSON parsing, Core Data stack, and data synchronization.
// Perfect for learning data management in iOS apps.

import Foundation
import CoreData
import Combine

// =============================================================================
// NETWORKING LAYER
// =============================================================================

// AI-SUGGESTION: Modern networking service with async/await
class NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    private let baseURL = URL(string: "https://api.example.com/v1")!
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // Generic request method
    func request<T: Codable>(_ endpoint: APIEndpoint, 
                           responseType: T.Type) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers
        
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: data)
    }
    
    // Download file
    func downloadFile(from url: URL) async throws -> URL {
        let (localURL, _) = try await session.download(from: url)
        return localURL
    }
    
    // Upload data
    func upload<T: Codable>(data: Data, 
                           to endpoint: APIEndpoint,
                           responseType: T.Type) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = endpoint.headers
        
        let (responseData, response) = try await session.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.uploadFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: responseData)
    }
}

// AI-SUGGESTION: API endpoint configuration
struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let body: Codable?
    
    init(path: String, 
         method: HTTPMethod = .GET,
         headers: [String: String] = ["Content-Type": "application/json"],
         body: Codable? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError
    case serverError(Int)
    case uploadFailed
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .uploadFailed:
            return "Upload failed"
        case .downloadFailed:
            return "Download failed"
        }
    }
}

// =============================================================================
// DATA MODELS
// =============================================================================

// AI-SUGGESTION: Codable data models for API responses
struct User: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    let avatar: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, email, avatar
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Post: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let content: String
    let tags: [String]
    let isPublished: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, tags
        case userId = "user_id"
        case isPublished = "is_published"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Comment: Codable, Identifiable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, content
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

// =============================================================================
// CORE DATA STACK
// =============================================================================

// AI-SUGGESTION: Core Data stack manager
class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Save Context
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveBackground(_ context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Background save error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Fetch Operations
    func fetch<T: NSManagedObject>(_ type: T.Type,
                                 predicate: NSPredicate? = nil,
                                 sortDescriptors: [NSSortDescriptor]? = nil,
                                 limit: Int? = nil) throws -> [T] {
        
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        return try viewContext.fetch(request)
    }
    
    // MARK: - Delete Operations
    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        save()
    }
    
    func batchDelete<T: NSManagedObject>(_ type: T.Type, 
                                       predicate: NSPredicate? = nil) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: type))
        request.predicate = predicate
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        try viewContext.execute(batchDeleteRequest)
        save()
    }
}

// =============================================================================
// CORE DATA ENTITIES (MANUAL)
// =============================================================================

// AI-SUGGESTION: NSManagedObject subclasses
@objc(UserEntity)
class UserEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var email: String
    @NSManaged var avatar: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var posts: NSSet?
    
    convenience init(context: NSManagedObjectContext, user: User) {
        guard let entity = NSEntityDescription.entity(forEntityName: "UserEntity", 
                                                     in: context) else {
            fatalError("Failed to find UserEntity entity")
        }
        
        self.init(entity: entity, insertInto: context)
        
        self.id = user.id
        self.name = user.name
        self.email = user.email
        self.avatar = user.avatar
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }
    
    func toUser() -> User {
        return User(
            id: id,
            name: name,
            email: email,
            avatar: avatar,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@objc(PostEntity)
class PostEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var userId: UUID
    @NSManaged var title: String
    @NSManaged var content: String
    @NSManaged var tagsData: Data?
    @NSManaged var isPublished: Bool
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var user: UserEntity?
    @NSManaged var comments: NSSet?
    
    var tags: [String] {
        get {
            guard let data = tagsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            tagsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    convenience init(context: NSManagedObjectContext, post: Post) {
        guard let entity = NSEntityDescription.entity(forEntityName: "PostEntity", 
                                                     in: context) else {
            fatalError("Failed to find PostEntity entity")
        }
        
        self.init(entity: entity, insertInto: context)
        
        self.id = post.id
        self.userId = post.userId
        self.title = post.title
        self.content = post.content
        self.tags = post.tags
        self.isPublished = post.isPublished
        self.createdAt = post.createdAt
        self.updatedAt = post.updatedAt
    }
    
    func toPost() -> Post {
        return Post(
            id: id,
            userId: userId,
            title: title,
            content: content,
            tags: tags,
            isPublished: isPublished,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// =============================================================================
// DATA REPOSITORY
// =============================================================================

// AI-SUGGESTION: Repository pattern for data access
class DataRepository: ObservableObject {
    private let networkService = NetworkService.shared
    private let coreDataManager = CoreDataManager.shared
    
    @Published var users: [User] = []
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - User Operations
    func fetchUsers() async {
        await setLoading(true)
        
        do {
            // Try to fetch from network first
            let endpoint = APIEndpoint(path: "users")
            let networkUsers = try await networkService.request(endpoint, 
                                                               responseType: [User].self)
            
            await MainActor.run {
                self.users = networkUsers
                self.errorMessage = nil
            }
            
            // Save to Core Data in background
            await saveUsersToCore(networkUsers)
            
        } catch {
            // Fallback to Core Data
            await loadUsersFromCore()
            await setError(error.localizedDescription)
        }
        
        await setLoading(false)
    }
    
    func createUser(_ user: User) async {
        do {
            let endpoint = APIEndpoint(path: "users", method: .POST, body: user)
            let createdUser = try await networkService.request(endpoint, 
                                                             responseType: User.self)
            
            await MainActor.run {
                self.users.append(createdUser)
            }
            
            // Save to Core Data
            await saveUserToCore(createdUser)
            
        } catch {
            await setError(error.localizedDescription)
        }
    }
    
    func updateUser(_ user: User) async {
        do {
            let endpoint = APIEndpoint(path: "users/\(user.id)", method: .PUT, body: user)
            let updatedUser = try await networkService.request(endpoint, 
                                                             responseType: User.self)
            
            await MainActor.run {
                if let index = self.users.firstIndex(where: { $0.id == user.id }) {
                    self.users[index] = updatedUser
                }
            }
            
            // Update Core Data
            await updateUserInCore(updatedUser)
            
        } catch {
            await setError(error.localizedDescription)
        }
    }
    
    func deleteUser(_ user: User) async {
        do {
            let endpoint = APIEndpoint(path: "users/\(user.id)", method: .DELETE)
            let _: EmptyResponse = try await networkService.request(endpoint, 
                                                                  responseType: EmptyResponse.self)
            
            await MainActor.run {
                self.users.removeAll { $0.id == user.id }
            }
            
            // Delete from Core Data
            await deleteUserFromCore(user.id)
            
        } catch {
            await setError(error.localizedDescription)
        }
    }
    
    // MARK: - Post Operations
    func fetchPosts() async {
        await setLoading(true)
        
        do {
            let endpoint = APIEndpoint(path: "posts")
            let networkPosts = try await networkService.request(endpoint, 
                                                              responseType: [Post].self)
            
            await MainActor.run {
                self.posts = networkPosts
                self.errorMessage = nil
            }
            
            await savePostsToCore(networkPosts)
            
        } catch {
            await loadPostsFromCore()
            await setError(error.localizedDescription)
        }
        
        await setLoading(false)
    }
    
    func createPost(_ post: Post) async {
        do {
            let endpoint = APIEndpoint(path: "posts", method: .POST, body: post)
            let createdPost = try await networkService.request(endpoint, 
                                                             responseType: Post.self)
            
            await MainActor.run {
                self.posts.append(createdPost)
            }
            
            await savePostToCore(createdPost)
            
        } catch {
            await setError(error.localizedDescription)
        }
    }
    
    // MARK: - Core Data Operations
    private func saveUsersToCore(_ users: [User]) async {
        let context = coreDataManager.backgroundContext
        
        context.perform {
            // Clear existing users
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "UserEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                
                // Save new users
                for user in users {
                    _ = UserEntity(context: context, user: user)
                }
                
                self.coreDataManager.saveBackground(context)
            } catch {
                print("Core Data save error: \(error)")
            }
        }
    }
    
    private func saveUserToCore(_ user: User) async {
        let context = coreDataManager.backgroundContext
        
        context.perform {
            _ = UserEntity(context: context, user: user)
            self.coreDataManager.saveBackground(context)
        }
    }
    
    private func updateUserInCore(_ user: User) async {
        let context = coreDataManager.backgroundContext
        
        context.perform {
            let fetchRequest: NSFetchRequest<UserEntity> = NSFetchRequest(entityName: "UserEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
            
            do {
                let entities = try context.fetch(fetchRequest)
                if let entity = entities.first {
                    entity.name = user.name
                    entity.email = user.email
                    entity.avatar = user.avatar
                    entity.updatedAt = user.updatedAt
                    
                    self.coreDataManager.saveBackground(context)
                }
            } catch {
                print("Core Data update error: \(error)")
            }
        }
    }
    
    private func deleteUserFromCore(_ userId: UUID) async {
        let context = coreDataManager.backgroundContext
        
        context.perform {
            let fetchRequest: NSFetchRequest<UserEntity> = NSFetchRequest(entityName: "UserEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            
            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                
                self.coreDataManager.saveBackground(context)
            } catch {
                print("Core Data delete error: \(error)")
            }
        }
    }
    
    private func loadUsersFromCore() async {
        do {
            let userEntities: [UserEntity] = try coreDataManager.fetch(UserEntity.self)
            let users = userEntities.map { $0.toUser() }
            
            await MainActor.run {
                self.users = users
            }
        } catch {
            print("Core Data fetch error: \(error)")
        }
    }
    
    private func savePostsToCore(_ posts: [Post]) async {
        let context = coreDataManager.backgroundContext
        
        context.perform {
            // Save posts
            for post in posts {
                _ = PostEntity(context: context, post: post)
            }
            
            self.coreDataManager.saveBackground(context)
        }
    }
    
    private func savePostToCore(_ post: Post) async {
        let context = coreDataManager.backgroundContext
        
        context.perform {
            _ = PostEntity(context: context, post: post)
            self.coreDataManager.saveBackground(context)
        }
    }
    
    private func loadPostsFromCore() async {
        do {
            let postEntities: [PostEntity] = try coreDataManager.fetch(PostEntity.self)
            let posts = postEntities.map { $0.toPost() }
            
            await MainActor.run {
                self.posts = posts
            }
        } catch {
            print("Core Data fetch error: \(error)")
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
}

// AI-SUGGESTION: Empty response for delete operations
struct EmptyResponse: Codable {}

// =============================================================================
// EXAMPLE USAGE
// =============================================================================

class CoreDataNetworkingExamples {
    static func demonstrateFeatures() async {
        print("=== Core Data and Networking Examples ===")
        
        let repository = DataRepository()
        
        // Fetch users (network + Core Data fallback)
        await repository.fetchUsers()
        print("Loaded \(repository.users.count) users")
        
        // Create new user
        let newUser = User(
            id: UUID(),
            name: "John Doe",
            email: "john@example.com",
            avatar: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        await repository.createUser(newUser)
        print("Created user: \(newUser.name)")
        
        // Fetch posts
        await repository.fetchPosts()
        print("Loaded \(repository.posts.count) posts")
        
        // Demonstrate Core Data operations
        let coreDataManager = CoreDataManager.shared
        
        do {
            let users: [UserEntity] = try coreDataManager.fetch(UserEntity.self)
            print("Core Data users: \(users.count)")
            
            // Query with predicate
            let predicate = NSPredicate(format: "name CONTAINS[cd] %@", "john")
            let filteredUsers: [UserEntity] = try coreDataManager.fetch(
                UserEntity.self,
                predicate: predicate
            )
            print("Filtered users: \(filteredUsers.count)")
            
        } catch {
            print("Core Data error: \(error)")
        }
        
        print("=== Examples Completed ===")
        print("Demonstrated:")
        print("  - Modern networking with async/await")
        print("  - Core Data stack management")
        print("  - Repository pattern")
        print("  - Network + local data synchronization")
        print("  - Error handling and fallbacks")
        print("  - Background context operations")
    }
} 