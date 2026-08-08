ARCHS = armv7 arm64
TARGET = iphone:clang:latest:9.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iOS12Animation

iOS12Animation_FILES = Tweak.xm
iOS12Animation_CFLAGS = -fobjc-arc -Wno-unused-function
iOS12Animation_FRAMEWORKS = UIKit QuartzCore CoreGraphics
iOS12Animation_PRIVATE_FRAMEWORKS = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
        install.exec "killall -9 SpringBoard"
