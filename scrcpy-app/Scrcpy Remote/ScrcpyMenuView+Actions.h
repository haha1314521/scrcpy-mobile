//
//  ScrcpyMenuView+Actions.h
//  Scrcpy Remote
//
//  Actions popup menu category for ScrcpyMenuView
//

#import "ScrcpyMenuView.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrcpyMenuView (Actions) <UITableViewDataSource, UITableViewDelegate>

// Actions Menu
- (void)showActionsMenu;

/// 打开「查看 UI 布局」(uiautomator dump)。
/// 更多菜单里的那一项和悬浮菜单上的按钮都调它。
- (void)showDumpUILayouts;

/// 截取设备当前屏幕(adb screencap → pull → 存相册/文件)。
/// 悬浮菜单上的截图按钮调它。
- (void)captureDeviceScreenshot;

/// 执行一条自定义动作(菜单里选中、或按钮条上固定的那些都走它)
- (void)executeActionData:(ScrcpyActionData *)actionData;
- (void)hideActionsMenu;

// UI Helpers
- (UIImage *)imageWithIcon:(UIImage *)icon inSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
