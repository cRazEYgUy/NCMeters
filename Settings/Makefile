ARCHS = armv7 arm64
TARGET = iphone:clang:latest:7.0

THEOS_BUILD_DIR = Packages

include theos/makefiles/common.mk

BUNDLE_NAME = NCMetersSettings
NCMetersSettings_CFLAGS = -fobjc-arc
NCMetersSettings_FILES = NCMetersSettings.m NCMetersMeterList.m NCMetersColorPicker.m NCMetersColorPickerLinkCell.m NCMetersTitleCell.m ../UIColor-Additions.m
NCMetersSettings_INSTALL_PATH = /Library/PreferenceBundles
NCMetersSettings_FRAMEWORKS = UIKit CoreGraphics Social
NCMetersSettings_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/NCMetersSettings.plist$(ECHO_END)
