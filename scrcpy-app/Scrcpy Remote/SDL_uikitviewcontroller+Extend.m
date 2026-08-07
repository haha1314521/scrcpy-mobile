//
//  SDL_uikitviewcontroller+Extend.m
//  Scrcpy Remote
//
//  Created by Ethan on 1/4/25.
//

#import "SDL_uikitviewcontroller+Extend.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <SDL2/SDL_events.h>
#import <SDL2/SDL_system.h>
#import "ScrcpyClientWrapper.h"
#import "ADBClient.h"
#import "ScrcpyADBClient.h"
#import "ScrcpyRuntime.h"
#import "ScrcpyMenuView.h"
#import "ScrcpyInputMaskView.h"
#import "ScrcpyCommon.h"
#import "Scrcpy_Remote-Swift.h"
#import "ScrcpyConstants.h"

// External notification name from ScrcpyRuntime
extern NSString * const ScrcpyRemoteOrientationChangedNotification;

@interface SDL_uikitviewcontroller () <ScrcpyMenuViewDelegate>
@property (nonatomic, assign)   NSInteger  homeIndicatorHidden;
@end

@implementation SDL_uikitviewcontroller (Extend)

// Key for menuView associated object
static char menuViewKey;
static char inputMaskViewKey;
static char lockedOrientationMaskKey;
static char orientationLockEnabledKey;

#pragma mark - Method Swizzling for Orientation Control

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        // Swizzle supportedInterfaceOrientations
        SEL originalSelector = @selector(supportedInterfaceOrientations);
        SEL swizzledSelector = @selector(scrcpy_supportedInterfaceOrientations);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        // If the original method doesn't exist, add it first
        BOOL didAddMethod = class_addMethod(class,
                                            originalSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                               swizzledSelector,
                               method_getImplementation(originalMethod),
                               method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }

        NSLog(@"📱 [SDL_uikitviewcontroller] Method swizzling completed for supportedInterfaceOrientations");
    });
}

- (UIInterfaceOrientationMask)scrcpy_supportedInterfaceOrientations {
    // If orientation lock is enabled, return only the locked orientation
    if ([self isOrientationLockEnabled]) {
        UIInterfaceOrientationMask lockedMask = [self lockedOrientationMask];
        NSLog(@"📱 [SDL_uikitviewcontroller] Returning locked orientation mask: %lu", (unsigned long)lockedMask);
        return lockedMask;
    }

    // Otherwise, call original implementation (which allows all orientations)
    return [self scrcpy_supportedInterfaceOrientations];
}

// Getter for menuView
- (ScrcpyMenuView *)menuView {
    return objc_getAssociatedObject(self, &menuViewKey);
}

// Setter for menuView
- (void)setMenuView:(ScrcpyMenuView *)menuView {
    objc_setAssociatedObject(self, &menuViewKey, menuView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Getter for inputMaskView
- (ScrcpyInputMaskView *)inputMaskView {
    return objc_getAssociatedObject(self, &inputMaskViewKey);
}

// Setter for inputMaskView
- (void)setInputMaskView:(ScrcpyInputMaskView *)inputMaskView {
    objc_setAssociatedObject(self, &inputMaskViewKey, inputMaskView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Getter for lockedOrientationMask
- (UIInterfaceOrientationMask)lockedOrientationMask {
    NSNumber *value = objc_getAssociatedObject(self, &lockedOrientationMaskKey);
    return value ? [value unsignedIntegerValue] : UIInterfaceOrientationMaskAll;
}

// Setter for lockedOrientationMask
- (void)setLockedOrientationMask:(UIInterfaceOrientationMask)mask {
    objc_setAssociatedObject(self, &lockedOrientationMaskKey, @(mask), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Getter for orientationLockEnabled
- (BOOL)isOrientationLockEnabled {
    NSNumber *value = objc_getAssociatedObject(self, &orientationLockEnabledKey);
    return value ? [value boolValue] : NO;
}

// Setter for orientationLockEnabled
- (void)setOrientationLockEnabled:(BOOL)enabled {
    objc_setAssociatedObject(self, &orientationLockEnabledKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Update video layer frame
    for (CALayer *layer in self.view.layer.sublayers) {
        if ([layer isKindOfClass:AVSampleBufferDisplayLayer.class]) {
            layer.frame = self.view.bounds;
        }
    }
    
    // Update menu view layout if it exists
    if (self.menuView) {
        [self.menuView updateLayout];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Initialize the ScrappyMenuView with appropriate size
    __weak typeof(self) weakSelf = self;
    self.menuView = [[ScrcpyMenuView alloc] initWithFrame:CGRectZero]; // Frame will be set correctly during initialization
    self.menuView.delegate = weakSelf;
    
    // 根据当前连接的设备类型配置菜单
    [self configureMenuForCurrentDeviceType];
    
    [self.menuView addToActiveWindow];
    
    // 监听键盘显示和隐藏的通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    // 监听 VNC 提示（例如：剪贴板同步成功）
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleVNCTipNotification:)
                                                 name:kNotificationVNCClipboardSynced
                                               object:nil];

    // 监听远程设备方向变化通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRemoteOrientationChanged:)
                                                 name:ScrcpyRemoteOrientationChangedNotification
                                               object:nil];

    // 监听断开连接通知，以便重置方向锁定
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDisconnectForOrientationReset:)
                                                 name:ScrcpyRequestDisconnectNotification
                                               object:nil];

    // 监听状态更新通知，检测断开连接状态
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleStatusUpdateForOrientationReset:)
                                                 name:ScrcpyStatusUpdatedNotificationName
                                               object:nil];

    // Check if there's already a known remote orientation (frame arrived before viewDidAppear)
    // Apply it now since we missed the notification
    [self applyPendingRemoteOrientation];
}

-(void)applyPendingRemoteOrientation {
    // Check if remote orientation is already known (frames arrived before viewDidAppear)
    if (!IsRemoteOrientationKnown()) {
        NSLog(@"📱 [SDL_uikitviewcontroller] No pending remote orientation to apply");
        return;
    }

    int width = 0, height = 0;
    BOOL isLandscape = GetCurrentRemoteOrientation(&width, &height);

    NSLog(@"📱 [SDL_uikitviewcontroller] Applying pending remote orientation: %@ (%dx%d)",
          isLandscape ? @"Landscape" : @"Portrait", width, height);

    // Force orientation change
    [self forceOrientationToLandscape:isLandscape];

    // Schedule layout updates
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateDisplayLayerFrame];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateDisplayLayerFrame];
    });
}

-(void)viewWillUnload
{
    [super viewWillUnload];

    // Unlock orientation when view is about to be unloaded
    [self unlockOrientation];

    self.homeIndicatorHidden = 0;
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    NSLog(@"Reset ViewControllers HomeIndicatorAutoHidden.");
}

- (void)dealloc
{
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - VNC Tips

-(void)handleVNCTipNotification:(NSNotification *)notification {
    BOOL isEmpty = [notification.userInfo[kKeyIsEmpty] boolValue];
    NSString *message = isEmpty
        ? NSLocalizedString(@"No Local Clipboard Content", nil)
        : NSLocalizedString(@"Synced Local Clipboard Content", nil);

    // Show a concise, one-line tip without exposing clipboard contents
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - Remote Orientation Change

-(void)handleRemoteOrientationChanged:(NSNotification *)notification {
    BOOL isLandscape = [notification.userInfo[@"isLandscape"] boolValue];
    int remoteWidth = [notification.userInfo[@"width"] intValue];
    int remoteHeight = [notification.userInfo[@"height"] intValue];
    BOOL isFirstFrame = [notification.userInfo[@"isFirstFrame"] boolValue];

    NSLog(@"📱 [SDL_uikitviewcontroller] Remote orientation %@: %@ (%dx%d)",
          isFirstFrame ? @"initial" : @"changed",
          isLandscape ? @"Landscape" : @"Portrait", remoteWidth, remoteHeight);

    // Force orientation change
    [self forceOrientationToLandscape:isLandscape];

    // Schedule layout update after a short delay to ensure orientation change completes
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateDisplayLayerFrame];
    });

    // Also update after a longer delay for iOS animation completion
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateDisplayLayerFrame];
    });
}

-(void)updateDisplayLayerFrame {
    // Force layout update
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];

    // Explicitly update all AVSampleBufferDisplayLayer frames
    for (CALayer *layer in self.view.layer.sublayers) {
        if ([layer isKindOfClass:AVSampleBufferDisplayLayer.class]) {
            CGRect newFrame = self.view.bounds;
            if (!CGRectEqualToRect(layer.frame, newFrame)) {
                NSLog(@"📱 [SDL_uikitviewcontroller] Updating display layer frame: %@ -> %@",
                      NSStringFromCGRect(layer.frame), NSStringFromCGRect(newFrame));
                layer.frame = newFrame;
            }
        }
    }
}

-(void)forceOrientationToLandscape:(BOOL)landscape {
    UIWindowScene *windowScene = self.view.window.windowScene;
    if (!windowScene) {
        NSLog(@"⚠️ [SDL_uikitviewcontroller] No window scene available for orientation change");
        return;
    }

    // Set the locked orientation mask to prevent local device rotation
    UIInterfaceOrientationMask targetMask = landscape
        ? UIInterfaceOrientationMaskLandscape
        : UIInterfaceOrientationMaskPortrait;

    [self setLockedOrientationMask:targetMask];
    [self setOrientationLockEnabled:YES];

    NSLog(@"🔒 [SDL_uikitviewcontroller] Orientation locked to: %@", landscape ? @"Landscape" : @"Portrait");

    // Check if current orientation already matches target
    UIInterfaceOrientation currentOrientation = windowScene.interfaceOrientation;
    BOOL currentIsLandscape = UIInterfaceOrientationIsLandscape(currentOrientation);

    if (currentIsLandscape == landscape) {
        NSLog(@"📱 [SDL_uikitviewcontroller] Orientation already matches: %@, updating layer frame",
              landscape ? @"Landscape" : @"Portrait");
        // Still update the layer frame in case it's not correct
        [self updateDisplayLayerFrame];
        return;
    }

    if (@available(iOS 16.0, *)) {
        // iOS 16+ uses requestGeometryUpdate
        UIWindowSceneGeometryPreferencesIOS *preferences =
            [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:targetMask];

        __weak typeof(self) weakSelf = self;
        [windowScene requestGeometryUpdateWithPreferences:preferences
                                             errorHandler:^(NSError * _Nonnull error) {
            NSLog(@"❌ [SDL_uikitviewcontroller] Failed to update geometry: %@", error.localizedDescription);
            // Still try to update layer frame on error
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf updateDisplayLayerFrame];
            });
        }];

        // Also update the view controller to ensure it reports the correct orientations
        [self setNeedsUpdateOfSupportedInterfaceOrientations];

        NSLog(@"📱 [SDL_uikitviewcontroller] Requested orientation change to %@ (iOS 16+)",
              landscape ? @"Landscape" : @"Portrait");
    } else {
        // iOS 15 and earlier - use device orientation value setting
        UIDeviceOrientation targetOrientation = landscape
            ? UIDeviceOrientationLandscapeLeft
            : UIDeviceOrientationPortrait;

        // Force orientation using private API (setValue:forKey:)
        [[UIDevice currentDevice] setValue:@(targetOrientation) forKey:@"orientation"];

        // Trigger orientation change
        [UIViewController attemptRotationToDeviceOrientation];

        NSLog(@"📱 [SDL_uikitviewcontroller] Forced orientation change to %@ (iOS 15-)",
              landscape ? @"Landscape" : @"Portrait");
    }
}

-(void)unlockOrientation {
    // Disable orientation lock
    [self setOrientationLockEnabled:NO];
    [self setLockedOrientationMask:UIInterfaceOrientationMaskAll];

    // Reset orientation tracking state in runtime
    ResetScrcpyOrientationTracking();

    NSLog(@"🔓 [SDL_uikitviewcontroller] Orientation unlocked, following local device orientation");

    // Update supported orientations
    if (@available(iOS 16.0, *)) {
        [self setNeedsUpdateOfSupportedInterfaceOrientations];

        // Request geometry update to allow all orientations
        UIWindowScene *windowScene = self.view.window.windowScene;
        if (windowScene) {
            UIWindowSceneGeometryPreferencesIOS *preferences =
                [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskAll];

            [windowScene requestGeometryUpdateWithPreferences:preferences
                                                 errorHandler:^(NSError * _Nonnull error) {
                NSLog(@"⚠️ [SDL_uikitviewcontroller] Failed to unlock geometry: %@", error.localizedDescription);
            }];
        }
    } else {
        [UIViewController attemptRotationToDeviceOrientation];
    }
}

-(void)handleDisconnectForOrientationReset:(NSNotification *)notification {
    NSLog(@"📱 [SDL_uikitviewcontroller] Disconnect requested, unlocking orientation");
    // Dispatch to main thread since this may be called from background
    if ([NSThread isMainThread]) {
        [self unlockOrientation];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlockOrientation];
        });
    }
}

-(void)handleStatusUpdateForOrientationReset:(NSNotification *)notification {
    NSNumber *statusNumber = notification.userInfo[@"status"];
    if (!statusNumber) return;

    int status = [statusNumber intValue];

    // Check if status is disconnected (ScrcpyStatusDisconnected = 0)
    if (status == 0) {
        NSLog(@"📱 [SDL_uikitviewcontroller] Status changed to disconnected, unlocking orientation");
        // Dispatch to main thread since this notification comes from background thread
        if ([NSThread isMainThread]) {
            [self unlockOrientation];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self unlockOrientation];
            });
        }
    }
}

#pragma mark - Keyboard Notifications

- (void)keyboardWillShow:(NSNotification *)notification {
    // 当键盘显示时，创建并显示输入遮罩视图，并在键盘上方显示工具栏
    if (!self.inputMaskView) {
        self.inputMaskView = [[ScrcpyInputMaskView alloc] initWithFrame:self.view.bounds];
    }
    [self.inputMaskView showInView:self.view];

    // 读取键盘最终位置与动画参数
    NSDictionary *info = notification.userInfo;
    CGRect kbFrameScreen = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [info[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    // 将键盘frame转换到当前视图坐标系
    // Convert to window coordinates so the overlay (added to window) can align correctly
    CGRect kbFrameInView = [self.view.window convertRect:kbFrameScreen fromWindow:nil];

    // 获取当前设备类型（adb/vnc）
    SessionConnectionManager *connectionManager = [SessionConnectionManager shared];
    NSString *deviceTypeString = [connectionManager getCurrentDeviceType];

    // 更新并动画展示工具栏
    [self.inputMaskView showKeyboardToolbarAboveKeyboardFrame:kbFrameInView
                                              deviceTypeString:deviceTypeString
                                                     duration:duration
                                                         curve:curve];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    // 当键盘隐藏时，隐藏工具栏并移除输入遮罩视图
    [self.inputMaskView hideKeyboardToolbarWithNotification:notification];
    [self.inputMaskView hide];
}

#pragma mark - Menu Configuration

- (void)configureMenuForCurrentDeviceType {
    // 获取当前设备类型
    SessionConnectionManager *connectionManager = [SessionConnectionManager shared];
    NSString *deviceTypeString = [connectionManager getCurrentDeviceType];
    
    // 使用便利方法转换设备类型
    ScrcpyDeviceType deviceType = [ScrcpyMenuView deviceTypeFromString:deviceTypeString];
    
    // 记录日志
    if (deviceTypeString) {
        NSLog(@"🎛️ [SDL_uikitviewcontroller] Configuring menu for %@ device", deviceTypeString);
    } else {
        NSLog(@"⚠️ [SDL_uikitviewcontroller] No current device type found, using ADB default");
    }
    
    // 配置菜单视图
    [self.menuView configureForDeviceType:deviceType];
}

#pragma mark - ScrappyMenuViewDelegate

- (void)didTapBackButton {
    // 发送 Back 按键事件 (Ctrl+B)
    ScrcpySendKeycodeEvent(SDL_SCANCODE_B, SDLK_b, KMOD_LCTRL);
}

- (void)didTapHomeButton {
    // 发送 Home 按键事件 (Ctrl+H)
    ScrcpySendKeycodeEvent(SDL_SCANCODE_H, SDLK_h, KMOD_LCTRL);
}

- (void)didTapSwitchButton {
    // 发送 Switch 按键事件 (Ctrl+S)
    ScrcpySendKeycodeEvent(SDL_SCANCODE_S, SDLK_s, KMOD_LCTRL);
}

- (void)didTapKeyboardButton {
    // Toggle keyboard
    SDL_StartTextInput();
}

- (void)didTapActionsButton {
    // 显示功能开发中的提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Actions", @"Actions title") 
                                                                   message:NSLocalizedString(@"This feature is under development, please wait.", @"WIP message") 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil];
    
    [alert addAction:okAction];
    
    // 在主线程中显示Alert
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)didTapRebootButton {
    // Confirm before rebooting the remote device
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Reboot Device", @"Reboot title")
                                                                   message:NSLocalizedString(@"Reboot the remote Android device? The connection will be closed.", @"Reboot confirm message")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *rebootAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Reboot", @"Reboot button")
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
        NSLog(@"🔄 [SDL_uikitviewcontroller] Sending adb reboot to remote device");
        [ADBClient.shared executeADBCommandAsync:@[@"reboot"] callback:^(NSString * _Nullable result, int returnCode) {
            NSLog(@"🔄 [SDL_uikitviewcontroller] adb reboot returned %d: %@", returnCode, result);
        }];
        // The device goes down immediately - close our side after a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:ScrcpyRequestDisconnectNotification object:nil];
        });
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel button")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:cancelAction];
    [alert addAction:rebootAction];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)didTapCleanupButton {
    // 清理后台: adb shell am kill-all
    //
    // am kill-all 只会杀可安全结束的后台进程, 不碰前台和系统 persistent 进程。
    // 不过挂机跑的任务(比如在后台的支付宝)也算后台进程, 会被一并结束,
    // 所以这里加确认框, 避免误触把正在跑的任务杀掉。
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Clean Background", @"Cleanup title")
                                                                  message:NSLocalizedString(@"Kill background apps on the remote device? Tasks running in the background will be stopped.", @"Cleanup confirm message")
                                                           preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cleanAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Clean", @"Cleanup button")
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *action) {
        NSLog(@"\U0001F9F9 [SDL_uikitviewcontroller] Sending am kill-all to remote device");
        [ADBClient.shared executeADBCommandAsync:@[@"shell", @"am", @"kill-all"] callback:^(NSString * _Nullable result, int returnCode) {
            NSLog(@"\U0001F9F9 [SDL_uikitviewcontroller] am kill-all returned %d: %@", returnCode, result);
        }];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel button")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:cancelAction];
    [alert addAction:cleanAction];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)didTapDisconnectButton {
    // Post notification to disconnect
    [[NSNotificationCenter defaultCenter] postNotificationName:ScrcpyRequestDisconnectNotification object:nil];
}

#pragma mark - VNC Zoom Delegate Methods

- (void)didPinchWithScale:(CGFloat)scale {
    NSLog(@"🔍 [SDL_uikitviewcontroller] VNC pinch with scale: %.2f", scale);
    
    // 发送VNC缩放通知给VNCClient处理
    NSDictionary *userInfo = @{
        @"scale": @(scale),
        @"centerX": @(0.5), // 默认屏幕中心，后续可改为实际触摸中心
        @"centerY": @(0.5),
        @"isFinished": @(NO)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ScrcpyVNCZoomNotification" object:nil userInfo:userInfo];
}

- (void)didPinchWithScale:(CGFloat)scale centerX:(CGFloat)centerX centerY:(CGFloat)centerY {
    NSLog(@"🔍 [SDL_uikitviewcontroller] VNC pinch with scale: %.2f, center: (%.3f, %.3f)", scale, centerX, centerY);
    
    // 发送VNC缩放通知给VNCClient处理（包含实际触摸中心点）
    NSDictionary *userInfo = @{
        @"scale": @(scale),
        @"centerX": @(centerX),
        @"centerY": @(centerY),
        @"isFinished": @(NO)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ScrcpyVNCZoomNotification" object:nil userInfo:userInfo];
}

- (void)didPinchEndWithFinalScale:(CGFloat)finalScale {
    NSLog(@"🔍 [SDL_uikitviewcontroller] VNC pinch ended with final scale: %.2f", finalScale);
    
    // 发送VNC缩放结束通知给VNCClient处理
    NSDictionary *userInfo = @{
        @"scale": @(finalScale),
        @"centerX": @(0.5), // 默认屏幕中心，后续可改为实际触摸中心
        @"centerY": @(0.5),
        @"isFinished": @(YES)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ScrcpyVNCZoomNotification" object:nil userInfo:userInfo];
}

- (void)didPinchEndWithFinalScale:(CGFloat)finalScale centerX:(CGFloat)centerX centerY:(CGFloat)centerY {
    NSLog(@"🔍 [SDL_uikitviewcontroller] VNC pinch ended with final scale: %.2f, center: (%.3f, %.3f)", finalScale, centerX, centerY);
    
    // 发送VNC缩放结束通知给VNCClient处理（包含实际触摸中心点）
    NSDictionary *userInfo = @{
        @"scale": @(finalScale),
        @"centerX": @(centerX),
        @"centerY": @(centerY),
        @"isFinished": @(YES)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ScrcpyVNCZoomNotification" object:nil userInfo:userInfo];
}

#pragma mark - VNC Drag Gesture Delegate

- (void)didDragWithState:(NSString *)state location:(CGPoint)location viewSize:(CGSize)viewSize {
    NSLog(@"🎯 [SDL_uikitviewcontroller] VNC drag - state: %@, location: (%.1f, %.1f), viewSize: (%.1f, %.1f)", 
          state, location.x, location.y, viewSize.width, viewSize.height);
    
    // 发送VNC拖拽通知给VNCClient处理
    NSDictionary *userInfo = @{
        @"state": state,
        @"location": [NSValue valueWithCGPoint:location],
        @"viewSize": [NSValue valueWithCGSize:viewSize]
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ScrcpyVNCDragNotification" object:nil userInfo:userInfo];
}

@end
