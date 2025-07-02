// AI-Generated Code Header
// **Intent:** Demonstrate Core Data management with Objective-C patterns
// **Optimization:** Efficient data persistence, batch operations, and memory management
// **Safety:** Thread-safe Core Data operations, proper context management, and error handling

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

// AI-SUGGESTION: Core Data entity model classes
@interface Person : NSManagedObject

@property (nonatomic, strong) NSString *personId;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSDate *birthDate;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSSet<Address *> *addresses;
@property (nonatomic, strong) NSSet<PhoneNumber *> *phoneNumbers;

- (NSString *)fullName;
- (NSInteger)age;
- (NSString *)primaryEmail;

@end

@interface Address : NSManagedObject

@property (nonatomic, strong) NSString *addressId;
@property (nonatomic, strong) NSString *street;
@property (nonatomic, strong) NSString *city;
@property (nonatomic, strong) NSString *state;
@property (nonatomic, strong) NSString *zipCode;
@property (nonatomic, strong) NSString *country;
@property (nonatomic, assign) BOOL isPrimary;
@property (nonatomic, strong) Person *person;

- (NSString *)formattedAddress;

@end

@interface PhoneNumber : NSManagedObject

@property (nonatomic, strong) NSString *phoneId;
@property (nonatomic, strong) NSString *number;
@property (nonatomic, strong) NSString *type; // home, work, mobile
@property (nonatomic, assign) BOOL isPrimary;
@property (nonatomic, strong) Person *person;

- (NSString *)formattedNumber;

@end

// AI-SUGGESTION: Implementation of Core Data entities
@implementation Person

@dynamic personId, firstName, lastName, email, birthDate, createdAt, addresses, phoneNumbers;

- (NSString *)fullName {
    return [NSString stringWithFormat:@"%@ %@", self.firstName ?: @"", self.lastName ?: @""];
}

- (NSInteger)age {
    if (!self.birthDate) return 0;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear
                                               fromDate:self.birthDate
                                                 toDate:[NSDate date]
                                                options:0];
    return components.year;
}

- (NSString *)primaryEmail {
    return self.email ?: @"No email";
}

- (void)awakeFromInsert {
    [super awakeFromInsert];
    self.personId = [[NSUUID UUID] UUIDString];
    self.createdAt = [NSDate date];
}

@end

@implementation Address

@dynamic addressId, street, city, state, zipCode, country, isPrimary, person;

- (NSString *)formattedAddress {
    NSMutableArray *components = [NSMutableArray array];
    
    if (self.street) [components addObject:self.street];
    if (self.city) [components addObject:self.city];
    if (self.state) [components addObject:self.state];
    if (self.zipCode) [components addObject:self.zipCode];
    if (self.country) [components addObject:self.country];
    
    return [components componentsJoinedByString:@", "];
}

- (void)awakeFromInsert {
    [super awakeFromInsert];
    self.addressId = [[NSUUID UUID] UUIDString];
    self.isPrimary = NO;
}

@end

@implementation PhoneNumber

@dynamic phoneId, number, type, isPrimary, person;

- (NSString *)formattedNumber {
    if (!self.number) return @"";
    
    // Simple US phone number formatting
    NSString *cleaned = [[self.number componentsSeparatedByCharactersInSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                        componentsJoinedByString:@""];
    
    if (cleaned.length == 10) {
        return [NSString stringWithFormat:@"(%@) %@-%@",
                [cleaned substringWithRange:NSMakeRange(0, 3)],
                [cleaned substringWithRange:NSMakeRange(3, 3)],
                [cleaned substringWithRange:NSMakeRange(6, 4)]];
    }
    
    return self.number;
}

- (void)awakeFromInsert {
    [super awakeFromInsert];
    self.phoneId = [[NSUUID UUID] UUIDString];
    self.isPrimary = NO;
    self.type = @"mobile";
}

@end

#pragma mark - Core Data Manager

// AI-SUGGESTION: Core Data stack manager with modern patterns
@interface CoreDataManager : NSObject

@property (readonly, strong) NSPersistentContainer *persistentContainer;
@property (readonly, strong) NSManagedObjectContext *mainContext;
@property (readonly, strong) NSManagedObjectContext *backgroundContext;

+ (instancetype)sharedManager;
- (void)saveContext;
- (void)saveContextWithCompletion:(void (^)(NSError *error))completion;
- (NSManagedObjectContext *)newBackgroundContext;

// Person management methods
- (Person *)createPersonWithFirstName:(NSString *)firstName 
                             lastName:(NSString *)lastName 
                                email:(NSString *)email;
- (NSArray<Person *> *)fetchAllPersons;
- (NSArray<Person *> *)fetchPersonsWithPredicate:(NSPredicate *)predicate;
- (Person *)fetchPersonWithId:(NSString *)personId;
- (void)deletePerson:(Person *)person;

// Batch operations
- (void)batchInsertPersonsWithData:(NSArray<NSDictionary *> *)personsData 
                        completion:(void (^)(NSError *error))completion;
- (void)batchDeletePersonsWithPredicate:(NSPredicate *)predicate 
                             completion:(void (^)(NSUInteger deletedCount, NSError *error))completion;

@end

@implementation CoreDataManager

+ (instancetype)sharedManager {
    static CoreDataManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CoreDataManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupCoreDataStack];
    }
    return self;
}

- (void)setupCoreDataStack {
    // AI-SUGGESTION: Create persistent container with error handling
    _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"DataModel"];
    
    [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
        if (error) {
            NSLog(@"Core Data error: %@", error.localizedDescription);
            // In production, implement proper error recovery
            abort();
        } else {
            NSLog(@"Core Data loaded successfully");
        }
    }];
    
    // Configure contexts
    _mainContext = _persistentContainer.viewContext;
    _mainContext.automaticallyMergesChangesFromParent = YES;
    
    _backgroundContext = [_persistentContainer newBackgroundContext];
    _backgroundContext.automaticallyMergesChangesFromParent = YES;
}

- (void)saveContext {
    [self saveContextWithCompletion:nil];
}

- (void)saveContextWithCompletion:(void (^)(NSError *error))completion {
    NSManagedObjectContext *context = self.mainContext;
    
    if (![context hasChanges]) {
        if (completion) completion(nil);
        return;
    }
    
    [context performBlock:^{
        NSError *error;
        BOOL success = [context save:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success ? nil : error);
            }
        });
    }];
}

- (NSManagedObjectContext *)newBackgroundContext {
    return [self.persistentContainer newBackgroundContext];
}

#pragma mark - Person Management

- (Person *)createPersonWithFirstName:(NSString *)firstName 
                             lastName:(NSString *)lastName 
                                email:(NSString *)email {
    
    NSManagedObjectContext *context = self.mainContext;
    Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" 
                                                   inManagedObjectContext:context];
    
    person.firstName = firstName;
    person.lastName = lastName;
    person.email = email;
    
    return person;
}

- (NSArray<Person *> *)fetchAllPersons {
    return [self fetchPersonsWithPredicate:nil];
}

- (NSArray<Person *> *)fetchPersonsWithPredicate:(NSPredicate *)predicate {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Person"];
    
    if (predicate) {
        request.predicate = predicate;
    }
    
    // AI-SUGGESTION: Add sorting for consistent results
    NSSortDescriptor *lastNameSort = [NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES];
    NSSortDescriptor *firstNameSort = [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES];
    request.sortDescriptors = @[lastNameSort, firstNameSort];
    
    NSError *error;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Fetch error: %@", error.localizedDescription);
        return @[];
    }
    
    return results;
}

- (Person *)fetchPersonWithId:(NSString *)personId {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"personId == %@", personId];
    NSArray<Person *> *results = [self fetchPersonsWithPredicate:predicate];
    return results.firstObject;
}

- (void)deletePerson:(Person *)person {
    [self.mainContext deleteObject:person];
}

#pragma mark - Batch Operations

- (void)batchInsertPersonsWithData:(NSArray<NSDictionary *> *)personsData 
                        completion:(void (^)(NSError *error))completion {
    
    NSManagedObjectContext *backgroundContext = [self newBackgroundContext];
    
    [backgroundContext performBlock:^{
        NSError *error;
        
        for (NSDictionary *personData in personsData) {
            Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" 
                                                           inManagedObjectContext:backgroundContext];
            
            person.firstName = personData[@"firstName"];
            person.lastName = personData[@"lastName"];
            person.email = personData[@"email"];
            
            if (personData[@"birthDate"]) {
                person.birthDate = personData[@"birthDate"];
            }
        }
        
        BOOL success = [backgroundContext save:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success ? nil : error);
            }
        });
    }];
}

- (void)batchDeletePersonsWithPredicate:(NSPredicate *)predicate 
                             completion:(void (^)(NSUInteger deletedCount, NSError *error))completion {
    
    NSManagedObjectContext *backgroundContext = [self newBackgroundContext];
    
    [backgroundContext performBlock:^{
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] 
                                               initWithFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Person"]];
        
        if (predicate) {
            deleteRequest.fetchRequest.predicate = predicate;
        }
        
        deleteRequest.resultType = NSBatchDeleteResultTypeCount;
        
        NSError *error;
        NSBatchDeleteResult *result = [backgroundContext executeRequest:deleteRequest error:&error];
        
        NSUInteger deletedCount = 0;
        if (result && !error) {
            deletedCount = [result.result unsignedIntegerValue];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(deletedCount, error);
            }
        });
    }];
}

@end

#pragma mark - Core Data Helper Categories

// AI-SUGGESTION: Convenient categories for common operations
@interface NSManagedObject (Helper)

+ (NSString *)entityName;
+ (instancetype)insertInContext:(NSManagedObjectContext *)context;
+ (NSArray *)fetchAllInContext:(NSManagedObjectContext *)context;
+ (NSArray *)fetchWithPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context;
+ (NSUInteger)countInContext:(NSManagedObjectContext *)context;
+ (void)deleteAllInContext:(NSManagedObjectContext *)context;

@end

@implementation NSManagedObject (Helper)

+ (NSString *)entityName {
    return NSStringFromClass(self);
}

+ (instancetype)insertInContext:(NSManagedObjectContext *)context {
    return [NSEntityDescription insertNewObjectForEntityForName:[self entityName] 
                                         inManagedObjectContext:context];
}

+ (NSArray *)fetchAllInContext:(NSManagedObjectContext *)context {
    return [self fetchWithPredicate:nil inContext:context];
}

+ (NSArray *)fetchWithPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[self entityName]];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Fetch error for %@: %@", [self entityName], error.localizedDescription);
        return @[];
    }
    
    return results;
}

+ (NSUInteger)countInContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[self entityName]];
    
    NSError *error;
    NSUInteger count = [context countForFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"Count error for %@: %@", [self entityName], error.localizedDescription);
        return 0;
    }
    
    return count;
}

+ (void)deleteAllInContext:(NSManagedObjectContext *)context {
    NSArray *objects = [self fetchAllInContext:context];
    for (NSManagedObject *object in objects) {
        [context deleteObject:object];
    }
}

@end

#pragma mark - Core Data Migration Helper

// AI-SUGGESTION: Migration helper for Core Data model versions
@interface CoreDataMigrationHelper : NSObject

+ (BOOL)requiresMigrationFromStoreURL:(NSURL *)storeURL 
                             toModel:(NSManagedObjectModel *)finalModel;
+ (BOOL)migrateStoreAtURL:(NSURL *)storeURL 
                 withType:(NSString *)storeType 
                  toModel:(NSManagedObjectModel *)finalModel 
                    error:(NSError **)error;

@end

@implementation CoreDataMigrationHelper

+ (BOOL)requiresMigrationFromStoreURL:(NSURL *)storeURL 
                             toModel:(NSManagedObjectModel *)finalModel {
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]) {
        return NO;
    }
    
    NSError *error;
    NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType 
                                                                                         URL:storeURL 
                                                                                     options:nil 
                                                                                       error:&error];
    
    if (!metadata) {
        NSLog(@"Failed to read metadata: %@", error.localizedDescription);
        return NO;
    }
    
    return ![finalModel isConfiguration:nil compatibleWithStoreMetadata:metadata];
}

+ (BOOL)migrateStoreAtURL:(NSURL *)storeURL 
                 withType:(NSString *)storeType 
                  toModel:(NSManagedObjectModel *)finalModel 
                    error:(NSError **)error {
    
    // AI-SUGGESTION: Implement progressive migration if needed
    NSMigrationManager *migrationManager = [[NSMigrationManager alloc] 
                                            initWithSourceModel:nil 
                                            destinationModel:finalModel];
    
    // This is a simplified version - in production, implement progressive migration
    // for complex model changes
    
    return YES; // Placeholder for actual migration logic
}

@end

#pragma mark - Usage Example

// AI-SUGGESTION: Example usage and demonstration
void demonstrateCoreDataUsage() {
    CoreDataManager *manager = [CoreDataManager sharedManager];
    
    // Create a person
    Person *person = [manager createPersonWithFirstName:@"John" 
                                               lastName:@"Doe" 
                                                  email:@"john.doe@example.com"];
    
    // Add address
    Address *address = [Address insertInContext:manager.mainContext];
    address.street = @"123 Main St";
    address.city = @"Anytown";
    address.state = @"CA";
    address.zipCode = @"12345";
    address.isPrimary = YES;
    address.person = person;
    
    // Add phone number
    PhoneNumber *phone = [PhoneNumber insertInContext:manager.mainContext];
    phone.number = @"5551234567";
    phone.type = @"mobile";
    phone.isPrimary = YES;
    phone.person = person;
    
    // Save changes
    [manager saveContextWithCompletion:^(NSError *error) {
        if (error) {
            NSLog(@"Save error: %@", error.localizedDescription);
        } else {
            NSLog(@"Person saved successfully: %@", person.fullName);
        }
    }];
    
    // Fetch all persons
    NSArray<Person *> *allPersons = [manager fetchAllPersons];
    NSLog(@"Total persons: %lu", (unsigned long)allPersons.count);
    
    // Batch insert example
    NSArray *batchData = @[
        @{@"firstName": @"Jane", @"lastName": @"Smith", @"email": @"jane@example.com"},
        @{@"firstName": @"Bob", @"lastName": @"Johnson", @"email": @"bob@example.com"}
    ];
    
    [manager batchInsertPersonsWithData:batchData completion:^(NSError *error) {
        if (error) {
            NSLog(@"Batch insert error: %@", error.localizedDescription);
        } else {
            NSLog(@"Batch insert completed successfully");
        }
    }];
} 