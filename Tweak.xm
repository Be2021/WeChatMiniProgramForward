#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL WMPFIsMenuItemView(UIView *view) {
    return [NSStringFromClass(view.class) isEqualToString:@"MMMenuItemView"];
}

static NSString *WMPFTextOfView(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) {
        return ((UILabel *)view).text;
    }

    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        return button.currentTitle ?: button.titleLabel.text;
    }

    return nil;
}

static UILabel *WMPFFindLabel(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) {
        return (UILabel *)view;
    }

    for (UIView *subview in view.subviews) {
        UILabel *label = WMPFFindLabel(subview);
        if (label) return label;
    }

    return nil;
}

static UIViewController *WMPFRootViewController(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window.rootViewController;
            }
        }
    }

    return nil;
}

static void WMPFShowAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = WMPFRootViewController();
        if (!root) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];

        [root presentViewController:alert animated:YES completion:nil];
    });
}

@interface WMPFForwardTarget : NSObject
+ (instancetype)shared;
- (void)forwardTapped;
@end

@implementation WMPFForwardTarget

+ (instancetype)shared {
    static WMPFForwardTarget *target = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [WMPFForwardTarget new];
    });
    return target;
}

- (void)forwardTapped {
    WMPFShowAlert(@"WMPF", @"已点击转发按钮。下一步接入微信原生转发逻辑。");
}

@end

static void WMPFCollectMenuItems(UIView *view, NSMutableArray<UIView *> *items) {
    if (!view) return;

    if (WMPFIsMenuItemView(view)) {
        UILabel *label = WMPFFindLabel(view);
        if (label.text.length > 0) {
            [items addObject:view];
        }
    }

    for (UIView *subview in view.subviews) {
        WMPFCollectMenuItems(subview, items);
    }
}

static BOOL WMPFMenuAlreadyHasForward(NSArray<UIView *> *items) {
    for (UIView *item in items) {
        UILabel *label = WMPFFindLabel(item);
        if ([label.text isEqualToString:@"转发"]) {
            return YES;
        }
    }

    return NO;
}

static UIView *WMPFFindLikelyContainer(NSArray<UIView *> *items) {
    NSMutableDictionary<NSValue *, NSNumber *> *counts = [NSMutableDictionary dictionary];

    for (UIView *item in items) {
        UIView *superview = item.superview;
        if (!superview) continue;

        NSValue *key = [NSValue valueWithNonretainedObject:superview];
        counts[key] = @([counts[key] integerValue] + 1);
    }

    UIView *bestSuperview = nil;
    NSInteger bestCount = 0;

    for (NSValue *key in counts) {
        NSInteger count = counts[key].integerValue;
        if (count > bestCount) {
            bestCount = count;
            bestSuperview = key.nonretainedObjectValue;
        }
    }

    return bestSuperview;
}

static void WMPFInjectForwardButton(UIWindow *menuWindow) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    WMPFCollectMenuItems(menuWindow, items);

    if (items.count == 0 || WMPFMenuAlreadyHasForward(items)) return;

    UIView *sourceItem = nil;
    for (UIView *item in items) {
        UILabel *label = WMPFFindLabel(item);
        if ([label.text isEqualToString:@"从当前听"]) {
            sourceItem = item;
            break;
        }
    }

    if (!sourceItem) {
        sourceItem = items.lastObject;
    }

    UIView *container = WMPFFindLikelyContainer(items);
    if (!container || !sourceItem) return;

    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:sourceItem requiringSecureCoding:NO error:nil];
    UIView *forwardItem = [NSKeyedUnarchiver unarchivedObjectOfClass:UIView.class fromData:archivedData error:nil];

    if (!forwardItem) return;

    UILabel *label = WMPFFindLabel(forwardItem);
    label.text = @"转发";

    CGRect frame = sourceItem.frame;
    frame.origin.x += frame.size.width + 8;
    forwardItem.frame = frame;

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:[WMPFForwardTarget shared]
                                                action:@selector(forwardTapped)];
    [forwardItem addGestureRecognizer:tap];
    forwardItem.userInteractionEnabled = YES;

    [container addSubview:forwardItem];
}

static void WMPFTryInjectMenu(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if ([NSStringFromClass(window.class) isEqualToString:@"MMMenuWindow"]) {
                    WMPFInjectForwardButton(window);
                }
            }
        }
    });
}

%hook MMMenuWindow

- (void)didMoveToWindow {
    %orig;
    WMPFTryInjectMenu();
}

- (void)didAddSubview:(UIView *)subview {
    %orig;
    WMPFTryInjectMenu();
}

- (void)layoutSubviews {
    %orig;
    WMPFTryInjectMenu();
}

%end

%hook UILongPressGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    %orig;

    if (state == UIGestureRecognizerStateBegan ||
        state == UIGestureRecognizerStateChanged ||
        state == UIGestureRecognizerStateEnded) {
        WMPFTryInjectMenu();
    }
}

%end
