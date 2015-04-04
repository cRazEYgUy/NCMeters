//
//  UIColor-Additions.h
//  NCMeters
//
//  Additions to the UIColor class.
//
//  Copyright (c) 2014-2015 Sticktron. All rights reserved.
//
//

#import <UIKit/UIColor.h>

@interface UIColor (CCMeters)
+ (UIColor *)colorFromHexString:(NSString *)hexString;
- (UIImage *)thumbnailWithSize:(CGSize)size;
@end

