// AI-Generated Code Header
// **Intent:** Demonstrate Objective-C foundation patterns, categories, and utility classes
// **Optimization:** Efficient string processing, collection utilities, and helper methods
// **Safety:** Null safety checks, proper memory management, and defensive programming

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// AI-SUGGESTION: Protocol definitions for common patterns
@protocol Copyable <NSObject>
- (id)deepCopy;
@end

@protocol Validatable <NSObject>
- (BOOL)isValid;
- (NSArray<NSString *> *)validationErrors;
@end

@protocol Serializable <NSObject>
- (NSDictionary *)toDictionary;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end

#pragma mark - NSString Categories

// AI-SUGGESTION: Useful string manipulation categories
@interface NSString (Utilities)

// Validation methods
- (BOOL)isValidEmail;
- (BOOL)isValidPhoneNumber;
- (BOOL)isValidURL;
- (BOOL)containsOnlyDigits;
- (BOOL)containsOnlyLetters;

// Transformation methods
- (NSString *)trimmedString;
- (NSString *)capitalizedFirstLetter;
- (NSString *)camelCaseToSnakeCase;
- (NSString *)snakeCaseToCamelCase;
- (NSString *)removeHTMLTags;
- (NSString *)urlEncodedString;
- (NSString *)urlDecodedString;

// Utility methods
- (NSInteger)wordCount;
- (NSString *)truncateToLength:(NSInteger)length;
- (NSString *)truncateToLength:(NSInteger)length withEllipsis:(BOOL)addEllipsis;
- (NSAttributedString *)attributedStringWithFont:(UIFont *)font color:(UIColor *)color;

@end

@implementation NSString (Utilities)

- (BOOL)isValidEmail {
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}";
    NSPredicate *emailPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailPredicate evaluateWithObject:self];
}

- (BOOL)isValidPhoneNumber {
    NSString *phoneRegex = @"^[\\+]?[1-9][\\d]{0,15}$";
    NSPredicate *phonePredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", phoneRegex];
    return [phonePredicate evaluateWithObject:self];
}

- (BOOL)isValidURL {
    NSURL *url = [NSURL URLWithString:self];
    return url != nil && url.scheme != nil && url.host != nil;
}

- (BOOL)containsOnlyDigits {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [self rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

- (BOOL)containsOnlyLetters {
    NSCharacterSet *nonLetters = [[NSCharacterSet letterCharacterSet] invertedSet];
    return [self rangeOfCharacterFromSet:nonLetters].location == NSNotFound;
}

- (NSString *)trimmedString {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)capitalizedFirstLetter {
    if (self.length == 0) return self;
    return [[[self substringToIndex:1] uppercaseString] stringByAppendingString:[self substringFromIndex:1]];
}

- (NSString *)camelCaseToSnakeCase {
    NSMutableString *result = [NSMutableString string];
    
    for (NSUInteger i = 0; i < self.length; i++) {
        unichar character = [self characterAtIndex:i];
        
        if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:character] && i > 0) {
            [result appendString:@"_"];
        }
        
        [result appendString:[[NSString stringWithCharacters:&character length:1] lowercaseString]];
    }
    
    return result;
}

- (NSString *)snakeCaseToCamelCase {
    NSArray *components = [self componentsSeparatedByString:@"_"];
    NSMutableString *result = [NSMutableString string];
    
    for (NSUInteger i = 0; i < components.count; i++) {
        NSString *component = components[i];
        if (i == 0) {
            [result appendString:[component lowercaseString]];
        } else {
            [result appendString:[component capitalizedString]];
        }
    }
    
    return result;
}

- (NSString *)removeHTMLTags {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" 
                                                                           options:0 
                                                                             error:nil];
    return [regex stringByReplacingMatchesInString:self 
                                           options:0 
                                             range:NSMakeRange(0, self.length) 
                                      withTemplate:@""];
}

- (NSString *)urlEncodedString {
    NSCharacterSet *allowedCharacters = [NSCharacterSet URLQueryAllowedCharacterSet];
    return [self stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

- (NSString *)urlDecodedString {
    return [self stringByRemovingPercentEncoding];
}

- (NSInteger)wordCount {
    NSArray *words = [self componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [words filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]].count;
}

- (NSString *)truncateToLength:(NSInteger)length {
    return [self truncateToLength:length withEllipsis:YES];
}

- (NSString *)truncateToLength:(NSInteger)length withEllipsis:(BOOL)addEllipsis {
    if (self.length <= length) return self;
    
    if (addEllipsis && length > 3) {
        return [[self substringToIndex:length - 3] stringByAppendingString:@"..."];
    } else {
        return [self substringToIndex:length];
    }
}

- (NSAttributedString *)attributedStringWithFont:(UIFont *)font color:(UIColor *)color {
    NSDictionary *attributes = @{
        NSFontAttributeName: font ?: [UIFont systemFontOfSize:16],
        NSForegroundColorAttributeName: color ?: [UIColor blackColor]
    };
    return [[NSAttributedString alloc] initWithString:self attributes:attributes];
}

@end

#pragma mark - NSArray Categories

// AI-SUGGESTION: Collection utility methods
@interface NSArray (Utilities)

- (id)safeObjectAtIndex:(NSUInteger)index;
- (NSArray *)shuffledArray;
- (NSArray *)reversedArray;
- (id)randomObject;
- (NSArray *)chunkedArrayWithSize:(NSUInteger)chunkSize;
- (NSDictionary *)groupedByKeyPath:(NSString *)keyPath;
- (NSArray *)compactMap:(id (^)(id obj))transform;
- (NSArray *)flatMap:(NSArray * (^)(id obj))transform;

@end

@implementation NSArray (Utilities)

- (id)safeObjectAtIndex:(NSUInteger)index {
    return (index < self.count) ? self[index] : nil;
}

- (NSArray *)shuffledArray {
    NSMutableArray *mutableArray = [self mutableCopy];
    
    for (NSUInteger i = mutableArray.count; i > 1; i--) {
        NSUInteger randomIndex = arc4random_uniform((uint32_t)i);
        [mutableArray exchangeObjectAtIndex:i - 1 withObjectAtIndex:randomIndex];
    }
    
    return [mutableArray copy];
}

- (NSArray *)reversedArray {
    return [[self reverseObjectEnumerator] allObjects];
}

- (id)randomObject {
    if (self.count == 0) return nil;
    NSUInteger randomIndex = arc4random_uniform((uint32_t)self.count);
    return self[randomIndex];
}

- (NSArray *)chunkedArrayWithSize:(NSUInteger)chunkSize {
    if (chunkSize == 0) return @[];
    
    NSMutableArray *chunks = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < self.count; i += chunkSize) {
        NSUInteger remainingItems = self.count - i;
        NSUInteger currentChunkSize = MIN(chunkSize, remainingItems);
        NSRange range = NSMakeRange(i, currentChunkSize);
        NSArray *chunk = [self subarrayWithRange:range];
        [chunks addObject:chunk];
    }
    
    return [chunks copy];
}

- (NSDictionary *)groupedByKeyPath:(NSString *)keyPath {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    
    for (id object in self) {
        id key = [object valueForKeyPath:keyPath];
        if (key) {
            NSMutableArray *group = groups[key];
            if (!group) {
                group = [NSMutableArray array];
                groups[key] = group;
            }
            [group addObject:object];
        }
    }
    
    return [groups copy];
}

- (NSArray *)compactMap:(id (^)(id obj))transform {
    NSMutableArray *result = [NSMutableArray array];
    
    for (id object in self) {
        id transformed = transform(object);
        if (transformed) {
            [result addObject:transformed];
        }
    }
    
    return [result copy];
}

- (NSArray *)flatMap:(NSArray * (^)(id obj))transform {
    NSMutableArray *result = [NSMutableArray array];
    
    for (id object in self) {
        NSArray *transformed = transform(object);
        if (transformed) {
            [result addObjectsFromArray:transformed];
        }
    }
    
    return [result copy];
}

@end

#pragma mark - NSDictionary Categories

// AI-SUGGESTION: Dictionary utility methods
@interface NSDictionary (Utilities)

- (id)safeObjectForKey:(id)key;
- (NSDictionary *)dictionaryByRemovingNullValues;
- (NSDictionary *)dictionaryWithKeysFromArray:(NSArray *)keys;
- (NSString *)JSONString;
- (BOOL)hasKey:(id)key;

@end

@implementation NSDictionary (Utilities)

- (id)safeObjectForKey:(id)key {
    id object = [self objectForKey:key];
    return ([object isKindOfClass:[NSNull class]]) ? nil : object;
}

- (NSDictionary *)dictionaryByRemovingNullValues {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    for (id key in self) {
        id value = self[key];
        if (![value isKindOfClass:[NSNull class]]) {
            result[key] = value;
        }
    }
    
    return [result copy];
}

- (NSDictionary *)dictionaryWithKeysFromArray:(NSArray *)keys {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    for (id key in keys) {
        id value = [self safeObjectForKey:key];
        if (value) {
            result[key] = value;
        }
    }
    
    return [result copy];
}

- (NSString *)JSONString {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    
    if (error) {
        NSLog(@"JSON serialization error: %@", error.localizedDescription);
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (BOOL)hasKey:(id)key {
    return [self objectForKey:key] != nil;
}

@end

#pragma mark - NSDate Categories

// AI-SUGGESTION: Date utility methods
@interface NSDate (Utilities)

- (NSString *)formattedStringWithFormat:(NSString *)format;
- (NSString *)timeAgoString;
- (NSDate *)dateByAddingDays:(NSInteger)days;
- (NSDate *)dateByAddingHours:(NSInteger)hours;
- (NSDate *)startOfDay;
- (NSDate *)endOfDay;
- (BOOL)isToday;
- (BOOL)isYesterday;
- (BOOL)isTomorrow;
- (NSInteger)daysBetweenDate:(NSDate *)otherDate;

@end

@implementation NSDate (Utilities)

- (NSString *)formattedStringWithFormat:(NSString *)format {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = format;
    return [formatter stringFromDate:self];
}

- (NSString *)timeAgoString {
    NSTimeInterval timeInterval = -[self timeIntervalSinceNow];
    
    if (timeInterval < 60) {
        return @"Just now";
    } else if (timeInterval < 3600) {
        NSInteger minutes = timeInterval / 60;
        return [NSString stringWithFormat:@"%ld minute%@ ago", (long)minutes, minutes == 1 ? @"" : @"s"];
    } else if (timeInterval < 86400) {
        NSInteger hours = timeInterval / 3600;
        return [NSString stringWithFormat:@"%ld hour%@ ago", (long)hours, hours == 1 ? @"" : @"s"];
    } else if (timeInterval < 2592000) {
        NSInteger days = timeInterval / 86400;
        return [NSString stringWithFormat:@"%ld day%@ ago", (long)days, days == 1 ? @"" : @"s"];
    } else {
        return [self formattedStringWithFormat:@"MMM dd, yyyy"];
    }
}

- (NSDate *)dateByAddingDays:(NSInteger)days {
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.day = days;
    return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:self options:0];
}

- (NSDate *)dateByAddingHours:(NSInteger)hours {
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.hour = hours;
    return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:self options:0];
}

- (NSDate *)startOfDay {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay 
                                               fromDate:self];
    return [calendar dateFromComponents:components];
}

- (NSDate *)endOfDay {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay 
                                               fromDate:self];
    components.hour = 23;
    components.minute = 59;
    components.second = 59;
    return [calendar dateFromComponents:components];
}

- (BOOL)isToday {
    return [[NSCalendar currentCalendar] isDateInToday:self];
}

- (BOOL)isYesterday {
    return [[NSCalendar currentCalendar] isDateInYesterday:self];
}

- (BOOL)isTomorrow {
    return [[NSCalendar currentCalendar] isDateInTomorrow:self];
}

- (NSInteger)daysBetweenDate:(NSDate *)otherDate {
    NSTimeInterval timeInterval = [otherDate timeIntervalSinceDate:self];
    return (NSInteger)(timeInterval / 86400);
}

@end

#pragma mark - Utility Classes

// AI-SUGGESTION: Performance timing utility
@interface PerformanceTimer : NSObject

@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) NSTimeInterval startTime;
@property (nonatomic, assign, readonly) NSTimeInterval endTime;
@property (nonatomic, assign, readonly) NSTimeInterval duration;

+ (instancetype)timerWithName:(NSString *)name;
- (void)start;
- (void)stop;
- (void)reset;
- (NSString *)formattedDuration;

@end

@implementation PerformanceTimer

+ (instancetype)timerWithName:(NSString *)name {
    PerformanceTimer *timer = [[PerformanceTimer alloc] init];
    timer->_name = name;
    return timer;
}

- (void)start {
    _startTime = [[NSDate date] timeIntervalSince1970];
    _endTime = 0;
}

- (void)stop {
    _endTime = [[NSDate date] timeIntervalSince1970];
}

- (void)reset {
    _startTime = 0;
    _endTime = 0;
}

- (NSTimeInterval)duration {
    if (_startTime == 0) return 0;
    if (_endTime == 0) return [[NSDate date] timeIntervalSince1970] - _startTime;
    return _endTime - _startTime;
}

- (NSString *)formattedDuration {
    NSTimeInterval duration = self.duration;
    
    if (duration < 0.001) {
        return [NSString stringWithFormat:@"%.0f μs", duration * 1000000];
    } else if (duration < 1.0) {
        return [NSString stringWithFormat:@"%.2f ms", duration * 1000];
    } else {
        return [NSString stringWithFormat:@"%.2f s", duration];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Timer '%@': %@", self.name, [self formattedDuration]];
}

@end

// AI-SUGGESTION: Weak reference wrapper
@interface WeakReference : NSObject

@property (nonatomic, weak, readonly) id object;

+ (instancetype)referenceWithObject:(id)object;
- (instancetype)initWithObject:(id)object;

@end

@implementation WeakReference

+ (instancetype)referenceWithObject:(id)object {
    return [[self alloc] initWithObject:object];
}

- (instancetype)initWithObject:(id)object {
    self = [super init];
    if (self) {
        _object = object;
    }
    return self;
}

@end

// AI-SUGGESTION: Thread-safe counter
@interface ThreadSafeCounter : NSObject

@property (nonatomic, assign, readonly) NSInteger value;

- (NSInteger)increment;
- (NSInteger)decrement;
- (NSInteger)add:(NSInteger)amount;
- (void)reset;

@end

@implementation ThreadSafeCounter {
    dispatch_queue_t _queue;
    NSInteger _internalValue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.threadSafeCounter.queue", DISPATCH_QUEUE_SERIAL);
        _internalValue = 0;
    }
    return self;
}

- (NSInteger)value {
    __block NSInteger result;
    dispatch_sync(_queue, ^{
        result = self->_internalValue;
    });
    return result;
}

- (NSInteger)increment {
    return [self add:1];
}

- (NSInteger)decrement {
    return [self add:-1];
}

- (NSInteger)add:(NSInteger)amount {
    __block NSInteger result;
    dispatch_sync(_queue, ^{
        self->_internalValue += amount;
        result = self->_internalValue;
    });
    return result;
}

- (void)reset {
    dispatch_sync(_queue, ^{
        self->_internalValue = 0;
    });
}

@end

// AI-SUGGESTION: Observer pattern implementation
@interface EventObserver : NSObject

typedef void (^EventBlock)(id sender, NSDictionary *userInfo);

@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, copy) EventBlock block;

+ (instancetype)observerWithTarget:(id)target selector:(SEL)selector;
+ (instancetype)observerWithBlock:(EventBlock)block;

@end

@implementation EventObserver

+ (instancetype)observerWithTarget:(id)target selector:(SEL)selector {
    EventObserver *observer = [[EventObserver alloc] init];
    observer.target = target;
    observer.selector = selector;
    return observer;
}

+ (instancetype)observerWithBlock:(EventBlock)block {
    EventObserver *observer = [[EventObserver alloc] init];
    observer.block = block;
    return observer;
}

- (void)notifyWithSender:(id)sender userInfo:(NSDictionary *)userInfo {
    if (self.block) {
        self.block(sender, userInfo);
    } else if (self.target && self.selector) {
        if ([self.target respondsToSelector:self.selector]) {
            NSMethodSignature *signature = [self.target methodSignatureForSelector:self.selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.target = self.target;
            invocation.selector = self.selector;
            
            if (signature.numberOfArguments > 2) {
                [invocation setArgument:&sender atIndex:2];
            }
            if (signature.numberOfArguments > 3) {
                [invocation setArgument:&userInfo atIndex:3];
            }
            
            [invocation invoke];
        }
    }
}

@end

@interface EventManager : NSObject

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<EventObserver *> *> *observers;

+ (instancetype)sharedManager;
- (void)addObserver:(EventObserver *)observer forEvent:(NSString *)eventName;
- (void)removeObserver:(EventObserver *)observer forEvent:(NSString *)eventName;
- (void)postEvent:(NSString *)eventName sender:(id)sender userInfo:(NSDictionary *)userInfo;
- (void)removeAllObserversForEvent:(NSString *)eventName;

@end

@implementation EventManager

+ (instancetype)sharedManager {
    static EventManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EventManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _observers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addObserver:(EventObserver *)observer forEvent:(NSString *)eventName {
    if (!self.observers[eventName]) {
        self.observers[eventName] = [[NSMutableArray alloc] init];
    }
    [self.observers[eventName] addObject:observer];
}

- (void)removeObserver:(EventObserver *)observer forEvent:(NSString *)eventName {
    [self.observers[eventName] removeObject:observer];
}

- (void)postEvent:(NSString *)eventName sender:(id)sender userInfo:(NSDictionary *)userInfo {
    NSArray<EventObserver *> *eventObservers = [self.observers[eventName] copy];
    
    for (EventObserver *observer in eventObservers) {
        [observer notifyWithSender:sender userInfo:userInfo];
    }
}

- (void)removeAllObserversForEvent:(NSString *)eventName {
    [self.observers removeObjectForKey:eventName];
}

@end

#pragma mark - File Manager Utilities

// AI-SUGGESTION: File system utilities
@interface FileManagerUtilities : NSObject

+ (NSString *)documentsDirectory;
+ (NSString *)cachesDirectory;
+ (NSString *)temporaryDirectory;
+ (BOOL)createDirectoryAtPath:(NSString *)path;
+ (BOOL)fileExistsAtPath:(NSString *)path;
+ (BOOL)deleteFileAtPath:(NSString *)path;
+ (NSUInteger)fileSizeAtPath:(NSString *)path;
+ (NSString *)formattedFileSize:(NSUInteger)bytes;

@end

@implementation FileManagerUtilities

+ (NSString *)documentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

+ (NSString *)cachesDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

+ (NSString *)temporaryDirectory {
    return NSTemporaryDirectory();
}

+ (BOOL)createDirectoryAtPath:(NSString *)path {
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:path
                                             withIntermediateDirectories:YES
                                                              attributes:nil
                                                                   error:&error];
    if (!success) {
        NSLog(@"Failed to create directory at path %@: %@", path, error.localizedDescription);
    }
    return success;
}

+ (BOOL)fileExistsAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

+ (BOOL)deleteFileAtPath:(NSString *)path {
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (!success && error.code != NSFileNoSuchFileError) {
        NSLog(@"Failed to delete file at path %@: %@", path, error.localizedDescription);
    }
    return success || error.code == NSFileNoSuchFileError;
}

+ (NSUInteger)fileSizeAtPath:(NSString *)path {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return [attributes[NSFileSize] unsignedIntegerValue];
}

+ (NSString *)formattedFileSize:(NSUInteger)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%lu B", (unsigned long)bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end

#pragma mark - Usage Examples

// AI-SUGGESTION: Example usage and demonstration
void demonstrateFoundationUtilities() {
    NSLog(@"=== Foundation Utilities Demo ===\n");
    
    // String utilities
    NSString *email = @"user@example.com";
    NSLog(@"Is valid email: %@", [@"user@example.com" isValidEmail] ? @"YES" : @"NO");
    NSLog(@"Capitalized: %@", [@"hello world" capitalizedFirstLetter]);
    NSLog(@"Camel to snake: %@", [@"firstName" camelCaseToSnakeCase]);
    
    // Array utilities
    NSArray *numbers = @[@1, @2, @3, @4, @5];
    NSLog(@"Shuffled: %@", [numbers shuffledArray]);
    NSLog(@"Random object: %@", [numbers randomObject]);
    NSLog(@"Chunks of 2: %@", [numbers chunkedArrayWithSize:2]);
    
    // Date utilities
    NSDate *now = [NSDate date];
    NSLog(@"Formatted date: %@", [now formattedStringWithFormat:@"yyyy-MM-dd HH:mm:ss"]);
    NSLog(@"Time ago: %@", [now timeAgoString]);
    NSLog(@"Is today: %@", [now isToday] ? @"YES" : @"NO");
    
    // Performance timing
    PerformanceTimer *timer = [PerformanceTimer timerWithName:@"Test Operation"];
    [timer start];
    
    // Simulate some work
    [NSThread sleepForTimeInterval:0.1];
    
    [timer stop];
    NSLog(@"Performance: %@", timer);
    
    // Thread-safe counter
    ThreadSafeCounter *counter = [[ThreadSafeCounter alloc] init];
    NSLog(@"Counter: %ld", (long)[counter increment]);
    NSLog(@"Counter: %ld", (long)[counter add:5]);
    NSLog(@"Counter value: %ld", (long)counter.value);
    
    // Event system
    EventManager *eventManager = [EventManager sharedManager];
    
    EventObserver *observer = [EventObserver observerWithBlock:^(id sender, NSDictionary *userInfo) {
        NSLog(@"Event received: %@", userInfo[@"message"]);
    }];
    
    [eventManager addObserver:observer forEvent:@"testEvent"];
    [eventManager postEvent:@"testEvent" sender:nil userInfo:@{@"message": @"Hello from event system!"}];
    
    // File utilities
    NSString *documentsPath = [FileManagerUtilities documentsDirectory];
    NSLog(@"Documents directory: %@", documentsPath);
    NSLog(@"Directory exists: %@", [FileManagerUtilities fileExistsAtPath:documentsPath] ? @"YES" : @"NO");
} 