/*
 * iOS 12 Animation Tweak for iOS 9
 * Добавляет анимацию открытия приложений в стиле iOS 12+
 * Иконка плавно увеличивается из своей позиции на SpringBoard
 */

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>

// ===== Настройки по умолчанию =====
static BOOL _enabled = YES;
static CGFloat _duration = 0.55;
static CGFloat _dampingRatio = 0.86;
static CGFloat _initialVelocity = 0.0;
static NSInteger _animationStyle = 0; // 0 = zoom, 1 = zoom+blur, 2 = zoom+fade

// ===== Хранилище данных иконки =====
static CGRect _capturedIconFrame = CGRectZero;
static UIImage *_capturedIconSnapshot = nil;
static NSString *_capturedBundleID = nil;
static BOOL _isAnimating = NO;

// ===== Загрузка настроек =====
static void reloadSettings() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:
        @"/var/mobile/Library/Preferences/com.yourname.ios12animation.plist"];
    if (prefs) {
        _enabled = [prefs[@"Enabled"] boolValue];
        if (!prefs[@"Enabled"]) _enabled = YES;
        _duration = [prefs[@"Duration"] floatValue];
        if (_duration <= 0.0) _duration = 0.55;
        _dampingRatio = [prefs[@"DampingRatio"] floatValue];
        if (_dampingRatio <= 0.0) _dampingRatio = 0.86;
        _initialVelocity = [prefs[@"InitialVelocity"] floatValue];
        _animationStyle = [prefs[@"AnimationStyle"] integerValue];
    }
}

// ===== Класс оверлейного окна анимации =====
@interface IOS12AnimWindow : UIWindow
@property (nonatomic, strong) UIView *zoomView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIView *whiteCard;
@end

@implementation IOS12AnimWindow

- (instancetype)initWithIconFrame:(CGRect)iconFrame snapshot:(UIImage *)snapshot {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 200;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = NO;
        self.alpha = 1.0;
        
        // --- Размытие фона (для стиля blur) ---
        if (_animationStyle >= 1) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            self.blurView.frame = self.bounds;
            self.blurView.alpha = 0.0;
            [self addSubview:self.blurView];
        }
        
        // --- Белая карточка (имитация экрана приложения) ---
        self.whiteCard = [[UIView alloc] initWithFrame:iconFrame];
        self.whiteCard.backgroundColor = [UIColor whiteColor];
        self.whiteCard.layer.cornerRadius = 13.0; // Скругление иконки
        self.whiteCard.layer.masksToBounds = YES;
        self.whiteCard.layer.shadowColor = [UIColor blackColor].CGColor;
        self.whiteCard.layer.shadowOffset = CGSizeMake(0, 4);
        self.whiteCard.layer.shadowOpacity = 0.15;
        self.whiteCard.layer.shadowRadius = 12.0;
        [self addSubview:self.whiteCard];
        
        // --- Изображение иконки поверх карточки ---
        if (snapshot) {
            self.iconImageView = [[UIImageView alloc] initWithImage:snapshot];
            self.iconImageView.frame = self.whiteCard.bounds;
            self.iconImageView.contentMode = UIViewContentModeScaleAspectFill;
            self.iconImageView.clipsToBounds = YES;
            [self.whiteCard addSubview:self.iconImageView];
        }
    }
    return self;
}

- (void)performAnimationWithCompletion:(void(^)(void))completion {
    if (_isAnimating) {
        if (completion) completion();
        return;
    }
    _isAnimating = YES;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    // --- Фаза 1: Увеличение иконки до полного экрана (Spring Animation) ---
    [UIView animateWithDuration:_duration
                          delay:0.02
         usingSpringWithDamping:_dampingRatio
          initialSpringVelocity:_initialVelocity
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowAnimatedContent
                     animations:^{
        // Размытие фона
        if (self.blurView) {
            self.blurView.alpha = 0.25;
        }
        
        // Карточка увеличивается до полного экрана
        self.whiteCard.frame = screenBounds;
        self.whiteCard.layer.cornerRadius = 0.0;
        self.whiteCard.layer.shadowOpacity = 0.0;
        
        // Иконка тоже масштабируется
        self.iconImageView.frame = screenBounds;
    }
                     completion:^(BOOL finished) {
        // --- Фаза 2: Плавное исчезновение оверлея ---
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.alpha = 0.0;
        }
                         completion:^(BOOL finished) {
            [self removeFromSuperview];
            _isAnimating = NO;
            if (completion) completion();
        }];
    }];
}

@end

#pragma mark - Хук SBIconView (захват позиции иконки)

%hook SBIconView

// Перехватываем касание иконки для захвата её позиции и снапшота
- (void)_handleIconTap:(id)tap {
    @try {
        UIView *iconView = (UIView *)self;
        if (iconView && iconView.window) {
            // Получаем позицию иконки относительно экрана
            _capturedIconFrame = [iconView convertRect:iconView.bounds 
                                               toView:iconView.window];
            
            // Создаём снапшот иконки
            _capturedIconSnapshot = nil; // Сбрасываем
            UIGraphicsBeginImageContextWithOptions(iconView.bounds.size, NO, [UIScreen mainScreen].scale);
            [iconView.layer renderInContext:UIGraphicsGetCurrentContext()];
            _capturedIconSnapshot = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    } @catch (NSException *e) {
        NSLog(@"[iOS12Animation] Error capturing icon: %@", e);
    }
    
    %orig;
}

// Дополнительный хук для совместимости с разными версиями iOS 9
- (void)iconTapped:(id)arg1 {
    @try {
        UIView *iconView = (UIView *)self;
        if (iconView && iconView.window) {
            _capturedIconFrame = [iconView convertRect:iconView.bounds 
                                               toView:iconView.window];
            
            UIGraphicsBeginImageContextWithOptions(iconView.bounds.size, NO, [UIScreen mainScreen].scale);
            [iconView.layer renderInContext:UIGraphicsGetCurrentContext()];
            _capturedIconSnapshot = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    } @catch (NSException *e) {
        NSLog(@"[iOS12Animation] Error in iconTapped: %@", e);
    }
    
    %orig;
}

%end

#pragma mark - Хук SBApplicationIcon (запуск анимации)

%hook SBApplicationIcon

- (void)launch {
    // Запускаем анимацию перед открытием приложения
    if (_enabled && !CGRectIsEmpty(_capturedIconFrame)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            IOS12AnimWindow *animWindow = [[IOS12AnimWindow alloc]
                initWithIconFrame:_capturedIconFrame
                          snapshot:_capturedIconSnapshot];
            
            // Устанавливаем rootViewController для корректного отображения
            animWindow.rootViewController = [[UIViewController alloc] init];
            animWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
            animWindow.rootViewController.view.userInteractionEnabled = NO;
            
            [animWindow performAnimationWithCompletion:^{
                // Сбрасываем захваченные данные
                _capturedIconFrame = CGRectZero;
                _capturedIconSnapshot = nil;
            }];
        });
    }
    
    %orig;
}

%end

#pragma mark - Хук SpringBoard (инициализация)

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    reloadSettings();
    
    // Слушаем изменения настроек
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)reloadSettings,
        CFSTR("com.yourname.ios12animation/settingschanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    
    NSLog(@"[iOS12Animation] Tweak loaded successfully! iOS 9 style -> iOS 12+ animation.");
}

%end

#pragma mark - Constructor

%ctor {
    // Регистрируем слушатель настроек при загрузке твика
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)reloadSettings,
        CFSTR("com.yourname.ios12animation/settingschanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    
    reloadSettings();
    NSLog(@"[iOS12Animation] Constructor called, tweak initialized.");
}
