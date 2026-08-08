/**
 * iOS 12 Animation v6 — Runtime Swizzle + Animation
 * iOS 9 | Haker1928
 * Лог: /var/mobile/Library/Logs/iOS12Anim.log
 */

%config(Generator=MobileSubstrate)

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <SpringBoard/SpringBoard.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

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

static UIView *findIconViewForApp(NSString *bundleID) {
    if (!bundleID) return nil;

    // Способ 1: через SBIconModel -> SBIconController -> viewForIcon:
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

    // Способ 2: перебор всех SBIconView на экране
    @try {
        UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
        if (!keyWin) return nil;

        void (^searchInView)(UIView *, NSMutableSet *) = ^void(UIView *view, NSMutableSet *found) {
            if ([view isKindOfClass:objc_getClass("SBIconView")]) {
                [found addObject:view];
            }
            for (UIView *sub in view.subviews) {
                searchInView(sub, found);
            }
        };

        NSMutableSet *iconViews = [NSMutableSet set];
        searchInView(keyWin, iconViews);

        for (UIView *iv in iconViews) {
            @try {
                // Проверяем bundleID иконки
                SEL iconSel = sel_registerName("icon");
                if ([iv respondsToSelector:iconSel]) {
                    id icon = [iv performSelector:iconSel];
                    if (icon) {
                        SEL bidSel = sel_registerName("applicationBundleID");
                        NSString *bid = nil;
                        if ([icon respondsToSelector:bidSel]) {
                            bid = [icon performSelector:bidSel];
                        }
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

#pragma mark - Хуки (runtime swizzle)

// --- SBUIController activateApplication:animated: ---
static void *orig_sbui_activateApp_anim = NULL;
static void hooked_sbui_activateApp_anim(id self, SEL _cmd, id app, BOOL animated) {
    writeLog(@"HOOK> SBUIController activateApplication:animated:");
    NSString *bid = nil;
    @try { if ([app respondsToSelector:@selector(bundleIdentifier)]) bid = [app bundleIdentifier]; } @catch(NSException *e) {}
    writeLog([NSString stringWithFormat:@"  app=%@ animated=%d", bid, animated]);

    if (tweakEnabled && bid) {
        UIView *iv = findIconViewForApp(bid);
        if (iv) {
            performZoomAnimation(iv.frame);
        } else {
            performZoomAnimation(CGRectNull);
        }
    }
    if (orig_sbui_activateApp_anim) CALL_ORIG_3(orig_sbui_activateApp_anim, self, app, (id)(long)animated);
}

// --- SBUIController activateApplication:fromIconView: ---
static void *orig_sbui_activate_fromIcon = NULL;
static void hooked_sbui_activate_fromIcon(id self, SEL _cmd, id app, id iconView) {
    writeLog(@"HOOK> SBUIController activateApplication:fromIconView:");
    if (tweakEnabled) {
        if (iconView && [iconView isKindOfClass:[UIView class]]) {
            performZoomAnimation([iconView frame]);
        } else {
            performZoomAnimation(CGRectNull);
        }
    }
    if (orig_sbui_activate_fromIcon) CALL_ORIG_3(orig_sbui_activate_fromIcon, self, app, iconView);
}

// --- SBUIController openApplication: ---
static void *orig_sbui_openApp = NULL;
static void hooked_sbui_openApp(id self, SEL _cmd, id app) {
    writeLog(@"HOOK> SBUIController openApplication:");
    NSString *bid = nil;
    @try { if ([app respondsToSelector:@selector(bundleIdentifier)]) bid = [app bundleIdentifier]; } @catch(NSException *e) {}
    if (tweakEnabled) {
        UIView *iv = findIconViewForApp(bid);
        performZoomAnimation(iv ? iv.frame : CGRectNull);
    }
    if (orig_sbui_openApp) CALL_ORIG_2(orig_sbui_openApp, self, app);
}

// --- SBApplicationIcon launch ---
static void *orig_sbai_launch = NULL;
static void hooked_sbai_launch(id self, SEL _cmd) {
    writeLog(@"HOOK> SBApplicationIcon launch");
    NSString *bid = nil;
    @try {
        if ([self respondsToSelector:@selector(applicationBundleID)])
            bid = [self performSelector:@selector(applicationBundleID)];
    } @catch(NSException *e) {}
    writeLog([NSString stringWithFormat:@"  icon bid=%@", bid]);
    if (orig_sbai_launch) ((void(*)(id, SEL))orig_sbai_launch)(self, _cmd);
}

// --- SBApplicationIcon launchFromLocation: ---
static void *orig_sbai_launchFrom = NULL;
static void hooked_sbai_launchFrom(id self, SEL _cmd, unsigned long long loc) {
    writeLog([NSString stringWithFormat:@"HOOK> SBApplicationIcon launchFromLocation:%llu", loc]);
    if (orig_sbai_launchFrom) CALL_ORIG_1U(orig_sbai_launchFrom, self, loc);
}

#pragma mark - Утилиты свизлинга

static void trySwizzle(Class cls, const char *selName, IMP newImp, void **origImpPtr) {
    SEL sel = sel_registerName(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        writeLog([NSString stringWithFormat:@"  NOT FOUND: -[%s %s]", class_getName(cls), selName]);
        return;
    }
    /* Сохраняем оригинальный IMP через void* для избежания проблем с типами */
    IMP origImp = method_getImplementation(m);
    union { void *p; IMP i; } u; u.i = origImp;
    *origImpPtr = u.p;
    method_setImplementation(m, newImp);
    writeLog([NSString stringWithFormat:@"  SWIZZLED: -[%s %s]", class_getName(cls), selName]);
}

/* Макрос для вызова оригинала через void* */
#define CALL_ORIG_2(ptr, self, a1) ((void(*)(id, SEL, id))(ptr))(self, _cmd, a1)
#define CALL_ORIG_3(ptr, self, a1, a2) ((void(*)(id, SEL, id, id))(ptr))(self, _cmd, a1, a2)
#define CALL_ORIG_1U(ptr, self, a1) ((void(*)(id, SEL, unsigned long long))(ptr))(self, _cmd, a1)

#pragma mark - Дамп класса

static void dumpRelevantMethods(const char *className) {
    Class cls = objc_getClass(className);
    if (!cls) {
        writeLog([NSString stringWithFormat:@"  %s: NOT FOUND", className]);
        return;
    }
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    writeLog([NSString stringWithFormat:@"  %s: %u total methods", className, count]);
    int matched = 0;
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);
        if ([name containsString:@"launch"] || [name containsString:@"activate"] ||
            [name containsString:@"openApp"] || [name containsString:@"transitionTo"] ||
            [name containsString:@"iconView"] || [name containsString:@"fromIcon"] ||
            [name containsString:@"startLaunch"] || [name containsString:@"handleIconTap"]) {
            writeLog([NSString stringWithFormat:@"    - %@", name]);
                matched++;
            }
        }
    free(methods);
    if (matched == 0) writeLog([NSString stringWithFormat:@"  %s: no matching methods", className]);
}

#pragma mark - Constructor

%ctor {
    // Проверка загрузки
    ensureLogDir();
    [@"" writeToFile:logFilePath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    writeLog(@"=== iOS12Anim v6 LOADED ===");

    loadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged,
        CFSTR("com.haker1928.ios12animation/settingschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);

    // Дамп классов
    writeLog(@"--- Class dump ---");
    dumpRelevantMethods("SBUIController");
    dumpRelevantMethods("SBApplicationIcon");
    dumpRelevantMethods("SBIconController");
    dumpRelevantMethods("SBIconModel");
    writeLog(@"--- End dump ---");

    // Свизл SBUIController
    Class sbuiCls = objc_getClass("SBUIController");
    if (sbuiCls) {
        writeLog(@"SBUIController found");
        trySwizzle(sbuiCls, "activateApplication:animated:",
                  (IMP)hooked_sbui_activateApp_anim, (void **)&orig_sbui_activateApp_anim);
        trySwizzle(sbuiCls, "activateApplication:fromIconView:",
                  (IMP)hooked_sbui_activate_fromIcon, (void **)&orig_sbui_activate_fromIcon);
        trySwizzle(sbuiCls, "openApplication:",
                  (IMP)hooked_sbui_openApp, (void **)&orig_sbui_openApp);
    } else {
        writeLog(@"SBUIController NOT FOUND!");
    }

    // Свизл SBApplicationIcon
    Class sbaiCls = objc_getClass("SBApplicationIcon");
    if (sbaiCls) {
        writeLog(@"SBApplicationIcon found");
        trySwizzle(sbaiCls, "launch",
                  (IMP)hooked_sbai_launch, (void **)&orig_sbai_launch);
        trySwizzle(sbaiCls, "launchFromLocation:",
                  (IMP)hooked_sbai_launchFrom, (void **)&orig_sbai_launchFrom);
    } else {
        writeLog(@"SBApplicationIcon NOT FOUND!");
    }

    writeLog(@"=== iOS12Anim v6 READY ===");
}

#pragma clang diagnostic pop
