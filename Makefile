ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WeChatMiniProgramForward

WeChatMiniProgramForward_FILES = Tweak.xm
WeChatMiniProgramForward_CFLAGS = -fobjc-arc -Wno-error=deprecated-declarations -Wno-error=unused-variable -Wno-error=unused-function

WeChatMiniProgramForward_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
