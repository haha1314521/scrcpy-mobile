//
//  ScrcpyCommon.h
//  Scrcpy Remote
//
//  Created by Ethan on 6/2/25.
//

#import <Foundation/Foundation.h>
#import "scrcpy-porting.h"

#define ScrcpyStatusUpdatedNotificationName @"ScrcpyStatusUpdated"

// 声明 ScrcpyUpdateStatus 函数
void ScrcpyUpdateStatus(enum ScrcpyStatus status, const char *message);

// 诊断标记(确认日志在工作 / 标记关键节点)

@protocol ScrcpyClientProtocol <NSObject>

@required

// Method for start scrcpy client with arguments
- (void)startWithArguments:(NSDictionary *)arguments completion:(void (^)(enum ScrcpyStatus statusCode, NSString *message))completion;

// Method for disconnect scrcpy client
- (void)disconnect;

@end
