//
//  ScrcpyActionsBridge.h
//  Scrcpy Remote
//
//  Created by Claude on 7/15/25.
//  Bridge for accessing Swift ActionManager and SessionConnectionManager from Objective-C
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Action data structure for Objective-C
@interface ScrcpyActionData : NSObject
@property (nonatomic, strong) NSString *actionId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *deviceType; // "VNC" or "ADB"
@property (nonatomic, strong) NSString *executionTiming; // "immediate", "delayed", "confirmation"
@property (nonatomic, assign) NSInteger delaySeconds;
@property (nonatomic, assign) BOOL isAnyDeviceAction; // True if this action works on any device of the type
@property (nonatomic, assign) BOOL showInFloatingMenu;  // 直接放到悬浮菜单的按钮网格里
@property (nonatomic, strong) NSString *floatingMenuIcon;  // 上按钮条时的 SF Symbol
@end

// Callback types for action execution
typedef void (^ScrcpyActionStatusCallback)(NSInteger status, NSString * _Nullable message, BOOL isConnecting);
typedef void (^ScrcpyActionErrorCallback)(NSString *title, NSString *message);
typedef void (^ScrcpyActionConfirmationCallback)(ScrcpyActionData *action, void (^confirmCallback)(void));

// Bridge class for accessing Swift functionality
@interface ScrcpyActionsBridge : NSObject

// Singleton instance
+ (instancetype)shared;

// ActionManager bridge methods
- (NSArray<ScrcpyActionData *> *)getActionsForCurrentDevice;
- (NSArray<ScrcpyActionData *> *)getActionsForDeviceId:(NSString *)deviceId;
- (BOOL)hasActionsForCurrentDevice;

// SessionConnectionManager bridge methods
- (BOOL)hasActiveSession;
- (NSString * _Nullable)getCurrentSessionId;
- (NSString * _Nullable)getCurrentDeviceType;

// Action execution methods
- (void)executeAction:(ScrcpyActionData *)action
       statusCallback:(ScrcpyActionStatusCallback)statusCallback
        errorCallback:(ScrcpyActionErrorCallback)errorCallback
confirmationCallback:(ScrcpyActionConfirmationCallback _Nullable)confirmationCallback;

// Execute action on current session without connecting
- (void)executeActionOnCurrentSession:(ScrcpyActionData *)action
                       statusCallback:(ScrcpyActionStatusCallback)statusCallback
                        errorCallback:(ScrcpyActionErrorCallback)errorCallback
               confirmationCallback:(ScrcpyActionConfirmationCallback _Nullable)confirmationCallback;

@end

NS_ASSUME_NONNULL_END