//
//  ScrcpyCommon.m
//  Scrcpy Remote
//
//  Created by Ethan on 6/2/25.
//

#import "ScrcpyCommon.h"
#import <Foundation/Foundation.h>
#import <execinfo.h>
#import <stdlib.h>

// ===== 退出诊断 =====
// 现象: App 有时"闪退"却不产生任何崩溃日志。崩溃(含被系统杀)一定会留 .ips,
// 不留日志说明是进程正常退出(exit)。App 内置了完整 adb 命令行代码, 而 adb 是
// 命令行程序, 出错时会直接 exit() 结束进程 —— 在 App 里就表现为整个软件消失。
// 这里注册 atexit 钩子: 一旦有人调用 exit, 就把调用栈打进日志, 直接定位是谁干的。
static void scrcpy_exit_diagnostic(void) {
    void *frames[64];
    int n = backtrace(frames, 64);
    char **symbols = backtrace_symbols(frames, n);
    printf("\n[EXIT] ======== 进程正在退出(exit 被调用) ========\n");
    if (symbols) {
        for (int i = 0; i < n; i++) {
            printf("[EXIT] #%02d %s\n", i, symbols[i]);
        }
        free(symbols);
    }
    printf("[EXIT] ======== 调用栈结束 ========\n");
    fflush(stdout);
    fflush(stderr);
}

__attribute__((constructor))
static void scrcpy_install_exit_diagnostic(void) {
    atexit(scrcpy_exit_diagnostic);
}

// 会话开始时打一条标记, 用于确认日志确实在工作(便于排查"日志里搜不到内容")
void ScrcpyDiagnosticMark(const char *tag) {
    printf("[DIAG] %s\n", tag ?: "");
    fflush(stdout);
    NSLog(@"[DIAG] %s", tag ?: "");
}

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

