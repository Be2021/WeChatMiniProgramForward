#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

static void WMPFCollectTexts(UIView *view, NSMutableString *result, NSInteger depth) {
    if (!view || depth > 8) return;

    NSString *text = WMPFTextOfView(view);
    if (text.length > 0) {
        [result appendFormat:@"text=%@ | view=%@ | super=%@ | frame=%@\n",
         text,
         NSStringFromClass(view.class),
         NSStringFromClass(view.superview.class),
         NSStringFromCGRect(view.frame)];
    }

    for (UIView *subview in view.subviews) {
        WMPFCollectTexts(subview, result, depth + 1);
    }
}

static UIViewController *WMPFRootViewController(void) {
    UIWindow *targetWindow = nil;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                targetWindow = window;
                break;
            }
        }

        if (targetWindow) break;
    }

    return targetWindow.rootViewController;
}

static UIWindow *WMPFKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
    }

    return nil;
}

static void WMPFShowResult(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = WMPFRootViewController();
        if (!root) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WMPF 菜单扫描结果"
                                                                       message:@"已复制到剪贴板，发给我分析。"
                                                                preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];

        UIPasteboard.generalPasteboard.string = message;

        [root presentViewController:alert animated:YES completion:nil];
    });
}

static void WMPFScanVisibleMenu(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableString *result = [NSMutableString string];
        UIWindow *keyWindow = WMPFKeyWindow();

        [result appendFormat:@"keyWindow=%@\n", NSStringFromClass(keyWindow.class)];


        NSArray *windows = nil;
        NSMutableArray *allWindows = [NSMutableArray array];

        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            [allWindows addObjectsFromArray:windowScene.windows];
        }

        windows = allWindows;

        for (UIWindow *window in windows) {
            [result appendFormat:@"\nWINDOW %@ hidden=%d frame=%@\n",
             NSStringFromClass(window.class),
             window.hidden,
             NSStringFromCGRect(window.frame)];

            WMPFCollectTexts(window, result, 0);
        }

        WMPFShowResult(result);
    });
}

%hook MicroMessengerAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[WMPF] loaded");
    });

    return result;
}

%end

%hook UILongPressGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    %orig;

    if (state == UIGestureRecognizerStateBegan) {
        WMPFScanVisibleMenu();
    }
}

%end
