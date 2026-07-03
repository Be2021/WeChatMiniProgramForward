#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void WMPFShowAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
UIViewController *root = nil;
for (UIWindow *window in UIApplication.sharedApplication.windows) {
    if (window.isKeyWindow) {
        root = window.rootViewController;
        break;
    }
}

        if (!root) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"复制"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = message;
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];

        [root presentViewController:alert animated:YES completion:nil];
    });
}

static NSString *WMPFStringField(id object, NSString *key) {
    @try {
        id value = [object valueForKey:key];
        return [value isKindOfClass:NSString.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *WMPFNumberField(id object, NSString *key) {
    @try {
        id value = [object valueForKey:key];
        if ([value isKindOfClass:NSNumber.class]) {
            return [value description];
        }
        return nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL WMPFIsMiniProgramMessage(id message) {
    if (!message) return NO;

    NSString *content = WMPFStringField(message, @"m_nsContent");
    NSString *appId = WMPFStringField(message, @"m_nsAppID");

    return [content containsString:@"<weappinfo>"] ||
           [content containsString:@"<appmsg"] ||
           appId.length > 0;
}

static NSString *WMPFDumpObject(id object) {
    if (!object) return @"nil";

    NSMutableString *result = [NSMutableString string];
    [result appendFormat:@"class=%@\n", NSStringFromClass([object class])];

    NSArray *keys = @[
        @"m_uiMessageType",
        @"m_nsContent",
        @"m_nsFromUsr",
        @"m_nsToUsr",
        @"m_nsRealChatUsr",
        @"m_nsAppID",
        @"m_nsTitle",
        @"m_nsDesc"
    ];

    for (NSString *key in keys) {
        NSString *stringValue = WMPFStringField(object, key);
        NSString *numberValue = WMPFNumberField(object, key);
        NSString *value = stringValue ?: numberValue;

        if (value.length > 0) {
            if (value.length > 500) {
                value = [[value substringToIndex:500] stringByAppendingString:@"..."];
            }
            [result appendFormat:@"%@=%@\n", key, value];
        }
    }

    return result;
}

%hook MicroMessengerAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WMPFShowAlert(@"WMPF 已加载", @"插件已注入微信。下一步请长按小程序卡片，如果能抓到消息会再弹窗。");
    });

    return result;
}

%end

%hook CMessageWrap

- (id)initWithMsgType:(long long)msgType {
    id result = %orig;

    if (WMPFIsMiniProgramMessage(result)) {
        NSString *message = [NSString stringWithFormat:@"msgType=%lld\n%@", msgType, WMPFDumpObject(result)];
        WMPFShowAlert(@"发现小程序消息", message);
    }

    return result;
}

%end
