//
//  ScrcpyCommon.m
//  Scrcpy Remote
//
//  Created by Ethan on 6/2/25.
//

#import "ScrcpyCommon.h"
#import <Foundation/Foundation.h>

// scrcpy 移植层(C)里的状态文案是硬编码英文, 且已编进静态库改不动。
// 这里是所有状态通知的唯一出口, 统一做本地化映射, 各监听方(ObjC/Swift)都能拿到中文。
static NSString *ScrcpyLocalizedStatusMessage(NSString *message) {
    if (message.length == 0) return message;
    static NSDictionary<NSString *, NSString *> *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"SDL Inited":            NSLocalizedString(@"SDL Inited", nil),
            @"SDL Window Created":    NSLocalizedString(@"SDL Window Created", nil),
            @"SDL Window Appeared":   NSLocalizedString(@"SDL Window Appeared", nil),
            @"Scrcpy connected":      NSLocalizedString(@"Scrcpy connected", nil),
            @"Scrcpy disconnected":   NSLocalizedString(@"Scrcpy disconnected", nil),
            @"Scrcpy connect failed": NSLocalizedString(@"Scrcpy connect failed", nil),
        };
    });
    NSString *hit = map[message];
    if (hit) return hit;
    // 后面拼接了错误详情时按前缀翻译, 详情原样保留
    for (NSString *key in map) {
        if ([message hasPrefix:key]) {
            return [map[key] stringByAppendingString:[message substringFromIndex:key.length]];
        }
    }
    return message;
}

void ScrcpyUpdateStatus(enum ScrcpyStatus status, const char *message) {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:@(status) forKey:@"status"];

    // 如果有消息，添加到 userInfo 中
    if (message != NULL) {
        NSString *messageString = [NSString stringWithUTF8String:message];
        if (messageString) {
            userInfo[@"message"] = ScrcpyLocalizedStatusMessage(messageString);
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ScrcpyStatusUpdatedNotificationName 
                                                        object:nil 
                                                      userInfo:userInfo];
}

