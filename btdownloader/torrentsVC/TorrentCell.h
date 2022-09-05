//
//  TorrentCell.h
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader

#import <UIKit/UIKit.h>
#import "TorrentModel.h"
@class TorrentModel;

@interface TorrentCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UILabel *stateLabel;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

+ (NSString *) identifier;
+ (CGFloat) defaultHeight;

- (void) updateFromModel: (TorrentModel *) model;

@end
