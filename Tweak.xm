/**
 * iOS 12 Animation v7 — Logos hooks + runtime diagnostics
 * iOS 9 | Haker1928
 * Лог: /var/mobile/Library/Logs/iOS12Anim.log
 */

%config(Generator=MobileSubstrate)

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <SpringBoard/SpringBoard.h>

#pragma mark - Логирование

static NSString *logFilePath(void) {
    return @"/var/mobile/Library/Logs/iOS12Anim.log";
}

static void ensureLogDir(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = @"/var/mobile/Library/Logs";
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

static void writeLog(NSString *msg) {
    ensureLogDir();
    NSDateFormatter *ts = [[NSDateFormatter alloc] init];
    [ts setDateFormat:@"HH:mm:ss.SSS"];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [ts stringFromDate:[NSDate date]], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logFilePath()];
    if (!fh) {
        [line writeToFile:logFilePath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

#pragma mark - Настройки

static BOOL tweakEnabled = YES;
static CGFloat animDuration = 0.55;
static NSInteger animStyle = 0;

static void loadPrefs(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:
        @"/var/mobile/Library/Preferences/com.haker1928.ios12animation.plist"];
    if (d) {
        if (d[@"Enabled"]) tweakEnabled = [d[@"Enabled"] boolValue];
        if (d[@"Duration"]) animDuration = [d[@"Duration"] floatValue];
        if (d[@"AnimationStyle"]) animStyle = [d[@"AnimationStyle"] integerValue];
    }
}

static void prefsChanged(CFNotificationCenterRef c, void *o,
                           CFStringRef n, const void *obj, CFDictionaryRef ui) {
    loadPrefs();
}

#pragma mark - Анимация

static BOOL isAnimating = NO;

static void performZoomAnimation(CGRect fromFrame) {
    if (isAnimating || !tweakEnabled) return;
    if (CGRectIsNull(fromFrame) || fromFrame.size.width < 1) {
        fromFrame = CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 30,
                               [UIScreen mainScreen].bounds.size.height / 2 - 30,
                               60, 60);
    }
    isAnimating = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
            if (!keyWin) { isAnimating = NO; return; }

            CGRect iconFrame = [keyWin convertRect:fromFrame fromView:nil];
            CGRect screenBounds = [UIScreen mainScreen].bounds;

            UIWindow *overlay = [[UIWindow alloc] initWithFrame:screenBounds];
            overlay.windowLevel = UIWindowLevelStatusBar + 500;
            overlay.backgroundColor = [UIColor clearColor];
            overlay.userInteractionEnabled = NO;

            UIViewController *vc = [[UIViewController alloc] init];
            vc.view.backgroundColor = [UIColor clearColor];
            vc.view.userInteractionEnabled = NO;
            overlay.rootViewController = vc;
            overlay.hidden = NO;

            UIView *bgView = nil;
            if (animStyle == 1) {
                UIVisualEffectView *blur = [[UIVisualEffectView alloc]
                    initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
                blur.frame = screenBounds;
                blur.alpha = 0;
                [vc.view addSubview:blur];
                bgView = blur;
            } else if (animStyle == 2) {
                UIView *dim = [[UIView alloc] initWithFrame:screenBounds];
                dim.backgroundColor = [UIColor blackColor];
                dim.alpha = 0;
                [vc.view addSubview:dim];
                bgView = dim;
            }

            UIView *card = [[UIView alloc] initWithFrame:iconFrame];
            card.backgroundColor = [UIColor whiteColor];
            card.layer.cornerRadius = 13.0;
            card.layer.masksToBounds = YES;
            card.layer.zPosition = 999;
            [vc.view addSubview:card];

            writeLog([NSString stringWithFormat:@"Anim start: %@", NSStringFromCGRect(iconFrame)]);

            [UIView animateWithDuration:animDuration
                                  delay:0.0
                 usingSpringWithDamping:0.78
                  initialSpringVelocity:0.5
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                if (bgView) bgView.alpha = 0.4;
                card.frame = screenBounds;
                card.layer.cornerRadius = 0;
            } completion:^(BOOL finished) {
                writeLog(@"Anim mid-complete");
                [UIView animateWithDuration:0.15
                                      delay:0.0
                                    options:UIViewAnimationOptionCurveEaseIn
                                 animations:^{
                    overlay.alpha = 0;
                } completion:^(BOOL finished2) {
                    overlay.hidden = YES;
                    overlay.rootViewController = nil;
                    isAnimating = NO;
                    writeLog(@"Anim done");
                }];
            }];
        } @catch (NSException *e) {
            writeLog([NSString stringWithFormat:@"Anim exception: %@", e.reason]);
            isAnimating = NO;
        }
    });
}

#pragma mark - Поиск иконки

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

static UIView *findIconViewForApp(NSString *bundleID) {
    if (!bundleID) return nil;

    Class sbIconModelCls = objc_getClass("SBIconModel");
    Class sbIconControllerCls = objc_getClass("SBIconController");

    if (sbIconModelCls && sbIconControllerCls) {
        @try {
            id iconModel = nil;
            if ([sbIconModelCls respondsToSelector:@selector(sharedInstance)])
                iconModel = [sbIconModelCls performSelector:@selector(sharedInstance)];

            id iconController = nil;
            if ([sbIconControllerCls respondsToSelector:@selector(sharedInstance)])
                iconController = [sbIconControllerCls performSelector:@selector(sharedInstance)];
            if (!iconController && [sbIconControllerCls respondsToSelector:@selector(sharedController)])
                iconController = [sbIconControllerCls performSelector:@selector(sharedController)];

            if (iconModel && iconController) {
                SEL modelSel = sel_registerName("applicationIconForBundleIdentifier:");
                if ([iconModel respondsToSelector:modelSel]) {
                    id icon = [iconModel performSelector:modelSel withObject:bundleID];
                    if (icon) {
                        SEL viewSel = sel_registerName("viewForIcon:");
                        if ([iconController respondsToSelector:viewSel]) {
                            UIView *iv = (UIView *)[iconController performSelector:viewSel withObject:icon];
                            if (iv && [iv isKindOfClass:[UIView class]]) {
                                writeLog(@"Found icon via model+controller");
                                return iv;
                            }
                        }
                    }
                }
            }
        } @catch (NSException *e) {
            writeLog([NSString stringWithFormat:@"findIcon model error: %@", e.reason]);
        }
    }

    /* Фоллбэк: сканируем все SBIconView */
    @try {
        UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
        if (!keyWin) return nil;

        NSMutableArray *iconViews = [NSMutableArray array];
        void (^collect)(UIView *) = ^(UIView *view) {
            if ([view isKindOfClass:objc_getClass("SBIconView")]) {
                [iconViews addObject:view];
            }
            for (UIView *sub in view.subviews) collect(sub);
        };
        collect(keyWin);

        for (UIView *iv in iconViews) {
            @try {
                SEL iconSel = sel_registerName("icon");
                if ([iv respondsToSelector:iconSel]) {
                    id icon = [iv performSelector:iconSel];
                    if (icon) {
                        SEL bidSel = sel_registerName("applicationBundleID");
                        NSString *bid = nil;
                        if ([icon respondsToSelector:bidSel])
                            bid = (NSString *)[icon performSelector:bidSel];
                        if (bid && [bid isEqualToString:bundleID]) {
                            writeLog([NSString stringWithFormat:@"Found icon via scan: %@", bid]);
                            return iv;
                        }
                    }
                }
            } @catch (NSException *e) {}
        }
        writeLog([NSString stringWithFormat:@"Scanned %lu icon views, none matched", (unsigned long)iconViews.count]);
    } @catch (NSException *e) {
        writeLog([NSString stringWithFormat:@"findIcon scan error: %@", e.reason]);
    }

    return nil;
}

#pragma clang diagnostic pop

#pragma mark - Хуки SBUIController

%hook SBUIController

- (void)activateApplication:(id)application animated:(BOOL)animated {
    writeLog(@"HOOK> SBUIController activateApplication:animated:");
    NSString *bid = nil;
    @try {
        if ([application respondsToSelector:@selector(bundleIdentifier)])
            bid = [application performSelector:@selector(bundleIdentifier)];
    } @catch (NSException *e) {}
    writeLog([NSString stringWithFormat:@"  app=%@ anim=%d", bid, animated]);

    if (tweakEnabled && bid) {
        UIView *iv = findIconViewForApp(bid);
        performZoomAnimation(iv ? iv.frame : CGRectNull);
    }
    %orig;
}

- (void)openApplication:(id)application {
    writeLog(@"HOOK> SBUIController openApplication:");
    NSString *bid = nil;
    @try {
        if ([application respondsToSelector:@selector(bundleIdentifier)])
            bid = [application performSelector:@selector(bundleIdentifier)];
    } @catch (NSException *e) {}
    writeLog([NSString stringWithFormat:@"  app=%@", bid]);

    if (tweakEnabled && bid) {
        UIView *iv = findIconViewForApp(bid);
        performZoomAnimation(iv ? iv.frame : CGRectNull);
    }
    %orig;
}

%end

#pragma mark - Хуки SBApplicationIcon

%hook SBApplicationIcon

- (void)launch {
    writeLog(@"HOOK> SBApplicationIcon launch");
    NSString *bid = nil;
    @try {
        if ([(id)self respondsToSelector:@selector(applicationBundleID)])
            bid = [(id)self performSelector:@selector(applicationBundleID)];
    } @catch (NSException *e) {}
    writeLog([NSString stringWithFormat:@"  icon bid=%@", bid]);
    %orig;
}

- (void)launchFromLocation:(unsigned long long)location {
    writeLog([NSString stringWithFormat:@"HOOK> SBApplicationIcon launchFromLocation:%llu", location]);
    %orig;
}

%end

#pragma mark - Хуки SBIcon

%hook SBIcon

- (void)launch {
    writeLog(@"HOOK> SBIcon launch");
    %orig;
}

- (void)activate {
    writeLog(@"HOOK> SBIcon activate");
    %orig;
}

%end

#pragma mark - Диагностика в constructor

static void dumpMethods(const char *className) {
    Class cls = objc_getClass(className);
    if (!cls) {
        writeLog([NSString stringWithFormat:@"  %s: NOT FOUND", className]);
        return;
    }
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    writeLog([NSString stringWithFormat:@"  %s: %u methods", className, count]);
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromSelector(method_getName(methods[i]));
        if ([name containsString:@"launch"] || [name containsString:@"activate"] ||
            [name containsString:@"openApp"] || [name containsString:@"transition"] ||
            [name containsString:@"fromIcon"] || [name containsString:@"iconView"]) {
            writeLog([NSString stringWithFormat:@"    - %@", name]);
        }
    }
    free(methods);
}

%ctor {
    ensureLogDir();
    [@"" writeToFile:logFilePath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    writeLog(@"=== iOS12Anim v7 LOADED ===");

    loadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged,
        CFSTR("com.haker1928.ios12animation/settingschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);

    writeLog(@"--- Class dump ---");
    dumpMethods("SBUIController");
    dumpMethods("SBApplicationIcon");
    dumpMethods("SBIcon");
    dumpMethods("SBIconController");
    dumpMethods("SBIconModel");
    writeLog(@"--- End dump ---");
    writeLog(@"=== iOS12Anim v7 READY ===");
}