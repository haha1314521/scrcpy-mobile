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
#import <signal.h>
#import <string.h>
#import <unistd.h>

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

// ===== 崩溃捕获 =====
// 系统的崩溃日志(分析数据里的 .ips)始终找不到, 因此让 App 自己把崩溃现场
// 写进应用日志(用户能直接导出的那个文件)。
// 信号处理里只用 async-signal-safe 的 write/backtrace_symbols_fd。
static void scrcpy_crash_handler(int sig) {
    const char *head = "\n[CRASH] ======== 收到致命信号 ========\n";
    write(STDOUT_FILENO, head, strlen(head));

    const char *name = "unknown";
    switch (sig) {
        case SIGSEGV: name = "SIGSEGV (非法内存访问)\n"; break;
        case SIGBUS:  name = "SIGBUS (总线错误)\n";      break;
        case SIGILL:  name = "SIGILL (非法指令)\n";      break;
        case SIGFPE:  name = "SIGFPE (算术错误)\n";      break;
        case SIGABRT: name = "SIGABRT (主动中止)\n";     break;
        case SIGTRAP: name = "SIGTRAP (断点/陷阱)\n";    break;
        case SIGPIPE: name = "SIGPIPE (管道断开)\n";     break;
        default:      name = "其它信号\n";               break;
    }
    write(STDOUT_FILENO, "[CRASH] ", 8);
    write(STDOUT_FILENO, name, strlen(name));

    void *frames[64];
    int n = backtrace(frames, 64);
    backtrace_symbols_fd(frames, n, STDOUT_FILENO);

    const char *tail = "[CRASH] ======== 调用栈结束 ========\n";
    write(STDOUT_FILENO, tail, strlen(tail));
    fsync(STDOUT_FILENO);

    signal(sig, SIG_DFL);
    raise(sig);
}

// 未捕获的 ObjC 异常(NSException)
static void scrcpy_exception_handler(NSException *exception) {
    printf("\n[CRASH] ======== 未捕获异常 ========\n");
    printf("[CRASH] name: %s\n", exception.name.UTF8String ?: "");
    printf("[CRASH] reason: %s\n", exception.reason.UTF8String ?: "");
    for (NSString *sym in exception.callStackSymbols) {
        printf("[CRASH] %s\n", sym.UTF8String ?: "");
    }
    printf("[CRASH] ======== 异常结束 ========\n");
    fflush(stdout);
}

__attribute__((constructor))
static void scrcpy_install_exit_diagnostic(void) {
    atexit(scrcpy_exit_diagnostic);

    int sigs[] = { SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT, SIGTRAP };
    for (unsigned i = 0; i < sizeof(sigs)/sizeof(sigs[0]); i++) {
        signal(sigs[i], scrcpy_crash_handler);
    }
    NSSetUncaughtExceptionHandler(&scrcpy_exception_handler);
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

    // 3) 带可变内容(域名/地址/系统错误串)的报错: 用关键词匹配, 给中文解释并保留原文
    static NSArray<NSArray<NSString *> *> *patterns = nil;
    static dispatch_once_t once2;
    dispatch_once(&once2, ^{
        patterns = @[
            @[@"failed to resolve host",   @"无法解析域名。请检查网络连接，或确认域名填写是否正确。"],
            @[@"nodename nor servname",    @"无法解析域名。请检查网络连接，或确认域名填写是否正确。"],
            @[@"Name or service not known",@"无法解析域名。请检查网络连接，或确认域名填写是否正确。"],
            @[@"unauthorized",             @"设备未授权。请在安卓设备上确认并接受 ADB 授权请求。"],
            @[@"device offline",           @"设备离线。请确认设备已开启无线调试且在线。"],
            @[@"Connection refused",       @"连接被拒绝。请确认设备已执行 adb tcpip 并开放了该端口。"],
            @[@"No route to host",         @"无法访问该主机。请检查地址与网络。"],
            @[@"Network is unreachable",   @"网络不可达。请检查网络连接。"],
            @[@"Operation timed out",      @"连接超时。请检查网络是否可达。"],
            @[@"timed out",                @"连接超时。请检查网络是否可达。"],
            @[@"more than one device",     @"检测到多个设备，无法确定操作对象。"],
        ];
    });
    for (NSArray<NSString *> *p in patterns) {
        if ([message rangeOfString:p[0] options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return [NSString stringWithFormat:@"%@\n\n(%@)", p[1],
                    [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
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

