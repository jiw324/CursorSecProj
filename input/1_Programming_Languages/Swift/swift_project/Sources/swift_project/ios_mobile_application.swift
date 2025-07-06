// AI-SUGGESTION: This file demonstrates iOS mobile application development in Swift
// including UIKit, MVC architecture, Core Data, networking, and common iOS patterns.
// Perfect for learning mobile app development with modern Swift practices.

import UIKit
import Foundation
import CoreData
import UserNotifications
import MapKit
import AVFoundation

// =============================================================================
// DOMAIN MODELS AND DATA STRUCTURES
// =============================================================================

// AI-SUGGESTION: Swift structs for value types and data models
struct User: Codable, Equatable {
    let id: UUID
    var name: String
    var email: String
    var avatar: String?
    var createdAt: Date
    var preferences: UserPreferences
    
    init(name: String, email: String) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.createdAt = Date()
        self.preferences = UserPreferences()
    }
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool = true
    var theme: AppTheme = .light
    var language: String = "en"
    var autoSync: Bool = true
}

enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

struct Task: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String?
    var isCompleted: Bool
    var priority: TaskPriority
    var dueDate: Date?
    var category: TaskCategory
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, description: String? = nil, priority: TaskPriority = .medium, category: TaskCategory = .general) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.isCompleted = false
        self.priority = priority
        self.category = category
        self.dueDate = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func markCompleted() {
        isCompleted = true
        updatedAt = Date()
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var color: UIColor {
        switch self {
        case .low: return .systemGreen
        case .medium: return .systemBlue
        case .high: return .systemOrange
        case .urgent: return .systemRed
        }
    }
}

enum TaskCategory: String, CaseIterable, Codable {
    case general = "general"
    case work = "work"
    case personal = "personal"
    case shopping = "shopping"
    case health = "health"
    
    var icon: String {
        switch self {
        case .general: return "list.bullet"
        case .work: return "briefcase"
        case .personal: return "person"
        case .shopping: return "cart"
        case .health: return "heart"
        }
    }
}

// =============================================================================
// CORE DATA STACK AND PERSISTENCE
// =============================================================================

// AI-SUGGESTION: Core Data stack for local persistence
class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TaskApp")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Save error: \(error)")
        }
    }
    
    func fetch<T: NSManagedObject>(_ type: T.Type) -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
}

// =============================================================================
// NETWORKING AND API SERVICES
// =============================================================================

// AI-SUGGESTION: Modern networking with async/await and protocols
protocol NetworkServiceProtocol {
    func fetchTasks() async throws -> [Task]
    func createTask(_ task: Task) async throws -> Task
    func updateTask(_ task: Task) async throws -> Task
    func deleteTask(id: UUID) async throws
}

class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    
    private let baseURL = URL(string: "https://api.taskapp.com/v1")!
    private let session = URLSession.shared
    
    private init() {}
    
    func fetchTasks() async throws -> [Task] {
        let url = baseURL.appendingPathComponent("tasks")
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode([Task].self, from: data)
    }
    
    func createTask(_ task: Task) async throws -> Task {
        let url = baseURL.appendingPathComponent("tasks")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(task)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode(Task.self, from: data)
    }
    
    func updateTask(_ task: Task) async throws -> Task {
        let url = baseURL.appendingPathComponent("tasks/\(task.id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(task)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode(Task.self, from: data)
    }
    
    func deleteTask(id: UUID) async throws {
        let url = baseURL.appendingPathComponent("tasks/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw NetworkError.invalidResponse
        }
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError:
            return "Failed to decode response"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// =============================================================================
// DATA MANAGER AND BUSINESS LOGIC
// =============================================================================

// AI-SUGGESTION: Centralized data management with local and remote sync
class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkService: NetworkServiceProtocol
    private let coreDataStack = CoreDataStack.shared
    
    init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
        loadLocalTasks()
    }
    
    func loadLocalTasks() {
        // Load from Core Data (simplified)
        tasks = []
    }
    
    func refreshTasks() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let remoteTasks = try await networkService.fetchTasks()
            await MainActor.run {
                self.tasks = remoteTasks
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func addTask(_ task: Task) async {
        do {
            let createdTask = try await networkService.createTask(task)
            await MainActor.run {
                self.tasks.append(createdTask)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func updateTask(_ task: Task) async {
        do {
            let updatedTask = try await networkService.updateTask(task)
            await MainActor.run {
                if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[index] = updatedTask
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func deleteTask(_ task: Task) async {
        do {
            try await networkService.deleteTask(id: task.id)
            await MainActor.run {
                self.tasks.removeAll { $0.id == task.id }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func toggleTaskCompletion(_ task: Task) async {
        var updatedTask = task
        updatedTask.markCompleted()
        await updateTask(updatedTask)
    }
}

// =============================================================================
// VIEW CONTROLLERS AND UI
// =============================================================================

// AI-SUGGESTION: Main task list view controller with modern UIKit patterns
class TaskListViewController: UIViewController {
    
    private let taskManager = TaskManager.shared
    private var tableView: UITableView!
    private var refreshControl: UIRefreshControl!
    private var addButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupTableView()
        bindTaskManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshTasks()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Tasks"
    }
    
    private func setupNavigationBar() {
        addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTaskTapped)
        )
        navigationItem.rightBarButtonItem = addButton
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        navigationItem.leftBarButtonItem = settingsButton
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TaskTableViewCell.self, forCellReuseIdentifier: TaskTableViewCell.identifier)
        
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshTasks), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func bindTaskManager() {
        // In a real app, you'd use Combine or similar for reactive binding
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tasksDidUpdate),
            name: NSNotification.Name("TasksDidUpdate"),
            object: nil
        )
    }
    
    @objc private func tasksDidUpdate() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc private func refreshTasks() {
        Task {
            await taskManager.refreshTasks()
        }
    }
    
    @objc private func addTaskTapped() {
        let addTaskVC = AddTaskViewController()
        let navController = UINavigationController(rootViewController: addTaskVC)
        present(navController, animated: true)
    }
    
    @objc private func settingsTapped() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
}

// AI-SUGGESTION: UITableView delegate and data source implementation
extension TaskListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return taskManager.tasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TaskTableViewCell.identifier, for: indexPath) as! TaskTableViewCell
        let task = taskManager.tasks[indexPath.row]
        cell.configure(with: task)
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let task = taskManager.tasks[indexPath.row]
        let detailVC = TaskDetailViewController(task: task)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let task = taskManager.tasks[indexPath.row]
            Task {
                await taskManager.deleteTask(task)
            }
        }
    }
}

// =============================================================================
// CUSTOM TABLE VIEW CELL
// =============================================================================

// AI-SUGGESTION: Custom cell with modern Auto Layout and delegation
protocol TaskTableViewCellDelegate: AnyObject {
    func taskCellDidToggleCompletion(_ cell: TaskTableViewCell, task: Task)
}

class TaskTableViewCell: UITableViewCell {
    static let identifier = "TaskTableViewCell"
    
    weak var delegate: TaskTableViewCellDelegate?
    private var task: Task?
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let priorityView = UIView()
    private let categoryIconView = UIImageView()
    private let completionButton = UIButton(type: .system)
    private let dueDateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Title label
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.numberOfLines = 1
        
        // Description label
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 2
        
        // Priority view
        priorityView.layer.cornerRadius = 4
        
        // Category icon
        categoryIconView.tintColor = .systemBlue
        categoryIconView.contentMode = .scaleAspectFit
        
        // Completion button
        completionButton.setImage(UIImage(systemName: "circle"), for: .normal)
        completionButton.addTarget(self, action: #selector(completionButtonTapped), for: .touchUpInside)
        
        // Due date label
        dueDateLabel.font = .caption1
        dueDateLabel.textColor = .systemOrange
        
        // Add subviews
        [titleLabel, descriptionLabel, priorityView, categoryIconView, completionButton, dueDateLabel].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Completion button
            completionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            completionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            completionButton.widthAnchor.constraint(equalToConstant: 24),
            completionButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Category icon
            categoryIconView.leadingAnchor.constraint(equalTo: completionButton.trailingAnchor, constant: 12),
            categoryIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            categoryIconView.widthAnchor.constraint(equalToConstant: 20),
            categoryIconView.heightAnchor.constraint(equalToConstant: 20),
            
            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: categoryIconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: priorityView.leadingAnchor, constant: -8),
            
            // Description label
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // Due date label
            dueDateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dueDateLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 4),
            dueDateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            dueDateLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            
            // Priority view
            priorityView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            priorityView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priorityView.widthAnchor.constraint(equalToConstant: 8),
            priorityView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(with task: Task) {
        self.task = task
        
        titleLabel.text = task.title
        descriptionLabel.text = task.description
        categoryIconView.image = UIImage(systemName: task.category.icon)
        priorityView.backgroundColor = task.priority.color
        
        let completionImage = task.isCompleted ? "checkmark.circle.fill" : "circle"
        completionButton.setImage(UIImage(systemName: completionImage), for: .normal)
        completionButton.tintColor = task.isCompleted ? .systemGreen : .systemGray
        
        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            dueDateLabel.text = "Due: \(formatter.string(from: dueDate))"
            dueDateLabel.isHidden = false
        } else {
            dueDateLabel.isHidden = true
        }
        
        // Apply strikethrough for completed tasks
        if task.isCompleted {
            let attributedText = NSAttributedString(
                string: task.title,
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
            titleLabel.attributedText = attributedText
        } else {
            titleLabel.attributedText = nil
            titleLabel.text = task.title
        }
    }
    
    @objc private func completionButtonTapped() {
        guard let task = task else { return }
        delegate?.taskCellDidToggleCompletion(self, task: task)
    }
}

// Implement delegate method
extension TaskListViewController: TaskTableViewCellDelegate {
    func taskCellDidToggleCompletion(_ cell: TaskTableViewCell, task: Task) {
        Task {
            await taskManager.toggleTaskCompletion(task)
        }
    }
}

// =============================================================================
// ADDITIONAL VIEW CONTROLLERS (STUBS)
// =============================================================================

// AI-SUGGESTION: Additional view controllers for complete app structure
class AddTaskViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Add Task"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        // Save task logic
        dismiss(animated: true)
    }
}

class TaskDetailViewController: UIViewController {
    private let task: Task
    
    init(task: Task) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = task.title
    }
}

class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Settings"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}

// =============================================================================
// APP DELEGATE AND SCENE DELEGATE
// =============================================================================

// AI-SUGGESTION: Modern app lifecycle with SceneDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure app-level settings
        requestNotificationPermissions()
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        let taskListVC = TaskListViewController()
        let navController = UINavigationController(rootViewController: taskListVC)
        
        window?.rootViewController = navController
        window?.makeKeyAndVisible()
    }
}

// =============================================================================
// EXAMPLE USAGE AND TESTING
// =============================================================================

class IOSMobileExampleRunner {
    static func demonstrateFeatures() {
        print("=== iOS Mobile Application Example ===")
        print("This application demonstrates:")
        print("  - Modern UIKit with programmatic UI")
        print("  - MVC architecture patterns")
        print("  - Core Data persistence stack")
        print("  - Async/await networking")
        print("  - Custom table view cells")
        print("  - Navigation and presentation")
        print("  - Protocol-oriented programming")
        print("  - Modern Swift concurrency")
        print("=== Ready for iOS deployment ===")
    }
} 