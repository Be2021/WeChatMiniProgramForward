#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static BOOL WXRoundedEnabled = YES;

static BOOL WXClassNameContains(UIView *view, NSArray<NSString *> *keywords) {
    if (!view) return NO;

    NSString *className = NSStringFromClass(view.class);
    NSString *superName = NSStringFromClass(view.superview.class);

    for (NSString *keyword in keywords) {
        if ([className localizedCaseInsensitiveContainsString:keyword]) return YES;
        if ([superName localizedCaseInsensitiveContainsString:keyword]) return YES;
    }

    return NO;
}

static BOOL WXIsProbablyAvatar(UIView *view) {
    if (!view) return NO;

    CGRect frame = view.frame;
    CGFloat w = frame.size.width;
    CGFloat h = frame.size.height;

    if (w <= 0 || h <= 0) return NO;

    BOOL squareSmall = fabs(w - h) < 3 && w >= 30 && w <= 70;
    NSString *className = NSStringFromClass(view.class);

    if (squareSmall &&
        ([className localizedCaseInsensitiveContainsString:@"Avatar"] ||
         [className localizedCaseInsensitiveContainsString:@"Head"] ||
         [className localizedCaseInsensitiveContainsString:@"Contact"])) {
        return YES;
    }

    return NO;
}

static BOOL WXIsProbablyNavigationOrTab(UIView *view) {
    if (!view) return NO;

    if ([view isKindOfClass:UINavigationBar.class]) return YES;
    if ([view isKindOfClass:UITabBar.class]) return YES;

    NSString *className = NSStringFromClass(view.class);

    NSArray *keywords = @[
        @"Navigation",
        @"NavBar",
        @"TabBar",
        @"StatusBar"
    ];

    for (NSString *keyword in keywords) {
        if ([className localizedCaseInsensitiveContainsString:keyword]) {
            return YES;
        }
    }

    return NO;
}

static void WXApplyRound(UIView *view, CGFloat radius, BOOL clip) {
    if (!WXRoundedEnabled || !view) return;
    if (WXIsProbablyAvatar(view)) return;
    if (WXIsProbablyNavigationOrTab(view)) return;

    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = clip;

    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static void WXApplySoftShadow(UIView *view) {
    if (!view) return;

    view.layer.shadowColor = UIColor.blackColor.CGColor;
    view.layer.shadowOpacity = 0.08;
    view.layer.shadowRadius = 8;
    view.layer.shadowOffset = CGSizeMake(0, 3);
    view.layer.masksToBounds = NO;
}

static BOOL WXShouldRoundView(UIView *view) {
    if (!view) return NO;

    if (WXIsProbablyAvatar(view)) return NO;
    if (WXIsProbablyNavigationOrTab(view)) return NO;

    NSString *className = NSStringFromClass(view.class);

    NSArray *keywords = @[
        @"Bubble",
        @"Message",
        @"Msg",
        @"AppMsg",
        @"AppMessage",
        @"Card",
        @"Link",
        @"Image",
        @"Video",
        @"CellContent",
        @"ContentView",
        @"Chat",
        @"MMMenu",
        @"MenuItem",
        @"Input",
        @"Tool",
        @"Panel",
        @"Album",
        @"Sight"
    ];

    for (NSString *keyword in keywords) {
        if ([className localizedCaseInsensitiveContainsString:keyword]) {
            return YES;
        }
    }

    return NO;
}

static CGFloat WXRadiusForView(UIView *view) {
    NSString *className = NSStringFromClass(view.class);

    if ([className localizedCaseInsensitiveContainsString:@"MMMenu"]) {
        return 18.0;
    }

    if ([className localizedCaseInsensitiveContainsString:@"MenuItem"]) {
        return 14.0;
    }

    if ([className localizedCaseInsensitiveContainsString:@"Bubble"]) {
        return 18.0;
    }

    if ([className localizedCaseInsensitiveContainsString:@"AppMsg"] ||
        [className localizedCaseInsensitiveContainsString:@"Card"] ||
        [className localizedCaseInsensitiveContainsString:@"Link"]) {
        return 16.0;
    }

    if ([className localizedCaseInsensitiveContainsString:@"Image"] ||
        [className localizedCaseInsensitiveContainsString:@"Video"] ||
        [className localizedCaseInsensitiveContainsString:@"Sight"]) {
        return 14.0;
    }

    if ([className localizedCaseInsensitiveContainsString:@"Input"] ||
        [className localizedCaseInsensitiveContainsString:@"Tool"] ||
        [className localizedCaseInsensitiveContainsString:@"Panel"]) {
        return 18.0;
    }

    return 14.0;
}

%hook UIView

- (void)layoutSubviews {
    %orig;

    if (!WXRoundedEnabled) return;

    @try {
        if (!WXShouldRoundView(self)) return;

        CGRect frame = self.frame;
        if (frame.size.width < 20 || frame.size.height < 20) return;
        if (frame.size.width > UIScreen.mainScreen.bounds.size.width + 20) return;

        CGFloat radius = WXRadiusForView(self);
        WXApplyRound(self, radius, YES);

    } @catch (__unused NSException *exception) {}
}

%end

%hook MMMenuWindow

- (void)layoutSubviews {
    %orig;

    @try {
        WXApplyRound((UIView *)self, 22.0, NO);
    } @catch (__unused NSException *exception) {}
}

%end

%hook MMMenuItemView

- (void)layoutSubviews {
    %orig;

    @try {
        WXApplyRound((UIView *)self, 16.0, YES);
    } @catch (__unused NSException *exception) {}
}

%end

%hook UITableViewCell

- (void)layoutSubviews {
    %orig;

    @try {
        NSString *className = NSStringFromClass(self.class);

        if ([className localizedCaseInsensitiveContainsString:@"Chat"] ||
            [className localizedCaseInsensitiveContainsString:@"Message"] ||
            [className localizedCaseInsensitiveContainsString:@"Msg"] ||
            [className localizedCaseInsensitiveContainsString:@"Session"]) {

            UIView *content = self.contentView;
            WXApplyRound(content, 14.0, NO);
        }

    } @catch (__unused NSException *exception) {}
}

%end

%hook UIImageView

- (void)layoutSubviews {
    %orig;

    @try {
        if (WXIsProbablyAvatar(self)) return;

        CGRect frame = self.frame;
        if (frame.size.width < 40 || frame.size.height < 40) return;

        NSString *className = NSStringFromClass(self.superview.class);

        if ([className localizedCaseInsensitiveContainsString:@"Message"] ||
            [className localizedCaseInsensitiveContainsString:@"Msg"] ||
            [className localizedCaseInsensitiveContainsString:@"Image"] ||
            [className localizedCaseInsensitiveContainsString:@"App"] ||
            [className localizedCaseInsensitiveContainsString:@"Card"] ||
            [className localizedCaseInsensitiveContainsString:@"Chat"]) {

            WXApplyRound(self, 14.0, YES);
        }

    } @catch (__unused NSException *exception) {}
}

%end

%hook UIButton

- (void)layoutSubviews {
    %orig;

    @try {
        NSString *title = self.currentTitle ?: self.titleLabel.text;
        NSString *className = NSStringFromClass(self.class);
        NSString *superName = NSStringFromClass(self.superview.class);

        BOOL shouldRound = NO;

        if (title.length > 0) {
            shouldRound = YES;
        }

        if ([className localizedCaseInsensitiveContainsString:@"Button"] &&
            ([superName localizedCaseInsensitiveContainsString:@"Tool"] ||
             [superName localizedCaseInsensitiveContainsString:@"Panel"] ||
             [superName localizedCaseInsensitiveContainsString:@"Menu"])) {
            shouldRound = YES;
        }

        if (shouldRound) {
            CGRect frame = self.frame;
            if (frame.size.width >= 30 && frame.size.height >= 24) {
                WXApplyRound(self, MIN(frame.size.height / 2.0, 18.0), YES);
            }
        }

    } @catch (__unused NSException *exception) {}
}

%end

%ctor {
    NSLog(@"[WXRounded] 微信圆角美化插件已加载");
}
