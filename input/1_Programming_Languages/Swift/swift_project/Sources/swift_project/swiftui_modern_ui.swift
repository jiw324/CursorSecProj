// AI-SUGGESTION: This file demonstrates SwiftUI modern UI development
// including declarative UI, state management, animations, and navigation.
// Perfect for learning modern iOS app development with SwiftUI.

import SwiftUI
import Combine
import Foundation

// =============================================================================
// DATA MODELS AND STATE
// =============================================================================

// AI-SUGGESTION: Observable data model for SwiftUI state management
class TodoStore: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var filter: TodoFilter = .all
    @Published var searchText = ""
    
    var filteredTodos: [Todo] {
        let filtered = todos.filter { todo in
            switch filter {
            case .all: return true
            case .active: return !todo.isCompleted
            case .completed: return todo.isCompleted
            }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func addTodo(title: String, category: TodoCategory = .general) {
        let todo = Todo(title: title, category: category)
        todos.append(todo)
    }
    
    func toggleTodo(_ todo: Todo) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            todos[index].completedAt = todos[index].isCompleted ? Date() : nil
        }
    }
    
    func deleteTodo(_ todo: Todo) {
        todos.removeAll { $0.id == todo.id }
    }
    
    func updateTodo(_ todo: Todo) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
        }
    }
}

struct Todo: Identifiable, Codable {
    let id = UUID()
    var title: String
    var isCompleted = false
    var category: TodoCategory
    var priority: Priority = .medium
    var dueDate: Date?
    var createdAt = Date()
    var completedAt: Date?
    var notes: String = ""
    
    init(title: String, category: TodoCategory = .general) {
        self.title = title
        self.category = category
    }
}

enum TodoFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
}

enum TodoCategory: String, CaseIterable, Codable {
    case general = "general"
    case work = "work"
    case personal = "personal"
    case shopping = "shopping"
    case health = "health"
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .work: return .orange
        case .personal: return .purple
        case .shopping: return .green
        case .health: return .red
        }
    }
    
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

enum Priority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// =============================================================================
// MAIN APP VIEW
// =============================================================================

// AI-SUGGESTION: Main SwiftUI app structure
struct TodoApp: App {
    @StateObject private var todoStore = TodoStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(todoStore)
        }
    }
}

// AI-SUGGESTION: Root content view with navigation
struct ContentView: View {
    @EnvironmentObject var todoStore: TodoStore
    @State private var showingAddTodo = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodoListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Todos")
                }
                .tag(0)
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .sheet(isPresented: $showingAddTodo) {
            AddTodoView()
        }
    }
}

// =============================================================================
// TODO LIST VIEW
// =============================================================================

// AI-SUGGESTION: Main todo list with search and filtering
struct TodoListView: View {
    @EnvironmentObject var todoStore: TodoStore
    @State private var showingAddTodo = false
    @State private var selectedTodo: Todo?
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $todoStore.searchText)
                
                // Filter picker
                FilterPicker(selection: $todoStore.filter)
                
                // Todo list
                List {
                    ForEach(todoStore.filteredTodos) { todo in
                        TodoRowView(todo: todo)
                            .onTapGesture {
                                selectedTodo = todo
                            }
                            .contextMenu {
                                Button("Edit") {
                                    selectedTodo = todo
                                }
                                Button("Delete", role: .destructive) {
                                    withAnimation {
                                        todoStore.deleteTodo(todo)
                                    }
                                }
                            }
                    }
                    .onDelete(perform: deleteTodos)
                }
                .animation(.default, value: todoStore.filteredTodos)
            }
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTodo = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView()
            }
            .sheet(item: $selectedTodo) { todo in
                TodoDetailView(todo: todo)
            }
        }
    }
    
    private func deleteTodos(offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let todo = todoStore.filteredTodos[index]
                todoStore.deleteTodo(todo)
            }
        }
    }
}

// AI-SUGGESTION: Individual todo row with animations
struct TodoRowView: View {
    let todo: Todo
    @EnvironmentObject var todoStore: TodoStore
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            // Completion button
            Button {
                withAnimation(.spring()) {
                    todoStore.toggleTodo(todo)
                    isAnimating = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAnimating = false
                }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .gray)
                    .font(.title2)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(todo.title)
                        .font(.headline)
                        .strikethrough(todo.isCompleted)
                        .foregroundColor(todo.isCompleted ? .gray : .primary)
                    
                    Spacer()
                    
                    // Priority indicator
                    Circle()
                        .fill(todo.priority.color)
                        .frame(width: 12, height: 12)
                }
                
                HStack {
                    // Category
                    Label(todo.category.rawValue.capitalized, systemImage: todo.category.icon)
                        .font(.caption)
                        .foregroundColor(todo.category.color)
                    
                    Spacer()
                    
                    // Due date
                    if let dueDate = todo.dueDate {
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.3), value: todo.isCompleted)
    }
}

// =============================================================================
// SEARCH AND FILTER COMPONENTS
// =============================================================================

// AI-SUGGESTION: Custom search bar component
struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            TextField("Search todos...", text: $text)
                .padding(8)
                .padding(.horizontal, 32)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if isEditing && !text.isEmpty {
                            Button {
                                text = ""
                            } label: {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                .onTapGesture {
                    isEditing = true
                }
            
            if isEditing {
                Button("Cancel") {
                    isEditing = false
                    text = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .padding(.trailing, 10)
                .transition(.move(edge: .trailing))
                .animation(.default, value: isEditing)
            }
        }
        .padding(.horizontal)
    }
}

// AI-SUGGESTION: Filter picker with segmented control
struct FilterPicker: View {
    @Binding var selection: TodoFilter
    
    var body: some View {
        Picker("Filter", selection: $selection) {
            ForEach(TodoFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}

// =============================================================================
// ADD TODO VIEW
// =============================================================================

// AI-SUGGESTION: Modal view for adding new todos
struct AddTodoView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var todoStore: TodoStore
    
    @State private var title = ""
    @State private var category: TodoCategory = .general
    @State private var priority: Priority = .medium
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Todo Details")) {
                    TextField("Title", text: $title)
                    
                    Picker("Category", selection: $category) {
                        ForEach(TodoCategory.allCases, id: \.self) { category in
                            Label(category.rawValue.capitalized, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                }
                
                Section(header: Text("Optional")) {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Todo")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTodo()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveTodo() {
        var todo = Todo(title: title, category: category)
        todo.priority = priority
        todo.dueDate = hasDueDate ? dueDate : nil
        todo.notes = notes
        
        todoStore.addTodo(title: title, category: category)
        if let lastTodo = todoStore.todos.last {
            var updatedTodo = lastTodo
            updatedTodo.priority = priority
            updatedTodo.dueDate = hasDueDate ? dueDate : nil
            updatedTodo.notes = notes
            todoStore.updateTodo(updatedTodo)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

// =============================================================================
// TODO DETAIL VIEW
// =============================================================================

// AI-SUGGESTION: Detailed view for editing todos
struct TodoDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var todoStore: TodoStore
    
    @State private var todo: Todo
    @State private var isEditing = false
    
    init(todo: Todo) {
        _todo = State(initialValue: todo)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title section
                    VStack(alignment: .leading) {
                        Text("Title")
                            .font(.headline)
                        
                        if isEditing {
                            TextField("Title", text: $todo.title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(todo.title)
                                .font(.title2)
                        }
                    }
                    
                    // Status section
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Status")
                                .font(.headline)
                            Text(todo.isCompleted ? "Completed" : "Active")
                                .foregroundColor(todo.isCompleted ? .green : .blue)
                        }
                        
                        Spacer()
                        
                        Button {
                            todoStore.toggleTodo(todo)
                            todo.isCompleted.toggle()
                        } label: {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title)
                                .foregroundColor(todo.isCompleted ? .green : .gray)
                        }
                    }
                    
                    // Category and Priority
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Category")
                                .font(.headline)
                            Label(todo.category.rawValue.capitalized, systemImage: todo.category.icon)
                                .foregroundColor(todo.category.color)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Priority")
                                .font(.headline)
                            Text(todo.priority.rawValue)
                                .foregroundColor(todo.priority.color)
                        }
                    }
                    
                    // Dates
                    VStack(alignment: .leading) {
                        Text("Created")
                            .font(.headline)
                        Text(todo.createdAt, style: .date)
                            .foregroundColor(.secondary)
                        
                        if let dueDate = todo.dueDate {
                            Text("Due Date")
                                .font(.headline)
                                .padding(.top)
                            Text(dueDate, style: .date)
                                .foregroundColor(.orange)
                        }
                        
                        if let completedAt = todo.completedAt {
                            Text("Completed")
                                .font(.headline)
                                .padding(.top)
                            Text(completedAt, style: .date)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Notes
                    if !todo.notes.isEmpty || isEditing {
                        VStack(alignment: .leading) {
                            Text("Notes")
                                .font(.headline)
                            
                            if isEditing {
                                TextField("Notes", text: $todo.notes, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(3...10)
                            } else {
                                Text(todo.notes.isEmpty ? "No notes" : todo.notes)
                                    .foregroundColor(todo.notes.isEmpty ? .secondary : .primary)
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Todo Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            todoStore.updateTodo(todo)
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
    }
}

// =============================================================================
// STATISTICS VIEW
// =============================================================================

// AI-SUGGESTION: Statistics and analytics view
struct StatisticsView: View {
    @EnvironmentObject var todoStore: TodoStore
    
    var completionRate: Double {
        guard !todoStore.todos.isEmpty else { return 0 }
        let completed = todoStore.todos.filter { $0.isCompleted }.count
        return Double(completed) / Double(todoStore.todos.count)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Completion rate card
                    StatCard(
                        title: "Completion Rate",
                        value: "\(Int(completionRate * 100))%",
                        color: .green,
                        icon: "checkmark.circle"
                    )
                    
                    // Total todos
                    StatCard(
                        title: "Total Todos",
                        value: "\(todoStore.todos.count)",
                        color: .blue,
                        icon: "list.bullet"
                    )
                    
                    // Active todos
                    StatCard(
                        title: "Active Todos",
                        value: "\(todoStore.todos.filter { !$0.isCompleted }.count)",
                        color: .orange,
                        icon: "clock"
                    )
                    
                    // Category breakdown
                    CategoryBreakdownView()
                        .environmentObject(todoStore)
                }
                .padding()
            }
            .navigationTitle("Statistics")
        }
    }
}

// AI-SUGGESTION: Reusable statistics card component
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// AI-SUGGESTION: Category breakdown chart
struct CategoryBreakdownView: View {
    @EnvironmentObject var todoStore: TodoStore
    
    var categoryCounts: [TodoCategory: Int] {
        var counts: [TodoCategory: Int] = [:]
        for category in TodoCategory.allCases {
            counts[category] = todoStore.todos.filter { $0.category == category }.count
        }
        return counts
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Category Breakdown")
                .font(.headline)
                .padding(.bottom)
            
            ForEach(TodoCategory.allCases, id: \.self) { category in
                let count = categoryCounts[category] ?? 0
                let percentage = todoStore.todos.isEmpty ? 0.0 : Double(count) / Double(todoStore.todos.count)
                
                HStack {
                    Label(category.rawValue.capitalized, systemImage: category.icon)
                        .foregroundColor(category.color)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .fontWeight(.semibold)
                }
                
                ProgressView(value: percentage)
                    .accentColor(category.color)
                    .padding(.bottom, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// =============================================================================
// SETTINGS VIEW
// =============================================================================

// AI-SUGGESTION: App settings and preferences
struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var showCompletedTodos = true
    @State private var defaultCategory: TodoCategory = .general
    @State private var defaultPriority: Priority = .medium
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preferences")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Show Completed Todos", isOn: $showCompletedTodos)
                    
                    Picker("Default Category", selection: $defaultCategory) {
                        ForEach(TodoCategory.allCases, id: \.self) { category in
                            Label(category.rawValue.capitalized, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    Picker("Default Priority", selection: $defaultPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Rate App") {
                        // Rate app functionality
                    }
                    
                    Button("Contact Support") {
                        // Contact support functionality
                    }
                }
            }
            .navigationTitle("Settings")
        }
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
        print("  - Navigation and presentation")
        print("  - Custom components and modifiers")
        print("  - Animations and transitions")
        print("  - Form handling and validation")
        print("  - List management with CRUD operations")
        print("  - Search and filtering")
        print("  - Statistics and data visualization")
        print("=== Ready for iOS deployment ===")
    }
} 