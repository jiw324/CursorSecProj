// AI-SUGGESTION: This file demonstrates SwiftUI modern UI development
// including declarative UI, state management, animations, and navigation.
// Perfect for learning iOS app development with SwiftUI.

import SwiftUI
import Combine

// =============================================================================
// DATA MODELS
// =============================================================================

// AI-SUGGESTION: Observable data model for SwiftUI
class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var filter: TaskFilter = .all
    
    var filteredTasks: [Task] {
        switch filter {
        case .all: return tasks
        case .active: return tasks.filter { !$0.isCompleted }
        case .completed: return tasks.filter { $0.isCompleted }
        }
    }
    
    func addTask(title: String) {
        let task = Task(title: title)
        tasks.append(task)
    }
    
    func toggleTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
        }
    }
    
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
    }
}

struct Task: Identifiable, Codable {
    let id = UUID()
    var title: String
    var isCompleted = false
    var category: TaskCategory = .general
    var createdAt = Date()
    
    init(title: String) {
        self.title = title
    }
}

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case active = "Active" 
    case completed = "Completed"
}

enum TaskCategory: String, CaseIterable, Codable {
    case general = "General"
    case work = "Work"
    case personal = "Personal"
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .work: return .orange
        case .personal: return .purple
        }
    }
}

// =============================================================================
// MAIN APP
// =============================================================================

// AI-SUGGESTION: SwiftUI App structure
struct TaskApp: App {
    @StateObject private var taskStore = TaskStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taskStore)
        }
    }
}

// =============================================================================
// CONTENT VIEW
// =============================================================================

// AI-SUGGESTION: Main content view with navigation
struct ContentView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var showingAddTask = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter picker
                Picker("Filter", selection: $taskStore.filter) {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Task list
                List {
                    ForEach(taskStore.filteredTasks) { task in
                        TaskRowView(task: task)
                    }
                    .onDelete(perform: deleteTasks)
                }
                .animation(.default, value: taskStore.filteredTasks)
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
            }
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let task = taskStore.filteredTasks[index]
                taskStore.deleteTask(task)
            }
        }
    }
}

// =============================================================================
// TASK ROW VIEW
// =============================================================================

// AI-SUGGESTION: Individual task row with animations
struct TaskRowView: View {
    let task: Task
    @EnvironmentObject var taskStore: TaskStore
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            Button {
                withAnimation(.spring()) {
                    taskStore.toggleTask(task)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            
            VStack(alignment: .leading) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                
                HStack {
                    Text(task.category.rawValue)
                        .font(.caption)
                        .padding(4)
                        .background(task.category.color.opacity(0.2))
                        .foregroundColor(task.category.color)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(task.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0) { isPressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = isPressing
            }
        } perform: {}
    }
}

// =============================================================================
// ADD TASK VIEW
// =============================================================================

// AI-SUGGESTION: Modal view for adding tasks
struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var taskStore: TaskStore
    @State private var title = ""
    @State private var category: TaskCategory = .general
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task title", text: $title)
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var task = Task(title: title)
                        task.category = category
                        taskStore.tasks.append(task)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// =============================================================================
// CUSTOM COMPONENTS
// =============================================================================

// AI-SUGGESTION: Custom button component with animations
struct AnimatedButton: View {
    let title: String
    let action: () -> Void
    let color: Color
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(color)
                .cornerRadius(10)
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0) { isPressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = isPressing
            }
        } perform: {}
    }
}

// AI-SUGGESTION: Custom progress view
struct TaskProgressView: View {
    @EnvironmentObject var taskStore: TaskStore
    
    var progress: Double {
        guard !taskStore.tasks.isEmpty else { return 0 }
        let completed = taskStore.tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(taskStore.tasks.count)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .animation(.easeInOut, value: progress)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// AI-SUGGESTION: Statistics card component
struct StatsCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// =============================================================================
// STATISTICS VIEW
// =============================================================================

// AI-SUGGESTION: Statistics and analytics view
struct StatisticsView: View {
    @EnvironmentObject var taskStore: TaskStore
    
    var completedTasks: Int {
        taskStore.tasks.filter { $0.isCompleted }.count
    }
    
    var activeTasks: Int {
        taskStore.tasks.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                TaskProgressView()
                
                HStack(spacing: 16) {
                    StatsCardView(
                        title: "Total",
                        value: "\(taskStore.tasks.count)",
                        icon: "list.bullet",
                        color: .blue
                    )
                    
                    StatsCardView(
                        title: "Completed",
                        value: "\(completedTasks)",
                        icon: "checkmark.circle",
                        color: .green
                    )
                    
                    StatsCardView(
                        title: "Active",
                        value: "\(activeTasks)",
                        icon: "clock",
                        color: .orange
                    )
                }
                
                // Category breakdown
                VStack(alignment: .leading) {
                    Text("Categories")
                        .font(.headline)
                        .padding(.bottom)
                    
                    ForEach(TaskCategory.allCases, id: \.self) { category in
                        let count = taskStore.tasks.filter { $0.category == category }.count
                        
                        HStack {
                            Text(category.rawValue)
                            Spacer()
                            Text("\(count)")
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Statistics")
    }
}

// =============================================================================
// TAB VIEW STRUCTURE
// =============================================================================

// AI-SUGGESTION: Tab-based navigation structure
struct MainTabView: View {
    @StateObject private var taskStore = TaskStore()
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Tasks")
                }
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
        }
        .environmentObject(taskStore)
    }
}

// =============================================================================
// EXAMPLE USAGE
// =============================================================================

class SwiftUIExamples {
    static func demonstrateFeatures() {
        print("=== SwiftUI Modern UI Examples ===")
        print("This SwiftUI app demonstrates:")
        print("  - Declarative UI with SwiftUI")
        print("  - @StateObject and @EnvironmentObject")
        print("  - Navigation and modal presentation")
        print("  - Custom components and modifiers")
        print("  - Animations and transitions")
        print("  - Form handling and validation")
        print("  - List management with CRUD operations")
        print("  - Tab-based navigation")
        print("  - Progress tracking and statistics")
        print("=== Ready for iOS deployment ===")
    }
} 