/*
 * iOS 12 Animation — Анимация открытия приложений в стиле iOS 12+
 * Для iOS 9 | Автор: Haker1928
 */

%config(Generator=MobileSubstrate)

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>

#pragma mark - Настройки

static NSString *const kDomain = @"com.haker1928.ios12animation";
static BOOL _enabled = YES;
static CGFloat _duration = 0.5;
static NSInteger _style = 0;

static void loadPrefs(void) {
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kDomain];
    if (!u) return;
    [u synchronize];
    if ([u objectForKey:@"Enabled"]) _enabled = [u boolForKey:@"Enabled"];
    if ([u objectForKey:@"Duration"]) _duration = [u floatForKey:@"Duration"];
    if ([u objectForKey:@"AnimationStyle"]) _style = [u integerForKey:@"AnimationStyle"];
}

static void prefsChanged(CFNotificationCenterRef c, void *o,
                           CFStringRef n, const void *obj, CFDictionaryRef ui) {
    loadPrefs();
}

#pragma mark - Поиск иконки

static UIView *searchIcon(UIView *view, NSString *bid) {
    if (!view) return nil;
    // Проверяем, является ли этот view SBIconView с нужным bundleID
    if ([NSStringFromClass([view class]) containsString:@"IconView"]) {
        @try {
            id icon = [view valueForKey:@"icon"];
            if (icon) {
                NSString *thisBid = [icon valueForKey:@"applicationBundleID"];
                if ([thisBid isEqualToString:bid]) return view;
            }
        } @catch(NSException *e) {}
    }
    // Рекурсия по subviews
    for (UIView *sub in view.subviews) {
        UIView *found = searchIcon(sub, bid);
        if (found) return found;
    }
    return nil;
}

#pragma mark - Анимация

static void doAnimation(CGRect fromFrame) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *win = [UIApplication sharedApplication].keyWindow;
        if (!win) {
            for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
                if (!w.hidden && w.alpha > 0) { win = w; break; }
            }
        }
        if (!win) return;

        CGRect screen = win.bounds;

        // Фон
        UIView *bg = nil;
        if (_style == 1) {
            UIVisualEffectView *b = [[UIVisualEffectView alloc]
                initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
            b.frame = screen; b.alpha = 0; b.tag = 88991;
            [win addSubview:b]; bg = b;
        } else if (_style == 2) {
            UIView *d = [[UIView alloc] initWithFrame:screen];
            d.backgroundColor = [UIColor blackColor]; d.alpha = 0; d.tag = 88991;
            [win addSubview:d]; bg = d;
        }

        // Карточка
        UIView *card = [[UIView alloc] initWithFrame:fromFrame];
        card.backgroundColor = [UIColor whiteColor];
        card.layer.cornerRadius = 12.5;
        card.layer.masksToBounds = YES;
        card.tag = 88992;
        [win addSubview:card];

        // Zoom
        [UIView animateWithDuration:_duration
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.5
                            options:0
                         animations:^{
            if (bg) bg.alpha = 0.3;
            card.frame = screen;
            card.layer.cornerRadius = 0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.15 animations:^{
                card.alpha = 0;
                if (bg) bg.alpha = 0;
            } completion:^(BOOL finished) {
                [card removeFromSuperview];
                [bg removeFromSuperview];
            }];
        }];
    });
}

#pragma mark - Хук: единственная точка входа

%hook SBApplicationIcon

- (void)launch {
    if (_enabled) {
        CGRect frame = CGRectZero;
        NSString *bid = nil;

        @try {
            bid = [(id)self valueForKey:@"applicationBundleID"];
        } @catch(NSException *e) {}

        if (bid) {
            // Ищем иконку в иерархии SpringBoard
            for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
                if (w.hidden) continue;
                UIView *iv = searchIcon(w, bid);
                if (iv && iv.window) {
                    frame = [iv convertRect:iv.bounds toView:nil];
                    break;
                }
            }
        }

        // Фоллбэк: анимация из нижней части экрана
        if (CGRectIsEmpty(frame)) {
            UIWindow *w = [UIApplication sharedApplication].keyWindow;
            if (w) {
                CGFloat s = 60;
                frame = CGRectMake(
                    CGRectGetMidX(w.bounds) - s/2,
                    CGRectGetMaxY(w.bounds) - 140,
                    s, s
                );
            }
        }

        NSLog(@"[iOS12Anim] launch %@ frame=%@", bid, NSStringFromCGRect(frame));
        doAnimation(frame);
    }
    %orig;
}

%end

#pragma mark - Init

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
    NSLog(@"[iOS12Anim] v3 loaded | Haker1928");
}
%end

%ctor {
    loadPrefs();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, prefsChanged,
        CFSTR("com.haker1928.ios12animation/settingschanged"),
        NULL, CFNotificationSuspensionBehaviorCoalesce
    );
    NSLog(@"[iOS12Anim] ctor");
}
