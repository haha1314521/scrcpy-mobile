//
//  ScrcpyCommonRuntime.m
//  Scrcpy Remote
//
//  Created by Ethan on 6/28/25.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// SDL 编译时用宏把 CFRunLoopRunInMode 换成了下面的 _fix 版本, 因此这里的间隔
// 直接决定了触摸事件的投递延迟。
//
// 原值 0.5 秒的问题(实测日志确认):
//   事件连续到达时用 0.0002 秒快轮询; 一旦出现短暂空档就退回 0.5 秒长等待,
//   这 0.5 秒内新到的触摸(尤其是"抬手")会被压住, 超时后才一起放出 ——
//   表现为: 单击被安卓判成长按(阈值恰好 0.5 秒), 或两次点击被合并成双击。
//   日志实证: 滑动过程中 MOVE 每 33ms 一个, 中间突然停顿 514ms, 之后 MOVE+UP 同时补发。
//
// 改为 10 毫秒: 最坏多等 10ms(无感), 触摸恢复跟手。
#define CFRunLoopNormalInterval     0.01f
#define CFRunLoopHandledSourceInterval 0.0002f

CFRunLoopRunResult CFRunLoopRunInMode_fix(CFRunLoopMode mode, CFTimeInterval seconds, Boolean returnAfterSourceHandled) {
    static CFTimeInterval nextLoopInterval = CFRunLoopNormalInterval;
    CFRunLoopRunResult result = CFRunLoopRunInMode(mode, nextLoopInterval, returnAfterSourceHandled);
    if (result == kCFRunLoopRunHandledSource) {
        nextLoopInterval = CFRunLoopHandledSourceInterval;
    } else {
        nextLoopInterval = CFRunLoopNormalInterval;
    }
    return result;
}
