//
//  ScrcpyMenuView.m
//  Scrcpy Remote
//
//  Core implementation of ScrcpyMenuView
//

#import "ScrcpyMenuView.h"
#import "ScrcpyMenuView+Private.h"
#import "ScrcpyMenuView+VNCGestures.h"
#import "ScrcpyMenuView+Actions.h"
#import "ScrcpyMenuView+FileTransfer.h"
#import "Scrcpy_Remote-Swift.h"
#import "ScrcpyMenuMaskView.h"
#import "ScrcpyConstants.h"
#import <SDL2/SDL_system.h>
#import <SDL2/SDL_syswm.h>
#import <SDL2/SDL_mouse.h>
#import "ScrcpyADBClient.h"
#import "ScrcpyVNCClient.h"

// Capsule View Constants
// 收起态: 仿 AssistiveTouch 的圆球(原本是 55x26 的胶囊)
static const CGFloat kCapsuleWidth = 50.0f;
static const CGFloat kCapsuleHeight = 50.0f;
static const CGFloat kCapsuleCornerRadius = 25.0f;
// 圆球里的图标: 居中摆放(原来这几个值是按 55x26 胶囊硬算的, 换成圆球会偏)
static const CGFloat kCapsuleHandleIconWidth = 24.0f;
static const CGFloat kCapsuleHandleIconHeight = 24.0f;
static const CGFloat kCapsuleHandleIconX = (kCapsuleWidth - kCapsuleHandleIconWidth) / 2.0f;
static const CGFloat kCapsuleHandleIconY = (kCapsuleHeight - kCapsuleHandleIconHeight) / 2.0f;

// Capsule Alpha Values
static const CGFloat kCapsuleAlphaIdle = 0.3f;
static const CGFloat kCapsuleAlphaNormal = 0.8f;
static const CGFloat kCapsuleAlphaExpanded = 0.8f;

// Menu View Constants
// 展开态: 网格面板。原来是横向一条, 8 个按钮挤在一行既难点又难看;
// 改成 3 列的网格, 按钮可以放大, 面板整体像 AssistiveTouch 那样是个圆角方块。
static const NSInteger kMenuColumns = 3;
static const CGFloat kMenuHeight = 60.0f;          /* 仅用于初始占位, 实际高度按行数算 */
static const CGFloat kMenuCornerRadius = 22.0f;
static const CGFloat kMenuHorizontalPadding = 8.0f;
static const CGFloat kMenuVerticalPadding = 8.0f;
static const CGFloat kMenuVerticalSpacing = 10.0f;

// Button Constants
// 网格里按钮做成正方形。原本 52x60 是横排一条时的尺寸,
// 高比宽还大, 摆到 3x3 网格里会显得整个面板又高又墩。
static const CGFloat kButtonWidth = 48.0f;
static const CGFloat kButtonHeight = 48.0f;
static const CGFloat kButtonSpacing = 4.0f;

// Animation Constants
static const CGFloat kAnimationDuration = 0.15f;
static const CGFloat kMenuAnimationDuration = 0.25f;
static const CGFloat kMenuAnimationDelay = 0.0f;
static const CGFloat kMenuAnimationSpringDamping = 0.6f;
static const CGFloat kMenuAnimationSpringVelocity = 0.5f;
static const CGFloat kFadeTimerInterval = 3.0f;

// Position Constants
static const CGFloat kDefaultPositionRatioX = 0.8f;
static const CGFloat kDefaultPositionRatioY = 0.8f;

// Dynamic Island avoidance constants
static const CGFloat kDynamicIslandWidth = 100.0f;

@interface ScrcpyMenuView () <ScrcpyMenuMaskViewDelegate, ScrcpyMenuViewDelegate>

@property (nonatomic, strong) ScrcpyMenuMaskView *maskView;

@end

@implementation ScrcpyMenuView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isExpanded = NO;
        _currentDeviceType = ScrcpyDeviceTypeADB;
        _currentZoomScale = 1.0;
        _gestureStartZoomScale = 1.0;
        _dragStartLocation = CGPointZero;
        _currentDragOffset = CGPointZero;
        _totalDragOffset = CGPointZero;

        LOG_POSITION(@"Initializing menu view with frame: (%.1f, %.1f, %.1f, %.1f)",
                     frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);

        self.userInteractionEnabled = YES;

        // Load saved position ratio or use default
        _positionRatio = [self loadPositionRatio];
        LOG_POSITION(@"Loaded position ratio: (%.3f, %.3f)", _positionRatio.x, _positionRatio.y);

        [self setupViews];
        [self setupGestures];
        [self startFadeTimer];

        // Set initial frame size based on capsule dimensions
        self.frame = CGRectMake(0, 0, kCapsuleWidth, kCapsuleHeight);

        // Initialize gesture states
        self.isDragging = NO;
        self.isScrolling = NO;
        self.currentZoomScale = 1.0;
        self.currentDragOffset = CGPointZero;
        self.totalDragOffset = CGPointZero;

        // Register for orientation change notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Clean up gestures
    [self removePinchGesture];
    [self removeDragGesture];
    [self removeTapGesture];
}

- (void)orientationDidChange:(NSNotification *)notification {
    LOG_POSITION(@"Device orientation changed, updating layout");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateLayout];
    });
}

#pragma mark - Position Management

- (CGPoint)loadPositionRatio {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat savedRatioX = [defaults floatForKey:kUserDefaultsPositionRatioX];
    CGFloat savedRatioY = [defaults floatForKey:kUserDefaultsPositionRatioY];

    if (savedRatioX >= -1 && savedRatioX <= 1 && savedRatioY >= -1 && savedRatioY <= 1) {
        if (savedRatioX == 0 && savedRatioY == 0) {
            LOG_POSITION(@"No saved position, using default (%.3f, %.3f)", kDefaultPositionRatioX, kDefaultPositionRatioY);
            return CGPointMake(kDefaultPositionRatioX, kDefaultPositionRatioY);
        }
        LOG_POSITION(@"Using saved position ratio");
        return CGPointMake(savedRatioX, savedRatioY);
    } else {
        LOG_POSITION(@"Invalid saved position, using default (%.3f, %.3f)", kDefaultPositionRatioX, kDefaultPositionRatioY);
        return CGPointMake(kDefaultPositionRatioX, kDefaultPositionRatioY);
    }
}

- (void)savePositionRatio:(CGPoint)ratio {
    LOG_POSITION(@"Saving position ratio: (%.3f, %.3f)", ratio.x, ratio.y);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:ratio.x forKey:kUserDefaultsPositionRatioX];
    [defaults setFloat:ratio.y forKey:kUserDefaultsPositionRatioY];
    [defaults synchronize];
}

- (void)updatePositionFromRatio {
    UIWindow *window = [self activeWindow];
    if (!window) return;

    LOG_POSITION(@"updatePositionFromRatio called - Current ratio: (%.3f, %.3f)",
                 self.positionRatio.x, self.positionRatio.y);

    CGRect screenBounds = window.bounds;
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;

    LOG_POSITION(@"Screen size: %.1f x %.1f", screenWidth, screenHeight);

    // Calculate screen center
    CGFloat screenCenterX = screenWidth / 2.0;
    CGFloat screenCenterY = screenHeight / 2.0;

    // Calculate reachable boundaries
    CGFloat minFrameX = 0;
    CGFloat maxFrameX = screenWidth - self.frame.size.width;
    CGFloat minFrameY = 0;
    CGFloat maxFrameY = screenHeight - self.frame.size.height;

    // Calculate the reachable center positions
    CGFloat minCenterX = minFrameX + self.frame.size.width / 2.0;
    CGFloat maxCenterX = maxFrameX + self.frame.size.width / 2.0;
    CGFloat minCenterY = minFrameY + self.frame.size.height / 2.0;
    CGFloat maxCenterY = maxFrameY + self.frame.size.height / 2.0;

    // Calculate maximum offsets from center
    CGFloat maxOffsetX = MAX(fabs(minCenterX - screenCenterX), fabs(maxCenterX - screenCenterX));
    CGFloat maxOffsetY = MAX(fabs(minCenterY - screenCenterY), fabs(maxCenterY - screenCenterY));

    LOG_POSITION(@"Screen center: (%.1f, %.1f), Max offsets: (%.1f, %.1f)",
                 screenCenterX, screenCenterY, maxOffsetX, maxOffsetY);

    // Calculate capsule center position using center-relative ratio
    CGFloat capsuleCenterX = screenCenterX + (maxOffsetX * self.positionRatio.x);
    CGFloat capsuleCenterY = screenCenterY + (maxOffsetY * self.positionRatio.y);

    LOG_POSITION(@"Target capsule center: (%.1f, %.1f)", capsuleCenterX, capsuleCenterY);

    // Convert center position to top-left corner position
    CGFloat x = capsuleCenterX - self.frame.size.width / 2.0;
    CGFloat y = capsuleCenterY - self.frame.size.height / 2.0;

    // Ensure position is within screen bounds
    CGFloat originalX = x, originalY = y;
    x = MAX(0, MIN(screenWidth - self.frame.size.width, x));
    y = MAX(0, MIN(screenHeight - self.frame.size.height, y));

    if (originalX != x || originalY != y) {
        LOG_POSITION(@"Position was clamped from (%.1f, %.1f) to (%.1f, %.1f)", originalX, originalY, x, y);
    }

    LOG_POSITION(@"Final position: (%.1f, %.1f)", x, y);

    // Update frame
    self.frame = CGRectMake(x, y, self.frame.size.width, self.frame.size.height);

    // Check for Dynamic Island overlap and adjust if necessary
    if ([self doesCapsuleOverlapDynamicIsland:window]) {
        LOG_POSITION(@"Position overlaps with Dynamic Island, adjusting...");
        CGPoint adjustedPosition = [self adjustPositionToAvoidDynamicIsland:window];
        self.frame = CGRectMake(adjustedPosition.x, adjustedPosition.y, self.frame.size.width, self.frame.size.height);
        LOG_POSITION(@"Position adjusted to: (%.1f, %.1f)", adjustedPosition.x, adjustedPosition.y);
    }
}

- (void)updateRatioFromPosition {
    UIWindow *window = [self activeWindow];
    if (!window) return;

    LOG_POSITION(@"updateRatioFromPosition called - Current frame: (%.1f, %.1f, %.1f, %.1f)",
                 self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);

    CGRect screenBounds = window.bounds;
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;

    // Calculate screen center
    CGFloat screenCenterX = screenWidth / 2.0;
    CGFloat screenCenterY = screenHeight / 2.0;

    // Calculate current capsule center
    CGFloat capsuleCenterX = self.frame.origin.x + self.frame.size.width / 2.0;
    CGFloat capsuleCenterY = self.frame.origin.y + self.frame.size.height / 2.0;

    // Calculate reachable boundaries
    CGFloat minFrameX = 0;
    CGFloat maxFrameX = screenWidth - self.frame.size.width;
    CGFloat minFrameY = 0;
    CGFloat maxFrameY = screenHeight - self.frame.size.height;

    // Calculate the reachable center positions
    CGFloat minCenterX = minFrameX + self.frame.size.width / 2.0;
    CGFloat maxCenterX = maxFrameX + self.frame.size.width / 2.0;
    CGFloat minCenterY = minFrameY + self.frame.size.height / 2.0;
    CGFloat maxCenterY = maxFrameY + self.frame.size.height / 2.0;

    // Calculate maximum offsets from center
    CGFloat maxOffsetX = MAX(fabs(minCenterX - screenCenterX), fabs(maxCenterX - screenCenterX));
    CGFloat maxOffsetY = MAX(fabs(minCenterY - screenCenterY), fabs(maxCenterY - screenCenterY));

    LOG_POSITION(@"Screen center: (%.1f, %.1f), Capsule center: (%.1f, %.1f)", screenCenterX, screenCenterY, capsuleCenterX, capsuleCenterY);
    LOG_POSITION(@"Reachable center range - X: [%.1f, %.1f], Y: [%.1f, %.1f]", minCenterX, maxCenterX, minCenterY, maxCenterY);
    LOG_POSITION(@"Max offsets: (%.1f, %.1f)", maxOffsetX, maxOffsetY);

    // Calculate center-relative ratio
    CGFloat ratioX = 0;
    CGFloat ratioY = 0;

    if (maxOffsetX > 0) {
        ratioX = (capsuleCenterX - screenCenterX) / maxOffsetX;
        ratioX = MAX(-1, MIN(1, ratioX));
    }

    if (maxOffsetY > 0) {
        ratioY = (capsuleCenterY - screenCenterY) / maxOffsetY;
        ratioY = MAX(-1, MIN(1, ratioY));
    }

    LOG_POSITION(@"Calculated center-relative ratio: (%.3f, %.3f)", ratioX, ratioY);
    LOG_POSITION(@"Previous ratio was: (%.3f, %.3f)", self.positionRatio.x, self.positionRatio.y);

    // Store the center-relative ratio
    self.positionRatio = CGPointMake(ratioX, ratioY);
    [self savePositionRatio:self.positionRatio];

    LOG_POSITION(@"Stored new center-relative ratio: (%.3f, %.3f)", ratioX, ratioY);
}

#pragma mark - AssistiveTouch 风格图标

// 照着 iOS 辅助触控的小白点画: 外层圆角方框, 中间圆环, 正中实心圆点。
// 三层都用白色但透明度递增, 越往里越实, 和系统观感一致。
+ (UIImage *)assistiveTouchIconOfSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGFloat w = size.width;
    CGFloat h = size.height;
    CGFloat lineWidth = MAX(1.0, w * 0.075);

    // 1) 外层圆角方框
    CGFloat outerInset = lineWidth / 2.0;
    CGRect outerRect = CGRectMake(outerInset, outerInset, w - outerInset * 2, h - outerInset * 2);
    UIBezierPath *outer = [UIBezierPath bezierPathWithRoundedRect:outerRect
                                                     cornerRadius:w * 0.30];
    [[UIColor colorWithWhite:1.0 alpha:0.55] setStroke];
    outer.lineWidth = lineWidth;
    [outer stroke];

    // 2) 中间圆环
    CGFloat ringInset = w * 0.26;
    CGRect ringRect = CGRectMake(ringInset, ringInset, w - ringInset * 2, h - ringInset * 2);
    UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:ringRect];
    [[UIColor colorWithWhite:1.0 alpha:0.75] setStroke];
    ring.lineWidth = lineWidth;
    [ring stroke];

    // 3) 正中实心圆点
    CGFloat dotInset = w * 0.40;
    CGRect dotRect = CGRectMake(dotInset, dotInset, w - dotInset * 2, h - dotInset * 2);
    UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:dotRect];
    [[UIColor colorWithWhite:1.0 alpha:0.95] setFill];
    [dot fill];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    (void)ctx;
    return image;
}

#pragma mark - Setup Views

- (void)setupViews {
    // Capsule view (container)
    self.capsuleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCapsuleWidth, kCapsuleHeight)];
    self.capsuleView.clipsToBounds = YES;

    // Capsule background view
    self.capsuleBackgroundView = [[UIView alloc] initWithFrame:self.capsuleView.bounds];
    self.capsuleBackgroundView.layer.cornerRadius = kCapsuleCornerRadius;
    self.capsuleBackgroundView.clipsToBounds = YES;

    // 背景: 仿 iOS 辅助触控(小白点)—— 系统用的是纯色半透明深灰, 不是渐变。
    // 渐变会让球看起来"有方向", 系统那个是均匀的。
    self.capsuleBackgroundView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.72];

    // 图标: 系统小白点内部是"圆角方框 + 圆环 + 实心圆点"三层同心图形,
    // SF Symbols 里没有完全对应的, 自己画一个。
    self.capsuleHandleIcon = [[UIImageView alloc] initWithFrame:CGRectMake(kCapsuleHandleIconX, kCapsuleHandleIconY, kCapsuleHandleIconWidth, kCapsuleHandleIconHeight)];
    self.capsuleHandleIcon.image = [ScrcpyMenuView assistiveTouchIconOfSize:CGSizeMake(kCapsuleHandleIconWidth, kCapsuleHandleIconHeight)];
    self.capsuleHandleIcon.contentMode = UIViewContentModeScaleAspectFit;

    // Add subviews to capsule view
    [self.capsuleView addSubview:self.capsuleBackgroundView];
    [self.capsuleView addSubview:self.capsuleHandleIcon];
    [self addSubview:self.capsuleView];

    // Menu view (expanded state)
    UIWindow *window = [self activeWindow];
    self.activeWindow = window;

    CGFloat initialMenuWidth = kMenuColumns * kButtonWidth + (kMenuColumns - 1) * kButtonSpacing + kMenuHorizontalPadding * 2;
    CGFloat maxAvailableWidth = window.bounds.size.width - (kMenuHorizontalPadding * 2);
    initialMenuWidth = MIN(initialMenuWidth, maxAvailableWidth);
    // 初始按 3 行估个高度, 真正的高度在 updateButtonLayout 里按可见按钮数算
    CGFloat initialMenuHeight = 3 * kButtonHeight + 2 * kButtonSpacing + kMenuVerticalPadding * 2;

    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, initialMenuWidth, initialMenuHeight)];
    self.menuView.layer.cornerRadius = kMenuCornerRadius;
    self.menuView.clipsToBounds = YES;
    self.menuView.alpha = 0;
    self.menuView.hidden = YES;

    // 展开面板: 和圆球同一种纯色半透明, 不用渐变(系统辅助触控的面板也是均匀色)
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.72];
    self.menuView.layer.masksToBounds = YES;

    // Create buttons with temporary positions
    CGRect tempButtonFrame = CGRectMake(0, 0, kButtonWidth, kButtonHeight);

    // Back button
    self.backButton = [self createButtonWithIcon:kIconBackButton position:tempButtonFrame];
    [self.menuView addSubview:self.backButton];

    // Home button
    self.homeButton = [self createButtonWithIcon:kIconHomeButton position:tempButtonFrame];
    [self.menuView addSubview:self.homeButton];

    // Switch button
    self.switchButton = [self createButtonWithIcon:kIconSwitchButton position:tempButtonFrame];
    [self.menuView addSubview:self.switchButton];

    // Keyboard button
    self.keyboardButton = [self createButtonWithIcon:kIconKeyboardButton position:tempButtonFrame];
    [self.menuView addSubview:self.keyboardButton];

    // Actions button
    self.actionsButton = [self createButtonWithIcon:kIconActionsButton position:tempButtonFrame];

    // Remove default button event handlers for Actions button
    [self.actionsButton removeTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.actionsButton removeTarget:self action:@selector(buttonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    [self.actionsButton removeTarget:self action:@selector(buttonTouchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
    [self.actionsButton removeTarget:self action:@selector(buttonTouchCancel:) forControlEvents:UIControlEventTouchCancel];

    // Add TapGesture to Actions button
    UITapGestureRecognizer *actionsTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionsButtonTappedViaGesture:)];
    actionsTapGesture.numberOfTapsRequired = 1;
    actionsTapGesture.cancelsTouchesInView = YES;
    [self.actionsButton addGestureRecognizer:actionsTapGesture];
    NSLog(@"🎯 [ScrcpyMenuView] Added TapGesture to Actions button");

    [self.menuView addSubview:self.actionsButton];

    // Clipboard Sync button (VNC only)
    self.clipboardSyncButton = [self createButtonWithIcon:kIconClipboardSyncButton position:tempButtonFrame];
    [self.menuView addSubview:self.clipboardSyncButton];

    // Reboot button (ADB only)
    self.rebootButton = [self createButtonWithIcon:kIconRebootButton position:tempButtonFrame];
    [self.menuView addSubview:self.rebootButton];

    // 截取当前屏幕: 高频操作, 放在按钮条上一步直达(「查看 UI 布局」留在更多菜单里)
    self.screenshotButton = [self createButtonWithIcon:kIconScreenshotButton position:tempButtonFrame];
    [self.menuView addSubview:self.screenshotButton];

    // 清理后台(adb shell am kill-all)
    self.cleanupButton = [self createButtonWithIcon:kIconCleanupButton position:tempButtonFrame];
    [self.menuView addSubview:self.cleanupButton];

    // Disconnect button
    self.disconnectButton = [self createButtonWithIcon:kIconDisconnectButton position:tempButtonFrame];
    [self.menuView addSubview:self.disconnectButton];
}

- (UIButton *)createButtonWithIcon:(NSString *)iconName position:(CGRect)frame {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;

    UIImage *icon = [UIImage systemImageNamed:iconName];
    [button setImage:icon forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    button.exclusiveTouch = YES;

    [button addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(buttonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(buttonTouchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(buttonTouchCancel:) forControlEvents:UIControlEventTouchCancel];

    button.accessibilityIdentifier = iconName;

    return button;
}

#pragma mark - Setup Gestures

- (void)setupGestures {
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapGesture.cancelsTouchesInView = YES;
    tapGesture.delaysTouchesEnded = YES;
    [self.capsuleView addGestureRecognizer:tapGesture];

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panGesture.cancelsTouchesInView = YES;
    panGesture.delaysTouchesEnded = YES;
    [self.capsuleView addGestureRecognizer:panGesture];

    // "点空白处收起菜单"的手势挂在整个窗口上, 会拦截投屏画面上的每一次触摸。
    // UIKit 在手势判定期间会扣住"抬手"事件(delaysTouchesEnded 默认 YES),
    // 实测导致抬手延迟约 0.5 秒 —— 正好达到安卓的长按阈值, 单击就变成了长按。
    // 因此: 平时禁用, 只在菜单展开时启用(那时本来也不该把点击透传给设备)。
    UITapGestureRecognizer *dismissTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissTap:)];
    dismissTapGesture.cancelsTouchesInView = YES;
    dismissTapGesture.delaysTouchesBegan = NO;
    dismissTapGesture.delaysTouchesEnded = NO;
    dismissTapGesture.enabled = NO;                 // 菜单收起时不参与触摸判定
    self.dismissGestureRecognizer = dismissTapGesture;
    [[self activeWindow] addGestureRecognizer:dismissTapGesture];
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    [self toggleMenuExpansion];
}

- (void)handleDismissTap:(UITapGestureRecognizer *)gesture {
    if (self.isExpanded) {
        CGPoint location = [gesture locationInView:self.window];
        if (![self.menuView pointInside:[self.menuView convertPoint:location fromView:self] withEvent:nil] &&
            ![self.capsuleView pointInside:[self.capsuleView convertPoint:location fromView:self] withEvent:nil]) {
            SDL_StopTextInput();
            [self toggleMenuExpansion];
        }
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    self.capsuleBackgroundView.alpha = kCapsuleAlphaNormal;

    UIView *referenceView = self.superview;
    if (!referenceView) {
        referenceView = [self activeWindow];
    }

    CGPoint translation = [gesture translationInView:referenceView];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        LOG_POSITION(@"Pan gesture began at position: (%.1f, %.1f)", self.frame.origin.x, self.frame.origin.y);
        LOG_POSITION(@"Current ratio: (%.3f, %.3f)", self.positionRatio.x, self.positionRatio.y);
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat newX = self.frame.origin.x + translation.x;
        CGFloat newY = self.frame.origin.y + translation.y;

        self.frame = CGRectMake(newX, newY, self.frame.size.width, self.frame.size.height);
        [gesture setTranslation:CGPointZero inView:referenceView];

        if (self.isExpanded) {
            [self updateMenuPosition];
        }

        LOG_POSITION(@"Dragging to position: (%.1f, %.1f)", newX, newY);
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        LOG_POSITION(@"Pan gesture ended, saving position");

        UIWindow *window = [self activeWindow];
        if (window && [self doesCapsuleOverlapDynamicIsland:window]) {
            LOG_POSITION(@"Dragged position overlaps with Dynamic Island, adjusting...");
            CGPoint adjustedPosition = [self adjustPositionToAvoidDynamicIsland:window];

            [UIView animateWithDuration:0.3 animations:^{
                self.frame = CGRectMake(adjustedPosition.x, adjustedPosition.y, self.frame.size.width, self.frame.size.height);
            }];

            LOG_POSITION(@"Position adjusted to: (%.1f, %.1f)", adjustedPosition.x, adjustedPosition.y);
        }

        [self updateRatioFromPosition];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isExpanded) {
                [UIView animateWithDuration:0.15 animations:^{
                    self.capsuleBackgroundView.alpha = kCapsuleAlphaIdle;
                }];
            }
        });
    }
}

#pragma mark - Menu Expansion

- (void)toggleMenuExpansion {
    if (self.isExpanded) {
        // 收起: 关掉窗口级手势, 恢复投屏触摸的原生响应速度
        self.dismissGestureRecognizer.enabled = NO;
        [UIView animateWithDuration:kAnimationDuration animations:^{
            self.menuView.alpha = 0;
            self.menuView.transform = CGAffineTransformMakeScale(0.5, 0.5);
            self.capsuleBackgroundView.alpha = kCapsuleAlphaIdle;
        } completion:^(BOOL finished) {
            self.menuView.hidden = YES;
            self.menuView.transform = CGAffineTransformIdentity;
            [self.menuView removeFromSuperview];
        }];

        [self.maskView hide];
    } else {
        // 展开: 启用"点空白处收起"手势
        self.dismissGestureRecognizer.enabled = YES;
        [self updateMenuPosition];
        [self updateButtonLayout];
        self.menuView.hidden = NO;
        self.menuView.alpha = 0;
        self.menuView.transform = CGAffineTransformMakeScale(0.5, 0.5);

        if (!self.maskView) {
            UIWindow *window = [self activeWindow];
            if (window) {
                self.maskView = [[ScrcpyMenuMaskView alloc] initWithFrame:window.bounds];
                self.maskView.delegate = self;
            }
        }

        UIWindow *window = [self activeWindow];
        if (window) {
            [self.maskView showInView:window];
            [window addSubview:self.menuView];
        }

        [UIView animateWithDuration:kMenuAnimationDuration
                              delay:kMenuAnimationDelay
             usingSpringWithDamping:kMenuAnimationSpringDamping
              initialSpringVelocity:kMenuAnimationSpringVelocity
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.menuView.alpha = 1.0;
            self.menuView.transform = CGAffineTransformIdentity;
            self.capsuleBackgroundView.alpha = kCapsuleAlphaExpanded;
        } completion:nil];
    }

    self.isExpanded = !self.isExpanded;
}

- (void)updateMenuPosition {
    UIWindow *window = [self activeWindow];
    if (!window) return;

    CGRect screenBounds = window.bounds;

    // 网格尺寸: 和 updateButtonLayout 里保持同一套算法
    NSInteger visibleButtonCount = [self visibleButtonCount];
    NSInteger columns = MIN(visibleButtonCount, kMenuColumns);
    NSInteger rows = (visibleButtonCount + kMenuColumns - 1) / kMenuColumns;
    if (columns < 1) columns = 1;
    if (rows < 1) rows = 1;

    CGFloat menuWidth = columns * kButtonWidth + (columns - 1) * kButtonSpacing + kMenuHorizontalPadding * 2;
    CGFloat menuHeight = rows * kButtonHeight + (rows - 1) * kButtonSpacing + kMenuVerticalPadding * 2;

    CGFloat availableWidth = screenBounds.size.width - (kMenuHorizontalPadding * 2);
    menuWidth = MIN(availableWidth, menuWidth);

    CGRect capsuleFrameInWindow = [self.capsuleView convertRect:self.capsuleView.bounds toView:window];

    CGFloat spaceAbove = capsuleFrameInWindow.origin.y;
    CGFloat spaceBelow = screenBounds.size.height - (capsuleFrameInWindow.origin.y + capsuleFrameInWindow.size.height);

    CGFloat menuY;
    BOOL showAbove = (spaceAbove > spaceBelow) && (spaceAbove >= menuHeight + kMenuVerticalSpacing * 2);

    if (showAbove) {
        menuY = capsuleFrameInWindow.origin.y - menuHeight - kMenuVerticalSpacing;
    } else {
        menuY = capsuleFrameInWindow.origin.y + capsuleFrameInWindow.size.height + kMenuVerticalSpacing;
    }

    menuY = MAX(kMenuHorizontalPadding,
                MIN(screenBounds.size.height - menuHeight - kMenuHorizontalPadding, menuY));

    CGFloat menuX;
    CGFloat screenCenterX = screenBounds.size.width / 2.0f;
    CGFloat capsuleCenterX = CGRectGetMidX(capsuleFrameInWindow);

    // 面板以悬浮球为中心展开 —— 系统辅助触控就是在球附近弹出的, 手指不用跑远。
    // (原来的逻辑是: 面板窄就跑到屏幕正中, 那是给横排长条菜单设计的, 网格面板不适用)
    menuX = capsuleCenterX - menuWidth / 2.0f;
    (void)screenCenterX;

    menuX = MAX(kMenuHorizontalPadding,
                MIN(screenBounds.size.width - menuWidth - kMenuHorizontalPadding, menuX));

    CGRect dynamicIslandRect = [self getDynamicIslandRect:window];
    if (dynamicIslandRect.size.height > 0) {
        CGRect proposedMenuRect = CGRectMake(menuX, menuY, menuWidth, menuHeight);

        if (CGRectIntersectsRect(proposedMenuRect, dynamicIslandRect)) {
            LOG_POSITION(@"Menu would overlap with Dynamic Island, adjusting position");

            CGFloat dynamicIslandBottom = dynamicIslandRect.origin.y + dynamicIslandRect.size.height;
            menuY = MAX(menuY, dynamicIslandBottom + kMenuVerticalSpacing);
            menuY = MIN(menuY, screenBounds.size.height - menuHeight - kMenuHorizontalPadding);

            LOG_POSITION(@"Menu position adjusted to avoid Dynamic Island: Y = %.1f", menuY);
        }
    }

    self.menuView.frame = CGRectMake(menuX, menuY, menuWidth, menuHeight);

    LOG_POSITION(@"🔧 updateMenuPosition completed, menu frame: (%.2f, %.2f, %.2f, %.2f)",
                 self.menuView.frame.origin.x, self.menuView.frame.origin.y,
                 self.menuView.frame.size.width, self.menuView.frame.size.height);

    if (!self.isUpdatingButtonLayout) {
        [self updateButtonLayout];
    }
}

#pragma mark - Fade Timer

- (void)startFadeTimer {
    [self.fadeTimer invalidate];
    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:kFadeTimerInterval target:self selector:@selector(fadeCapsule) userInfo:nil repeats:NO];
}

- (void)fadeCapsule {
    if (!self.isExpanded) {
        [UIView animateWithDuration:kAnimationDuration animations:^{
            self.capsuleBackgroundView.alpha = kCapsuleAlphaIdle;
        }];
    }
}

#pragma mark - Button Actions

- (void)backButtonTapped:(UIButton *)sender {
    SDL_StopTextInput();
    if ([self.delegate respondsToSelector:@selector(didTapBackButton)]) {
        [self.delegate didTapBackButton];
    }
}

- (void)homeButtonTapped:(UIButton *)sender {
    SDL_StopTextInput();
    if ([self.delegate respondsToSelector:@selector(didTapHomeButton)]) {
        [self.delegate didTapHomeButton];
    }
}

- (void)switchButtonTapped:(UIButton *)sender {
    SDL_StopTextInput();
    if ([self.delegate respondsToSelector:@selector(didTapSwitchButton)]) {
        [self.delegate didTapSwitchButton];
    }
}

- (void)rebootButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapRebootButton)]) {
        [self.delegate didTapRebootButton];
    }
}

- (void)cleanupButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapCleanupButton)]) {
        [self.delegate didTapCleanupButton];
    }
}

- (void)screenshotButtonTapped:(UIButton *)sender {
    NSLog(@"📷 [ScrcpyMenuView] Screenshot button tapped");
    // 先收起菜单, 否则截到的画面里会有菜单本身
    if (self.isExpanded) {
        [self toggleMenuExpansion];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self captureDeviceScreenshot];
    });
}

- (void)keyboardButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapKeyboardButton)]) {
        [self.delegate didTapKeyboardButton];
    }
    [self toggleMenuExpansion];
}

- (void)actionsButtonTapped:(UIButton *)sender {
    NSLog(@"🚀 [ScrcpyMenuView] Actions button tapped");
    SDL_StopTextInput();
    [self showActionsMenu];
}

- (void)actionsButtonTappedViaGesture:(UITapGestureRecognizer *)gesture {
    NSLog(@"🎯🎯🎯 [ScrcpyMenuView] actionsButtonTappedViaGesture called - GESTURE WORKING!");

    UIView *targetView = gesture.view;
    [UIView animateWithDuration:0.1 animations:^{
        targetView.alpha = 0.5;
        targetView.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            targetView.alpha = 1.0;
            targetView.transform = CGAffineTransformIdentity;
        }];
    }];

    SDL_StopTextInput();

    NSLog(@"🎯🎯🎯 [ScrcpyMenuView] About to call showActionsMenu via gesture");
    [self showActionsMenu];
}

- (void)disconnectButtonTapped:(UIButton *)sender {
    SDL_StopTextInput();
    if ([self.delegate respondsToSelector:@selector(didTapDisconnectButton)]) {
        [self.delegate didTapDisconnectButton];
    }
    [self toggleMenuExpansion];
}

#pragma mark - ScrcpyMenuMaskViewDelegate

- (void)didTapMenuMask {
    if (self.isExpanded) {
        [self toggleMenuExpansion];
    }
}

#pragma mark - Hit Testing

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.userInteractionEnabled || self.hidden || self.alpha <= 0.01) {
        return nil;
    }

    if (CGRectContainsPoint(self.capsuleView.frame, point)) {
        return self.capsuleView;
    }

    if (self.isExpanded && !self.menuView.hidden && self.menuView.superview) {
        CGPoint menuPoint = [self convertPoint:point toView:self.menuView];
        if ([self.menuView pointInside:menuPoint withEvent:event]) {
            return [self.menuView hitTest:menuPoint withEvent:event];
        }
    }

    if (self.currentDeviceType == ScrcpyDeviceTypeVNC) {
        return self;
    }

    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(self.capsuleView.frame, point)) {
        return YES;
    }

    if (self.isExpanded && !self.menuView.hidden && self.menuView.superview) {
        CGPoint menuPoint = [self convertPoint:point toView:self.menuView];
        if ([self.menuView pointInside:menuPoint withEvent:event]) {
            return YES;
        }
    }

    if (self.currentDeviceType == ScrcpyDeviceTypeVNC) {
        return YES;
    }

    return NO;
}

#pragma mark - Window Helper

- (UIWindow *)activeWindow {
    SDL_Window *window = SDL_GetMouseFocus();
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (SDL_GetWindowWMInfo(window, &info)) {
        UIWindow *uiWindow = info.info.uikit.window;
        return uiWindow;
    }
    return [UIApplication sharedApplication].keyWindow;
}

#pragma mark - Public Methods

- (void)addToActiveWindow {
    UIWindow *window = [self activeWindow];
    if (!window) return;

    LOG_POSITION(@"addToActiveWindow called");

    [self updateLayout];

    self.userInteractionEnabled = YES;
    self.capsuleView.userInteractionEnabled = YES;
    self.menuView.userInteractionEnabled = YES;

    for (UIView *subview in self.menuView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.exclusiveTouch = YES;
        }
    }

    self.maskView = [[ScrcpyMenuMaskView alloc] initWithFrame:window.bounds];
    self.maskView.delegate = self;

    self.capsuleBackgroundView.alpha = kCapsuleAlphaIdle;

    [window addSubview:self];
}

- (void)updateLayout {
    UIWindow *window = [self activeWindow];
    if (!window) return;

    LOG_POSITION(@"updateLayout called");

    [self updatePositionFromRatio];

    if (self.isExpanded) {
        [self updateMenuPosition];
    }
}

#pragma mark - Device Type Configuration

- (NSInteger)visibleButtonCount {
    // Single source of truth - keep in sync with getVisibleButtons
    return (NSInteger)[self getVisibleButtons].count;
}

+ (ScrcpyDeviceType)deviceTypeFromString:(NSString *)deviceTypeString {
    if ([deviceTypeString.lowercaseString isEqualToString:kDeviceTypeVNC]) {
        return ScrcpyDeviceTypeVNC;
    } else if ([deviceTypeString.lowercaseString isEqualToString:kDeviceTypeADB]) {
        return ScrcpyDeviceTypeADB;
    } else {
        return ScrcpyDeviceTypeADB;
    }
}

- (void)configureForDeviceType:(ScrcpyDeviceType)deviceType {
    self.currentDeviceType = deviceType;

    if (deviceType == ScrcpyDeviceTypeADB) {
        self.backButton.hidden = NO;
        self.homeButton.hidden = NO;
        self.switchButton.hidden = NO;
        self.keyboardButton.hidden = NO;
        self.actionsButton.hidden = NO;
        self.clipboardSyncButton.hidden = YES;
        self.rebootButton.hidden = NO;
        self.screenshotButton.hidden = NO;
        self.cleanupButton.hidden = NO;
        self.disconnectButton.hidden = NO;

        [self removePinchGesture];
        [self removeDragGesture];
        [self removeTapGesture];

        LOG_POSITION(@"Configured menu for ADB device - all buttons visible");
    } else if (deviceType == ScrcpyDeviceTypeVNC) {
        self.backButton.hidden = YES;
        self.homeButton.hidden = YES;
        self.switchButton.hidden = YES;
        self.keyboardButton.hidden = NO;
        self.actionsButton.hidden = NO;
        self.clipboardSyncButton.hidden = NO;
        self.rebootButton.hidden = YES;
        self.screenshotButton.hidden = YES;
        self.cleanupButton.hidden = YES;
        self.disconnectButton.hidden = NO;

        LOG_POSITION(@"🐆 [ScrcpyMenuView] Scheduling VNC gestures setup with 0.3s delay");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            LOG_POSITION(@"🐆 [ScrcpyMenuView] Adding VNC gestures now");
            [self addPinchGesture];
            [self addDragGesture];
            [self addTapGesture];
            [self setupGesturePriorities];
            LOG_POSITION(@"🐆 [ScrcpyMenuView] VNC gestures setup completed");
        });

        LOG_POSITION(@"Configured menu for VNC device - limited buttons visible and pinch gesture enabled");
    }

    [self updateButtonLayout];
}

- (NSArray<UIButton *> *)getVisibleButtons {
    NSMutableArray *visibleButtons = [NSMutableArray array];

    if (!self.backButton.hidden) [visibleButtons addObject:self.backButton];
    if (!self.homeButton.hidden) [visibleButtons addObject:self.homeButton];
    if (!self.switchButton.hidden) [visibleButtons addObject:self.switchButton];
    if (!self.keyboardButton.hidden) [visibleButtons addObject:self.keyboardButton];
    if (!self.screenshotButton.hidden) [visibleButtons addObject:self.screenshotButton];
    if (!self.actionsButton.hidden) [visibleButtons addObject:self.actionsButton];
    if (!self.clipboardSyncButton.hidden) [visibleButtons addObject:self.clipboardSyncButton];
    if (!self.cleanupButton.hidden) [visibleButtons addObject:self.cleanupButton];
    if (!self.disconnectButton.hidden) [visibleButtons addObject:self.disconnectButton];
    if (!self.rebootButton.hidden) [visibleButtons addObject:self.rebootButton];

    return [visibleButtons copy];
}

- (void)updateButtonLayout {
    if (!self.menuView) return;

    if (self.isUpdatingButtonLayout) {
        LOG_POSITION(@"🔧 updateButtonLayout skipped - already updating");
        return;
    }
    self.isUpdatingButtonLayout = YES;

    NSArray<UIButton *> *visibleButtons = [self getVisibleButtons];

    if (visibleButtons.count == 0) {
        LOG_POSITION(@"No visible buttons to layout");
        self.isUpdatingButtonLayout = NO;
        return;
    }

    LOG_POSITION(@"🔧 Starting updateButtonLayout - Device type: %ld", (long)self.currentDeviceType);
    LOG_POSITION(@"🔧 Visible buttons count: %ld", (long)visibleButtons.count);

    CGFloat buttonWidth = kButtonWidth;
    CGFloat buttonHeight = kButtonHeight;
    CGFloat spacing = kButtonSpacing;

    // 网格排布: 每行最多 kMenuColumns 个, 不足一行时按实际个数算宽度
    NSInteger totalCount = (NSInteger)visibleButtons.count;
    NSInteger columns = MIN(totalCount, kMenuColumns);
    NSInteger rows = (totalCount + kMenuColumns - 1) / kMenuColumns;

    CGFloat idealMenuWidth = columns * buttonWidth + (columns - 1) * spacing + kMenuHorizontalPadding * 2;
    CGFloat idealMenuHeight = rows * buttonHeight + (rows - 1) * spacing + kMenuVerticalPadding * 2;

    CGRect currentFrame = self.menuView.frame;
    CGFloat menuHeight = idealMenuHeight;

    // Re-center horizontally after the width changes instead of keeping the old
    // origin (which left the menu visually shifted to the left)
    CGFloat menuOriginX = currentFrame.origin.x;
    UIView *hostView = self.menuView.superview;
    if (hostView) {
        menuOriginX = (hostView.bounds.size.width - idealMenuWidth) / 2.0f;
        menuOriginX = MAX(kMenuHorizontalPadding,
                          MIN(hostView.bounds.size.width - idealMenuWidth - kMenuHorizontalPadding, menuOriginX));
    }

    // 面板变高之后要保证不会顶出屏幕
    CGFloat menuOriginY = currentFrame.origin.y;
    if (hostView) {
        CGFloat maxY = hostView.bounds.size.height - idealMenuHeight - kMenuVerticalPadding;
        menuOriginY = MAX(kMenuVerticalPadding, MIN(maxY, menuOriginY));
    }

    self.menuView.frame = CGRectMake(menuOriginX, menuOriginY, idealMenuWidth, menuHeight);

    for (NSInteger i = 0; i < totalCount; i++) {
        UIButton *button = visibleButtons[i];

        NSInteger row = i / kMenuColumns;
        NSInteger col = i % kMenuColumns;

        // 最后一行不满时居中摆放, 免得孤零零地挂在左边
        NSInteger countInThisRow = MIN(kMenuColumns, totalCount - row * kMenuColumns);
        CGFloat rowWidth = countInThisRow * buttonWidth + (countInThisRow - 1) * spacing;
        CGFloat rowStartX = (idealMenuWidth - rowWidth) / 2.0;

        CGFloat xPosition = rowStartX + col * (buttonWidth + spacing);
        CGFloat yPosition = kMenuVerticalPadding + row * (buttonHeight + spacing);

        button.translatesAutoresizingMaskIntoConstraints = YES;
        button.frame = CGRectMake(xPosition, yPosition, buttonWidth, buttonHeight);

        [button setNeedsLayout];
        [button layoutIfNeeded];
    }

    [self.menuView setNeedsLayout];
    [self.menuView layoutIfNeeded];

    LOG_POSITION(@"Updated button layout: %ld visible buttons, menu %.1f x %.1f",
                 (long)visibleButtons.count, idealMenuWidth, idealMenuHeight);

    self.isUpdatingButtonLayout = NO;
}

#pragma mark - Dynamic Island Avoidance

- (CGRect)getDynamicIslandRect:(UIWindow *)window {
    if (!window) return CGRectZero;

    CGRect screenBounds = window.bounds;
    CGFloat screenWidth = screenBounds.size.width;

    UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeAreaInsets = window.safeAreaInsets;
    }

    CGFloat dynamicIslandHeight = safeAreaInsets.top;
    CGFloat dynamicIslandX = (screenWidth - kDynamicIslandWidth) / 2.0;
    CGFloat dynamicIslandY = 0;

    CGRect dynamicIslandRect = CGRectMake(dynamicIslandX, dynamicIslandY, kDynamicIslandWidth, dynamicIslandHeight);

    LOG_POSITION(@"Dynamic Island rect: (%.1f, %.1f, %.1f, %.1f)",
                 dynamicIslandRect.origin.x, dynamicIslandRect.origin.y,
                 dynamicIslandRect.size.width, dynamicIslandRect.size.height);

    return dynamicIslandRect;
}

- (BOOL)doesCapsuleOverlapDynamicIsland:(UIWindow *)window {
    CGRect dynamicIslandRect = [self getDynamicIslandRect:window];

    if (dynamicIslandRect.size.height <= 0) {
        return NO;
    }

    CGRect capsuleRect = self.frame;
    BOOL overlap = CGRectIntersectsRect(capsuleRect, dynamicIslandRect);

    if (overlap) {
        LOG_POSITION(@"Capsule overlaps with Dynamic Island - Capsule: (%.1f, %.1f, %.1f, %.1f), Island: (%.1f, %.1f, %.1f, %.1f)",
                     capsuleRect.origin.x, capsuleRect.origin.y, capsuleRect.size.width, capsuleRect.size.height,
                     dynamicIslandRect.origin.x, dynamicIslandRect.origin.y, dynamicIslandRect.size.width, dynamicIslandRect.size.height);
    }

    return overlap;
}

- (CGPoint)adjustPositionToAvoidDynamicIsland:(UIWindow *)window {
    CGRect dynamicIslandRect = [self getDynamicIslandRect:window];

    if (dynamicIslandRect.size.height <= 0) {
        return self.frame.origin;
    }

    CGRect capsuleRect = self.frame;
    CGRect screenBounds = window.bounds;

    CGFloat moveLeft = dynamicIslandRect.origin.x - (capsuleRect.origin.x + capsuleRect.size.width);
    CGFloat moveRight = (dynamicIslandRect.origin.x + dynamicIslandRect.size.width) - capsuleRect.origin.x;
    CGFloat moveDown = (dynamicIslandRect.origin.y + dynamicIslandRect.size.height) - capsuleRect.origin.y;

    CGFloat newX = capsuleRect.origin.x;
    CGFloat newY = capsuleRect.origin.y;

    if (fabs(moveLeft) <= fabs(moveRight)) {
        newX = capsuleRect.origin.x + moveLeft;
        LOG_POSITION(@"Avoiding Dynamic Island by moving left by %.1f", fabs(moveLeft));
    } else {
        newX = capsuleRect.origin.x + moveRight;
        LOG_POSITION(@"Avoiding Dynamic Island by moving right by %.1f", moveRight);
    }

    if (newX < 0 || newX + capsuleRect.size.width > screenBounds.size.width) {
        newX = capsuleRect.origin.x;
        newY = capsuleRect.origin.y + moveDown;
        LOG_POSITION(@"Horizontal movement out of bounds, moving down by %.1f instead", moveDown);
    }

    newX = MAX(0, MIN(screenBounds.size.width - capsuleRect.size.width, newX));
    newY = MAX(0, MIN(screenBounds.size.height - capsuleRect.size.height, newY));

    LOG_POSITION(@"Adjusted position to avoid Dynamic Island: (%.1f, %.1f) -> (%.1f, %.1f)",
                 capsuleRect.origin.x, capsuleRect.origin.y, newX, newY);

    return CGPointMake(newX, newY);
}

#pragma mark - Button Touch Event Handlers

- (void)buttonTouchDown:(UIButton *)sender {
    [self animateButton:sender pressed:YES];
}

- (void)buttonTouchUpInside:(UIButton *)sender {
    [self animateButton:sender pressed:NO];
    NSString *buttonType = sender.accessibilityIdentifier;
    [self handleButtonAction:buttonType];
}

- (void)buttonTouchUpOutside:(UIButton *)sender {
    [self animateButton:sender pressed:NO];
}

- (void)buttonTouchCancel:(UIButton *)sender {
    [self animateButton:sender pressed:NO];
}

- (void)animateButton:(UIButton *)button pressed:(BOOL)pressed {
    [UIView animateWithDuration:0.1 animations:^{
        button.alpha = pressed ? 0.5 : 1.0;
        button.transform = pressed ? CGAffineTransformMakeScale(0.9, 0.9) : CGAffineTransformIdentity;
    }];
}

- (void)handleButtonAction:(NSString *)buttonType {
    if ([buttonType isEqualToString:kIconActionsButton]) {
        [self actionsButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconBackButton]) {
        [self backButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconHomeButton]) {
        [self homeButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconSwitchButton]) {
        [self switchButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconKeyboardButton]) {
        [self keyboardButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconClipboardSyncButton]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationVNCSyncClipboardRequest object:nil];
    } else if ([buttonType isEqualToString:kIconRebootButton]) {
        [self rebootButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconScreenshotButton]) {
        [self screenshotButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconCleanupButton]) {
        [self cleanupButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconDisconnectButton]) {
        [self disconnectButtonTapped:nil];
    }
}

@end
