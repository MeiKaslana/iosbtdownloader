//
//  FileBrowserViewController.h
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader

#import <UIKit/UIKit.h>

@interface FileBrowserViewController : UIViewController<UIActionSheetDelegate>
@property (readwrite, nonatomic) NSString *path;
@property (nonatomic) NSURL *fileURL;
@end
