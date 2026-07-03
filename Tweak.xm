#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *WMPFStringField(id object, NSString *key) {
    @try {
        id value = [object valueForKey:key];
        return [value isKindOfClass:NSString.class] ? value : nil;
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

static void WMPFDumpObject(id object, NSString *tag) {
    if (!object) return;

    NSLog(@"[WMPF] %@ class=%@", tag, NSStringFromClass([object class]));

    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([object class], &count);

    for (unsigned int index = 0; index < count; index++) {
        const char *ivarName = ivar_getName(ivars[index]);
        if (!ivarName) continue;

        NSString *key = [NSString stringWithUTF8String:ivarName];

        @try {
            id value = [object valueForKey:key];

            if ([value isKindOfClass:NSString.class] ||
                [value isKindOfClass:NSNumber.class]) {
                NSLog(@"[WMPF] %@ %@=%@", tag, key, value);
            }
        } @catch (__unused NSException *exception) {}
    }

    if (ivars) free(ivars);
}

%hook MicroMessengerAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    NSLog(@"[WMPF] WeChatMiniProgramForward loaded");

    return result;
}

%end

%hook CMessageWrap

- (id)initWithMsgType:(long long)msgType {
    id result = %orig;

    if (WMPFIsMiniProgramMessage(result)) {
        NSLog(@"[WMPF] mini program message detected msgType=%lld", msgType);
        WMPFDumpObject(result, @"CMessageWrap");
    }

    return result;
}

%end
