// AI-Generated Code Header
// **Intent:** WPF application with MVVM pattern and modern UI features
// **Optimization:** Efficient data binding and UI responsiveness
// **Safety:** Input validation and proper event handling

using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Input;
using System.Threading.Tasks;
using System.Windows.Controls;

namespace WpfApplication
{
    // AI-SUGGESTION: Data models
    public class Task : INotifyPropertyChanged
    {
        private string _title = string.Empty;
        private string _description = string.Empty;
        private bool _isCompleted;
        private TaskPriority _priority;
        private DateTime _dueDate = DateTime.Today.AddDays(1);

        public int Id { get; set; }
        
        public string Title
        {
            get => _title;
            set { _title = value; OnPropertyChanged(); }
        }
        
        public string Description
        {
            get => _description;
            set { _description = value; OnPropertyChanged(); }
        }
        
        public bool IsCompleted
        {
            get => _isCompleted;
            set { _isCompleted = value; OnPropertyChanged(); OnPropertyChanged(nameof(Status)); }
        }
        
        public TaskPriority Priority
        {
            get => _priority;
            set { _priority = value; OnPropertyChanged(); }
        }
        
        public DateTime DueDate
        {
            get => _dueDate;
            set { _dueDate = value; OnPropertyChanged(); OnPropertyChanged(nameof(IsOverdue)); }
        }

        public string Status => IsCompleted ? "Completed" : "Pending";
        public bool IsOverdue => !IsCompleted && DueDate < DateTime.Today;
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public event PropertyChangedEventHandler? PropertyChanged;
        
        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public enum TaskPriority { Low, Normal, High, Critical }

    // AI-SUGGESTION: MVVM Command implementation
    public class RelayCommand : ICommand
    {
        private readonly Action<object?> _execute;
        private readonly Predicate<object?>? _canExecute;

        public RelayCommand(Action<object?> execute, Predicate<object?>? canExecute = null)
        {
            _execute = execute ?? throw new ArgumentNullException(nameof(execute));
            _canExecute = canExecute;
        }

        public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;

        public void Execute(object? parameter) => _execute(parameter);

        public event EventHandler? CanExecuteChanged
        {
            add { CommandManager.RequerySuggested += value; }
            remove { CommandManager.RequerySuggested -= value; }
        }
    }

    // AI-SUGGESTION: Main ViewModel
    public class MainViewModel : INotifyPropertyChanged
    {
        private Task? _selectedTask;
        private string _newTaskTitle = string.Empty;
        private string _newTaskDescription = string.Empty;
        private TaskPriority _newTaskPriority = TaskPriority.Normal;
        private DateTime _newTaskDueDate = DateTime.Today.AddDays(1);
        private string _searchText = string.Empty;
        private TaskPriority? _filterPriority;
        private bool _showCompletedTasks = true;

        public ObservableCollection<Task> Tasks { get; } = new();
        public ObservableCollection<Task> FilteredTasks { get; } = new();

        public Task? SelectedTask
        {
            get => _selectedTask;
            set { _selectedTask = value; OnPropertyChanged(); }
        }

        public string NewTaskTitle
        {
            get => _newTaskTitle;
            set { _newTaskTitle = value; OnPropertyChanged(); }
        }

        public string NewTaskDescription
        {
            get => _newTaskDescription;
            set { _newTaskDescription = value; OnPropertyChanged(); }
        }

        public TaskPriority NewTaskPriority
        {
            get => _newTaskPriority;
            set { _newTaskPriority = value; OnPropertyChanged(); }
        }

        public DateTime NewTaskDueDate
        {
            get => _newTaskDueDate;
            set { _newTaskDueDate = value; OnPropertyChanged(); }
        }

        public string SearchText
        {
            get => _searchText;
            set { _searchText = value; OnPropertyChanged(); ApplyFilters(); }
        }

        public TaskPriority? FilterPriority
        {
            get => _filterPriority;
            set { _filterPriority = value; OnPropertyChanged(); ApplyFilters(); }
        }

        public bool ShowCompletedTasks
        {
            get => _showCompletedTasks;
            set { _showCompletedTasks = value; OnPropertyChanged(); ApplyFilters(); }
        }

        // AI-SUGGESTION: Commands
        public ICommand AddTaskCommand { get; }
        public ICommand DeleteTaskCommand { get; }
        public ICommand ToggleTaskCommand { get; }
        public ICommand ClearCompletedCommand { get; }
        public ICommand ClearFiltersCommand { get; }

        // AI-SUGGESTION: Statistics
        public int TotalTasks => Tasks.Count;
        public int CompletedTasks => Tasks.Count(t => t.IsCompleted);
        public int PendingTasks => Tasks.Count(t => !t.IsCompleted);
        public int OverdueTasks => Tasks.Count(t => t.IsOverdue);

        public MainViewModel()
        {
            AddTaskCommand = new RelayCommand(AddTask, CanAddTask);
            DeleteTaskCommand = new RelayCommand(DeleteTask, CanDeleteTask);
            ToggleTaskCommand = new RelayCommand(ToggleTask, CanToggleTask);
            ClearCompletedCommand = new RelayCommand(ClearCompleted, CanClearCompleted);
            ClearFiltersCommand = new RelayCommand(ClearFilters);

            // AI-SUGGESTION: Add sample data
            LoadSampleData();
            ApplyFilters();
        }

        private void AddTask(object? parameter)
        {
            if (string.IsNullOrWhiteSpace(NewTaskTitle)) return;

            var task = new Task
            {
                Id = Tasks.Count + 1,
                Title = NewTaskTitle,
                Description = NewTaskDescription,
                Priority = NewTaskPriority,
                DueDate = NewTaskDueDate
            };

            Tasks.Add(task);
            
            // AI-SUGGESTION: Clear form
            NewTaskTitle = string.Empty;
            NewTaskDescription = string.Empty;
            NewTaskPriority = TaskPriority.Normal;
            NewTaskDueDate = DateTime.Today.AddDays(1);

            ApplyFilters();
            UpdateStatistics();
        }

        private bool CanAddTask(object? parameter) => !string.IsNullOrWhiteSpace(NewTaskTitle);

        private void DeleteTask(object? parameter)
        {
            if (SelectedTask != null)
            {
                Tasks.Remove(SelectedTask);
                ApplyFilters();
                UpdateStatistics();
            }
        }

        private bool CanDeleteTask(object? parameter) => SelectedTask != null;

        private void ToggleTask(object? parameter)
        {
            if (parameter is Task task)
            {
                task.IsCompleted = !task.IsCompleted;
                ApplyFilters();
                UpdateStatistics();
            }
        }

        private bool CanToggleTask(object? parameter) => parameter is Task;

        private void ClearCompleted(object? parameter)
        {
            var completedTasks = Tasks.Where(t => t.IsCompleted).ToList();
            foreach (var task in completedTasks)
            {
                Tasks.Remove(task);
            }
            ApplyFilters();
            UpdateStatistics();
        }

        private bool CanClearCompleted(object? parameter) => Tasks.Any(t => t.IsCompleted);

        private void ClearFilters(object? parameter)
        {
            SearchText = string.Empty;
            FilterPriority = null;
            ShowCompletedTasks = true;
        }

        private void ApplyFilters()
        {
            FilteredTasks.Clear();
            
            var filtered = Tasks.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(SearchText))
            {
                filtered = filtered.Where(t => 
                    t.Title.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                    t.Description.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
            }

            if (FilterPriority.HasValue)
            {
                filtered = filtered.Where(t => t.Priority == FilterPriority.Value);
            }

            if (!ShowCompletedTasks)
            {
                filtered = filtered.Where(t => !t.IsCompleted);
            }

            foreach (var task in filtered.OrderBy(t => t.IsCompleted).ThenBy(t => t.DueDate))
            {
                FilteredTasks.Add(task);
            }
        }

        private void UpdateStatistics()
        {
            OnPropertyChanged(nameof(TotalTasks));
            OnPropertyChanged(nameof(CompletedTasks));
            OnPropertyChanged(nameof(PendingTasks));
            OnPropertyChanged(nameof(OverdueTasks));
        }

        private void LoadSampleData()
        {
            var sampleTasks = new[]
            {
                new Task { Id = 1, Title = "Complete project proposal", Description = "Finish the Q4 project proposal document", Priority = TaskPriority.High, DueDate = DateTime.Today.AddDays(2) },
                new Task { Id = 2, Title = "Review code changes", Description = "Review pull requests from team members", Priority = TaskPriority.Normal, DueDate = DateTime.Today.AddDays(1) },
                new Task { Id = 3, Title = "Update documentation", Description = "Update API documentation", Priority = TaskPriority.Low, DueDate = DateTime.Today.AddDays(5) },
                new Task { Id = 4, Title = "Team meeting", Description = "Weekly team standup meeting", Priority = TaskPriority.Normal, DueDate = DateTime.Today, IsCompleted = true },
                new Task { Id = 5, Title = "Bug fixes", Description = "Fix critical bugs reported by QA", Priority = TaskPriority.Critical, DueDate = DateTime.Today.AddDays(-1) }
            };

            foreach (var task in sampleTasks)
            {
                Tasks.Add(task);
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        
        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    // AI-SUGGESTION: Value converters
    public class PriorityToBrushConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is TaskPriority priority)
            {
                return priority switch
                {
                    TaskPriority.Critical => new SolidColorBrush(Colors.Red),
                    TaskPriority.High => new SolidColorBrush(Colors.Orange),
                    TaskPriority.Normal => new SolidColorBrush(Colors.Blue),
                    TaskPriority.Low => new SolidColorBrush(Colors.Gray),
                    _ => new SolidColorBrush(Colors.Black)
                };
            }
            return new SolidColorBrush(Colors.Black);
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }

    // AI-SUGGESTION: Main Window
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            DataContext = new MainViewModel();
        }
    }

    // AI-SUGGESTION: Application entry point
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            
            var mainWindow = new MainWindow();
            mainWindow.Show();
        }
    }
}

// AI-SUGGESTION: Program entry point for console testing
class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        Console.WriteLine("C# WPF Application with MVVM Pattern");
        Console.WriteLine("====================================");
        
        try
        {
            var app = new WpfApplication.App();
            
            // AI-SUGGESTION: Demo without UI for console testing
            var viewModel = new WpfApplication.MainViewModel();
            
            Console.WriteLine($"Sample Task Manager Application");
            Console.WriteLine($"Total Tasks: {viewModel.TotalTasks}");
            Console.WriteLine($"Completed: {viewModel.CompletedTasks}");
            Console.WriteLine($"Pending: {viewModel.PendingTasks}");
            Console.WriteLine($"Overdue: {viewModel.OverdueTasks}");
            
            Console.WriteLine("\nTasks:");
            foreach (var task in viewModel.Tasks.Take(5))
            {
                Console.WriteLine($"- {task.Title} ({task.Priority}) - {task.Status}");
            }
            
            // AI-SUGGESTION: Test adding a task
            viewModel.NewTaskTitle = "Test Task";
            viewModel.NewTaskDescription = "This is a test task";
            viewModel.AddTaskCommand.Execute(null);
            
            Console.WriteLine($"\nAfter adding task: {viewModel.TotalTasks} total tasks");
            
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
        
        Console.WriteLine("\n=== WPF Application Demo Complete ===");
    }
} 