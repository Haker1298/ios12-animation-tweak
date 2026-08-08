/*
 * iOS 12 Animation v5 — DIAGNOSTIC BUILD
 * iOS 9 | Haker1928
 * Логи пишутся в /var/mobile/Documents/iOS12Anim.log
 */

%config(Generator=MobileSubstrate)

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Логирование в файл

static NSString *logPath(void) {
    return @"/var/mobile/Documents/iOS12Anim.log";
}

static void writeLog(NSString *msg) {
    NSString *ts = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                  dateStyle:NSDateFormatterShortStyle
                                                  timeStyle:NSDateFormatterMediumStyle];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", ts, msg];
    NSString *existing = [NSString stringWithContentsOfFile:logPath() encoding:NSUTF8StringEncoding error:nil];
    NSString *updated = existing ? [existing stringByAppendingString:line] : line;
    [updated writeToFile:logPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - Настройки

static BOOL _enabled = YES;
static CGFloat _duration = 0.5;
static NSInteger _style = 0;
static BOOL _animating = NO;

static void loadPrefs(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:
        @"/var/mobile/Library/Preferences/com.haker1928.ios12animation.plist"];
    if (d) {
        if (d[@"Enabled"]) _enabled = [d[@"Enabled"] boolValue];
        if (d[@"Duration"]) _duration = [d[@"Duration"] floatValue];
        if (d[@"AnimationStyle"]) _style = [d[@"AnimationStyle"] integerValue];
    }
}

static void prefsChanged(CFNotificationCenterRef c, void *o,
                           CFStringRef n, const void *obj, CFDictionaryRef ui) {
    loadPrefs();
}

#pragma mark - Диагностика: список методов класса

static void dumpClassMethods(const char *className) {
    Class cls = objc_getClass(className);
    if (!cls) {
        writeLog([NSString stringWithFormat:@"  Class %s: NOT FOUND", className]);
        return;
    }
    writeLog([NSString stringWithFormat:@"  Class %s EXISTS", className]);

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableString *ms = [NSMutableString string];
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);
        // Фильтруем только релевантные методы
        if ([name containsString:@"launch"] || [name containsString:@"activate"] ||
            [name containsString:@"open"] || [name containsString:@"tap"] ||
            [name containsString:@"touch"] || [name containsString:@"icon"]) {
            [ms appendFormat:@"    %@\n", name];
        }
    }
    free(methods);
    if (ms.length == 0) {
        writeLog([NSString stringWithFormat:@"  %s: %u methods (no match)", className, count]);
    } else {
        writeLog([NSString stringWithFormat:@"  %s matching methods:\n%@", className, ms]);
    }
}

#pragma mark - Анимация

static void doZoomAnimation(CGRect fromFrame) {
    if (_animating) return;
    _animating = YES;
    writeLog([NSString stringWithFormat:@"ANIMATING from %@", NSStringFromCGRect(fromFrame)]]);

    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenBounds = [UIScreen mainScreen].bounds;

        UIWindow *overlay = [[UIWindow alloc] initWithFrame:screenBounds];
        overlay.windowLevel = UIWindowLevelStatusBar + 500;
        overlay.backgroundColor = [UIColor clearColor];
        overlay.alpha = 1.0;

        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        overlay.rootViewController = vc;
        overlay.hidden = NO;

        UIView *bg = nil;
        if (_style == 1) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc]
                initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
            blur.frame = screenBounds; blur.alpha = 0;
            [vc.view addSubview:blur]; bg = blur;
        } else if (_style == 2) {
            UIView *dim = [[UIView alloc] initWithFrame:screenBounds];
            dim.backgroundColor = [UIColor blackColor]; dim.alpha = 0;
            [vc.view addSubview:dim]; bg = dim;
        }

        UIView *card = [[UIView alloc] initWithFrame:fromFrame];
        card.backgroundColor = [UIColor whiteColor];
        card.layer.cornerRadius = 12.5;
        card.layer.masksToBounds = YES;
        card.layer.zPosition = 999;
        [vc.view addSubview:card];

        [UIView animateWithDuration:_duration delay:0
             usingSpringWithDamping:0.82 initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            if (bg) bg.alpha = 0.35;
            card.frame = screenBounds;
            card.layer.cornerRadius = 0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn
                             animations:^{ overlay.alpha = 0; }
                             completion:^(BOOL finished) {
                overlay.hidden = YES;
                overlay.rootViewController = nil;
                _animating = NO;
            }];
        }];
    });
}

#pragma mark - Хуки

%hook SBApplicationIcon
- (void)launch {
    writeLog(@"HOOK: SBApplicationIcon -launch");
    %orig;
}
- (void)activate {
    writeLog(@"HOOK: SBApplicationIcon -activate");
    %orig;
}
- (void)launchFromLocation:(unsigned long long)loc {
    writeLog(@"HOOK: SBApplicationIcon -launchFromLocation");
    %orig;
}
%end

%hook SBIcon
- (void)launch {
    writeLog(@"HOOK: SBIcon -launch");
    %orig;
}
- (void)activate {
    writeLog(@"HOOK: SBIcon -activate");
    %orig;
}
%end

%hook SBIconView
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e {
    writeLog(@"HOOK: SBIconView touchesBegan");
    %orig;
}
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e {
    writeLog(@"HOOK: SBIconView touchesEnded");
    %orig;
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    loadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged,
        CFSTR("com.haker1928.ios12animation/settingschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);

    // === ДИАГНОСТИКА ===
    ["" writeToFile:logPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    writeLog(@"=== iOS 12 Animation v5 DIAGNOSTIC ===");
    writeLog([NSString stringWithFormat:@"Enabled: %d, Duration: %.2f, Style: %ld", _enabled, _duration, (long)_style]);
    writeLog(@"--- Checking classes ---");
    dumpClassMethods("SBApplicationIcon");
    dumpClassMethods("SBIcon");
    dumpClassMethods("SBIconView");
    dumpClassMethods("SBIconController");
    writeLog(@"--- Diagnostic complete ---");
}
%end

%ctor {
    loadPrefs();
    writeLog(@"=== iOS12Anim %ctor loaded ===");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged,
        CFSTR("com.haker1928.ios12animation/settingschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);
}
