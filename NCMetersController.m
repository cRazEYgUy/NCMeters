//
//  NCMetersController.m
//  NCMeters
//
//  System meters widget for the Notification Center.
//
//  Copyright (c) 2014-2015 Sticktron. All rights reserved.
//
//

#define DEBUG_PREFIX @"••••• [NCMeters]"
#import "DebugLog.h"

#import "Headers/_SBUIWidgetViewController.h"
#import "Privates.h"
#import "UIColor-Additions.h"

#import <sys/socket.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <mach/mach_host.h>
#import <mach/mach_time.h>
#import <net/if.h>
#import <net/if_var.h>
#import <net/if_dl.h>


#define	RTM_IFINFO2 		0x12 /* route.h */

#define UPDATE_INTERVAL		1.0

#define SIDE_MARGIN			2.0
#define ICON_HEIGHT			16.0
#define LABEL_HEIGHT		16.0

#define REGULAR_FONT				[UIFont systemFontOfSize:12]
#define BOLD_FONT					[UIFont boldSystemFontOfSize:12]

#define TRANSLUCENT_COLOR			[UIColor colorWithWhite:0.6 alpha:1]
#define TRANSLUCENT_BLEND_MODE		kBlendModeColorDodge


enum BackdropBlendModes {
	kBlendModeNormal,
	kBlendModePlusDarker,
	kBlendModePlusLighter,
	kBlendModeColorDodge
};

typedef struct {
	uint64_t totalSystemTime;
	uint64_t totalUserTime;
	uint64_t totalIdleTime;
} CPUSample;

typedef struct {
	uint64_t timestamp;
	uint64_t totalDownloadBytes;
	uint64_t totalUploadBytes;
} NetSample;


static CFStringRef const kPrefsAppID = CFSTR("com.sticktron.ncmeters");
static CFStringRef const kPrefsChangedNotification = CFSTR("com.sticktron.ncmeters.settings-changed");

static NSTimer *meterUpdateTimer;



//------------------------------------------------------------------------------
// NCMeter class
//------------------------------------------------------------------------------

@interface NCMeter : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIButton *icon;
@property (nonatomic, strong) UILabel *label;
- (instancetype)initWithName:(NSString *)name title:(NSString *)title;
@end


@implementation NCMeter
- (instancetype)initWithName:(NSString *)name title:(NSString *)title {
	if (self = [super init]) {
		_enabled = YES;
		_name = name;
		_title = title;
	}
	return self;
}
@end



//------------------------------------------------------------------------------
// NCMetersController interface
//------------------------------------------------------------------------------

@interface NCMetersController : _SBUIWidgetViewController
- (void)loadSettings;
- (void)updateStyle;
- (void)updateLayout;
@end

@interface NCMetersController ()
@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) UIView *view;

@property (nonatomic, assign) CPUSample lastCPUSample;
@property (nonatomic, assign) NetSample lastNetSample;
@property (nonatomic, strong) NCMeter *cpuMeter;
@property (nonatomic, strong) NCMeter *ramMeter;
@property (nonatomic, strong) NCMeter *diskMeter;
@property (nonatomic, strong) NCMeter *uploadMeter;
@property (nonatomic, strong) NCMeter *downloadMeter;

// settings
@property (nonatomic, assign) BOOL useBoldText;
@property (nonatomic, strong) NSString *iconColor;
@property (nonatomic, strong) NSString *textColor;
@property (nonatomic, strong) NSMutableArray *meters;
@end



//------------------------------------------------------------------------------
// helper functions
//------------------------------------------------------------------------------

static void settingsChanged(CFNotificationCenterRef center, void *observer,
							CFStringRef name, const void *object,
							CFDictionaryRef userInfo) {
	
	DebugLogC(@"******** Responding to Notification (%@) ********", (__bridge NSString *)name);
	
	NCMetersController *controller = (__bridge NCMetersController *)observer;
	
	if (controller) {
		[controller loadSettings];
		
		if (controller.view) {
			[controller updateStyle];
			[controller updateLayout];
		}
	}
}



//------------------------------------------------------------------------------
// NCMeters Implementation
//------------------------------------------------------------------------------

@implementation NCMetersController

- (instancetype)init {
    self = [super init];
    if (self) {
		DebugLog0;
		
        _bundle = [NSBundle bundleForClass:[self class]];
		
		// create meters
		_cpuMeter = [[NCMeter alloc] initWithName:@"cpu" title:@"CPU"];
		_ramMeter = [[NCMeter alloc] initWithName:@"ram" title:@"RAM"];
		_diskMeter = [[NCMeter alloc] initWithName:@"disk" title:@"DISK"];
		_uploadMeter = [[NCMeter alloc] initWithName:@"upload" title:@"U/L"];
		_downloadMeter = [[NCMeter alloc] initWithName:@"download" title:@"D/L"];
		
		_meters = [NSMutableArray arrayWithArray:@[ _cpuMeter,
													_ramMeter,
													_diskMeter,
													_uploadMeter,
													_downloadMeter ]];
		
		// get user preferences or apply defaults
		[self loadSettings];
		
		// register for notifications from preferences
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
										(__bridge void*)self,
										(CFNotificationCallback)settingsChanged,
										kPrefsChangedNotification,
										NULL,
										CFNotificationSuspensionBehaviorDeliverImmediately);
		
    }
    return self;
}

- (CGSize)preferredViewSize {
	return CGSizeMake(UIScreen.mainScreen.bounds.size.width, 44.0f);
}

- (void)loadView {
	DebugLog0;
	
	self.view = [[UIView alloc] initWithFrame:(CGRect){CGPointZero, [self preferredViewSize]}];
	self.view.backgroundColor = UIColor.clearColor;
	self.view.clipsToBounds = YES;
	
	// create subviews for icons and labels
	for (NCMeter *meter in self.meters) {
		
		// icon ...
		
		UIButton *icon = [[UIButton alloc] init];
		icon.userInteractionEnabled = NO;
		icon.backgroundColor = UIColor.clearColor;
		
		UIImage *iconImage = [UIImage imageNamed:meter.name inBundle:self.bundle];
		if (iconImage) {
			// make image tintable
			iconImage = [iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
			[icon setImage:iconImage forState:UIControlStateNormal];
		}
		
		[self.view addSubview:icon];
		meter.icon = icon;
		
		
		// label ...
		
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.backgroundColor = UIColor.clearColor;
		label.textAlignment = NSTextAlignmentCenter;
		label.text = meter.title;
		
		[self.view addSubview:label];
		meter.label = label;
		
		//DebugLog(@"created icon for %@: %@", meter.name, meter.icon);
		//DebugLog(@"created label for %@: %@", meter.name, meter.label);
	}
	
	[self updateStyle];
	[self updateLayout];
}

- (void)hostWillPresent {
	DebugLog0;
	
	[super hostWillPresent];
	
	// start updating meters !!!
	[self startUpdating];
}

- (void)hostDidDismiss {
	DebugLog0;
	
	// stop updating meters
	[self stopUpdating];
	
	[super hostDidDismiss];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	
	// we don't really need to re-layout every time this is called,
	// but it will catch orientation changes for us
	[self updateLayout];
}

- (void)dealloc {
	// make SURE the timer is dead.
	[meterUpdateTimer invalidate];
	meterUpdateTimer = nil;
}

//

- (void)loadSettings {
	DebugLog0;
	
	NSDictionary *prefs = nil;
	
	CFPreferencesAppSynchronize(kPrefsAppID);
	
	CFArrayRef keyList = CFPreferencesCopyKeyList(kPrefsAppID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keyList) {
		prefs = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, kPrefsAppID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		CFRelease(keyList);
		DebugLogC(@"found user prefs: %@", prefs);
	} else {
		DebugLogC(@"couldn't find user prefs, using defaults instead");
	}
	
	// style
	self.useBoldText = (prefs && prefs[@"BoldText"]) ? [prefs[@"BoldText"] boolValue] : NO;
	self.iconColor = (prefs[@"IconColor"]) ? prefs[@"IconColor"] : @"translucent";
	self.textColor = (prefs && prefs[@"TextColor"]) ? prefs[@"TextColor"] : @"translucent";
	
	// order & visibility
	if (prefs && prefs[@"EnabledMeters"] && prefs[@"DisabledMeters"]) {
		NSMutableArray *newMeterOrder = [NSMutableArray array];
		
		for (NSString *name in prefs[@"EnabledMeters"]) {
			
			NCMeter *meter = [self meterForName:name];
			if (meter) {
				meter.enabled = YES;
				[newMeterOrder addObject:meter];
			}
		}
		
		for (NSString *name in prefs[@"DisabledMeters"]) {
			NCMeter *meter = [self meterForName:name];
			if (meter) {
				meter.enabled = NO;
				[newMeterOrder addObject:meter];
			}
		}
		
		self.meters = newMeterOrder;
	}
}

- (void)updateStyle {
	DebugLog0;
	
	for (NCMeter *meter in self.meters) {
		meter.label.font = self.useBoldText ? BOLD_FONT : REGULAR_FONT;
		[self updateStyleForIcon:meter.icon];
		[self updateStyleForLabel:meter.label];
	}
}

- (void)updateLayout {
	DebugLog(@"self.view.bounds=%@", NSStringFromCGRect(self.view.bounds));
	
	NSMutableArray *visibleMeters = [NSMutableArray array];
	
	// update visibility
	for (NCMeter *meter in self.meters) {
		if (meter.enabled) {
			meter.icon.hidden = NO;
			meter.label.hidden = NO;
			[visibleMeters addObject:meter];
		} else {
			meter.icon.hidden = YES;
			meter.label.hidden = YES;
		}
	}
	
	// update position
	int count = [visibleMeters count];
	//DebugLog(@"laying out meters: %@", visibleMeters);
	
	if (count > 0) {
		CGRect frame = self.view.bounds;
		
		// calculate base meter frame
		frame.size.width -= 2 * SIDE_MARGIN;
		frame.size.width /= (float)count;
		float viewHeight = frame.size.height;
		float topMargin = (viewHeight - ICON_HEIGHT - LABEL_HEIGHT) / 2.0;
		frame.size.height = ICON_HEIGHT;
		
		// layout icons
		frame.origin.x = SIDE_MARGIN;
		frame.origin.y = topMargin;
		for (NCMeter *meter in visibleMeters) {
			meter.icon.frame = frame;
			frame.origin.x += frame.size.width;
		}
		
		// layout labels
		frame.origin.x = SIDE_MARGIN;
		frame.origin.y = topMargin + ICON_HEIGHT;
		for (NCMeter *meter in visibleMeters) {
			meter.label.frame = frame;
			frame.origin.x += frame.size.width;
		}
	}
}

- (void)updateStyleForIcon:(UIButton *)icon {
	if (icon) {
		if ([self.iconColor isEqualToString:@"translucent"]) {
			icon.tintColor = TRANSLUCENT_COLOR;
			[icon _setDrawsAsBackdropOverlayWithBlendMode:TRANSLUCENT_BLEND_MODE];
		} else {
			icon.tintColor = [UIColor colorFromHexString:self.iconColor];
			[icon _setDrawsAsBackdropOverlay:NO];
			//[icon _setDrawsAsBackdropOverlayWithBlendMode:kBlendModeNormal];
		}
	}
}

- (void)updateStyleForLabel:(UILabel *)label {
	if (label) {
		if ([self.textColor isEqualToString:@"translucent"]) {
			label.textColor = TRANSLUCENT_COLOR;
			[label _setDrawsAsBackdropOverlayWithBlendMode:TRANSLUCENT_BLEND_MODE];
		} else {
			label.textColor = [UIColor colorFromHexString:self.textColor];
			[label _setDrawsAsBackdropOverlay:NO];
			//[label _setDrawsAsBackdropOverlayWithBlendMode:kBlendModeNormal];
		}
	}
}

- (void)startUpdating {
	// bail if the meters are already running
	if ([meterUpdateTimer isValid]) {
		DebugLog(@"meters are already running, no need to start them again");
		
	} else {
		// show placeholder values
		for (NCMeter *meter in self.meters) {
			meter.label.text = meter.title;
		}
		
		// get starting measurements
		self.lastCPUSample = [self getCPUSample];
		self.lastNetSample = [self getNetSample];
		
		// start timer
		meterUpdateTimer = [NSTimer timerWithTimeInterval:UPDATE_INTERVAL target:self
												 selector:@selector(updateMeters:)
												 userInfo:nil
												  repeats:YES];
		[[NSRunLoop mainRunLoop] addTimer:meterUpdateTimer forMode:NSRunLoopCommonModes];
		DebugLog(@"Started Timer ••••• (%@)", meterUpdateTimer);
	}
}

- (void)stopUpdating {
	if (meterUpdateTimer) {
		DebugLog(@"Stopping Timer ••••• (%@)", meterUpdateTimer);
		[meterUpdateTimer invalidate];
		meterUpdateTimer = nil;
	} else {
		DebugLog(@"Stopping Timer ••••• (no timer to stop)");
	}
}

- (void)updateMeters:(NSTimer *)timer {
	DebugLog(@"updateMeters called (timer %@)", timer);
	
	// Disk Meter: free space on /User
	if (self.diskMeter.enabled) {
		long long bytesFree = [self diskFreeInBytesForPath:@"/private/var"];
		double gigsFree = (double)bytesFree / (1024*1024*1024);
		[self.diskMeter.label setText:[NSString stringWithFormat:@"%.1f GB", gigsFree]];
	}
	
	// RAM Meter: "available" memory (free + inactive)
	if (self.ramMeter.enabled) {
		uint32_t ram = [self memoryAvailableInBytes];
		ram /= (1024*1024); // convert to MB
		[self.ramMeter.label setText:[NSString stringWithFormat:@"%u MB", ram]];
	}
	
	// CPU Meter: percentage of time in use since last sample
	if (self.cpuMeter.enabled) {
		CPUSample cpu_delta;
		CPUSample cpu_sample = [self getCPUSample];
		
		// get usage for period
		cpu_delta.totalUserTime = cpu_sample.totalUserTime - self.lastCPUSample.totalUserTime;
		cpu_delta.totalSystemTime = cpu_sample.totalSystemTime - self.lastCPUSample.totalSystemTime;
		cpu_delta.totalIdleTime = cpu_sample.totalIdleTime - self.lastCPUSample.totalIdleTime;
		
		// calculate time spent in use as a percentage of the total time
		uint64_t total = cpu_delta.totalUserTime + cpu_delta.totalSystemTime + cpu_delta.totalIdleTime;
		//		double idle = (double)(cpu_delta.totalIdleTime) / (double)total * 100.0; // in %
		//		double used = 100.0 - idle;
		double used = ((cpu_delta.totalUserTime + cpu_delta.totalSystemTime) / (double)total) * 100.0;
		
		[self.cpuMeter.label setText:[NSString stringWithFormat:@"%.1f %%", used]];
		
		// save this sample for next time
		self.lastCPUSample = cpu_sample;
	}
	
	
	// Net Meters: bandwidth used during sample period, normalized to per-second values
	if (self.uploadMeter.enabled || self.downloadMeter.enabled) {
		NetSample net_delta;
		NetSample net_sample = [self getNetSample];
		
		// calculate period length
		net_delta.timestamp = (net_sample.timestamp - self.lastNetSample.timestamp);
		double interval = net_delta.timestamp / 1000.0 / 1000.0 / 1000.0; // ns-to-s
		DebugLog(@"Net Meters sample delta: %fs", interval);
		
		// get bytes transferred since last sample was taken
		net_delta.totalUploadBytes = net_sample.totalUploadBytes - self.lastNetSample.totalUploadBytes;
		net_delta.totalDownloadBytes = net_sample.totalDownloadBytes - self.lastNetSample.totalDownloadBytes;
		
		if (self.uploadMeter.enabled) {
			double ul = (double)net_delta.totalUploadBytes / interval;
			self.uploadMeter.label.text = [self formatBytes:ul];
		}
		
		if (self.downloadMeter.enabled) {
			double dl = net_delta.totalDownloadBytes / interval;
			self.downloadMeter.label.text = [self formatBytes:dl];
		}
		
		// save this sample for next time
		self.lastNetSample = net_sample;
	}
}

- (long long)diskFreeInBytesForPath:(NSString *)path {
	long long result = 0;
	NSDictionary *attr = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:nil];
	if (attr && attr[@"NSFileSystemFreeSize"]) {
		result = [attr[@"NSFileSystemFreeSize"] longLongValue];
	}
	return result;
}

- (uint32_t)memoryAvailableInBytes {
	// I'm counting "available" as free + inactive ram
	
	uint32_t bytesFree = 0;
	mach_port_t	host_port = mach_host_self();
	
	if (host_port) {
		mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
		
		//vm_size_t pagesize = host_page_size(host_port, &pagesize);
		uint32_t pagesize = 4096; // set manually because in 64-bit mode host_page_size() returns 16K (?)
		
		vm_statistics_data_t vm_stat;
		
		if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
			NSLog(@"######## NCMeters: error fetching vm info from mach !#");
		} else {
			// stats are in bytes
			bytesFree = (vm_stat.free_count + vm_stat.inactive_count) * pagesize;
			//DebugLog(@"available RAM = %u Bytes", bytesFree);
		}
	} else {
		NSLog(@"######## NCMeters: couldn't get host_port #!");
	}
	
	return bytesFree;
}

- (CPUSample)getCPUSample {
	/*
		CPUSample: { totalUserTime, totalSystemTime, totalIdleTime }
	 */
	CPUSample sample = {0, 0, 0};
	
	kern_return_t kr;
	mach_msg_type_number_t count;
	host_cpu_load_info_data_t r_load;
	
	count = HOST_CPU_LOAD_INFO_COUNT;
	kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (int *)&r_load, &count);
	
	if (kr != KERN_SUCCESS) {
		NSLog(@"######## NCMeters: error fetching HOST_CPU_LOAD_INFO !#");
	} else {
		sample.totalUserTime = r_load.cpu_ticks[CPU_STATE_USER] + r_load.cpu_ticks[CPU_STATE_NICE];
		sample.totalSystemTime = r_load.cpu_ticks[CPU_STATE_SYSTEM];
		sample.totalIdleTime = r_load.cpu_ticks[CPU_STATE_IDLE];
	}
	
	//DebugLog(@"got CPU sample [ user:%llu; sys:%llu; idle:%llu ]", sample.totalUserTime, sample.totalSystemTime, sample.totalIdleTime);
	
	return sample;
}

- (NetSample)getNetSample {
	/*
		NetSample: { timestamp, totalUploadBytes, totalDownloadBytes }
	 */
	NetSample sample = {0, 0, 0};
	
	int mib[] = {
		CTL_NET,
		PF_ROUTE,
		0,
		0,
		NET_RT_IFLIST2,
		0
	};
	
	size_t len = 0;
	
	if (sysctl(mib, 6, NULL, &len, NULL, 0) >= 0) {
		char *buf = (char *)malloc(len);
		
		if (sysctl(mib, 6, buf, &len, NULL, 0) >= 0) {
			
			// read interface stats ...
			
			char *lim = buf + len;
			char *next = NULL;
			u_int64_t totalibytes = 0;
			u_int64_t totalobytes = 0;
			char name[32];
			
			for (next = buf; next < lim; ) {
				struct if_msghdr *ifm = (struct if_msghdr *)next;
				next += ifm->ifm_msglen;
				
				if (ifm->ifm_type == RTM_IFINFO2) {
					struct if_msghdr2 *if2m = (struct if_msghdr2 *)ifm;
					struct sockaddr_dl *sdl = (struct sockaddr_dl *)(if2m + 1);
					
					strncpy(name, sdl->sdl_data, sdl->sdl_nlen);
					name[sdl->sdl_nlen] = 0;
					
					NSString *interface = [NSString stringWithUTF8String:name];
					//DebugLog(@"interface (%u) name=%@", if2m->ifm_index, interface);
					
					// skip local interface (lo0)
					if (![interface isEqualToString:@"lo0"]) {
						totalibytes += if2m->ifm_data.ifi_ibytes;
						totalobytes += if2m->ifm_data.ifi_obytes;
					}
				}
			}
			
			sample.timestamp = [self timestamp];
			sample.totalUploadBytes = totalobytes;
			sample.totalDownloadBytes = totalibytes;
			
		} else {
			NSLog(@"######## NCMeters: sysctl error !#");
		}
		
		free(buf);
		
	} else {
		NSLog(@"######## XCMeters: sysctl error !#");
	}
	
	//DebugLog(@"got Net sample [ up:%llu; down=%llu ]", sample.totalUploadBytes, sample.totalDownloadBytes);
	
	return sample;
}

- (uint64_t)timestamp {
	
	// get timer units
	mach_timebase_info_data_t info;
	mach_timebase_info(&info);
	
	// get timer value
	uint64_t timestamp = mach_absolute_time();
	
	// convert to nanoseconds
	timestamp *= info.numer;
	timestamp /= info.denom;
	
	return timestamp;
}

- (NSString *)formatBytes:(double)bytes {
	NSString *result;
	
	if (bytes > (1024*1024*1024)) { // G
		result = [NSString stringWithFormat:@"%.1f GB/s", bytes/1024/1024/1024];
	} else if (bytes > (1024*1024)) { // M
		result = [NSString stringWithFormat:@"%.1f MB/s", bytes/1024/1024];
	} else if (bytes > 1024) { // K
		result = [NSString stringWithFormat:@"%.1f KB/s", bytes/1024];
	} else if (bytes > 0 ) {
		result = [NSString stringWithFormat:@"%.0f B/s", bytes];
	} else {
		result = @"0";
	}
	
	return result;
}

- (NCMeter *)meterForName:(NSString *)name {
	//DebugLog(@"looking for meter (%@) in self.meters=%@", name, self.meters);
	for (NCMeter *meter in self.meters) {
		if ([meter.name isEqualToString:name]) {
			return meter;
		}
	}
	return nil;
}

@end
