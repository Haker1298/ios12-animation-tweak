/*
 * iOS 12 Animation v4 — Анимация открытия в стиле iOS 12+
 * iOS 9 | Haker1928
 *
 * Подход: перехватываем переход приложения через SBApplication
 * и заменяем стоковую анимацию на spring-zoom через UIWindow
 */

%config(Generator=MobileSubstrate)

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

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

#pragma mark - Поиск иконки

static UIView *findIconRecursive(UIView *v, NSString *bid) {
    if (!v) return nil;
    if ([NSStringFromClass([v class]) rangeOfString:@"IconView"].location != NSNotFound) {
        @try {
            id icon = [v valueForKey:@"icon"];
            if (icon) {
                NSString *b = [icon valueForKey:@"applicationBundleID"];
                if ([b isEqualToString:bid]) return v;
            }
        } @catch(NSException *e) {}
    }
    for (UIView *sub in [v subviews]) {
        UIView *r = findIconRecursive(sub, bid);
        if (r) return r;
    }
    return nil;
}

#pragma mark - Анимация (UIWindow overlay)

static void doZoomAnimation(CGRect fromFrame) {
    if (_animating) return;
    _animating = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenBounds = [UIScreen mainScreen].bounds;

        // === Отдельное UIWindow поверх ВСЕГО ===
        UIWindow *overlay = [[UIWindow alloc] initWithFrame:screenBounds];
        overlay.windowLevel = UIWindowLevelStatusBar + 500;
        overlay.backgroundColor = [UIColor clearColor];
        overlay.alpha = 1.0;

        // rootViewController ОБЯЗАТЕЛЕН на iOS 8+
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        overlay.rootViewController = vc;
        overlay.hidden = NO;

        // --- Фон (blur или dim) ---
        UIView *bg = nil;
        if (_style == 1) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc]
                initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
            blur.frame = screenBounds;
            blur.alpha = 0;
            [vc.view addSubview:blur];
            bg = blur;
        } else if (_style == 2) {
            UIView *dim = [[UIView alloc] initWithFrame:screenBounds];
            dim.backgroundColor = [UIColor blackColor];
            dim.alpha = 0;
            [vc.view addSubview:dim];
            bg = dim;
        }

        // --- Карточка ---
        UIView *card = [[UIView alloc] initWithFrame:fromFrame];
        card.backgroundColor = [UIColor whiteColor];
        card.layer.cornerRadius = 12.5;
        card.layer.masksToBounds = YES;
        card.layer.zPosition = 999;
        [vc.view addSubview:card];

        // === Фаза 1: Spring zoom до полного экрана ===
        [UIView animateWithDuration:_duration
                              delay:0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            if (bg) bg.alpha = 0.35;
            card.frame = screenBounds;
            card.layer.cornerRadius = 0;
        }
                         completion:^(BOOL finished) {
            // === Фаза 2: Плавное растворение ===
            [UIView animateWithDuration:0.2
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                overlay.alpha = 0;
            }
                             completion:^(BOOL finished) {
                overlay.hidden = YES;
                overlay.rootViewController = nil;
                _animating = NO;
            }];
        }];
    });
}

#pragma mark - Хук 1: SBApplicationIcon (все возможные методы запуска)

%hook SBApplicationIcon

- (void)launch {
    NSLog(@"[iOS12Anim] SBApplicationIcon -launch called");
    if (_enabled && !_animating) {
        NSString *bid = nil;
        @try { bid = [(id)self valueForKey:@"applicationBundleID"]; } @catch(NSException *e) {}
        NSLog(@"[iOS12Anim] bid=%@", bid);

        CGRect frame = CGRectZero;
        if (bid) {
            for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
                if (w.hidden) continue;
                UIView *iv = findIconRecursive(w, bid);
                if (iv && iv.window) {
                    frame = [iv convertRect:iv.bounds toView:nil];
                    break;
                }
            }
        }
        if (CGRectIsEmpty(frame)) {
            CGFloat s = 60;
            CGRect sb = [UIScreen mainScreen].bounds;
            frame = CGRectMake(CGRectGetMidX(sb)-s/2, CGRectGetMaxY(sb)-140, s, s);
        }
        doZoomAnimation(frame);
    }
    %orig;
}

- (void)activate {
    NSLog(@"[iOS12Anim] SBApplicationIcon -activate called");
    if (_enabled && !_animating) {
        CGFloat s = 60;
        CGRect sb = [UIScreen mainScreen].bounds;
        doZoomAnimation(CGRectMake(CGRectGetMidX(sb)-s/2, CGRectGetMaxY(sb)-140, s, s));
    }
    %orig;
}

- (void)launchFromLocation:(unsigned long long)loc {
    NSLog(@"[iOS12Anim] SBApplicationIcon -launchFromLocation called");
    if (_enabled && !_animating) {
        NSString *bid = nil;
        @try { bid = [(id)self valueForKey:@"applicationBundleID"]; } @catch(NSException *e) {}
        CGRect frame = CGRectZero;
        if (bid) {
            for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
                if (w.hidden) continue;
                UIView *iv = findIconRecursive(w, bid);
                if (iv && iv.window) {
                    frame = [iv convertRect:iv.bounds toView:nil];
                    break;
                }
            }
        }
        if (CGRectIsEmpty(frame)) {
            CGFloat s = 60;
            CGRect sb = [UIScreen mainScreen].bounds;
            frame = CGRectMake(CGRectGetMidX(sb)-s/2, CGRectGetMaxY(sb)-140, s, s);
        }
        doZoomAnimation(frame);
    }
    %orig;
}

%end

#pragma mark - Хук 2: SBIcon (базовый класс, фоллбэк)

%hook SBIcon

- (void)launch {
    NSLog(@"[iOS12Anim] SBIcon -launch called");
    if (_enabled && !_animating) {
        CGFloat s = 60;
        CGRect sb = [UIScreen mainScreen].bounds;
        doZoomAnimation(CGRectMake(CGRectGetMidX(sb)-s/2, CGRectGetMaxY(sb)-140, s, s));
    }
    %orig;
}

%end

#pragma mark - Хук 3: SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    loadPrefs();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged,
        CFSTR("com.haker1928.ios12animation/settingschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce
    );
    NSLog(@"[iOS12Anim] v4 loaded | Haker1928 | enabled=%d", _enabled);
}

%end

#pragma mark - Constructor

%ctor {
    loadPrefs();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged,
        CFSTR("com.haker1928.ios12animation/settingschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce
    );
    NSLog(@"[iOS12Anim] ctor | classes: SBApplicationIcon=%d SBIcon=%d",
        objc_getClass("SBApplicationIcon") != nil,
        objc_getClass("SBIcon") != nil);
}
