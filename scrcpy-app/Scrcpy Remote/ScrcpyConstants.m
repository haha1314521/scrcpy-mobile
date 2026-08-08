//
//  ScrcpyConstants.m
//  Scrcpy Remote
//
//  Created by Claude on 6/19/25.
//

#import "ScrcpyConstants.h"

// MARK: - Icon Constants

// System Icon Names
NSString * const kIconCapsuleHandle = @"ellipsis";
NSString * const kIconBackButton = @"arrow.left";
NSString * const kIconHomeButton = @"house.circle";
NSString * const kIconSwitchButton = @"square.circle";
NSString * const kIconKeyboardButton = @"keyboard";
NSString * const kIconActionsButton = @"ellipsis.circle";
NSString * const kIconDisconnectButton = @"xmark.circle";
NSString * const kIconRebootButton = @"power";
// 查看界面控件树; 用 SF Symbols 1.0 就有的图标, 避免 iOS 14 上空白
NSString * const kIconScreenshotButton = @"camera.fill";
// 清理后台; trash 属于 SF Symbols 1.0, iOS 13 就有, 不会在 iOS 14 上空白
NSString * const kIconCleanupButton = @"trash";
NSString * const kIconClipboardSyncButton = @"square.and.arrow.up.on.square";

// UserDefaults Keys
NSString * const kUserDefaultsPositionRatioX = @"ScrcpyMenuPositionRatioX";
NSString * const kUserDefaultsPositionRatioY = @"ScrcpyMenuPositionRatioY";

// Notification Names
NSString * const kNotificationVNCDrag = @"ScrcpyVNCDragNotification";
NSString * const kNotificationVNCDragOffset = @"ScrcpyVNCDragOffsetNotification";
NSString * const kNotificationVNCMouseEvent = @"ScrcpyVNCMouseEventNotification";
NSString * const kNotificationVNCScrollEvent = @"ScrcpyVNCScrollEventNotification";
NSString * const kNotificationVNCKeyboardEvent = @"ScrcpyVNCKeyboardEventNotification";
NSString * const kNotificationVNCClipboardSynced = @"ScrcpyVNCClipboardSyncedNotification";
NSString * const kNotificationVNCSyncClipboardRequest = @"ScrcpyVNCSyncClipboardRequestNotification";
NSString * const kNotificationVNCClearCandidateModifiers = @"ScrcpyVNCClearCandidateModifiersNotification";
NSString * const kNotificationVNCModifierStateUpdated = @"ScrcpyVNCModifierStateUpdatedNotification";
NSString * const kNotificationVNCNextKeyAlreadyCombined = @"ScrcpyVNCNextKeyAlreadyCombinedNotification";

// Device Types
NSString * const kDeviceTypeVNC = @"vnc";
NSString * const kDeviceTypeADB = @"adb";

// Mouse Event Types
NSString * const kMouseEventTypeMove = @"mouseMove";
NSString * const kMouseEventTypeDragStart = @"mouseDragStart";
NSString * const kMouseEventTypeDrag = @"mouseDrag";
NSString * const kMouseEventTypeDragEnd = @"mouseDragEnd";
NSString * const kMouseEventTypeClick = @"mouseClick";
NSString * const kMouseEventTypeScroll = @"mouseScroll";

// Keyboard Event Types
NSString * const kKeyboardEventTypeKeyDown = @"keyDown";
NSString * const kKeyboardEventTypeKeyUp = @"keyUp";
NSString * const kKeyboardEventTypeTextInput = @"textInput";

// Drag States
NSString * const kDragStateBegan = @"began";
NSString * const kDragStateChanged = @"changed";
NSString * const kDragStateEnded = @"ended";
NSString * const kDragStateCancelled = @"cancelled";

// Dictionary Keys
NSString * const kKeyState = @"state";
NSString * const kKeyLocation = @"location";
NSString * const kKeyViewSize = @"viewSize";
NSString * const kKeyOffset = @"offset";
NSString * const kKeyNormalizedOffset = @"normalizedOffset";
NSString * const kKeyZoomScale = @"zoomScale";
NSString * const kKeyType = @"type";
NSString * const kKeyIsRightClick = @"isRightClick";
NSString * const kKeyIsEmpty = @"isEmpty";

// Keyboard Event Keys
NSString * const kKeyKeyCode = @"keyCode";
NSString * const kKeyText = @"text";
NSString * const kKeyModifiers = @"modifiers";

// Button Type Names
NSString * const kButtonTypeBack = @"back";
NSString * const kButtonTypeHome = @"home";
NSString * const kButtonTypeSwitch = @"switch";
NSString * const kButtonTypeKeyboard = @"keyboard";
NSString * const kButtonTypeActions = @"actions";
NSString * const kButtonTypeDisconnect = @"disconnect";
NSString * const kButtonTypeUnknown = @"unknown";

// Log Labels
NSString * const kLogLabelRight = @"Right";
NSString * const kLogLabelLeft = @"Left";
