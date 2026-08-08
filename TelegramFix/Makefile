ARCHS = armv7 arm64
TARGET = iphone:clang:latest:9.0
INSTALL_TARGET_PROCESSES = Telegram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TelegramFix

TelegramFix_FILES = Tweak.xm
TelegramFix_CFLAGS = -fobjc-arc -Wno-unused-function
TelegramFix_FRAMEWORKS = Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
