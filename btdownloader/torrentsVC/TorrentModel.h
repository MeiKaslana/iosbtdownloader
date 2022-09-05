//
//  TorrentModel.h
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader

#import <Foundation/Foundation.h>
typedef enum {
    TorrentStateClosed,
    TorrentStateCheckingHash,
    TorrentStateStarting,
    TorrentStateSearching,
    TorrentStateConnecting,
    TorrentStateDownloading,
    TorrentStateEndgame,
    TorrentStateSeeding
} TorrentState;

@interface TorrentModel : NSObject
@property (nonatomic) NSInteger downrate;
@property (nonatomic) NSInteger total_wanted;
@property (nonatomic) NSInteger total_wanted_done;
@property (nonatomic) TorrentState torrentstate;
@property (nonatomic) NSString* torrentname;
@property (nonatomic) NSString* filepath;
@end


