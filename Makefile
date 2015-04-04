
ARCHS = armv7 arm64
TARGET = iphone:clang:latest:7.0

THEOS_BUILD_DIR = Packages

include theos/makefiles/common.mk

BUNDLE_NAME = NCMeters
NCMeters_CFLAGS = -fobjc-arc
NCMeters_FILES = NCMetersController.m UIColor-Additions.m
NCMeters_INSTALL_PATH = /Library/WeeLoader/Plugins
NCMeters_FRAMEWORKS = UIKit CoreGraphics
NCMeters_PRIVATE_FRAMEWORKS = SpringBoardUIServices

include $(THEOS_MAKE_PATH)/bundle.mk

SUBPROJECTS += Settings
include $(THEOS_MAKE_PATH)/aggregate.mk

after-stage::
	find $(FW_STAGING_DIR) -iname '*.plist' -or -iname '*.strings' -exec plutil -convert binary1 {} \;
	find $(FW_STAGING_DIR) -iname '*.png' -exec pincrush-osx -i {} \;

after-install::
	install.exec "killall -9 backboardd"
