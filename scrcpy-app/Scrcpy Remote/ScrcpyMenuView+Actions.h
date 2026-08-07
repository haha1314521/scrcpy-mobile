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
- (void)hideActionsMenu;

// UI Helpers
- (UIImage *)imageWithIcon:(UIImage *)icon inSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
