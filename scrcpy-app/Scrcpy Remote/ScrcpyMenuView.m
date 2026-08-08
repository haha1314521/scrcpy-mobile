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
#import "ScrcpyActionsBridge.h"
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
// 鏀惰捣鎬? 浠?AssistiveTouch 鐨勫渾鐞?鍘熸湰鏄?55x26 鐨勮兌鍥?
static const CGFloat kCapsuleWidth = 50.0f;
static const CGFloat kCapsuleHeight = 50.0f;
static const CGFloat kCapsuleCornerRadius = 25.0f;
// 鍦嗙悆閲岀殑鍥炬爣: 灞呬腑鎽嗘斁(鍘熸潵杩欏嚑涓€兼槸鎸?55x26 鑳跺泭纭畻鐨? 鎹㈡垚鍦嗙悆浼氬亸)
static const CGFloat kCapsuleHandleIconWidth = 24.0f;
static const CGFloat kCapsuleHandleIconHeight = 24.0f;
static const CGFloat kCapsuleHandleIconX = (kCapsuleWidth - kCapsuleHandleIconWidth) / 2.0f;
static const CGFloat kCapsuleHandleIconY = (kCapsuleHeight - kCapsuleHandleIconHeight) / 2.0f;

// Capsule Alpha Values
static const CGFloat kCapsuleAlphaIdle = 0.3f;
static const CGFloat kCapsuleAlphaNormal = 0.8f;
static const CGFloat kCapsuleAlphaExpanded = 0.8f;

// Menu View Constants
// 灞曞紑鎬? 缃戞牸闈㈡澘銆傚師鏉ユ槸妯悜涓€鏉? 8 涓寜閽尋鍦ㄤ竴琛屾棦闅剧偣鍙堥毦鐪?
// 鏀规垚 3 鍒楃殑缃戞牸, 鎸夐挳鍙互鏀惧ぇ, 闈㈡澘鏁翠綋鍍?AssistiveTouch 閭ｆ牱鏄釜鍦嗚鏂瑰潡銆?static const NSInteger kMenuColumns = 3;
static const CGFloat kMenuHeight = 60.0f;          /* 浠呯敤浜庡垵濮嬪崰浣? 瀹為檯楂樺害鎸夎鏁扮畻 */
static const CGFloat kMenuCornerRadius = 22.0f;
static const CGFloat kMenuHorizontalPadding = 8.0f;
static const CGFloat kMenuVerticalPadding = 8.0f;
static const CGFloat kMenuVerticalSpacing = 10.0f;

// Button Constants
// 缃戞牸閲屾寜閽仛鎴愭鏂瑰舰銆傚師鏈?52x60 鏄í鎺掍竴鏉℃椂鐨勫昂瀵?
// 楂樻瘮瀹借繕澶? 鎽嗗埌 3x3 缃戞牸閲屼細鏄惧緱鏁翠釜闈㈡澘鍙堥珮鍙堝ⅸ銆?static const CGFloat kButtonWidth = 48.0f;
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

    // 鍒囧悗鍙?鍥炲墠鍙扮殑鐬棿 window 鍙兘杩樻病甯冨眬濂? bounds 鏄?0銆?    // 杩欐椂涓嬮潰绠楀嚭鏉ョ殑"鏈€澶у亸绉?涔熸槸 0, 浣嶇疆浼氬闄锋垚灞忓箷姝ｄ腑 鈥斺€?    // 琛ㄧ幇灏辨槸"鍒囦竴娆″悗鍙板洖鏉? 鎮诞鐞冭窇鍒颁腑闂村幓浜?銆傜洿鎺ユ斁寮冭繖娆″畾浣嶃€?    if (screenWidth <= 1.0 || screenHeight <= 1.0) {
        LOG_POSITION(@"Window not laid out yet (%.1f x %.1f), skip repositioning", screenWidth, screenHeight);
        return;
    }
    if (self.frame.size.width <= 1.0 || self.frame.size.height <= 1.0) {
        LOG_POSITION(@"Self not sized yet, skip repositioning");
        return;
    }

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

    // 鍚岀悊: 鍋忕Щ閲忓闄锋椂涓嶈纭畻, 鍚﹀垯缁撴灉灏辨槸灞忓箷姝ｄ腑
    if (maxOffsetX <= 1.0 && maxOffsetY <= 1.0) {
        LOG_POSITION(@"Max offsets collapsed (%.1f, %.1f), skip repositioning", maxOffsetX, maxOffsetY);
        return;
    }

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

#pragma mark - AssistiveTouch 椋庢牸鍥炬爣

// 鐓х潃 iOS 杈呭姪瑙︽帶鐨勫皬鐧界偣鐢? 澶栧眰鍦嗚鏂规, 涓棿鍦嗙幆, 姝ｄ腑瀹炲績鍦嗙偣銆?// 涓夊眰閮界敤鐧借壊浣嗛€忔槑搴﹂€掑, 瓒婂線閲岃秺瀹? 鍜岀郴缁熻鎰熶竴鑷淬€?+ (UIImage *)assistiveTouchIconOfSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);

    CGFloat w = size.width;
    CGFloat h = size.height;

    // 鍏堝墠鐢ㄦ弿杈圭敾浜嗕竴灞傚渾瑙掓柟妗? 鐪嬬潃鍍忕浉妗嗐€?    // 绯荤粺灏忕櫧鐐圭殑瑙嗚閲嶅績鍦ㄤ腑闂寸殑鍦? 澶栧眰鍙槸寰堟贰鐨勮‖搴?
    // 鎵€浠ユ敼鎴? 娣″簳鍦嗚鏂瑰潡(濉厖) + 鍦嗙幆 + 涓績鍦嗙偣銆?
    // 1) 娣″簳鍦嗚鏂瑰潡(濉厖鑰岄潪鎻忚竟)
    CGRect plateRect = CGRectMake(0, 0, w, h);
    UIBezierPath *plate = [UIBezierPath bezierPathWithRoundedRect:plateRect
                                                     cornerRadius:w * 0.32];
    [[UIColor colorWithWhite:1.0 alpha:0.22] setFill];
    [plate fill];

    // 2) 鍦嗙幆
    CGFloat ringLine = MAX(1.5, w * 0.085);
    CGFloat ringInset = w * 0.22;
    CGRect ringRect = CGRectInset(CGRectMake(0, 0, w, h), ringInset, ringInset);
    UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:ringRect];
    ring.lineWidth = ringLine;
    [[UIColor colorWithWhite:1.0 alpha:0.92] setStroke];
    [ring stroke];

    // 3) 涓績瀹炲績鍦嗙偣
    CGFloat dotInset = w * 0.40;
    CGRect dotRect = CGRectInset(CGRectMake(0, 0, w, h), dotInset, dotInset);
    UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:dotRect];
    [[UIColor colorWithWhite:1.0 alpha:1.0] setFill];
    [dot fill];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
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

    // 鑳屾櫙: 浠?iOS 杈呭姪瑙︽帶(灏忕櫧鐐?鈥斺€?绯荤粺鐢ㄧ殑鏄函鑹插崐閫忔槑娣辩伆, 涓嶆槸娓愬彉銆?    // 娓愬彉浼氳鐞冪湅璧锋潵"鏈夋柟鍚?, 绯荤粺閭ｄ釜鏄潎鍖€鐨勩€?    self.capsuleBackgroundView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.72];

    // 鍥炬爣: 绯荤粺灏忕櫧鐐瑰唴閮ㄦ槸"鍦嗚鏂规 + 鍦嗙幆 + 瀹炲績鍦嗙偣"涓夊眰鍚屽績鍥惧舰,
    // SF Symbols 閲屾病鏈夊畬鍏ㄥ搴旂殑, 鑷繁鐢讳竴涓€?    self.capsuleHandleIcon = [[UIImageView alloc] initWithFrame:CGRectMake(kCapsuleHandleIconX, kCapsuleHandleIconY, kCapsuleHandleIconWidth, kCapsuleHandleIconHeight)];
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
    // 鍒濆鎸?3 琛屼及涓珮搴? 鐪熸鐨勯珮搴﹀湪 updateButtonLayout 閲屾寜鍙鎸夐挳鏁扮畻
    CGFloat initialMenuHeight = 3 * kButtonHeight + 2 * kButtonSpacing + kMenuVerticalPadding * 2;

    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, initialMenuWidth, initialMenuHeight)];
    self.menuView.layer.cornerRadius = kMenuCornerRadius;
    self.menuView.clipsToBounds = YES;
    self.menuView.alpha = 0;
    self.menuView.hidden = YES;

    // 灞曞紑闈㈡澘: 鍜屽渾鐞冨悓涓€绉嶇函鑹插崐閫忔槑, 涓嶇敤娓愬彉(绯荤粺杈呭姪瑙︽帶鐨勯潰鏉夸篃鏄潎鍖€鑹?
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
    NSLog(@"馃幆 [ScrcpyMenuView] Added TapGesture to Actions button");

    [self.menuView addSubview:self.actionsButton];

    // Clipboard Sync button (VNC only)
    self.clipboardSyncButton = [self createButtonWithIcon:kIconClipboardSyncButton position:tempButtonFrame];
    [self.menuView addSubview:self.clipboardSyncButton];

    // Reboot button (ADB only)
    self.rebootButton = [self createButtonWithIcon:kIconRebootButton position:tempButtonFrame];
    [self.menuView addSubview:self.rebootButton];

    // 鎴彇褰撳墠灞忓箷: 楂橀鎿嶄綔, 鏀惧湪鎸夐挳鏉′笂涓€姝ョ洿杈?銆屾煡鐪?UI 甯冨眬銆嶇暀鍦ㄦ洿澶氳彍鍗曢噷)
    self.screenshotButton = [self createButtonWithIcon:kIconScreenshotButton position:tempButtonFrame];
    [self.menuView addSubview:self.screenshotButton];

    // 娓呯悊鍚庡彴(adb shell am kill-all)
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

    // "鐐圭┖鐧藉鏀惰捣鑿滃崟"鐨勬墜鍔挎寕鍦ㄦ暣涓獥鍙ｄ笂, 浼氭嫤鎴姇灞忕敾闈笂鐨勬瘡涓€娆¤Е鎽搞€?    // UIKit 鍦ㄦ墜鍔垮垽瀹氭湡闂翠細鎵ｄ綇"鎶墜"浜嬩欢(delaysTouchesEnded 榛樿 YES),
    // 瀹炴祴瀵艰嚧鎶墜寤惰繜绾?0.5 绉?鈥斺€?姝ｅソ杈惧埌瀹夊崜鐨勯暱鎸夐槇鍊? 鍗曞嚮灏卞彉鎴愪簡闀挎寜銆?    // 鍥犳: 骞虫椂绂佺敤, 鍙湪鑿滃崟灞曞紑鏃跺惎鐢?閭ｆ椂鏈潵涔熶笉璇ユ妸鐐瑰嚮閫忎紶缁欒澶?銆?    UITapGestureRecognizer *dismissTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissTap:)];
    dismissTapGesture.cancelsTouchesInView = YES;
    dismissTapGesture.delaysTouchesBegan = NO;
    dismissTapGesture.delaysTouchesEnded = NO;
    dismissTapGesture.enabled = NO;                 // 鑿滃崟鏀惰捣鏃朵笉鍙備笌瑙︽懜鍒ゅ畾
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
        // 鏀惰捣: 鍏虫帀绐楀彛绾ф墜鍔? 鎭㈠鎶曞睆瑙︽懜鐨勫師鐢熷搷搴旈€熷害
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
        // 灞曞紑: 鍚敤"鐐圭┖鐧藉鏀惰捣"鎵嬪娍
        self.dismissGestureRecognizer.enabled = YES;
        // 鍔ㄤ綔鍙兘鍒氳鏂板缓/鍒犻櫎/鏀瑰浘鏍? 姣忔灞曞紑閮介噸寤轰竴閬?        [self refreshCustomActionButtons];
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

    // 缃戞牸灏哄: 鍜?updateButtonLayout 閲屼繚鎸佸悓涓€濂楃畻娉?    NSInteger visibleButtonCount = [self visibleButtonCount];
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

    // 闈㈡澘浠ユ偓娴悆涓轰腑蹇冨睍寮€ 鈥斺€?绯荤粺杈呭姪瑙︽帶灏辨槸鍦ㄧ悆闄勮繎寮瑰嚭鐨? 鎵嬫寚涓嶇敤璺戣繙銆?    // (鍘熸潵鐨勯€昏緫鏄? 闈㈡澘绐勫氨璺戝埌灞忓箷姝ｄ腑, 閭ｆ槸缁欐í鎺掗暱鏉¤彍鍗曡璁＄殑, 缃戞牸闈㈡澘涓嶉€傜敤)
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

    LOG_POSITION(@"馃敡 updateMenuPosition completed, menu frame: (%.2f, %.2f, %.2f, %.2f)",
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

/// 鎵ц琚浐瀹氬埌鎸夐挳鏉′笂鐨勮嚜瀹氫箟鍔ㄤ綔
- (void)executePinnedActionWithId:(NSString *)actionId {
    NSArray<ScrcpyActionData *> *actions = [[ScrcpyActionsBridge shared] getActionsForCurrentDevice];
    for (ScrcpyActionData *action in actions) {
        if (![action.actionId isEqualToString:actionId]) continue;

        NSLog(@"\U0001F9E9 [ScrcpyMenuView] Executing pinned action: %@", action.name);
        if (self.isExpanded) {
            [self toggleMenuExpansion];
        }
        [self executeActionData:action];
        return;
    }
    NSLog(@"\U0001F9E9 [ScrcpyMenuView] Pinned action %@ not found (deleted?)", actionId);
}

- (void)screenshotButtonTapped:(UIButton *)sender {
    NSLog(@"馃摲 [ScrcpyMenuView] Screenshot button tapped");
    // 鍏堟敹璧疯彍鍗? 鍚﹀垯鎴埌鐨勭敾闈㈤噷浼氭湁鑿滃崟鏈韩
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
    NSLog(@"馃殌 [ScrcpyMenuView] Actions button tapped");
    SDL_StopTextInput();
    [self showActionsMenu];
}

- (void)actionsButtonTappedViaGesture:(UITapGestureRecognizer *)gesture {
    NSLog(@"馃幆馃幆馃幆 [ScrcpyMenuView] actionsButtonTappedViaGesture called - GESTURE WORKING!");

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

    NSLog(@"馃幆馃幆馃幆 [ScrcpyMenuView] About to call showActionsMenu via gesture");
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

        LOG_POSITION(@"馃悊 [ScrcpyMenuView] Scheduling VNC gestures setup with 0.3s delay");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            LOG_POSITION(@"馃悊 [ScrcpyMenuView] Adding VNC gestures now");
            [self addPinchGesture];
            [self addDragGesture];
            [self addTapGesture];
            [self setupGesturePriorities];
            LOG_POSITION(@"馃悊 [ScrcpyMenuView] VNC gestures setup completed");
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

    // 鍕鹃€変簡涓婃寜閽潯鐨勮嚜瀹氫箟鍔ㄤ綔鎺ュ湪鍚庨潰
    for (UIButton *button in self.customActionButtons) {
        if (!button.hidden) [visibleButtons addObject:button];
    }

    return [visibleButtons copy];
}

/// 閲嶅缓鑷畾涔夊姩浣滄寜閽€?///
/// 鍔ㄤ綔鍙兘闅忔椂琚柊寤?鍒犻櫎/鏀瑰浘鏍? 鎵€浠ヤ笉鍋氬閲忔洿鏂? 鐩存帴鍏ㄩ儴閲嶅缓銆?/// 鎸夐挳鐨?accessibilityIdentifier 瀛樻垚 "action:<uuid>", 鐐瑰嚮鍒嗗彂鏃堕潬杩欎釜鍓嶇紑璇嗗埆銆?- (void)refreshCustomActionButtons {
    if (!self.customActionButtons) {
        self.customActionButtons = [NSMutableArray array];
    }
    for (UIButton *button in self.customActionButtons) {
        [button removeFromSuperview];
    }
    [self.customActionButtons removeAllObjects];

    NSArray<ScrcpyActionData *> *actions = [[ScrcpyActionsBridge shared] getActionsForCurrentDevice];
    for (ScrcpyActionData *action in actions) {
        if (!action.showInFloatingMenu) continue;

        NSString *iconName = action.floatingMenuIcon.length > 0 ? action.floatingMenuIcon : @"bolt.fill";
        UIButton *button = [self createButtonWithIcon:iconName
                                             position:CGRectMake(0, 0, kButtonWidth, kButtonHeight)];
        // 鐢ㄥ墠缂€鍖哄垎浜庡浐瀹氭寜閽?鍥哄畾鎸夐挳瀛樼殑鏄浘鏍囧悕)
        button.accessibilityIdentifier = [NSString stringWithFormat:@"action:%@", action.actionId];
        [self.menuView addSubview:button];
        [self.customActionButtons addObject:button];
    }

    if (self.customActionButtons.count > 0) {
        NSLog(@"\U0001F9E9 [ScrcpyMenuView] %lu custom action button(s) on the bar",
              (unsigned long)self.customActionButtons.count);
    }
}

- (void)updateButtonLayout {
    if (!self.menuView) return;

    if (self.isUpdatingButtonLayout) {
        LOG_POSITION(@"馃敡 updateButtonLayout skipped - already updating");
        return;
    }
    self.isUpdatingButtonLayout = YES;

    NSArray<UIButton *> *visibleButtons = [self getVisibleButtons];

    if (visibleButtons.count == 0) {
        LOG_POSITION(@"No visible buttons to layout");
        self.isUpdatingButtonLayout = NO;
        return;
    }

    LOG_POSITION(@"馃敡 Starting updateButtonLayout - Device type: %ld", (long)self.currentDeviceType);
    LOG_POSITION(@"馃敡 Visible buttons count: %ld", (long)visibleButtons.count);

    CGFloat buttonWidth = kButtonWidth;
    CGFloat buttonHeight = kButtonHeight;
    CGFloat spacing = kButtonSpacing;

    // 缃戞牸鎺掑竷: 姣忚鏈€澶?kMenuColumns 涓? 涓嶈冻涓€琛屾椂鎸夊疄闄呬釜鏁扮畻瀹藉害
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

    // 闈㈡澘鍙橀珮涔嬪悗瑕佷繚璇佷笉浼氶《鍑哄睆骞?    CGFloat menuOriginY = currentFrame.origin.y;
    if (hostView) {
        CGFloat maxY = hostView.bounds.size.height - idealMenuHeight - kMenuVerticalPadding;
        menuOriginY = MAX(kMenuVerticalPadding, MIN(maxY, menuOriginY));
    }

    self.menuView.frame = CGRectMake(menuOriginX, menuOriginY, idealMenuWidth, menuHeight);

    for (NSInteger i = 0; i < totalCount; i++) {
        UIButton *button = visibleButtons[i];

        NSInteger row = i / kMenuColumns;
        NSInteger col = i % kMenuColumns;

        // 鏈€鍚庝竴琛屼笉婊℃椂灞呬腑鎽嗘斁, 鍏嶅緱瀛ら浂闆跺湴鎸傚湪宸﹁竟
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
    } else if ([buttonType hasPrefix:@"action:"]) {
        [self executePinnedActionWithId:[buttonType substringFromIndex:7]];
    } else if ([buttonType isEqualToString:kIconScreenshotButton]) {
        [self screenshotButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconCleanupButton]) {
        [self cleanupButtonTapped:nil];
    } else if ([buttonType isEqualToString:kIconDisconnectButton]) {
        [self disconnectButtonTapped:nil];
    }
}

@end
