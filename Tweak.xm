#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL WMPFEnabled(void) {
    return YES;
}

static BOOL WMPFIsMenuWindow(UIWindow *window) {
    return [NSStringFromClass(window.class) isEqualToString:@"MMMenuWindow"];
}

static BOOL WMPFIsMenuItemView(UIView *view) {
    return [NSStringFromClass(view.class) isEqualToString:@"MMMenuItemView"];
}

static UILabel *WMPFFindLabel(UIView *view) {
    if (!view) return nil;

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
                UIViewController *root = window.rootViewController;
                while (root.presentedViewController) {
                    root = root.presentedViewController;
                }
                return root;
            }
        }
    }

    return nil;
}

static void WMPFShowAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = WMPFRootViewController();
        if (!root) return;

        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:title
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
    WMPFShowAlert(@"小程序分享可转发", @"已点击“转发”。下一步需要接入微信原生转发流程。");
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

static BOOL WMPFMenuHasTitle(NSArray<UIView *> *items, NSString *title) {
    for (UIView *item in items) {
        UILabel *label = WMPFFindLabel(item);
        if ([label.text isEqualToString:title]) {
            return YES;
        }
    }

    return NO;
}

static UIView *WMPFFindLikelyContainer(NSArray<UIView *> *items) {
    NSMutableDictionary<NSValue *, NSNumber *> *counter = [NSMutableDictionary dictionary];

    for (UIView *item in items) {
        UIView *superview = item.superview;
        if (!superview) continue;

        NSValue *key = [NSValue valueWithNonretainedObject:superview];
        counter[key] = @([counter[key] integerValue] + 1);
    }

    UIView *best = nil;
    NSInteger bestCount = 0;

    for (NSValue *key in counter) {
        NSInteger count = counter[key].integerValue;
        if (count > bestCount) {
            bestCount = count;
            best = key.nonretainedObjectValue;
        }
    }

    return best;
}

static UIView *WMPFCloneMenuItem(UIView *sourceItem) {
    if (!sourceItem) return nil;

    NSData *data = nil;
    UIView *newItem = nil;

    @try {
        data = [NSKeyedArchiver archivedDataWithRootObject:sourceItem
                                     requiringSecureCoding:NO
                                                     error:nil];

        newItem = [NSKeyedUnarchiver unarchivedObjectOfClass:UIView.class
                                                    fromData:data
                                                       error:nil];
    } @catch (__unused NSException *exception) {
        newItem = nil;
    }

    return newItem;
}

static void WMPFInjectForwardButton(UIWindow *menuWindow) {
    if (!WMPFEnabled()) return;
    if (!WMPFIsMenuWindow(menuWindow)) return;

    NSMutableArray<UIView *> *items = [NSMutableArray array];
    WMPFCollectMenuItems(menuWindow, items);

    if (items.count == 0) return;

    // 如果微信本身已经有“转发”，就不重复加
    if (WMPFMenuHasTitle(items, @"转发")) return;

    UIView *sourceItem = nil;

    // 优先复制“从当前听”这一类第二排菜单项
    for (UIView *item in items) {
        UILabel *label = WMPFFindLabel(item);
        if ([label.text isEqualToString:@"从当前听"]) {
            sourceItem = item;
            break;
        }
    }

    // 没找到就复制最后一个
    if (!sourceItem) {
        sourceItem = items.lastObject;
    }

    UIView *container = WMPFFindLikelyContainer(items);
    if (!container || !sourceItem) return;

    UIView *forwardItem = WMPFCloneMenuItem(sourceItem);
    if (!forwardItem) return;

    UILabel *label = WMPFFindLabel(forwardItem);
    if (label) {
        label.text = @"转发";
    }

    CGRect frame = sourceItem.frame;

    // 默认放到 sourceItem 右边
    frame.origin.x += frame.size.width + 8;

    // 如果超出容器右边，则放到下一行左边
    CGFloat maxX = CGRectGetMaxX(frame);
    if (maxX > container.bounds.size.width - 8) {
        frame.origin.x = sourceItem.frame.origin.x;
        frame.origin.y += frame.size.height + 10;
    }

    forwardItem.frame = frame;
    forwardItem.userInteractionEnabled = YES;

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:[WMPFForwardTarget shared]
                                                action:@selector(forwardTapped)];

    [forwardItem addGestureRecognizer:tap];

    [container addSubview:forwardItem];
}

static void WMPFTryInjectAllMenuWindows(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            for (UIWindow *window in windowScene.windows) {
                if (WMPFIsMenuWindow(window)) {
                    WMPFInjectForwardButton(window);
                }
            }
        }
    });
}

%hook MMMenuWindow

- (void)didAddSubview:(UIView *)subview {
    %orig;
    WMPFTryInjectAllMenuWindows();
}

- (void)layoutSubviews {
    %orig;
    WMPFTryInjectAllMenuWindows();
}

%end

%hook UILongPressGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    %orig;

    if (state == UIGestureRecognizerStateBegan ||
        state == UIGestureRecognizerStateChanged ||
        state == UIGestureRecognizerStateEnded) {
        WMPFTryInjectAllMenuWindows();
    }
}

%end

%ctor {
    NSLog(@"[WMPF] 小程序分享可转发 UI 注入版 loaded");
}
