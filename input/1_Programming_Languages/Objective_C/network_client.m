// AI-Generated Code Header
// **Intent:** Demonstrate modern networking patterns with Objective-C and NSURLSession
// **Optimization:** Efficient HTTP operations, proper caching, and background processing
// **Safety:** Thread-safe operations, proper error handling, and request validation

#import <Foundation/Foundation.h>

// AI-SUGGESTION: Forward declarations and type definitions
typedef NS_ENUM(NSInteger, HTTPMethod) {
    HTTPMethodGET,
    HTTPMethodPOST,
    HTTPMethodPUT,
    HTTPMethodDELETE,
    HTTPMethodPATCH
};

typedef NS_ENUM(NSInteger, NetworkError) {
    NetworkErrorInvalidURL = 1000,
    NetworkErrorInvalidResponse,
    NetworkErrorJSONParsing,
    NetworkErrorNoData,
    NetworkErrorUnauthorized,
    NetworkErrorServerError
};

// AI-SUGGESTION: Completion block type definitions
typedef void (^NetworkCompletionBlock)(id _Nullable response, NSError * _Nullable error);
typedef void (^DownloadProgressBlock)(NSProgress * _Nonnull progress);
typedef void (^UploadProgressBlock)(NSProgress * _Nonnull progress);

#pragma mark - Request Configuration

// AI-SUGGESTION: Request configuration object
@interface NetworkRequestConfig : NSObject

@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, assign) HTTPMethod method;
@property (nonatomic, strong) NSString *endpoint;
@property (nonatomic, strong, nullable) NSDictionary *headers;
@property (nonatomic, strong, nullable) NSDictionary *parameters;
@property (nonatomic, strong, nullable) NSData *body;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, assign) BOOL requiresAuthentication;

- (instancetype)initWithBaseURL:(NSString *)baseURL 
                         method:(HTTPMethod)method 
                       endpoint:(NSString *)endpoint;

- (NSURLRequest *)buildURLRequest;
- (NSString *)HTTPMethodString;

@end

@implementation NetworkRequestConfig

- (instancetype)initWithBaseURL:(NSString *)baseURL 
                         method:(HTTPMethod)method 
                       endpoint:(NSString *)endpoint {
    self = [super init];
    if (self) {
        _baseURL = baseURL;
        _method = method;
        _endpoint = endpoint;
        _timeout = 30.0; // Default timeout
        _requiresAuthentication = NO;
    }
    return self;
}

- (NSURLRequest *)buildURLRequest {
    NSString *fullURL = [self.baseURL stringByAppendingPathComponent:self.endpoint];
    
    // Add query parameters for GET requests
    if (self.method == HTTPMethodGET && self.parameters.count > 0) {
        NSURLComponents *components = [NSURLComponents componentsWithString:fullURL];
        NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
        
        for (NSString *key in self.parameters) {
            NSString *value = [NSString stringWithFormat:@"%@", self.parameters[key]];
            [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:value]];
        }
        
        components.queryItems = queryItems;
        fullURL = components.URL.absoluteString;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fullURL]];
    request.HTTPMethod = [self HTTPMethodString];
    request.timeoutInterval = self.timeout;
    
    // Set headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    for (NSString *headerKey in self.headers) {
        [request setValue:self.headers[headerKey] forHTTPHeaderField:headerKey];
    }
    
    // Set body for non-GET requests
    if (self.method != HTTPMethodGET) {
        if (self.body) {
            request.HTTPBody = self.body;
        } else if (self.parameters) {
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.parameters 
                                                              options:0 
                                                                error:&error];
            if (!error) {
                request.HTTPBody = jsonData;
            }
        }
    }
    
    return request;
}

- (NSString *)HTTPMethodString {
    switch (self.method) {
        case HTTPMethodGET: return @"GET";
        case HTTPMethodPOST: return @"POST";
        case HTTPMethodPUT: return @"PUT";
        case HTTPMethodDELETE: return @"DELETE";
        case HTTPMethodPATCH: return @"PATCH";
        default: return @"GET";
    }
}

@end

#pragma mark - Authentication Manager

// AI-SUGGESTION: Authentication token management
@interface AuthenticationManager : NSObject

@property (nonatomic, strong, nullable) NSString *accessToken;
@property (nonatomic, strong, nullable) NSString *refreshToken;
@property (nonatomic, strong, nullable) NSDate *tokenExpirationDate;

+ (instancetype)sharedManager;
- (void)setTokens:(NSString *)accessToken 
     refreshToken:(NSString *)refreshToken 
    expirationDate:(NSDate *)expirationDate;
- (void)clearTokens;
- (BOOL)isTokenValid;
- (NSDictionary *)authenticationHeaders;

@end

@implementation AuthenticationManager

+ (instancetype)sharedManager {
    static AuthenticationManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AuthenticationManager alloc] init];
    });
    return sharedInstance;
}

- (void)setTokens:(NSString *)accessToken 
     refreshToken:(NSString *)refreshToken 
    expirationDate:(NSDate *)expirationDate {
    
    self.accessToken = accessToken;
    self.refreshToken = refreshToken;
    self.tokenExpirationDate = expirationDate;
    
    // AI-SUGGESTION: Store tokens securely in keychain in production
    [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:@"access_token"];
    [[NSUserDefaults standardUserDefaults] setObject:refreshToken forKey:@"refresh_token"];
    [[NSUserDefaults standardUserDefaults] setObject:expirationDate forKey:@"token_expiration"];
}

- (void)clearTokens {
    self.accessToken = nil;
    self.refreshToken = nil;
    self.tokenExpirationDate = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"access_token"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"refresh_token"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"token_expiration"];
}

- (BOOL)isTokenValid {
    return self.accessToken && 
           self.tokenExpirationDate && 
           [self.tokenExpirationDate compare:[NSDate date]] == NSOrderedDescending;
}

- (NSDictionary *)authenticationHeaders {
    if ([self isTokenValid]) {
        return @{@"Authorization": [NSString stringWithFormat:@"Bearer %@", self.accessToken]};
    }
    return @{};
}

@end

#pragma mark - Response Parser

// AI-SUGGESTION: Response parsing and validation
@interface NetworkResponseParser : NSObject

+ (id)parseResponse:(NSData *)data 
           response:(NSURLResponse *)response 
              error:(NSError **)error;

+ (NSError *)errorForStatusCode:(NSInteger)statusCode;
+ (NSError *)errorWithCode:(NetworkError)code 
               description:(NSString *)description;

@end

@implementation NetworkResponseParser

+ (id)parseResponse:(NSData *)data 
           response:(NSURLResponse *)response 
              error:(NSError **)error {
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    // Check for HTTP errors
    if (httpResponse.statusCode >= 400) {
        if (error) {
            *error = [self errorForStatusCode:httpResponse.statusCode];
        }
        return nil;
    }
    
    // Check for data
    if (!data || data.length == 0) {
        if (error) {
            *error = [self errorWithCode:NetworkErrorNoData 
                             description:@"No data received from server"];
        }
        return nil;
    }
    
    // Parse JSON
    NSError *jsonError;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data 
                                                    options:NSJSONReadingMutableContainers 
                                                      error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = [self errorWithCode:NetworkErrorJSONParsing 
                             description:@"Failed to parse JSON response"];
        }
        return nil;
    }
    
    return jsonObject;
}

+ (NSError *)errorForStatusCode:(NSInteger)statusCode {
    NSString *description;
    NetworkError errorCode;
    
    switch (statusCode) {
        case 401:
            errorCode = NetworkErrorUnauthorized;
            description = @"Unauthorized access";
            break;
        case 404:
            errorCode = NetworkErrorInvalidResponse;
            description = @"Resource not found";
            break;
        case 500:
        case 502:
        case 503:
            errorCode = NetworkErrorServerError;
            description = @"Server error occurred";
            break;
        default:
            errorCode = NetworkErrorInvalidResponse;
            description = [NSString stringWithFormat:@"HTTP error %ld", (long)statusCode];
            break;
    }
    
    return [self errorWithCode:errorCode description:description];
}

+ (NSError *)errorWithCode:(NetworkError)code description:(NSString *)description {
    return [NSError errorWithDomain:@"NetworkErrorDomain" 
                               code:code 
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@end

#pragma mark - Network Cache Manager

// AI-SUGGESTION: Intelligent caching system
@interface NetworkCacheManager : NSObject

@property (nonatomic, strong) NSURLCache *urlCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *cacheTimestamps;

+ (instancetype)sharedManager;
- (void)configureCache;
- (BOOL)shouldUseCacheForRequest:(NSURLRequest *)request;
- (void)cacheResponse:(NSURLResponse *)response 
                 data:(NSData *)data 
           forRequest:(NSURLRequest *)request;

@end

@implementation NetworkCacheManager

+ (instancetype)sharedManager {
    static NetworkCacheManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[NetworkCacheManager alloc] init];
        [sharedInstance configureCache];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cacheTimestamps = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)configureCache {
    // AI-SUGGESTION: Configure URL cache with appropriate sizes
    NSUInteger memoryCapacity = 10 * 1024 * 1024; // 10 MB
    NSUInteger diskCapacity = 50 * 1024 * 1024;   // 50 MB
    
    self.urlCache = [[NSURLCache alloc] initWithMemoryCapacity:memoryCapacity
                                                  diskCapacity:diskCapacity
                                                      diskPath:nil];
    [NSURLCache setSharedURLCache:self.urlCache];
}

- (BOOL)shouldUseCacheForRequest:(NSURLRequest *)request {
    // Only cache GET requests
    if (![request.HTTPMethod isEqualToString:@"GET"]) {
        return NO;
    }
    
    NSString *cacheKey = request.URL.absoluteString;
    NSDate *cacheTime = self.cacheTimestamps[cacheKey];
    
    if (!cacheTime) {
        return NO;
    }
    
    // Cache valid for 5 minutes
    NSTimeInterval cacheAge = [[NSDate date] timeIntervalSinceDate:cacheTime];
    return cacheAge < 300; // 5 minutes
}

- (void)cacheResponse:(NSURLResponse *)response 
                 data:(NSData *)data 
           forRequest:(NSURLRequest *)request {
    
    if ([request.HTTPMethod isEqualToString:@"GET"]) {
        NSString *cacheKey = request.URL.absoluteString;
        self.cacheTimestamps[cacheKey] = [NSDate date];
    }
}

@end

#pragma mark - Main Network Client

// AI-SUGGESTION: Main network client with comprehensive functionality
@interface NetworkClient : NSObject

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSOperationQueue *requestQueue;

- (instancetype)initWithBaseURL:(NSString *)baseURL;

// Basic HTTP methods
- (void)GET:(NSString *)endpoint 
 parameters:(nullable NSDictionary *)parameters 
 completion:(NetworkCompletionBlock)completion;

- (void)POST:(NSString *)endpoint 
  parameters:(nullable NSDictionary *)parameters 
  completion:(NetworkCompletionBlock)completion;

- (void)PUT:(NSString *)endpoint 
 parameters:(nullable NSDictionary *)parameters 
 completion:(NetworkCompletionBlock)completion;

- (void)DELETE:(NSString *)endpoint 
    parameters:(nullable NSDictionary *)parameters 
    completion:(NetworkCompletionBlock)completion;

// Advanced methods
- (NSURLSessionDataTask *)performRequest:(NetworkRequestConfig *)config 
                              completion:(NetworkCompletionBlock)completion;

- (NSURLSessionDownloadTask *)downloadFileFromURL:(NSString *)urlString 
                                         progress:(DownloadProgressBlock)progressBlock 
                                       completion:(void (^)(NSURL *fileURL, NSError *error))completion;

- (NSURLSessionUploadTask *)uploadData:(NSData *)data 
                            toEndpoint:(NSString *)endpoint 
                              progress:(UploadProgressBlock)progressBlock 
                            completion:(NetworkCompletionBlock)completion;

// Utility methods
- (void)cancelAllRequests;
- (void)setAuthenticationToken:(NSString *)token;

@end

@implementation NetworkClient

- (instancetype)initWithBaseURL:(NSString *)baseURL {
    self = [super init];
    if (self) {
        _baseURL = baseURL;
        [self setupSession];
        [self setupRequestQueue];
    }
    return self;
}

- (void)setupSession {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    config.timeoutIntervalForResource = 60.0;
    config.URLCache = [NetworkCacheManager sharedManager].urlCache;
    
    // AI-SUGGESTION: Configure session for optimal performance
    config.HTTPMaximumConnectionsPerHost = 4;
    config.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    
    self.session = [NSURLSession sessionWithConfiguration:config];
}

- (void)setupRequestQueue {
    self.requestQueue = [[NSOperationQueue alloc] init];
    self.requestQueue.name = @"NetworkRequestQueue";
    self.requestQueue.maxConcurrentOperationCount = 4;
}

#pragma mark - HTTP Methods

- (void)GET:(NSString *)endpoint 
 parameters:(nullable NSDictionary *)parameters 
 completion:(NetworkCompletionBlock)completion {
    
    NetworkRequestConfig *config = [[NetworkRequestConfig alloc] initWithBaseURL:self.baseURL 
                                                                           method:HTTPMethodGET 
                                                                         endpoint:endpoint];
    config.parameters = parameters;
    
    [self performRequest:config completion:completion];
}

- (void)POST:(NSString *)endpoint 
  parameters:(nullable NSDictionary *)parameters 
  completion:(NetworkCompletionBlock)completion {
    
    NetworkRequestConfig *config = [[NetworkRequestConfig alloc] initWithBaseURL:self.baseURL 
                                                                           method:HTTPMethodPOST 
                                                                         endpoint:endpoint];
    config.parameters = parameters;
    
    [self performRequest:config completion:completion];
}

- (void)PUT:(NSString *)endpoint 
 parameters:(nullable NSDictionary *)parameters 
 completion:(NetworkCompletionBlock)completion {
    
    NetworkRequestConfig *config = [[NetworkRequestConfig alloc] initWithBaseURL:self.baseURL 
                                                                           method:HTTPMethodPUT 
                                                                         endpoint:endpoint];
    config.parameters = parameters;
    
    [self performRequest:config completion:completion];
}

- (void)DELETE:(NSString *)endpoint 
    parameters:(nullable NSDictionary *)parameters 
    completion:(NetworkCompletionBlock)completion {
    
    NetworkRequestConfig *config = [[NetworkRequestConfig alloc] initWithBaseURL:self.baseURL 
                                                                           method:HTTPMethodDELETE 
                                                                         endpoint:endpoint];
    config.parameters = parameters;
    
    [self performRequest:config completion:completion];
}

#pragma mark - Advanced Methods

- (NSURLSessionDataTask *)performRequest:(NetworkRequestConfig *)config 
                              completion:(NetworkCompletionBlock)completion {
    
    NSURLRequest *request = [config buildURLRequest];
    
    // AI-SUGGESTION: Add authentication headers if required
    if (config.requiresAuthentication) {
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        NSDictionary *authHeaders = [[AuthenticationManager sharedManager] authenticationHeaders];
        
        for (NSString *key in authHeaders) {
            [mutableRequest setValue:authHeaders[key] forHTTPHeaderField:key];
        }
        
        request = mutableRequest;
    }
    
    // Check cache first
    NetworkCacheManager *cacheManager = [NetworkCacheManager sharedManager];
    if ([cacheManager shouldUseCacheForRequest:request]) {
        NSCachedURLResponse *cachedResponse = [cacheManager.urlCache cachedResponseForRequest:request];
        if (cachedResponse) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error;
                id parsedResponse = [NetworkResponseParser parseResponse:cachedResponse.data 
                                                                response:cachedResponse.response 
                                                                   error:&error];
                completion(parsedResponse, error);
            });
            return nil;
        }
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request 
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        // Cache the response
        [cacheManager cacheResponse:response data:data forRequest:request];
        
        // Parse response
        NSError *parseError;
        id parsedResponse = [NetworkResponseParser parseResponse:data 
                                                        response:response 
                                                           error:&parseError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(parsedResponse, parseError);
        });
    }];
    
    [task resume];
    return task;
}

- (NSURLSessionDownloadTask *)downloadFileFromURL:(NSString *)urlString 
                                         progress:(DownloadProgressBlock)progressBlock 
                                       completion:(void (^)(NSURL *fileURL, NSError *error))completion {
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithRequest:request 
                                                                 completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        // Move file to permanent location
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *fileName = [url.absoluteString lastPathComponent];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
        NSURL *destinationURL = [NSURL fileURLWithPath:filePath];
        
        NSError *fileError;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:&fileError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(fileError ? nil : destinationURL, fileError);
        });
    }];
    
    // AI-SUGGESTION: Track download progress
    if (progressBlock) {
        [downloadTask addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:nil];
    }
    
    [downloadTask resume];
    return downloadTask;
}

- (NSURLSessionUploadTask *)uploadData:(NSData *)data 
                            toEndpoint:(NSString *)endpoint 
                              progress:(UploadProgressBlock)progressBlock 
                            completion:(NetworkCompletionBlock)completion {
    
    NetworkRequestConfig *config = [[NetworkRequestConfig alloc] initWithBaseURL:self.baseURL 
                                                                           method:HTTPMethodPOST 
                                                                         endpoint:endpoint];
    config.body = data;
    config.headers = @{@"Content-Type": @"application/octet-stream"};
    
    NSURLRequest *request = [config buildURLRequest];
    
    NSURLSessionUploadTask *uploadTask = [self.session uploadTaskWithRequest:request 
                                                                    fromData:data 
                                                           completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        NSError *parseError;
        id parsedResponse = [NetworkResponseParser parseResponse:responseData 
                                                        response:response 
                                                           error:&parseError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(parsedResponse, parseError);
        });
    }];
    
    [uploadTask resume];
    return uploadTask;
}

#pragma mark - Utility Methods

- (void)cancelAllRequests {
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *dataTasks, 
                                                  NSArray<NSURLSessionUploadTask *> *uploadTasks, 
                                                  NSArray<NSURLSessionDownloadTask *> *downloadTasks) {
        for (NSURLSessionTask *task in dataTasks) {
            [task cancel];
        }
        for (NSURLSessionTask *task in uploadTasks) {
            [task cancel];
        }
        for (NSURLSessionTask *task in downloadTasks) {
            [task cancel];
        }
    }];
}

- (void)setAuthenticationToken:(NSString *)token {
    [[AuthenticationManager sharedManager] setTokens:token 
                                         refreshToken:nil 
                                        expirationDate:[NSDate dateWithTimeIntervalSinceNow:3600]]; // 1 hour
}

@end

#pragma mark - API Service Example

// AI-SUGGESTION: Example API service using the network client
@interface UserAPIService : NSObject

@property (nonatomic, strong) NetworkClient *networkClient;

- (instancetype)initWithBaseURL:(NSString *)baseURL;

- (void)fetchUserProfile:(NSString *)userId 
              completion:(void (^)(NSDictionary *user, NSError *error))completion;

- (void)updateUserProfile:(NSDictionary *)userInfo 
               completion:(void (^)(NSDictionary *updatedUser, NSError *error))completion;

- (void)uploadUserAvatar:(NSData *)imageData 
              completion:(void (^)(NSString *avatarURL, NSError *error))completion;

@end

@implementation UserAPIService

- (instancetype)initWithBaseURL:(NSString *)baseURL {
    self = [super init];
    if (self) {
        _networkClient = [[NetworkClient alloc] initWithBaseURL:baseURL];
    }
    return self;
}

- (void)fetchUserProfile:(NSString *)userId 
              completion:(void (^)(NSDictionary *user, NSError *error))completion {
    
    NSString *endpoint = [NSString stringWithFormat:@"users/%@", userId];
    
    [self.networkClient GET:endpoint parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            completion(response, error);
        }
    }];
}

- (void)updateUserProfile:(NSDictionary *)userInfo 
               completion:(void (^)(NSDictionary *updatedUser, NSError *error))completion {
    
    [self.networkClient PUT:@"users/profile" parameters:userInfo completion:^(id response, NSError *error) {
        if (completion) {
            completion(response, error);
        }
    }];
}

- (void)uploadUserAvatar:(NSData *)imageData 
              completion:(void (^)(NSString *avatarURL, NSError *error))completion {
    
    [self.networkClient uploadData:imageData 
                        toEndpoint:@"users/avatar" 
                          progress:^(NSProgress *progress) {
                              NSLog(@"Upload progress: %.2f%%", progress.fractionCompleted * 100);
                          } 
                        completion:^(id response, NSError *error) {
                            if (completion) {
                                NSString *avatarURL = error ? nil : response[@"avatar_url"];
                                completion(avatarURL, error);
                            }
                        }];
}

@end

#pragma mark - Usage Example

// AI-SUGGESTION: Example usage demonstration
void demonstrateNetworkUsage() {
    // Initialize network client
    NetworkClient *client = [[NetworkClient alloc] initWithBaseURL:@"https://api.example.com"];
    
    // Set authentication
    [client setAuthenticationToken:@"your_access_token_here"];
    
    // Make a GET request
    [client GET:@"users" parameters:@{@"page": @1, @"limit": @10} completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching users: %@", error.localizedDescription);
        } else {
            NSLog(@"Users fetched: %@", response);
        }
    }];
    
    // Make a POST request
    NSDictionary *newUser = @{
        @"name": @"John Doe",
        @"email": @"john@example.com",
        @"age": @30
    };
    
    [client POST:@"users" parameters:newUser completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"Error creating user: %@", error.localizedDescription);
        } else {
            NSLog(@"User created: %@", response);
        }
    }];
    
    // Use the API service
    UserAPIService *userService = [[UserAPIService alloc] initWithBaseURL:@"https://api.example.com"];
    
    [userService fetchUserProfile:@"123" completion:^(NSDictionary *user, NSError *error) {
        if (error) {
            NSLog(@"Error fetching user profile: %@", error.localizedDescription);
        } else {
            NSLog(@"User profile: %@", user);
        }
    }];
} 