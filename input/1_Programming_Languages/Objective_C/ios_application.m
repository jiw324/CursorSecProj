// AI-Generated Code Header
// **Intent:** Demonstrate iOS application development with Objective-C and UIKit
// **Optimization:** Efficient view lifecycle management, memory optimization, and UI performance
// **Safety:** ARC memory management, proper delegate patterns, and exception handling

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// AI-SUGGESTION: Forward declarations for clean header organization
@class TaskListViewController;
@class TaskDetailViewController;
@class Task;

#pragma mark - Task Model

// AI-SUGGESTION: Model object following Objective-C conventions
@interface Task : NSObject <NSCoding, NSCopying>

@property (nonatomic, strong) NSString *taskId;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *taskDescription;
@property (nonatomic, assign) BOOL isCompleted;
@property (nonatomic, strong) NSDate *createdDate;
@property (nonatomic, strong) NSDate *dueDate;
@property (nonatomic, assign) NSInteger priority; // 1=Low, 2=Medium, 3=High

- (instancetype)initWithTitle:(NSString *)title description:(NSString *)description;
- (instancetype)initWithTitle:(NSString *)title description:(NSString *)description dueDate:(NSDate *)dueDate;
- (NSString *)formattedDueDate;
- (UIColor *)priorityColor;
- (NSString *)priorityString;

@end

@implementation Task

- (instancetype)initWithTitle:(NSString *)title description:(NSString *)description {
    return [self initWithTitle:title description:description dueDate:nil];
}

- (instancetype)initWithTitle:(NSString *)title description:(NSString *)description dueDate:(NSDate *)dueDate {
    self = [super init];
    if (self) {
        _taskId = [[NSUUID UUID] UUIDString];
        _title = [title copy];
        _taskDescription = [description copy];
        _dueDate = dueDate;
        _createdDate = [NSDate date];
        _isCompleted = NO;
        _priority = 2; // Default to medium priority
    }
    return self;
}

// AI-SUGGESTION: NSCoding implementation for persistence
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.taskId forKey:@"taskId"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.taskDescription forKey:@"taskDescription"];
    [coder encodeBool:self.isCompleted forKey:@"isCompleted"];
    [coder encodeObject:self.createdDate forKey:@"createdDate"];
    [coder encodeObject:self.dueDate forKey:@"dueDate"];
    [coder encodeInteger:self.priority forKey:@"priority"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _taskId = [coder decodeObjectForKey:@"taskId"];
        _title = [coder decodeObjectForKey:@"title"];
        _taskDescription = [coder decodeObjectForKey:@"taskDescription"];
        _isCompleted = [coder decodeBoolForKey:@"isCompleted"];
        _createdDate = [coder decodeObjectForKey:@"createdDate"];
        _dueDate = [coder decodeObjectForKey:@"dueDate"];
        _priority = [coder decodeIntegerForKey:@"priority"];
    }
    return self;
}

// AI-SUGGESTION: NSCopying implementation
- (id)copyWithZone:(NSZone *)zone {
    Task *copy = [[Task alloc] init];
    copy.taskId = [self.taskId copy];
    copy.title = [self.title copy];
    copy.taskDescription = [self.taskDescription copy];
    copy.isCompleted = self.isCompleted;
    copy.createdDate = [self.createdDate copy];
    copy.dueDate = [self.dueDate copy];
    copy.priority = self.priority;
    return copy;
}

- (NSString *)formattedDueDate {
    if (!self.dueDate) return @"No due date";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    return [formatter stringFromDate:self.dueDate];
}

- (UIColor *)priorityColor {
    switch (self.priority) {
        case 1: return [UIColor systemGreenColor];
        case 3: return [UIColor systemRedColor];
        default: return [UIColor systemOrangeColor];
    }
}

- (NSString *)priorityString {
    switch (self.priority) {
        case 1: return @"Low";
        case 3: return @"High";
        default: return @"Medium";
    }
}

@end

#pragma mark - Task Manager

// AI-SUGGESTION: Singleton pattern for data management
@interface TaskManager : NSObject

@property (nonatomic, strong, readonly) NSMutableArray<Task *> *tasks;

+ (instancetype)sharedManager;
- (void)addTask:(Task *)task;
- (void)removeTask:(Task *)task;
- (void)updateTask:(Task *)task;
- (void)saveTasks;
- (void)loadTasks;
- (NSArray<Task *> *)tasksFilteredByCompletion:(BOOL)completed;
- (NSArray<Task *> *)tasksSortedByDueDate;

@end

@implementation TaskManager

+ (instancetype)sharedManager {
    static TaskManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TaskManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _tasks = [[NSMutableArray alloc] init];
        [self loadTasks];
        
        // AI-SUGGESTION: Observe app lifecycle events for data persistence
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addTask:(Task *)task {
    if (task) {
        [self.tasks addObject:task];
        [self saveTasks];
        
        // AI-SUGGESTION: Post notification for UI updates
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TasksDidChangeNotification" object:nil];
    }
}

- (void)removeTask:(Task *)task {
    [self.tasks removeObject:task];
    [self saveTasks];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TasksDidChangeNotification" object:nil];
}

- (void)updateTask:(Task *)task {
    [self saveTasks];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TasksDidChangeNotification" object:nil];
}

- (NSString *)tasksFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    return [documentsDirectory stringByAppendingPathComponent:@"tasks.plist"];
}

- (void)saveTasks {
    NSString *filePath = [self tasksFilePath];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.tasks requiringSecureCoding:NO error:nil];
    [data writeToFile:filePath atomically:YES];
}

- (void)loadTasks {
    NSString *filePath = [self tasksFilePath];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (data) {
        NSArray *loadedTasks = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (loadedTasks) {
            [self.tasks setArray:loadedTasks];
        }
    } else {
        // AI-SUGGESTION: Create sample data if no saved tasks exist
        [self createSampleTasks];
    }
}

- (void)createSampleTasks {
    Task *task1 = [[Task alloc] initWithTitle:@"Review project proposal"
                                  description:@"Go through the Q4 project proposal and provide feedback"
                                      dueDate:[NSDate dateWithTimeIntervalSinceNow:86400]]; // Tomorrow
    task1.priority = 3;
    
    Task *task2 = [[Task alloc] initWithTitle:@"Update iOS app"
                                  description:@"Implement new features and fix reported bugs"];
    task2.priority = 2;
    
    Task *task3 = [[Task alloc] initWithTitle:@"Schedule team meeting"
                                  description:@"Set up weekly sync meeting with development team"
                                      dueDate:[NSDate dateWithTimeIntervalSinceNow:172800]]; // Day after tomorrow
    task3.priority = 1;
    
    [self.tasks addObjectsFromArray:@[task1, task2, task3]];
}

- (NSArray<Task *> *)tasksFilteredByCompletion:(BOOL)completed {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isCompleted == %@", @(completed)];
    return [self.tasks filteredArrayUsingPredicate:predicate];
}

- (NSArray<Task *> *)tasksSortedByDueDate {
    return [self.tasks sortedArrayUsingComparator:^NSComparisonResult(Task *task1, Task *task2) {
        if (!task1.dueDate && !task2.dueDate) return NSOrderedSame;
        if (!task1.dueDate) return NSOrderedDescending;
        if (!task2.dueDate) return NSOrderedAscending;
        return [task1.dueDate compare:task2.dueDate];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self saveTasks];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self saveTasks];
}

@end

#pragma mark - Custom Table View Cell

// AI-SUGGESTION: Custom cell for enhanced UI presentation
@interface TaskTableViewCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *descriptionLabel;
@property (nonatomic, weak) IBOutlet UILabel *dueDateLabel;
@property (nonatomic, weak) IBOutlet UIView *priorityIndicator;
@property (nonatomic, weak) IBOutlet UIButton *completeButton;

- (void)configureWithTask:(Task *)task;

@end

@implementation TaskTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // AI-SUGGESTION: Setup cell appearance
    self.priorityIndicator.layer.cornerRadius = 4.0;
    self.completeButton.layer.cornerRadius = 12.0;
    
    // Add target for complete button
    [self.completeButton addTarget:self action:@selector(completeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)configureWithTask:(Task *)task {
    self.titleLabel.text = task.title;
    self.descriptionLabel.text = task.taskDescription;
    self.dueDateLabel.text = [task formattedDueDate];
    self.priorityIndicator.backgroundColor = [task priorityColor];
    
    // AI-SUGGESTION: Visual state for completed tasks
    if (task.isCompleted) {
        self.titleLabel.textColor = [UIColor systemGrayColor];
        self.descriptionLabel.textColor = [UIColor systemGray2Color];
        [self.completeButton setTitle:@"✓" forState:UIControlStateNormal];
        [self.completeButton setBackgroundColor:[UIColor systemGreenColor]];
    } else {
        self.titleLabel.textColor = [UIColor labelColor];
        self.descriptionLabel.textColor = [UIColor secondaryLabelColor];
        [self.completeButton setTitle:@"○" forState:UIControlStateNormal];
        [self.completeButton setBackgroundColor:[UIColor systemGray4Color]];
    }
}

- (IBAction)completeButtonTapped:(UIButton *)sender {
    // This will be handled by the delegate pattern in the view controller
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TaskCellCompleteButtonTapped" 
                                                        object:self];
}

@end

#pragma mark - Task List View Controller

// AI-SUGGESTION: Main view controller implementing MVC pattern
@interface TaskListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UISegmentedControl *filterSegmentedControl;
@property (nonatomic, strong) NSArray<Task *> *filteredTasks;

- (IBAction)addButtonTapped:(UIBarButtonItem *)sender;
- (IBAction)filterChanged:(UISegmentedControl *)sender;

@end

@implementation TaskListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // AI-SUGGESTION: Setup navigation and UI
    self.title = @"Tasks";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addButtonTapped:)];
    
    // Setup table view
    [self.tableView registerClass:[TaskTableViewCell class] forCellReuseIdentifier:@"TaskCell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // Setup initial filter
    [self updateFilteredTasks];
    
    // AI-SUGGESTION: Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tasksDidChange:)
                                                 name:@"TasksDidChangeNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskCellCompleteButtonTapped:)
                                                 name:@"TaskCellCompleteButtonTapped"
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateFilteredTasks {
    TaskManager *manager = [TaskManager sharedManager];
    
    switch (self.filterSegmentedControl.selectedSegmentIndex) {
        case 0: // All tasks
            self.filteredTasks = [manager tasksSortedByDueDate];
            break;
        case 1: // Active tasks
            self.filteredTasks = [manager tasksFilteredByCompletion:NO];
            break;
        case 2: // Completed tasks
            self.filteredTasks = [manager tasksFilteredByCompletion:YES];
            break;
        default:
            self.filteredTasks = manager.tasks;
            break;
    }
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredTasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TaskTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TaskCell" forIndexPath:indexPath];
    Task *task = self.filteredTasks[indexPath.row];
    [cell configureWithTask:task];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    Task *selectedTask = self.filteredTasks[indexPath.row];
    
    // AI-SUGGESTION: Navigate to detail view
    TaskDetailViewController *detailVC = [[TaskDetailViewController alloc] initWithTask:selectedTask];
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Task *taskToDelete = self.filteredTasks[indexPath.row];
        [[TaskManager sharedManager] removeTask:taskToDelete];
    }
}

#pragma mark - Actions

- (IBAction)addButtonTapped:(UIBarButtonItem *)sender {
    // AI-SUGGESTION: Present add task interface
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Add New Task"
                                                                             message:@"Enter task details"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Task title";
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Description";
    }];
    
    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *title = alertController.textFields[0].text;
        NSString *description = alertController.textFields[1].text;
        
        if (title.length > 0) {
            Task *newTask = [[Task alloc] initWithTitle:title description:description];
            [[TaskManager sharedManager] addTask:newTask];
        }
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alertController addAction:addAction];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)filterChanged:(UISegmentedControl *)sender {
    [self updateFilteredTasks];
}

#pragma mark - Notifications

- (void)tasksDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateFilteredTasks];
    });
}

- (void)taskCellCompleteButtonTapped:(NSNotification *)notification {
    TaskTableViewCell *cell = notification.object;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    if (indexPath) {
        Task *task = self.filteredTasks[indexPath.row];
        task.isCompleted = !task.isCompleted;
        [[TaskManager sharedManager] updateTask:task];
    }
}

@end

#pragma mark - Task Detail View Controller

// AI-SUGGESTION: Detail view controller for task editing
@interface TaskDetailViewController : UIViewController

@property (nonatomic, strong) Task *task;
@property (nonatomic, weak) IBOutlet UITextField *titleTextField;
@property (nonatomic, weak) IBOutlet UITextView *descriptionTextView;
@property (nonatomic, weak) IBOutlet UIDatePicker *dueDatePicker;
@property (nonatomic, weak) IBOutlet UISegmentedControl *prioritySegmentedControl;

- (instancetype)initWithTask:(Task *)task;
- (IBAction)saveButtonTapped:(UIBarButtonItem *)sender;

@end

@implementation TaskDetailViewController

- (instancetype)initWithTask:(Task *)task {
    self = [super init];
    if (self) {
        _task = task;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Task Details";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(saveButtonTapped:)];
    
    // AI-SUGGESTION: Populate UI with task data
    [self populateFields];
}

- (void)populateFields {
    self.titleTextField.text = self.task.title;
    self.descriptionTextView.text = self.task.taskDescription;
    
    if (self.task.dueDate) {
        self.dueDatePicker.date = self.task.dueDate;
    }
    
    self.prioritySegmentedControl.selectedSegmentIndex = self.task.priority - 1;
}

- (IBAction)saveButtonTapped:(UIBarButtonItem *)sender {
    // AI-SUGGESTION: Update task with form data
    self.task.title = self.titleTextField.text;
    self.task.taskDescription = self.descriptionTextView.text;
    self.task.dueDate = self.dueDatePicker.date;
    self.task.priority = self.prioritySegmentedControl.selectedSegmentIndex + 1;
    
    [[TaskManager sharedManager] updateTask:self.task];
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end

#pragma mark - App Delegate

// AI-SUGGESTION: Application entry point and lifecycle management
@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // AI-SUGGESTION: Setup main window and navigation
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    TaskListViewController *taskListVC = [[TaskListViewController alloc] init];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:taskListVC];
    
    self.window.rootViewController = navigationController;
    [self.window makeKeyAndVisible];
    
    // AI-SUGGESTION: Initialize task manager
    [TaskManager sharedManager];
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // AI-SUGGESTION: Ensure data is saved before termination
    [[TaskManager sharedManager] saveTasks];
}

@end

// AI-SUGGESTION: Main function
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
} 