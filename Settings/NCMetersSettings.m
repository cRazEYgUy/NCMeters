//
//  NCMetersSettings.m
//  NCMeters Settings
//
//  Copyright (c) 2014-2015 Sticktron. All rights reserved.
//
//

#define DEBUG_PREFIX @"••••• [NCMeters|Settings]"
#import "../DebugLog.h"

#import "Headers/PSListController.h"
#import <Social/Social.h>


static NSString * const kBundlePath = @"/Library/PreferenceBundles/NCMetersSettings.bundle";
static NSString * const kIconColorSpecID = @"Icon Color";
static NSString * const kTextColorSpecID = @"Text Color";



@interface NCMetersSettingsController : PSListController
@property (nonatomic, strong) UIImage *titleImage;
@end


@implementation NCMetersSettingsController

- (id)specifiers {
	if (_specifiers == nil) {
		_specifiers = [self loadSpecifiersFromPlistName:@"NCMetersSettings" target:self];
	}
	return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[self reloadSpecifierID:@"Icon Color" animated:NO];
	[self reloadSpecifierID:@"Text Color" animated:NO];
}

- (void)setTitle:(id)title {
	// no thanks
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	// add a heart button to the navbar
	NSString *path = [kBundlePath stringByAppendingPathComponent:@"heart"];
	UIImage *heartImage = [[UIImage alloc] initWithContentsOfFile:path];
	
	UIBarButtonItem *heartButton = [[UIBarButtonItem alloc] initWithImage:heartImage
																	style:UIBarButtonItemStylePlain
																   target:self
																   action:@selector(showLove)];
	heartButton.imageInsets = (UIEdgeInsets){1, 0, -1, 0};
	//heartButton.tintColor = ???;
	
	[self.navigationItem setRightBarButtonItem:heartButton];
}

- (void)openEmail {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:sticktron@hotmail.com"]];
}

- (void)openTwitter {
	NSURL *url;
	
	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:"]]) {
		url = [NSURL URLWithString:@"tweetbot:///user_profile/sticktron"];
		
	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitterrific:"]]) {
		url = [NSURL URLWithString:@"twitterrific:///profile?screen_name=sticktron"];
		
	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetings:"]]) {
		url = [NSURL URLWithString:@"tweetings:///user?screen_name=sticktron"];
		
	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]]) {
		url = [NSURL URLWithString:@"twitter://user?screen_name=sticktron"];
		
	} else {
		url = [NSURL URLWithString:@"http://twitter.com/sticktron"];
	}
	
	[[UIApplication sharedApplication] openURL:url];
}

- (void)openGitHub {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://github.com/Sticktron/NCMeters"]];
}

- (void)openSticktronWeb {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.sticktron.com"]];
}

- (void)openPayPal {
	NSString *url = @"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=BKGYMJNGXM424&lc=CA&item_name=Donation%20to%20Sticktron&item_number=NCMeters&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted";
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)openCCMetersInCydia {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/org.thebigboss.ccmeters"]];
}

- (void)showLove {
	// send a nice tweet ;)
	
	SLComposeViewController *composeController = [SLComposeViewController
												  composeViewControllerForServiceType:SLServiceTypeTwitter];
	
	[composeController setInitialText:@"I'm using #NCMeters by @Sticktron to keep an eye on performance!"];
	
	[self presentViewController:composeController
					   animated:YES
					 completion:nil];
}

@end

