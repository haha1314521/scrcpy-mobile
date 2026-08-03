//
//  ADBLatencyTester.m
//  Scrcpy Remote
//
//  Created by Claude on 12/27/24.
//

#import "ADBLatencyTester.h"
#ifdef LATENCY_TESTER_CLI
#import "ADBClient_cli.h"
#else
#import "ADBClient.h"
#endif
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <netdb.h>

// Debug logging macro - displays both to console and printf for CLI use
#define LOG_DEBUG(fmt, ...) do { \
    NSLog(@"[ADBLatencyTester] " fmt, ##__VA_ARGS__); \
    printf("[ADBLatencyTester] " fmt "\n", ##__VA_ARGS__); \
} while(0)

@interface ADBLatencyTester ()

@property (nonatomic, strong) NSDictionary *session;
@property (nonatomic, copy) NSString *deviceSerial;
@property (nonatomic, copy) NSString *hostName;
@property (nonatomic, copy) NSString *port;

@end

@implementation ADBLatencyTester

#pragma mark - Initialization

- (instancetype)initWithSession:(NSDictionary *)session {
    self = [super init];
    if (self) {
        _session = session;
        
        // Extract device serial from session
        _hostName = session[@"hostReal"];
        _port = session[@"port"];
        if (_hostName && _port) {
            _deviceSerial = [NSString stringWithFormat:@"%@:%@", _hostName, _port];
            LOG_DEBUG("Initialized with device: %s:%s", [_hostName UTF8String], [_port UTF8String]);
        } else {
            LOG_DEBUG("Warning: Invalid session parameters hostReal=%s, port=%s", 
                     [_hostName UTF8String] ?: "nil", 
                     [_port UTF8String] ?: "nil");
        }
    }
    return self;
}

#pragma mark - Public Methods

- (void)testLatency:(ADBLatencyCallback)completion {
    LOG_DEBUG("Starting latency test for device: %s", [self.deviceSerial UTF8String]);
    
    if (!self.deviceSerial || self.deviceSerial.length == 0) {
        NSError *error = [NSError errorWithDomain:@"ADBLatencyTester" 
                                             code:1001 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid device serial"}];
        LOG_DEBUG("Error: Invalid device serial");
        completion(nil, error);
        return;
    }
    
    // First try the direct ADB protocol method for more accurate results
    LOG_DEBUG("Trying direct ADB protocol method first...");
    [self testDirectADBHandshake:^(NSNumber * _Nullable latencyMs, NSError * _Nullable error) {
        if (latencyMs && !error) {
            // Direct method succeeded
            LOG_DEBUG("Direct ADB protocol test succeeded: %.2f ms", [latencyMs doubleValue]);
            completion(latencyMs, nil);
            return;
        }
        
        // Fall back to ADB command method if direct method fails
        LOG_DEBUG("Direct ADB protocol test failed: %s. Falling back to ADB command method...", 
                 error ? [error.localizedDescription UTF8String] : "unknown error");
        
        [self testADBCommandLatency:^(NSNumber * _Nullable cmdLatencyMs, NSError * _Nullable cmdError) {
            if (cmdLatencyMs && !cmdError) {
                LOG_DEBUG("ADB command test succeeded: %.2f ms", [cmdLatencyMs doubleValue]);
            } else {
                LOG_DEBUG("ADB command test failed: %s", 
                         cmdError ? [cmdError.localizedDescription UTF8String] : "unknown error");
            }
            completion(cmdLatencyMs, cmdError);
        }];
    }];
}

- (void)testAverageLatencyWithCount:(NSInteger)count completion:(ADBLatencyCallback)completion {
    if (count <= 0) {
        count = 1; // Ensure at least one test is performed
    }
    
    LOG_DEBUG("Starting average latency test with %ld iterations", (long)count);
    
    // Keep track of total latency and number of successful tests
    __block double totalLatency = 0;
    __block NSInteger successfulTests = 0;
    __block NSInteger testsRemaining = count;
    
    // Create a recursive function to run multiple tests
    // Use a local variable to avoid retain cycles
    __block void (^weakTestBlock)(void);
    
    weakTestBlock = ^{
        LOG_DEBUG("Running latency test iteration %ld of %ld", 
                 (long)(count - testsRemaining + 1), (long)count);
        
        [self testLatency:^(NSNumber * _Nullable latencyMs, NSError * _Nullable error) {
            testsRemaining--;
            
            if (latencyMs && !error) {
                totalLatency += [latencyMs doubleValue];
                successfulTests++;
                LOG_DEBUG("Test iteration %ld succeeded: %.2f ms", 
                         (long)(count - testsRemaining), [latencyMs doubleValue]);
            } else {
                LOG_DEBUG("Test iteration %ld failed: %s", 
                         (long)(count - testsRemaining), 
                         error ? [error.localizedDescription UTF8String] : "unknown error");
            }
            
            if (testsRemaining > 0) {
                // Continue testing using a local copy to avoid retain cycles
                void (^localTestBlock)(void) = weakTestBlock;
                if (localTestBlock) {
                    localTestBlock();
                }
            } else {
                // All tests completed
                LOG_DEBUG("All test iterations completed. Successful tests: %ld/%ld", 
                         (long)successfulTests, (long)count);
                
                if (successfulTests > 0) {
                    // Calculate average latency
                    double averageLatency = totalLatency / successfulTests;
                    LOG_DEBUG("Average latency: %.2f ms", averageLatency);
                    completion(@(averageLatency), nil);
                } else {
                    // No successful tests
                    NSError *noResultsError = [NSError errorWithDomain:@"ADBLatencyTester" 
                                                                  code:1004 
                                                              userInfo:@{NSLocalizedDescriptionKey: @"No successful latency tests"}];
                    LOG_DEBUG("Error: No successful latency tests");
                    completion(nil, noResultsError);
                }
            }
        }];
    };
    
    // Start the first test
    weakTestBlock();
}

#pragma mark - ADB Protocol Implementation

- (void)testDirectADBHandshake:(ADBLatencyCallback)completion {
    LOG_DEBUG("Starting direct ADB protocol handshake test to %s:%s", 
             [self.hostName UTF8String], [self.port UTF8String]);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        int socketFd = -1;
        NSError *error = nil;
        NSNumber *latencyMs = nil;
        
        @try {
            // Record overall start time
            // 注意: 这里先不计时。域名解析(getaddrinfo)在没有 DNS 缓存时可能耗时
            // 数秒(实测冷启动一次用了 2.7 秒), 那是一次性的名称解析开销, 不属于
            // 网络往返延迟。若算进去, 首次测速会虚高到几千毫秒, 再点一次(走缓存)
            // 又恢复正常 —— 正是用户反馈的现象。
            // 真正的计时在域名解析完成之后开始。
            NSDate *overallStartTime = nil;
            
            // Resolve hostname first - getaddrinfo supports both IPv4 (A) and
            // IPv6 (AAAA) records; the legacy gethostbyname is IPv4-only and
            // always fails for IPv6-only DDNS hosts
            LOG_DEBUG("Resolving hostname: %s", [self.hostName UTF8String]);
            struct addrinfo hints;
            struct addrinfo *resolved = NULL;
            memset(&hints, 0, sizeof(hints));
            hints.ai_family = AF_UNSPEC;
            hints.ai_socktype = SOCK_STREAM;
            hints.ai_protocol = IPPROTO_TCP;
            int gaiResult = getaddrinfo(self.hostName.UTF8String, self.port.UTF8String, &hints, &resolved);
            if (gaiResult != 0 || resolved == NULL) {
                LOG_DEBUG("Error: Failed to resolve hostname (getaddrinfo: %s)", gai_strerror(gaiResult));
                if (resolved) { freeaddrinfo(resolved); }
                error = [NSError errorWithDomain:@"ADBLatencyTester"
                                            code:2003
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

            // 域名解析已完成, 从这里开始计时(只测网络往返, 不含 DNS)
            overallStartTime = [NSDate date];
            LOG_DEBUG("Test timing started (after DNS)");

            // Create socket matching the resolved address family
            LOG_DEBUG("Creating socket...");
            socketFd = socket(addrFamily, SOCK_STREAM, 0);
            if (socketFd < 0) {
                LOG_DEBUG("Error: Failed to create socket (errno: %d)", errno);
                error = [NSError errorWithDomain:@"ADBLatencyTester"
                                            code:2001
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to create socket"}];
                return;
            }

            // Set socket timeout
            LOG_DEBUG("Setting socket timeout to 10 seconds...");
            struct timeval timeout;
            timeout.tv_sec = 10;
            timeout.tv_usec = 0;
            if (setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0) {
                LOG_DEBUG("Error: Failed to set socket timeout (errno: %d)", errno);
                error = [NSError errorWithDomain:@"ADBLatencyTester"
                                            code:2002
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to set socket timeout"}];
                return;
            }

            // Connect
            LOG_DEBUG("Connecting to %s:%s...", [self.hostName UTF8String], [self.port UTF8String]);

            // Record connection start time
            NSDate *connectStartTime = [NSDate date];
            if (connect(socketFd, (struct sockaddr *)&serverAddr, serverAddrLen) < 0) {
                LOG_DEBUG("Error: Failed to connect (errno: %d)", errno);
                error = [NSError errorWithDomain:@"ADBLatencyTester"
                                            code:2004
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to connect to ADB server"}];
                return;
            }
            
            NSTimeInterval connectTime = [[NSDate date] timeIntervalSinceDate:connectStartTime] * 1000;
            LOG_DEBUG("Connected in %.2f ms", connectTime);
            
            // Prepare CNXN message
            LOG_DEBUG("Preparing ADB CNXN message...");
            NSString *identityString = @"host::objc-adb-tester\0";
            NSData *identityData = [identityString dataUsingEncoding:NSUTF8StringEncoding];
            NSData *cnxnMessage = [self packADBMessageWithCommand:ADB_CMD_CNXN
                                                             arg0:ADB_VERSION
                                                             arg1:ADB_MAX_PAYLOAD
                                                          payload:identityData];
            LOG_DEBUG("CNXN message prepared: %zu bytes", cnxnMessage.length);
            
            // Send CNXN message
            LOG_DEBUG("Sending CNXN message...");
            NSDate *sendStartTime = [NSDate date];
            ssize_t bytesSent = send(socketFd, cnxnMessage.bytes, cnxnMessage.length, 0);
            if (bytesSent != cnxnMessage.length) {
                LOG_DEBUG("Error: Failed to send CNXN message (sent: %zd, expected: %zu, errno: %d)", 
                         bytesSent, cnxnMessage.length, errno);
                error = [NSError errorWithDomain:@"ADBLatencyTester" 
                                            code:2005 
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to send CNXN message"}];
                return;
            }
            
            NSTimeInterval sendTime = [[NSDate date] timeIntervalSinceDate:sendStartTime] * 1000;
            LOG_DEBUG("CNXN message sent in %.2f ms", sendTime);
            
            // Receive response
            LOG_DEBUG("Waiting for ADB response...");
            NSDate *recvStartTime = [NSDate date];
            NSData *headerData = [self receiveExactBytes:socketFd length:24];
            if (!headerData || headerData.length != 24) {
                LOG_DEBUG("Error: Failed to receive header response (received: %zu bytes)", 
                         headerData ? headerData.length : 0);
                error = [NSError errorWithDomain:@"ADBLatencyTester" 
                                            code:2006 
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to receive header response"}];
                return;
            }
            LOG_DEBUG("Received header: 24 bytes");
            
            // Unpack header
            LOG_DEBUG("Unpacking ADB header...");
            NSString *command;
            uint32_t arg0, arg1, dataLength, dataCrc32;
            NSString *magic;
            [self unpackADBMessageHeader:headerData 
                                 command:&command 
                                    arg0:&arg0 
                                    arg1:&arg1 
                              dataLength:&dataLength 
                               dataCrc32:&dataCrc32 
                                   magic:&magic];
            LOG_DEBUG("Header unpacked: command=%s, arg0=0x%08x, arg1=0x%08x, dataLength=%u", 
                     [command UTF8String], arg0, arg1, dataLength);
            
            // Receive payload if any
            NSData *payloadData = nil;
            if (dataLength > 0) {
                LOG_DEBUG("Receiving payload: %u bytes...", dataLength);
                payloadData = [self receiveExactBytes:socketFd length:dataLength];
                if (!payloadData || payloadData.length != dataLength) {
                    LOG_DEBUG("Error: Failed to receive payload (received: %zu bytes, expected: %u)", 
                             payloadData ? payloadData.length : 0, dataLength);
                    error = [NSError errorWithDomain:@"ADBLatencyTester" 
                                                code:2007 
                                            userInfo:@{NSLocalizedDescriptionKey: @"Failed to receive payload"}];
                    return;
                }
                LOG_DEBUG("Payload received: %u bytes", dataLength);
                
                // Try to show payload as string if possible
                if (payloadData) {
                    NSString *payloadStr = [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];
                    if (payloadStr) {
                        LOG_DEBUG("Payload as string: \"%s\"", [payloadStr UTF8String]);
                    }
                }
            }
            
            NSTimeInterval recvTime = [[NSDate date] timeIntervalSinceDate:recvStartTime] * 1000;
            LOG_DEBUG("Response received in %.2f ms", recvTime);
            
            // Calculate total handshake time regardless of command type
            NSDate *overallEndTime = [NSDate date];
            NSTimeInterval totalLatency = [overallEndTime timeIntervalSinceDate:overallStartTime] * 1000;
            latencyMs = @(totalLatency);
            
            // Check the response type (but still report latency for AUTH)
            if ([command isEqualToString:ADB_CMD_CNXN]) {
                LOG_DEBUG("Handshake successful! ADB version: 0x%08x, Max payload: %u bytes", arg0, arg1);
                LOG_DEBUG("Total handshake latency: %.2f ms", totalLatency);
                
            } else if ([command isEqualToString:ADB_CMD_AUTH]) {
                LOG_DEBUG("Authentication required (type: %u). Reporting handshake latency anyway: %.2f ms", 
                         arg0, totalLatency);
                
                // Return success but with a note
                LOG_DEBUG("Note: Full connection would require authentication which is not implemented");
                
            } else {
                LOG_DEBUG("Unexpected command received: %s. Reporting latency anyway: %.2f ms",
                         [command UTF8String], totalLatency);
                
                // Return success but with a note
                LOG_DEBUG("Note: Unexpected response type, but latency measurement is still valid");
            }
        }
        @catch (NSException *exception) {
            LOG_DEBUG("Exception occurred: %s", [exception.reason UTF8String]);
            error = [NSError errorWithDomain:@"ADBLatencyTester" 
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
            
            // Call completion handler on main queue - always report latency if we got it
            if (latencyMs) {
                LOG_DEBUG("Test completed with latency: %.2f ms", [latencyMs doubleValue]);
                completion(latencyMs, nil); // Return latency even with AUTH responses
            } else if (error) {
                LOG_DEBUG("Test failed with error: %s", [error.localizedDescription UTF8String]);
                completion(nil, error);
            } else {
                LOG_DEBUG("Test completed with no results");
                NSError *genericError = [NSError errorWithDomain:@"ADBLatencyTester" 
                                                            code:2099 
                                                        userInfo:@{NSLocalizedDescriptionKey: @"No latency results"}];
                completion(nil, genericError);
            }
        }
    });
}

#pragma mark - ADB Protocol Helper Methods

- (NSData *)packADBMessageWithCommand:(NSString *)command arg0:(uint32_t)arg0 arg1:(uint32_t)arg1 payload:(NSData *)payload {
    // Create mutable data to hold the message
    NSMutableData *messageData = [NSMutableData dataWithCapacity:24 + payload.length];
    
    // Calculate checksum
    uint32_t checksum = [self calculateChecksumForData:payload];
    
    // Convert command to uint32_t - ensure it's always 4 bytes
    const char *cmdStr = [command UTF8String];
    uint32_t cmdInt = 0;
    if (strlen(cmdStr) >= 4) {
        memcpy(&cmdInt, cmdStr, 4);
    }
    uint32_t magicInt = cmdInt ^ 0xFFFFFFFF;
    
    // Create header
    struct {
        char cmd[4];
        uint32_t arg0;
        uint32_t arg1;
        uint32_t dataLength;
        uint32_t dataCrc32;
        char magic[4];
    } header;
    
    memcpy(header.cmd, cmdStr, MIN(strlen(cmdStr), 4));
    header.arg0 = arg0;
    header.arg1 = arg1;
    header.dataLength = (uint32_t)payload.length;
    header.dataCrc32 = checksum;
    
    char magicStr[4];
    memcpy(magicStr, &magicInt, 4);
    memcpy(header.magic, magicStr, 4);
    
    // Append header
    [messageData appendBytes:&header length:sizeof(header)];
    
    // Append payload
    if (payload.length > 0) {
        [messageData appendData:payload];
    }
    
    return messageData;
}

- (void)unpackADBMessageHeader:(NSData *)headerData 
                       command:(NSString **)command 
                          arg0:(uint32_t *)arg0 
                          arg1:(uint32_t *)arg1 
                    dataLength:(uint32_t *)dataLength 
                     dataCrc32:(uint32_t *)dataCrc32 
                         magic:(NSString **)magic {
    
    struct {
        char cmd[4];
        uint32_t arg0;
        uint32_t arg1;
        uint32_t dataLength;
        uint32_t dataCrc32;
        char magic[4];
    } header;
    
    [headerData getBytes:&header length:sizeof(header)];
    
    char cmdStr[5] = {0};
    char magicStr[5] = {0};
    memcpy(cmdStr, header.cmd, 4);
    memcpy(magicStr, header.magic, 4);
    
    *command = [NSString stringWithUTF8String:cmdStr];
    *arg0 = header.arg0;
    *arg1 = header.arg1;
    *dataLength = header.dataLength;
    *dataCrc32 = header.dataCrc32;
    *magic = [NSString stringWithUTF8String:magicStr];
}

- (uint32_t)calculateChecksumForData:(NSData *)data {
    uint32_t checksum = 0;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        checksum = (checksum + bytes[i]) & 0xFFFFFFFF;
    }
    return checksum;
}

- (NSData *)receiveExactBytes:(int)socketFd length:(NSUInteger)length {
    NSMutableData *data = [NSMutableData dataWithCapacity:length];
    size_t totalReceived = 0;
    
    LOG_DEBUG("Receiving exactly %zu bytes...", length);
    
    while (totalReceived < length) {
        size_t remaining = length - totalReceived;
        uint8_t buffer[4096];
        ssize_t received = recv(socketFd, buffer, MIN(remaining, sizeof(buffer)), 0);
        
        if (received <= 0) {
            LOG_DEBUG("Socket receive error or connection closed (received: %zd, errno: %d)", 
                     received, errno);
            return nil; // Error or connection closed
        }
        
        [data appendBytes:buffer length:received];
        totalReceived += received;
        LOG_DEBUG("Received chunk: %zd bytes, total: %zu/%zu bytes", 
                 received, totalReceived, length);
    }
    
    return data;
}

#pragma mark - ADB Command Method

- (void)testADBCommandLatency:(ADBLatencyCallback)completion {
    LOG_DEBUG("Starting ADB command latency test");
    
    if (!ADBClient.shared.isADBLaunched) {
        LOG_DEBUG("Error: ADB Client not launched");
        NSError *error = [NSError errorWithDomain:@"ADBLatencyTester" 
                                             code:1002 
                                         userInfo:@{NSLocalizedDescriptionKey: @"ADB Client not launched"}];
        completion(nil, error);
        return;
    }
    
    // Measure latency by timing how long it takes to run a simple ADB command
    NSDate *startTime = [NSDate date];
    LOG_DEBUG("Running ADB command: adb shell echo ping");
    
    // Run a simple command to test connectivity and measure round-trip time.
    // 显式指定本次要测的设备: 测延迟发生在会话之外, adb 里可能连着多台设备,
    // 不指定就会报 "more than one device/emulator"。
    NSArray *pingCmd = self.deviceSerial.length > 0
        ? @[@"-s", self.deviceSerial, @"shell", @"echo", @"ping"]
        : @[@"shell", @"echo", @"ping"];
    [ADBClient.shared executeADBCommandAsync:pingCmd callback:^(NSString * _Nullable output, int returnCode) {
        NSDate *endTime = [NSDate date];
        LOG_DEBUG("ADB command completed with return code: %d", returnCode);
        
        if (returnCode != 0 || !output || ![output containsString:@"ping"]) {
            LOG_DEBUG("ADB command failed. Output: %s", [output UTF8String] ?: "null");
            NSError *error = [NSError errorWithDomain:@"ADBLatencyTester" 
                                                 code:1003 
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to execute ADB command"}];
            completion(nil, error);
            return;
        }
        
        // Calculate latency in milliseconds
        NSTimeInterval latencySeconds = [endTime timeIntervalSinceDate:startTime];
        NSNumber *latencyMs = @(latencySeconds * 1000);
        LOG_DEBUG("ADB command latency: %.2f ms", [latencyMs doubleValue]);
        
        // Return result via callback
        completion(latencyMs, nil);
    }];
}

@end

#pragma mark - Main Function for CLI

#ifdef LATENCY_TESTER_CLI
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Default values
        NSString *host = @"127.0.0.1";
        NSString *port = @"5555";
        int testCount = 5;
        BOOL verbose = NO;
        
        // Parse command line arguments
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            
            if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--host"]) {
                if (i + 1 < argc) {
                    host = [NSString stringWithUTF8String:argv[++i]];
                }
            } else if ([arg isEqualToString:@"-p"] || [arg isEqualToString:@"--port"]) {
                if (i + 1 < argc) {
                    port = [NSString stringWithUTF8String:argv[++i]];
                }
            } else if ([arg isEqualToString:@"-c"] || [arg isEqualToString:@"--count"]) {
                if (i + 1 < argc) {
                    testCount = atoi(argv[++i]);
                    if (testCount <= 0) testCount = 1;
                }
            } else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"--verbose"]) {
                verbose = YES;
            } else if ([arg isEqualToString:@"--help"]) {
                printf("ADB Latency Tester - Tests latency to an ADB server\n\n");
                printf("Usage: adb-latency-tester [options]\n\n");
                printf("Options:\n");
                printf("  -h, --host HOST      Host to connect to (default: 127.0.0.1)\n");
                printf("  -p, --port PORT      Port to connect to (default: 5555)\n");
                printf("  -c, --count COUNT    Number of tests to run for average (default: 5)\n");
                printf("  -v, --verbose        Enable verbose output\n");
                printf("  --help               Show this help message\n");
                return 0;
            }
        }
        
        // Create session dictionary
        NSDictionary *sessionDict = @{
            @"hostReal": host,
            @"port": port,
            @"deviceType": @"adb"
        };
        
        // Print test info
        printf("ADB Latency Tester\n");
        printf("Target: %s:%s\n", [host UTF8String], [port UTF8String]);
        printf("Running %d test(s)...\n\n", testCount);
        
        // Create tester
        ADBLatencyTester *tester = [[ADBLatencyTester alloc] initWithSession:sessionDict];
        
        // Use a semaphore to wait for async operations
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        // Test direct protocol latency
        if (verbose) {
            printf("Testing direct ADB protocol latency...\n");
        }
        
        __block BOOL directSuccess = NO;
        [tester testDirectADBHandshake:^(NSNumber * _Nullable latencyMs, NSError * _Nullable error) {
            if (error) {
                if (verbose) {
                    printf("Direct protocol test failed: %s\n", [error.localizedDescription UTF8String]);
                }
            } else {
                directSuccess = YES;
                printf("Direct protocol latency: %.2f ms\n", [latencyMs doubleValue]);
            }
            dispatch_semaphore_signal(semaphore);
        }];
        
        // Wait for direct test to complete
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        // Test ADB command latency if direct protocol failed
        if (!directSuccess && verbose) {
            printf("Testing ADB command latency...\n");
            
            [tester testADBCommandLatency:^(NSNumber * _Nullable latencyMs, NSError * _Nullable error) {
                if (error) {
                    printf("ADB command test failed: %s\n", [error.localizedDescription UTF8String]);
                } else {
                    printf("ADB command latency: %.2f ms\n", [latencyMs doubleValue]);
                }
                dispatch_semaphore_signal(semaphore);
            }];
            
            // Wait for command test to complete
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
        
        // Run average latency test
        printf("\nRunning average latency test (%d iterations)...\n", testCount);
        
        [tester testAverageLatencyWithCount:testCount completion:^(NSNumber * _Nullable latencyMs, NSError * _Nullable error) {
            if (error) {
                printf("Average latency test failed: %s\n", [error.localizedDescription UTF8String]);
            } else {
                printf("Average latency: %.2f ms\n", [latencyMs doubleValue]);
            }
            dispatch_semaphore_signal(semaphore);
        }];
        
        // Wait for average test to complete
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    return 0;
}
#endif 