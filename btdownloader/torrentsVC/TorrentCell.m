//
//  TorrentCell.m
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader

#import "TorrentCell.h"
#import "ColorTheme.h"
#import "KxBitArray.h"


@implementation TorrentCell {

    TorrentState         _state;
    KxBitArray  *_pieces;
    KxBitArray  *_pending;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+ (NSString *) identifier
{
    return @"TorrentCell";
}

+ (CGFloat) defaultHeight
{
    return 65.0;
}


- (void) prepareForReuse
{
    _state = TorrentStateClosed;
    [super prepareForReuse];
}

- (void) updateFromModel: (TorrentModel *) model
{
    ColorTheme *theme = [ColorTheme theme];
    TorrentState state = model.torrentstate;
    const BOOL closed = model.torrentstate == TorrentStateClosed;
    if (_state != state) {
        _state = state;
        UIImage *image = [UIImage imageNamed: closed ? @"resume.png" : @"pause.png"];
        [self.startButton setImage:image forState:UIControlStateNormal];
        [self.startButton setTitle:@"" forState:UIControlStateNormal];
        const BOOL seed = state == TorrentStateSeeding;
        self.stateLabel.textColor = seed ? theme.highlightTextColor : theme.textColor;
        switch (model.torrentstate) {
            case TorrentStateClosed:
                self.stateLabel.text = @"未开始";
                break;
            case TorrentStateCheckingHash:
                self.stateLabel.text = @"验证资源";
                break;
            case TorrentStateStarting:
                self.stateLabel.text = @"开始中";
                break;
            case TorrentStateSearching:
                self.stateLabel.text = @"搜索资源中";
                break;
            case TorrentStateConnecting:
                self.stateLabel.text = @"连接中";
                break;
            case TorrentStateDownloading:
                self.stateLabel.text = @"下载中";
                break;
            case TorrentStateEndgame:
                self.stateLabel.text = @"下载完成";
                break;
            case TorrentStateSeeding:
                self.stateLabel.text = @"寻找种子中";
                break;
            default:
                self.stateLabel.text = @"未开始";
                break;
        }
    }
    self.progressLabel.text = [NSString stringWithFormat:@"%ldMB of %ldMB",(long)model.total_wanted_done/1024/1024 ,model.total_wanted/1024/1024];
    self.infoLabel.text = closed ? @"--" : [NSString stringWithFormat:@"%ldKB/s",(long)model.downrate/1024];
//    [self setNeedsDisplay];
}

- (void) drawRect:(CGRect)r
{
#define BATCH_NUM 64
    
    ColorTheme *theme = [ColorTheme theme];
    
    CGRect rc = self.bounds;
    rc.origin.y = 2;
    rc.size.height -= 4;
    rc.origin.x = 5;
    rc.size.width -= 10;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [theme.backgroundColor set];
	CGContextFillRect(context, rc);
     
    const NSUInteger piecesCount = _pieces.count;
    const NSUInteger completed = [_pieces countBits:YES];
    
    if (completed) {
                
        [theme.altBackColor set];
        
        if (piecesCount == completed) {
                        
            CGContextFillRect(context, rc);
            
        } else {
            
            const float X = rc.origin.x;
            const float Y = rc.origin.y;
            const float W = rc.size.width;
            const float H = rc.size.height;
            
            CGRect boxes[BATCH_NUM];
            const float dx = W / piecesCount;
            NSUInteger n = 0;
            
            for (NSUInteger i = 0; i < piecesCount; ++i) {
                
                if ([_pieces testBit:i]) {
                    
                    const CGRect rc = CGRectMake(X + i * dx, Y, dx, H);
                    boxes[n++] = rc;
                    
                    if (n == BATCH_NUM) {
                        CGContextFillRects(context, boxes, n);
                        n = 0;
                    }
                }
            }
            
            if (n)
                CGContextFillRects(context, boxes, n);
            
            if (_pending) {
                               
                [theme.alertColor set];
                for (NSUInteger i = 0; i < _pending.count; ++i) {
                    
                    if ([_pending testBit:i]) {
                        
                        const CGRect rc = CGRectMake(X + i * dx, Y, dx, H);
                        CGContextFillRect(context, rc);
                    }
                }
            }
        }
    }
}


@end
