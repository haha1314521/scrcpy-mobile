//
//  ScrcpyMenuView+Actions.m
//  Scrcpy Remote
//
//  Actions popup menu category for ScrcpyMenuView
//

#import "ScrcpyMenuView+Actions.h"
#import "ScrcpyMenuView+Private.h"
#import "ScrcpyMenuView+FileTransfer.h"
#import "ScrcpyActionsBridge.h"
#import "ADBClient.h"
#import "Scrcpy_Remote-Swift.h"
#import <objc/runtime.h>
#import <Photos/Photos.h>

@implementation ScrcpyMenuView (Actions)

#pragma mark - UI Helpers

- (UIImage *)imageWithIcon:(UIImage *)icon inSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGFloat x = (size.width - icon.size.width) / 2;
    CGFloat y = (size.height - icon.size.height) / 2;
    [icon drawInRect:CGRectMake(x, y, icon.size.width, icon.size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

#pragma mark - Actions Menu Implementation

- (void)showActionsMenu {
    NSLog(@"🔥 [ScrcpyMenuView] Showing Actions popup menu");

    // If popup is already showing, hide it
    if (self.actionsPopupView) {
        [self hideActionsMenu];
        return;
    }

    // Get actions for current device
    ScrcpyActionsBridge *actionsBridge = [ScrcpyActionsBridge shared];
    self.actionsData = [actionsBridge getActionsForCurrentDevice];

    NSLog(@"🔥 [ScrcpyMenuView] Found %lu actions for current device", (unsigned long)self.actionsData.count);

    // Check if we have any items to show (custom actions OR embedded options for ADB devices)
    BOOL hasEmbeddedOptions = [self embeddedActionsCount] > 0;
    if (self.actionsData.count == 0 && !hasEmbeddedOptions) {
        NSLog(@"⚠️ [ScrcpyMenuView] No actions found for current device");
        [self showNoActionsMessage];
        return;
    }

    // Create and show popup
    [self createActionsPopup];
    [self showActionsPopup];
}

- (void)hideActionsMenu {
    NSLog(@"🔥 [ScrcpyMenuView] Hiding Actions popup menu");

    if (!self.actionsPopupView) {
        return;
    }

    // Remove dismiss gesture recognizer
    UIWindow *window = [self activeWindow];
    if (window && self.dismissGestureRecognizer) {
        [window removeGestureRecognizer:self.dismissGestureRecognizer];
        self.dismissGestureRecognizer = nil;
        NSLog(@"🔧 [ScrcpyMenuView] Removed dismiss gesture recognizer");
    }

    // Animate hide
    [UIView animateWithDuration:0.2 animations:^{
        self.actionsPopupView.alpha = 0.0;
        self.actionsPopupView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [self.actionsPopupView removeFromSuperview];
        self.actionsPopupView = nil;
        self.actionsTableView = nil;
        self.actionsData = nil;
    }];
}

- (void)showNoActionsMessage {
    NSLog(@"⚠️ [ScrcpyMenuView] Showing no actions message");

    UIWindow *window = [self activeWindow];
    if (!window) return;

    // Create temporary message view
    UIView *messageView = [[UIView alloc] init];
    messageView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    messageView.layer.cornerRadius = 10.0;

    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.text = NSLocalizedString(@"No Actions Available", nil);
    messageLabel.textColor = [UIColor whiteColor];
    messageLabel.font = [UIFont systemFontOfSize:16.0];
    messageLabel.textAlignment = NSTextAlignmentCenter;

    [messageView addSubview:messageLabel];

    // Layout
    CGFloat messageWidth = 180.0;
    CGFloat messageHeight = 60.0;
    messageView.frame = CGRectMake(0, 0, messageWidth, messageHeight);
    messageLabel.frame = messageView.bounds;

    // Calculate position (above Actions button, right-aligned with button)
    CGRect actionsButtonFrame = [self.menuView convertRect:self.actionsButton.frame toView:window];

    CGFloat popupX = CGRectGetMaxX(actionsButtonFrame) - messageWidth;
    CGFloat popupY = actionsButtonFrame.origin.y - messageHeight - 10;

    // Ensure within screen bounds
    popupX = MAX(10, MIN(popupX, window.bounds.size.width - messageWidth - 10));
    if (popupY < 50) {
        popupY = CGRectGetMaxY(actionsButtonFrame) + 10;
    }

    messageView.frame = CGRectMake(popupX, popupY, messageWidth, messageHeight);
    messageView.alpha = 0.0;
    messageView.transform = CGAffineTransformMakeScale(0.8, 0.8);

    [window addSubview:messageView];

    // Show animation
    [UIView animateWithDuration:0.2 animations:^{
        messageView.alpha = 1.0;
        messageView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        // Auto-hide after 2 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{
                messageView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [messageView removeFromSuperview];
            }];
        });
    }];
}

- (void)createActionsPopup {
    NSLog(@"🔥 [ScrcpyMenuView] Creating Actions popup");

    UIWindow *window = [self activeWindow];
    if (!window) return;

    // Calculate popup size (include embedded options for ADB devices)
    CGFloat popupWidth = 280.0;
    CGFloat cellHeight = 50.0;
    NSInteger totalRows = self.actionsData.count + [self embeddedActionsCount];
    CGFloat maxHeight = MIN(totalRows * cellHeight + 20, window.bounds.size.height * 0.6);
    CGFloat popupHeight = maxHeight;

    // Create popup container
    self.actionsPopupView = [[UIView alloc] init];
    self.actionsPopupView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    self.actionsPopupView.layer.cornerRadius = 12.0;
    self.actionsPopupView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.actionsPopupView.layer.shadowOffset = CGSizeMake(0, 4);
    self.actionsPopupView.layer.shadowOpacity = 0.3;
    self.actionsPopupView.layer.shadowRadius = 8.0;
    self.actionsPopupView.userInteractionEnabled = YES;
    NSLog(@"🔧 [ScrcpyMenuView] Popup container created with userInteractionEnabled=YES");

    // Create TableView
    self.actionsTableView = [[UITableView alloc] init];
    self.actionsTableView.backgroundColor = [UIColor clearColor];
    self.actionsTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.actionsTableView.dataSource = self;
    self.actionsTableView.delegate = self;
    self.actionsTableView.rowHeight = cellHeight;
    self.actionsTableView.layer.cornerRadius = 8.0;
    self.actionsTableView.showsVerticalScrollIndicator = NO;
    self.actionsTableView.userInteractionEnabled = YES;
    self.actionsTableView.allowsSelection = YES;
    NSLog(@"🔧 [ScrcpyMenuView] TableView created with userInteractionEnabled=YES, allowsSelection=YES");

    // Register cell
    [self.actionsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ActionCell"];

    [self.actionsPopupView addSubview:self.actionsTableView];

    // Layout TableView
    self.actionsTableView.frame = CGRectMake(10, 10, popupWidth - 20, popupHeight - 20);

    // Calculate popup position (above Actions button, right-aligned with button)
    CGRect actionsButtonFrame = [self.menuView convertRect:self.actionsButton.frame toView:window];

    NSLog(@"🔧 [ScrcpyMenuView] Actions button frame in window: %@", NSStringFromCGRect(actionsButtonFrame));

    CGFloat popupX = CGRectGetMaxX(actionsButtonFrame) - popupWidth;
    CGFloat popupY = actionsButtonFrame.origin.y - popupHeight - 10;

    // Ensure popup is within screen bounds
    CGFloat minX = 10;
    CGFloat maxX = window.bounds.size.width - popupWidth - 10;
    popupX = MAX(minX, MIN(popupX, maxX));

    if (popupY < 50) {
        popupY = CGRectGetMaxY(actionsButtonFrame) + 10;
    }

    if (popupY + popupHeight > window.bounds.size.height - 10) {
        popupY = window.bounds.size.height - popupHeight - 10;
    }

    self.actionsPopupView.frame = CGRectMake(popupX, popupY, popupWidth, popupHeight);

    NSLog(@"🔥 [ScrcpyMenuView] Popup frame: %@", NSStringFromCGRect(self.actionsPopupView.frame));
}

- (void)showActionsPopup {
    NSLog(@"🔥 [ScrcpyMenuView] Showing Actions popup");

    UIWindow *window = [self activeWindow];
    if (!window) return;

    // Initial state
    self.actionsPopupView.alpha = 0.0;
    self.actionsPopupView.transform = CGAffineTransformMakeScale(0.8, 0.8);

    // Add to window
    [window addSubview:self.actionsPopupView];

    // Add tap outside to dismiss gesture
    self.dismissGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissActionsPopup:)];
    self.dismissGestureRecognizer.cancelsTouchesInView = NO;
    [window addGestureRecognizer:self.dismissGestureRecognizer];
    NSLog(@"🔧 [ScrcpyMenuView] Added dismiss gesture with cancelsTouchesInView=NO");

    // Show animation
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.actionsPopupView.alpha = 1.0;
        self.actionsPopupView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismissActionsPopup:(UITapGestureRecognizer *)gesture {
    UIWindow *window = [self activeWindow];
    if (!window || !self.actionsPopupView) {
        return;
    }

    CGPoint locationInWindow = [gesture locationInView:window];
    CGRect popupFrameInWindow = self.actionsPopupView.frame;

    NSLog(@"🔍 [ScrcpyMenuView] Tap location in window: %@", NSStringFromCGPoint(locationInWindow));
    NSLog(@"🔍 [ScrcpyMenuView] Popup frame in window: %@", NSStringFromCGRect(popupFrameInWindow));

    // If tap is inside popup, don't close
    if (CGRectContainsPoint(popupFrameInWindow, locationInWindow)) {
        NSLog(@"🔍 [ScrcpyMenuView] Tap inside popup - NOT closing");
        return;
    }

    NSLog(@"🔍 [ScrcpyMenuView] Tap outside popup - closing");

    // Remove gesture recognizer
    if (self.dismissGestureRecognizer) {
        [window removeGestureRecognizer:self.dismissGestureRecognizer];
        self.dismissGestureRecognizer = nil;
    }

    // Close popup
    [self hideActionsMenu];
}

#pragma mark - TableView DataSource & Delegate

- (BOOL)shouldShowSendFilesOption {
    return self.currentDeviceType == ScrcpyDeviceTypeADB;
}

// 截取当前设备屏幕(走 adb screencap,原始像素,保存到相册)
- (BOOL)shouldShowScreenshotOption {
    return self.currentDeviceType == ScrcpyDeviceTypeADB;
}

- (BOOL)shouldShowDumpUILayoutsOption {
    return self.currentDeviceType == ScrcpyDeviceTypeADB;
}

- (NSInteger)embeddedActionsCount {
    NSInteger count = 0;
    if ([self shouldShowSendFilesOption]) count++;
    if ([self shouldShowScreenshotOption]) count++;
    if ([self shouldShowDumpUILayoutsOption]) count++;
    return count;
}

- (NSInteger)actionIndexFromRow:(NSInteger)row {
    return row - [self embeddedActionsCount];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = self.actionsData.count + [self embeddedActionsCount];
    NSLog(@"🔧 [ScrcpyMenuView] numberOfRowsInSection returning: %ld", (long)count);
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"🔧 [ScrcpyMenuView] cellForRowAtIndexPath called for row: %ld", (long)indexPath.row);
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionCell" forIndexPath:indexPath];

    // Configure cell appearance
    cell.backgroundColor = [UIColor clearColor];
    cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];

    // Left align text
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;

    // Define consistent icon container size
    CGSize iconContainerSize = CGSizeMake(28, 28);
    UIImageSymbolConfiguration *largeConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    UIImageSymbolConfiguration *smallConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];

    // Track embedded row index
    NSInteger embeddedRowIndex = 0;

    // Check if this is the "Send Files or Photos" row (first embedded row for ADB devices)
    if ([self shouldShowSendFilesOption]) {
        if (indexPath.row == embeddedRowIndex) {
            UIImage *sendIcon = [[UIImage systemImageNamed:@"square.and.arrow.up.fill" withConfiguration:largeConfig]
                                 imageWithTintColor:[UIColor systemBlueColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            cell.imageView.image = [self imageWithIcon:sendIcon inSize:iconContainerSize];
            cell.textLabel.text = NSLocalizedString(@"Send Files or Photos", nil);
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
            cell.detailTextLabel.text = NSLocalizedString(@"Push files or photos to device", nil);
            cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
            return cell;
        }
        embeddedRowIndex++;
    }

    // 截图行(紧跟在"发送文件或照片"下面)
    if ([self shouldShowScreenshotOption]) {
        if (indexPath.row == embeddedRowIndex) {
            UIImage *shotIcon = [[UIImage systemImageNamed:@"camera.fill" withConfiguration:largeConfig]
                                 imageWithTintColor:[UIColor systemGreenColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            cell.imageView.image = [self imageWithIcon:shotIcon inSize:iconContainerSize];
            cell.textLabel.text = NSLocalizedString(@"Capture Screenshot", nil);
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
            cell.detailTextLabel.text = NSLocalizedString(@"Save device screen to this iPhone", nil);
            cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
            return cell;
        }
        embeddedRowIndex++;
    }

    // Check if this is the "Dump UI Layouts" row (second embedded row for ADB devices)
    if ([self shouldShowDumpUILayoutsOption]) {
        if (indexPath.row == embeddedRowIndex) {
            UIImageSymbolConfiguration *dumpConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
            UIImage *dumpIcon = [[UIImage systemImageNamed:@"rectangle.3.group" withConfiguration:dumpConfig]
                                 imageWithTintColor:[UIColor systemPurpleColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            cell.imageView.image = [self imageWithIcon:dumpIcon inSize:iconContainerSize];
            cell.textLabel.text = NSLocalizedString(@"Dump UI Layouts", nil);
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
            cell.detailTextLabel.text = NSLocalizedString(@"Capture and inspect UI hierarchy", nil);
            cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
            return cell;
        }
        embeddedRowIndex++;
    }

    // Get actual action index
    NSInteger actionIndex = [self actionIndexFromRow:indexPath.row];
    if (actionIndex < 0 || actionIndex >= (NSInteger)self.actionsData.count) {
        return cell;
    }

    ScrcpyActionData *actionData = self.actionsData[actionIndex];

    // Use different icon for "any device" actions vs specific device actions
    UIImage *actionIcon;
    if (actionData.isAnyDeviceAction) {
        // Use a different icon to indicate this is an "any device" action
        actionIcon = [[UIImage systemImageNamed:@"rectangle.stack.fill" withConfiguration:smallConfig]
                      imageWithTintColor:[UIColor systemOrangeColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        actionIcon = [[UIImage systemImageNamed:@"terminal.fill" withConfiguration:smallConfig]
                      imageWithTintColor:[UIColor systemGrayColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    cell.imageView.image = [self imageWithIcon:actionIcon inSize:iconContainerSize];

    // Configure text
    cell.textLabel.text = actionData.name;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16.0];

    // Configure detail text
    NSString *timingText = @"";
    if ([actionData.executionTiming isEqualToString:@"immediate"]) {
        timingText = @"Immediate";
    } else if ([actionData.executionTiming isEqualToString:@"delayed"]) {
        timingText = [NSString stringWithFormat:@"Delay %lds", (long)actionData.delaySeconds];
    } else {
        timingText = @"Confirm";
    }

    // Add "Any Device" indicator for any-device actions
    if (actionData.isAnyDeviceAction) {
        timingText = [NSString stringWithFormat:@"Any %@ · %@", actionData.deviceType, timingText];
    }

    cell.detailTextLabel.text = timingText;
    cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"🔥 [ScrcpyMenuView] didSelectRowAtIndexPath called for row: %ld", (long)indexPath.row);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // Track embedded row index
    NSInteger embeddedRowIndex = 0;

    // Check if "Send Files or Photos" was tapped (first embedded row for ADB devices)
    if ([self shouldShowSendFilesOption]) {
        if (indexPath.row == embeddedRowIndex) {
            NSLog(@"📤 [ScrcpyMenuView] Send Files or Photos selected");
            [self hideActionsMenu];
            [self showSendFilesOrPhotosActionSheet];
            return;
        }
        embeddedRowIndex++;
    }

    // 截图
    if ([self shouldShowScreenshotOption]) {
        if (indexPath.row == embeddedRowIndex) {
            NSLog(@"📷 [ScrcpyMenuView] Capture Screenshot selected");
            [self hideActionsMenu];
            if (self.isExpanded) {
                [self toggleMenuExpansion];
            }
            // 等菜单收起动画结束再截, 否则会把菜单也拍进去
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self captureDeviceScreenshot];
            });
            return;
        }
        embeddedRowIndex++;
    }

    // Check if "Dump UI Layouts" was tapped (second embedded row for ADB devices)
    if ([self shouldShowDumpUILayoutsOption]) {
        if (indexPath.row == embeddedRowIndex) {
            NSLog(@"📱 [ScrcpyMenuView] Dump UI Layouts selected");
            [self hideActionsMenu];
            // Also collapse the main menu
            if (self.isExpanded) {
                [self toggleMenuExpansion];
            }
            [self showDumpUILayouts];
            return;
        }
        embeddedRowIndex++;
    }

    // Get actual action index
    NSInteger actionIndex = [self actionIndexFromRow:indexPath.row];
    if (actionIndex < 0 || actionIndex >= (NSInteger)self.actionsData.count) {
        return;
    }

    ScrcpyActionData *selectedAction = self.actionsData[actionIndex];
    NSLog(@"🎯 [ScrcpyMenuView] Action selected: %@", selectedAction.name);

    // Check if confirmation is required
    BOOL requiresConfirmation = [selectedAction.executionTiming isEqualToString:@"confirmation"];

    // Execute action
    [self executeActionData:selectedAction];

    // Only hide popup if confirmation is not required
    if (!requiresConfirmation) {
        [self hideActionsMenu];
    }
}

- (void)executeActionData:(ScrcpyActionData *)actionData {
    NSLog(@"🚀 [ScrcpyMenuView] Executing action on current session: %@", actionData.name);

    ScrcpyActionsBridge *actionsBridge = [ScrcpyActionsBridge shared];

    [actionsBridge executeActionOnCurrentSession:actionData
                                  statusCallback:^(NSInteger status, NSString * _Nullable message, BOOL isConnecting) {
                                      NSLog(@"📊 [ScrcpyMenuView] Action status: %ld, message: %@, connecting: %@",
                                            (long)status, message, isConnecting ? @"YES" : @"NO");
                                  }
                                   errorCallback:^(NSString *title, NSString *message) {
                                       NSLog(@"❌ [ScrcpyMenuView] Action error: %@ - %@", title, message);
                                   }
                            confirmationCallback:^(ScrcpyActionData *action, void (^confirmCallback)(void)) {
                                NSLog(@"✋ [ScrcpyMenuView] Action requires confirmation: %@", action.name);
                                [self showActionConfirmation:action confirmCallback:confirmCallback];
                            }];
}

- (void)showActionConfirmation:(ScrcpyActionData *)actionData confirmCallback:(void (^)(void))confirmCallback {
    NSLog(@"✋ [ScrcpyMenuView] Showing action confirmation (unified) for: %@", actionData.name);

    // Hide Actions popup first
    [self hideActionsMenu];

    // Present unified global confirmation using Swift presenter
    [ActionConfirmationPresenter showForActionId:actionData.actionId confirmCallback:confirmCallback];
}

- (void)cancelActionConfirmation:(UIButton *)sender {
    NSLog(@"❌ [ScrcpyMenuView] Action confirmation cancelled");
    [self hideActionConfirmation];
}

- (void)executeActionConfirmation:(UIButton *)sender {
    NSLog(@"✅ [ScrcpyMenuView] Action confirmation accepted");

    void (^confirmCallback)(void) = objc_getAssociatedObject(sender, "confirmCallback");
    if (confirmCallback) {
        confirmCallback();
    }

    [self hideActionConfirmation];
}

- (void)hideActionConfirmation {
    if (!self.actionConfirmationView) {
        return;
    }

    [UIView animateWithDuration:0.2 animations:^{
        self.actionConfirmationView.alpha = 0.0;
        self.actionConfirmationView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [self.actionConfirmationView removeFromSuperview];
        self.actionConfirmationView = nil;
    }];
}

#pragma mark - Dump UI Layouts

- (void)showDumpUILayouts {
    NSLog(@"📱 [ScrcpyMenuView] showDumpUILayouts called");

    // Present the SwiftUI DumpUIView (it will get the device info from SessionConnectionManager)
    [ScrcpyDumpUIPresenter show];
}

#pragma mark - 截取设备屏幕

// 走 adb screencap 而不是截 iPhone 这边的画面:
// 拿到的是安卓设备的原始分辨率原图(比如 1080x1920), 没有缩放、没有黑边,
// 用来量控件坐标或存档都准确。
- (void)captureDeviceScreenshot {
    NSString *remotePath = @"/sdcard/scrcpy_remote_capture.png";
    NSString *localPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"scrcpy_capture.png"];
    [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];

    [self showCaptureHUD:NSLocalizedString(@"Capturing screen...", nil) autoHide:NO];

    __weak typeof(self) weakSelf = self;

    // 1) 在设备上截图存成文件。
    //    不用 exec-out 直接读流是有原因的: 老 adb 会对 shell 输出做 LF->CRLF 转换,
    //    直接拿流会把 PNG 二进制弄坏, 存文件再 pull 最稳。
    [[ADBClient shared] executeADBCommandAsync:@[@"shell", @"screencap", @"-p", remotePath]
                                      callback:^(NSString * _Nullable output, int returnCode) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (returnCode != 0) {
            NSLog(@"📷 screencap failed (%d): %@", returnCode, output);
            [self showCaptureHUD:NSLocalizedString(@"Screenshot failed", nil) autoHide:YES];
            return;
        }

        // 2) 拉到本机沙盒
        [[ADBClient shared] executeADBCommandAsync:@[@"pull", remotePath, localPath]
                                          callback:^(NSString * _Nullable out2, int code2) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            // 3) 顺手清掉设备上的临时文件, 失败也无所谓
            [[ADBClient shared] executeADBCommandAsync:@[@"shell", @"rm", @"-f", remotePath]
                                              callback:^(NSString * _Nullable o, int c) {}];

            NSData *data = [NSData dataWithContentsOfFile:localPath];
            if (code2 != 0 || data.length == 0) {
                NSLog(@"📷 pull failed (%d), bytes=%lu: %@", code2, (unsigned long)data.length, out2);
                [self showCaptureHUD:NSLocalizedString(@"Screenshot failed", nil) autoHide:YES];
                return;
            }

            [self saveCapturedScreenshotAtPath:localPath];
        }];
    }];
}

- (void)saveCapturedScreenshotAtPath:(NSString *)localPath {
    UIImage *image = [UIImage imageWithContentsOfFile:localPath];
    NSString *sizeText = image ? [NSString stringWithFormat:@"%.0f × %.0f", image.size.width, image.size.height] : @"";
    if (!image) {
        // 读不出图说明 pull 回来的不是有效 PNG, 别再往相册塞了
        NSLog(@"📷 pulled file is not a valid image: %@", localPath);
        [self showCaptureHUD:NSLocalizedString(@"Screenshot failed", nil) autoHide:YES];
        return;
    }

    // 文件名带时间戳, 一是相册里好认, 二是留档不会互相覆盖
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *fileName = [NSString stringWithFormat:@"scrcpy_%@.png", [fmt stringFromDate:[NSDate date]]];

    // 同时在 App 的 Documents 里留一份:
    // 相册那条路万一被系统权限挡住, 还能从「文件」App → 我的 iPhone → Scrcpy Remote 取。
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *keepPath = [docs stringByAppendingPathComponent:fileName];
    NSError *copyError = nil;
    [[NSFileManager defaultManager] copyItemAtPath:localPath toPath:keepPath error:&copyError];
    if (copyError) {
        NSLog(@"📷 keep a copy in Documents failed: %@", copyError);
    }

    __weak typeof(self) weakSelf = self;
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            [self showCaptureHUD:NSLocalizedString(@"No permission to save to Photos", nil) autoHide:YES];
            return;
        }

        __block NSString *localIdentifier = nil;

        // 用 addResourceWithType:fileURL: 直接写入原始 PNG 文件,
        // 不经过 UIImage 重新编码, 像素和文件内容都是原样。
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];

            PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
            options.originalFilename = fileName;
            [request addResourceWithType:PHAssetResourceTypePhoto
                                 fileURL:[NSURL fileURLWithPath:localPath]
                                 options:options];

            // ★ 必须显式指定创建时间。
            //   不指定的话系统会去读文件自身的时间戳, 而 adb pull 保留的是安卓那边的
            //   文件时间 —— 安卓设备时间只要和现在对不上, 照片就会被排到相册很久以前的
            //   位置, 表现为"提示保存成功但相册里找不到"。
            request.creationDate = [NSDate date];

            localIdentifier = request.placeholderForCreatedAsset.localIdentifier;
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            if (success) {
                NSLog(@"📷 saved to photos, id=%@, file=%@", localIdentifier, fileName);
                [self showCaptureHUD:[NSString stringWithFormat:@"%@  %@",
                                      NSLocalizedString(@"Saved to Photos", nil), sizeText]
                            autoHide:YES];
            } else {
                NSLog(@"📷 save to photos failed: %@", error);
                // 相册失败也没关系, Documents 那份还在
                [self showCaptureHUD:[NSString stringWithFormat:@"%@\n%@",
                                      NSLocalizedString(@"Failed to save to Photos", nil),
                                      NSLocalizedString(@"A copy is kept in Files app", nil)]
                            autoHide:YES];
            }
        }];
    }];
}

#define kCaptureHUDTag 908601

- (void)showCaptureHUD:(NSString *)text autoHide:(BOOL)autoHide {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *host = self.window ?: self.superview;
        if (!host) return;

        UIView *old = [host viewWithTag:kCaptureHUDTag];
        [old removeFromSuperview];

        UILabel *hud = [[UILabel alloc] init];
        hud.tag = kCaptureHUDTag;
        hud.text = text;
        hud.textColor = [UIColor whiteColor];
        hud.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        hud.textAlignment = NSTextAlignmentCenter;
        hud.numberOfLines = 0;
        hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        hud.layer.cornerRadius = 10.0;
        hud.layer.masksToBounds = YES;
        hud.alpha = 0.0;
        hud.translatesAutoresizingMaskIntoConstraints = NO;
        [host addSubview:hud];

        [NSLayoutConstraint activateConstraints:@[
            [hud.centerXAnchor constraintEqualToAnchor:host.centerXAnchor],
            [hud.centerYAnchor constraintEqualToAnchor:host.centerYAnchor],
            [hud.widthAnchor constraintLessThanOrEqualToAnchor:host.widthAnchor multiplier:0.8],
            [hud.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        ]];
        // 左右留白
        hud.preferredMaxLayoutWidth = host.bounds.size.width * 0.8 - 32;
        [hud setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

        [UIView animateWithDuration:0.15 animations:^{
            hud.alpha = 1.0;
        }];

        if (autoHide) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    hud.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [hud removeFromSuperview];
                }];
            });
        }
    });
}

@end
