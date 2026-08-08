# iOS 12 Animation Tweak

Твик для iOS 9, добавляющий плавную анимацию открытия приложений в стиле iOS 12+.
Иконка плавно увеличивается из своей позиции на рабочем столе до полного экрана
с пружинной анимацией (spring animation).

## Структура проекта

```
iOS12Animation/
├── Makefile                                    # Сборка через Theos
├── control                                     # Метаданные пакета (DEBIAN)
├── iOS12Animation.plist                        # Фильтр твика (SpringBoard)
├── Tweak.xm                                    # Основной код твика (Logos/ObjC)
└── layout/
    └── Library/
        └── PreferenceLoader/
            └── Preferences/
                └── iOS12Animation.plist         # Панель настроек
```

## Требования

- **Theos** — установлен и настроен (https://theos.dev)
- **Xcode** (для компиляции Objective-C) или `clang` через Theos
- **Jailbroken устройство** с iOS 9.x
- **OpenSSH** на устройстве для установки

## Установка Theos (если не установлен)

```bash
export THEOS=~/theos
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
```

## Сборка и установка

### 1. Собрать .deb пакет

```bash
cd iOS12Animation
make package
```

Результат: `packages/com.yourname.ios12animation_1.0.0_iphoneos-arm.deb`

### 2. Установить на устройство

```bash
make install THEOS_DEVICE_IP=<IP_УСТРОЙСТВА>
```

Или вручную через SCP:

```bash
scp packages/*.deb root@<IP>:/var/mobile/
ssh root@<IP>
dpkg -i /var/mobile/com.yourname.ios12animation_*.deb
killall -9 SpringBoard
```

### 3. Удаление

```bash
dpkg -r com.yourname.ios12animation
killall -9 SpringBoard
```

## Настройки

После установки появится раздел **"iOS 12 Animation"** в Настройках:

| Параметр | Описание | По умолчанию |
|----------|----------|-------------|
| Включить твик | Вкл/Выкл анимацию | Вкл |
| Длительность | Время анимации (0.3–1.0 сек) | 0.55 сек |
| Упругость | Spring damping (0.5–1.0, ниже = больше пружинит) | 0.86 |
| Начальная скорость | Initial spring velocity (0.0–5.0) | 0.0 |
| Стиль анимации | Zoom / Zoom+Blur / Zoom+Fade | Zoom |

## Принцип работы

1. Хук `SBIconView` перехватывает касание иконки и захватывает её позицию на экране + снапшот
2. Хук `SBApplicationIcon -launch` запускает кастомную анимацию перед открытием приложения
3. Создаётся оверлейное окно (`UIWindow`) поверх SpringBoard
4. Белая карточка со снапшотом иконки увеличивается от позиции иконки до полного экрана
5. Используется `UIView animateWithDuration:usingSpringWithDamping:` для пружинного эффекта
6. После увеличения оверлей плавно исчезает, открывая запущенное приложение

## Совместимость

- iOS 9.0 — 9.3.6
- armv7 + arm64
