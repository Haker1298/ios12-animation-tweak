/*
 * iOS 12 Animation — Анимация открытия приложений в стиле iOS 12+
 * Для джейлбрейкнутых устройств на iOS 9
 * Автор: Haker1928
 */

%config(Generator=MobileSubstrate)

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>

#pragma mark - Конфигурация

static NSString *const kPrefsDomain = @"com.haker1928.ios12animation";
static NSString *const kSettingsChanged = @"com.haker1928.ios12animation/settingschanged";

static BOOL _enabled = YES;
static CGFloat _duration = 0.5;
static NSInteger _style = 0;

#pragma mark - Хранилище

static CGRect _iconFrame = CGRectZero;
static UIView *_capturedIconView = nil;
static BOOL _pendingLaunch = NO;

#pragma mark - Настройки

static void reloadSettings() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kPrefsDomain]];
    if (prefs) {
        if (prefs[@"Enabled"]) _enabled = [prefs[@"Enabled"] boolValue];
        if (prefs[@"Duration"]) _duration = [prefs[@"Duration"] floatValue];
        if (prefs[@"AnimationStyle"]) _style = [prefs[@"AnimationStyle"] integerValue];
    }
    _pendingLaunch = NO;
}

static void onSettingsChanged(CFNotificationCenterRef center, void *observer,
                                CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    reloadSettings();
}

#pragma mark - Анимация

static void performZoomAnimation(void) {
    if (!_enabled || CGRectIsEmpty(_iconFrame)) {
        _iconFrame = CGRectZero;
        _capturedIconView = nil;
        return;
    }

    CGRect startFrame = _iconFrame;
    _iconFrame = CGRectZero;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *sbWindow = nil;

        // Ищем окно SpringBoard
        for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
            if (!w.hidden && w != [UIApplication sharedApplication].keyWindow) {
                sbWindow = w;
                break;
            }
        }
        if (!sbWindow) {
            sbWindow = [UIApplication sharedApplication].keyWindow;
        }
        if (!sbWindow) return;

        CGRect screenBounds = sbWindow.bounds;

        // --- Белая карточка (имитация экрана приложения) ---
        UIView *card = [[UIView alloc] initWithFrame:startFrame];
        card.backgroundColor = [UIColor whiteColor];
        card.layer.cornerRadius = 12.5;
        card.layer.masksToBounds = YES;
        card.layer.zPosition = 9999;
        [sbWindow addSubview:card];

        // --- Добавляем снапшот иконки на карточку ---
        if (_capturedIconView) {
            UIGraphicsBeginImageContextWithOptions(startFrame.size, NO, 0);
            [_capturedIconView.layer renderInContext:UIGraphicsGetCurrentContext()];
            UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            if (snapshot) {
                UIImageView *imgView = [[UIImageView alloc] initWithImage:snapshot];
                imgView.frame = card.bounds;
                imgView.contentMode = UIViewContentModeScaleToFill;
                imgView.clipsToBounds = YES;
                [card addSubview:imgView];
            }
        }
        _capturedIconView = nil;

        // --- Размытие фона (для стиля blur) ---
        UIView *dimView = nil;
        if (_style == 1) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc]
                initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
            blur.frame = screenBounds;
            blur.alpha = 0;
            blur.layer.zPosition = 9998;
            [sbWindow insertSubview:blur belowSubview:card];
            dimView = blur;
        } else if (_style == 2) {
            UIView *dim = [[UIView alloc] initWithFrame:screenBounds];
            dim.backgroundColor = [UIColor blackColor];
            dim.alpha = 0;
            dim.layer.zPosition = 9998;
            [sbWindow insertSubview:dim belowSubview:card];
            dimView = dim;
        }

        // --- Фаза 1: Spring Zoom ---
        CGFloat dur = _duration;
        [UIView animateWithDuration:dur
                              delay:0.02
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionAllowAnimatedContent
                         animations:^{
            if (dimView) dimView.alpha = 0.3;
            card.frame = screenBounds;
            card.layer.cornerRadius = 0;
        }
                         completion:^(BOOL finished) {
            // --- Фаза 2: Плавное исчезновение ---
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                card.alpha = 0;
                if (dimView) dimView.alpha = 0;
            } completion:^(BOOL finished) {
                [card removeFromSuperview];
                [dimView removeFromSuperview];
            }];
        }];
    });
}

#pragma mark - Хук SBIconView (захват позиции)

%hook SBIconView

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    @try {
        UIView *selfView = (UIView *)self;
        if (selfView.window) {
            _iconFrame = [selfView convertRect:selfView.bounds toView:nil];
            _capturedIconView = selfView;
            _pendingLaunch = YES;
        }
    } @catch (NSException *e) {
        NSLog(@"[iOS12Anim] touchesEnded error: %@", e);
    }
    %orig;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    _iconFrame = CGRectZero;
    _capturedIconView = nil;
    _pendingLaunch = NO;
    %orig;
}

%end

#pragma mark - Хук SBIconController (запуск анимации)

%hook SBIconController

- (void)openApplication:(id)application fromIconView:(id)iconView {
    // Защитный захват позиции прямо из iconView
    if (iconView && !_pendingLaunch) {
        @try {
            UIView *v = (UIView *)iconView;
            if (v.window) {
                _iconFrame = [v convertRect:v.bounds toView:nil];
                _capturedIconView = v;
            }
        } @catch (NSException *e) {}
    }

    // Запускаем анимацию
    if (_enabled && !CGRectIsEmpty(_iconFrame)) {
        performZoomAnimation();
    }

    %orig;
}

%end

#pragma mark - Хук SBApplicationIcon (запуск + фоллбэк)

%hook SBApplicationIcon

- (void)launch {
    // Фоллбэк: если SBIconController не сработал, пробуем здесь
    if (_enabled && _pendingLaunch && !CGRectIsEmpty(_iconFrame)) {
        performZoomAnimation();
    }
    _pendingLaunch = NO;
    %orig;
}

%end

#pragma mark - Инициализация

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    reloadSettings();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, onSettingsChanged,
        (__bridge CFStringRef)kSettingsChanged,
        NULL, CFNotificationSuspensionBehaviorCoalesce
    );
    NSLog(@"[iOS12Anim] Загружен! Автор: Haker1928");
}

%end

%ctor {
    reloadSettings();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, onSettingsChanged,
        (__bridge CFStringRef)kSettingsChanged,
        NULL, CFNotificationSuspensionBehaviorCoalesce
    );
    NSLog(@"[iOS12Anim] ctor loaded");
}
