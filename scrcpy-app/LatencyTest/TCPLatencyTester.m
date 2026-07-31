//
//  TCPLatencyTester.m
//  Scrcpy Remote
//
//  Created by Claude on 12/27/24.
//

#import "TCPLatencyTester.h"
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <netdb.h>
#import <errno.h>

// Debug logging macro - displays both to console and printf for CLI use
#define LOG_DEBUG(fmt, ...) do { \
    NSLog(@"[TCPLatencyTester] " fmt, ##__VA_ARGS__); \
    printf("[TCPLatencyTester] " fmt "\n", ##__VA_ARGS__); \
} while(0)

@interface TCPLatencyTester ()

@property (nonatomic, readwrite, copy) NSString *host;
@property (nonatomic, readwrite, copy) NSString *port;

@end

@implementation TCPLatencyTester

#pragma mark - Initialization

- (instancetype)initWithHost:(NSString *)host port:(NSString *)port {
    self = [super init];
    if (self) {
        _host = [host copy];
        _port = [port copy];
        _connectionTimeout = 10.0; // Default 10 seconds
        _readTimeout = 5.0;        // Default 5 seconds
        
        LOG_DEBUG("Initialized with target: %s:%s", [_host UTF8String], [_port UTF8String]);
    }
    return self;
}

- (instancetype)initWithHost:(NSString *)host portNumber:(NSInteger)port {
    return [self initWithHost:host port:[NSString stringWithFormat:@"%ld", (long)port]];
}

#pragma mark - Public Methods

- (void)testLatency:(TCPLatencyCallback)completion {
    [self testLatencyWithCustomData:nil completion:completion];
}

- (void)testLatencyWithCustomData:(NSData *)data completion:(TCPLatencyCallback)completion {
    LOG_DEBUG("Starting TCP latency test to %s:%s", [self.host UTF8String], [self.port UTF8String]);
    
    // Validate input parameters
    if (!self.host || self.host.length == 0) {
        NSError *error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                             code:1001 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid host"}];
        LOG_DEBUG("Error: Invalid host");
        completion(nil, error);
        return;
    }
    
    if (!self.port || self.port.length == 0) {
        NSError *error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                             code:1002 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid port"}];
        LOG_DEBUG("Error: Invalid port");
        completion(nil, error);
        return;
    }
    
    // Use default data if none provided
    if (!data) {
        NSString *defaultMessage = @"PING\n";
        data = [defaultMessage dataUsingEncoding:NSUTF8StringEncoding];
        LOG_DEBUG("Using default PING message (%zu bytes)", data.length);
    } else {
        LOG_DEBUG("Using custom data payload (%zu bytes)", data.length);
    }
    
    // Run the test asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self performTCPLatencyTestWithData:data completion:completion];
    });
}

- (void)testAverageLatencyWithCount:(NSInteger)count completion:(TCPLatencyCallback)completion {
    if (count <= 0) {
        count = 1; // Ensure at least one test is performed
    }
    
    LOG_DEBUG("Starting average TCP latency test with %ld iterations", (long)count);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSNumber *> *results = [NSMutableArray array];
        
        for (NSInteger i = 0; i < count; i++) {
            LOG_DEBUG("Running TCP latency test iteration %ld of %ld", (long)(i + 1), (long)count);
            
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            __block NSNumber *testResult = nil;
            __block NSError *testError = nil;
            
            [self testLatency:^(NSNumber * _Nullable latencyMs, NSError * _Nullable error) {
                testResult = latencyMs;
                testError = error;
                dispatch_semaphore_signal(semaphore);
            }];
            
            // Wait for this test to complete
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
            if (testResult && !testError) {
                [results addObject:testResult];
                LOG_DEBUG("Test iteration %ld succeeded: %.2f ms", (long)(i + 1), [testResult doubleValue]);
            } else {
                LOG_DEBUG("Test iteration %ld failed: %s", (long)(i + 1), 
                         testError ? [testError.localizedDescription UTF8String] : "unknown error");
            }
            
            // Add a small delay between tests (except for the last one)
            if (i < count - 1) {
                [NSThread sleepForTimeInterval:0.1];
            }
        }
        
        // Calculate results
        dispatch_async(dispatch_get_main_queue(), ^{
            LOG_DEBUG("All test iterations completed. Successful tests: %lu/%ld", 
                     (unsigned long)results.count, (long)count);
            
            if (results.count > 0) {
                // Calculate average latency
                double totalLatency = 0;
                for (NSNumber *result in results) {
                    totalLatency += [result doubleValue];
                }
                double averageLatency = totalLatency / results.count;
                LOG_DEBUG("Average TCP latency: %.2f ms", averageLatency);
                completion(@(averageLatency), nil);
            } else {
                // No successful tests
                NSError *noResultsError = [NSError errorWithDomain:@"TCPLatencyTester" 
                                                              code:1004 
                                                          userInfo:@{NSLocalizedDescriptionKey: @"No successful latency tests"}];
                LOG_DEBUG("Error: No successful latency tests");
                completion(nil, noResultsError);
            }
        });
    });
}

#pragma mark - TCP Implementation

- (void)performTCPLatencyTestWithData:(NSData *)data completion:(TCPLatencyCallback)completion {
    int socketFd = -1;
    NSError *error = nil;
    NSNumber *latencyMs = nil;
    
    @try {
        // Record overall start time
        NSDate *overallStartTime = [NSDate date];
        LOG_DEBUG("TCP test started at: %s", [[overallStartTime description] UTF8String]);
        
        // Create socket
        LOG_DEBUG("Creating socket...");
        socketFd = socket(AF_INET, SOCK_STREAM, 0);
        if (socketFd < 0) {
            LOG_DEBUG("Error: Failed to create socket (errno: %d)", errno);
            error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                        code:2001 
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to create socket"}];
            return;
        }
        
        // Set socket timeouts
        LOG_DEBUG("Setting socket timeouts (connect: %.1fs, read: %.1fs)...", 
                 self.connectionTimeout, self.readTimeout);
        
        struct timeval connectTimeout;
        connectTimeout.tv_sec = (long)self.connectionTimeout;
        connectTimeout.tv_usec = (long)((self.connectionTimeout - (long)self.connectionTimeout) * 1000000);
        
        struct timeval readTimeout;
        readTimeout.tv_sec = (long)self.readTimeout;
        readTimeout.tv_usec = (long)((self.readTimeout - (long)self.readTimeout) * 1000000);
        
        if (setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, sizeof(readTimeout)) < 0) {
            LOG_DEBUG("Error: Failed to set read timeout (errno: %d)", errno);
            error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                        code:2002 
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to set socket timeout"}];
            return;
        }
        
        if (setsockopt(socketFd, SOL_SOCKET, SO_SNDTIMEO, &connectTimeout, sizeof(connectTimeout)) < 0) {
            LOG_DEBUG("Error: Failed to set send timeout (errno: %d)", errno);
            error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                        code:2003 
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to set socket timeout"}];
            return;
        }
        
        // Resolve hostname - getaddrinfo supports both IPv4 (A) and IPv6 (AAAA)
        // records; the legacy gethostbyname is IPv4-only and always fails for
        // IPv6-only DDNS hosts
        LOG_DEBUG("Resolving hostname: %s", [self.host UTF8String]);
        struct addrinfo hints;
        struct addrinfo *resolved = NULL;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        hints.ai_protocol = IPPROTO_TCP;
        int gaiResult = getaddrinfo(self.host.UTF8String, self.port.UTF8String, &hints, &resolved);
        if (gaiResult != 0 || resolved == NULL) {
            LOG_DEBUG("Error: Failed to resolve hostname (getaddrinfo: %s)", gai_strerror(gaiResult));
            if (resolved) { freeaddrinfo(resolved); }
            error = [NSError errorWithDomain:@"TCPLatencyTester"
                                        code:2004
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to resolve host"}];
            return;
        }

        // Copy first result then release the list (safe on early returns)
        struct sockaddr_storage serverAddr;
        socklen_t serverAddrLen = resolved->ai_addrlen;
        int addrFamily = resolved->ai_family;
        memcpy(&serverAddr, resolved->ai_addr, resolved->ai_addrlen);
        freeaddrinfo(resolved);
        LOG_DEBUG("Hostname resolved (family: %s)", addrFamily == AF_INET6 ? "IPv6" : "IPv4");

        // Recreate the socket if the resolved family is not IPv4 (socket above
        // was created as AF_INET)
        if (addrFamily != AF_INET) {
            close(socketFd);
            socketFd = socket(addrFamily, SOCK_STREAM, 0);
            if (socketFd < 0) {
                LOG_DEBUG("Error: Failed to recreate socket for family %d (errno: %d)", addrFamily, errno);
                error = [NSError errorWithDomain:@"TCPLatencyTester"
                                            code:2004
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to create socket"}];
                return;
            }
            setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, sizeof(readTimeout));
            setsockopt(socketFd, SOL_SOCKET, SO_SNDTIMEO, &connectTimeout, sizeof(connectTimeout));
        }

        // Connect to server
        LOG_DEBUG("Connecting to %s:%s...", [self.host UTF8String], [self.port UTF8String]);
        NSDate *connectStartTime = [NSDate date];

        if (connect(socketFd, (struct sockaddr *)&serverAddr, serverAddrLen) < 0) {
            LOG_DEBUG("Error: Failed to connect (errno: %d)", errno);
            error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                        code:2005 
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to connect to target"}];
            return;
        }
        
        NSTimeInterval connectTime = [[NSDate date] timeIntervalSinceDate:connectStartTime] * 1000;
        LOG_DEBUG("Connected in %.2f ms", connectTime);
        
        // Send data
        LOG_DEBUG("Sending data (%zu bytes)...", data.length);
        NSDate *sendStartTime = [NSDate date];
        
        ssize_t bytesSent = send(socketFd, data.bytes, data.length, 0);
        if (bytesSent != data.length) {
            LOG_DEBUG("Error: Failed to send data (sent: %zd, expected: %zu, errno: %d)", 
                     bytesSent, data.length, errno);
            error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                        code:2006 
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to send data"}];
            return;
        }
        
        NSTimeInterval sendTime = [[NSDate date] timeIntervalSinceDate:sendStartTime] * 1000;
        LOG_DEBUG("Data sent in %.2f ms", sendTime);
        
        // Receive response
        LOG_DEBUG("Waiting for response...");
        NSDate *recvStartTime = [NSDate date];
        
        char responseBuffer[1024];
        ssize_t bytesReceived = recv(socketFd, responseBuffer, sizeof(responseBuffer) - 1, 0);
        
        if (bytesReceived <= 0) {
            LOG_DEBUG("Error: Failed to receive response (received: %zd, errno: %d)", 
                     bytesReceived, errno);
            error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                        code:2007 
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to receive response"}];
            return;
        }
        
        NSTimeInterval recvTime = [[NSDate date] timeIntervalSinceDate:recvStartTime] * 1000;
        LOG_DEBUG("Response received in %.2f ms (%zd bytes)", recvTime, bytesReceived);
        
        // Null-terminate and log received data
        responseBuffer[bytesReceived] = '\0';
        LOG_DEBUG("Received data: \"%s\"", responseBuffer);
        
        // Calculate total round-trip time
        NSDate *overallEndTime = [NSDate date];
        NSTimeInterval totalLatency = [overallEndTime timeIntervalSinceDate:overallStartTime] * 1000;
        latencyMs = @(totalLatency);
        
        LOG_DEBUG("Total TCP round-trip latency: %.2f ms", totalLatency);
        LOG_DEBUG("Breakdown - Connect: %.2f ms, Send: %.2f ms, Receive: %.2f ms", 
                 connectTime, sendTime, recvTime);
        
    }
    @catch (NSException *exception) {
        LOG_DEBUG("Exception occurred: %s", [exception.reason UTF8String]);
        error = [NSError errorWithDomain:@"TCPLatencyTester" 
                                    code:2010 
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception: %@", exception.reason]}];
    }
    @finally {
        // Close socket if opened
        if (socketFd >= 0) {
            LOG_DEBUG("Closing socket...");
            close(socketFd);
            LOG_DEBUG("Socket closed");
        }
        
        // Call completion handler on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (latencyMs) {
                LOG_DEBUG("TCP test completed successfully with latency: %.2f ms", [latencyMs doubleValue]);
                completion(latencyMs, nil);
            } else if (error) {
                LOG_DEBUG("TCP test failed with error: %s", [error.localizedDescription UTF8String]);
                completion(nil, error);
            } else {
                LOG_DEBUG("TCP test completed with no results");
                NSError *genericError = [NSError errorWithDomain:@"TCPLatencyTester" 
                                                            code:2099 
                                                        userInfo:@{NSLocalizedDescriptionKey: @"No latency results"}];
                completion(nil, genericError);
            }
        });
    }
}

@end 