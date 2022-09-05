//
//  TorrentsViewController.h
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader

#import <UIKit/UIKit.h>

@interface TorrentsViewController : UIViewController

- (void) updateAfterEnterBackground;
- (BOOL) openTorrentWithData: (NSData *) data error: (NSError **) perror;
@end
