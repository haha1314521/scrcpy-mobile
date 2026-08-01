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
#import "Scrcpy_Remote-Swift.h"
#import <objc/runtime.h>

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

- (BOOL)shouldShowDumpUILayoutsOption {
    return self.currentDeviceType == ScrcpyDeviceTypeADB;
}

- (NSInteger)embeddedActionsCount {
    NSInteger count = 0;
    if ([self shouldShowSendFilesOption]) count++;
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

@end
