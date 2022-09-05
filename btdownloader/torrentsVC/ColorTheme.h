//
//  ColorTheme.h
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader
#import "UIKit/UIKit.h"
#import <Foundation/Foundation.h>

@interface ColorTheme : NSObject
@property (readonly, nonatomic, strong) UIColor *tintColor;
@property (readonly, nonatomic, strong) UIColor *backgroundColor;
@property (readonly, nonatomic, strong) UIColor *altBackColor;
@property (readonly, nonatomic, strong) UIColor *shadowColor;
@property (readonly, nonatomic, strong) UIColor *textColor;
@property (readonly, nonatomic, strong) UIColor *altTextColor;
@property (readonly, nonatomic, strong) UIColor *selectedTextColor;
@property (readonly, nonatomic, strong) UIColor *highlightTextColor;
@property (readonly, nonatomic, strong) UIColor *grayedTextColor;
@property (readonly, nonatomic, strong) UIColor *backgroundColorWithPattern;
@property (readonly, nonatomic, strong) UIColor *alertColor;

+ (id) theme;
+ (void) setup;
@end
