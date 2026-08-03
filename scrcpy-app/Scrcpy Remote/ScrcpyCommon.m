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
            // scrcpy 移植层(C)
            @"SDL Inited":                        NSLocalizedString(@"SDL Inited", nil),
            @"SDL Window Created":                NSLocalizedString(@"SDL Window Created", nil),
            @"SDL Window Appeared":               NSLocalizedString(@"SDL Window Appeared", nil),
            @"Scrcpy connected":                  NSLocalizedString(@"Scrcpy connected", nil),
            @"Scrcpy disconnected":               NSLocalizedString(@"Scrcpy disconnected", nil),
            @"Scrcpy connect failed":             NSLocalizedString(@"Scrcpy connect failed", nil),
            @"First frame rendered":              NSLocalizedString(@"First frame rendered", nil),
            // ADB 会话
            @"Connecting to ADB device":          NSLocalizedString(@"Connecting to ADB device", nil),
            @"User disconnected from ADB client": NSLocalizedString(@"User disconnected from ADB client", nil),
            // VNC 会话
            @"SDL initialized successfully":      NSLocalizedString(@"SDL initialized successfully", nil),
            @"SDL window created successfully":   NSLocalizedString(@"SDL window created successfully", nil),
            @"VNC client connected successfully": NSLocalizedString(@"VNC client connected successfully", nil),
            @"VNC client cleaned up":             NSLocalizedString(@"VNC client cleaned up", nil),
            @"VNC connection cancelled":          NSLocalizedString(@"VNC connection cancelled", nil),
            @"VNC message wait failed":           NSLocalizedString(@"VNC message wait failed", nil),
            @"VNC server message handling failed":NSLocalizedString(@"VNC server message handling failed", nil),
            // 带参数的前缀(后面拼主机/端口, 前缀匹配即可)
            @"Connecting to ":                    NSLocalizedString(@"Connecting to ", nil),
            @"Failed to connect to VNC server ":  NSLocalizedString(@"Failed to connect to VNC server ", nil),
        };
    });
    NSString *hit = map[message];
    if (hit) return hit;
    // 后面拼接了主机/错误详情时按前缀翻译, 详情原样保留。
    // 取最长匹配, 避免短前缀(如 "Connecting to ")抢走长键的匹配。
    NSString *best = nil;
    for (NSString *key in map) {
        if ([message hasPrefix:key] && key.length > best.length) {
            best = key;
        }
    }
    if (best) {
        return [map[best] stringByAppendingString:[message substringFromIndex:best.length]];
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

