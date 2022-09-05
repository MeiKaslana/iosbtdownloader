//
//  TorrentsViewController.m
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader


#import "TorrentsViewController.h"
#import "TorrentCell.h"
#import "TorrentModel.h"
#import <libtorrent/torrent_info.hpp>
#import <libtorrent/bencode.hpp>
#import <libtorrent/magnet_uri.hpp>
#import <libtorrent/create_torrent.hpp>
#import <libtorrent/session.hpp>
#import <libtorrent/torrent_info.hpp>
#import <libtorrent/torrent_handle.hpp>
#import <libtorrent/torrent_status.hpp>
#import <libtorrent/alert_types.hpp>
#import "PTTorrentStreamer+Protected.h"
#import "ColorTheme.h"

@class TorrentModel;

@interface TorrentsViewController ()<UITableViewDataSource,UITableViewDelegate> {
    
    NSMutableArray              *_torrentmodels;
}
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableDictionary *torrentsessions;
@end
using namespace libtorrent;
@implementation TorrentsViewController

- (id)init
{
    self = [super init];
    if (self) {

    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    if (!_torrentmodels) {
        _torrentmodels = [NSMutableArray new];
        [self loadTorrents];
    }
    if (!_torrentsessions){
        _torrentsessions = [NSMutableDictionary new];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(writeTorrentwithMagnet:) name:@"PasteBoradUpdateMagnet" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    // 移除当前对象监听的事件
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
#pragma mark - public

- (void) writeTorrentwithMagnet:(NSNotification *)noti
{
    NSRange hashtag = [noti.object rangeOfString:@"urn:btih:"];
    NSRange word = [[noti.object substringFromIndex:hashtag.location + 9] rangeOfString:@"&dn="];
    NSString *hashtagWord = [noti.object substringWithRange:NSMakeRange(hashtag.location+9, word.location)];
    NSString *urlpath = [NSString stringWithFormat:@"https://itorrents.org/torrent/%@.torrent",hashtagWord];
    NSURL *url = [NSURL URLWithString:urlpath];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        NSString *sandboxdocpath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)lastObject];
        NSString *folder = [NSString stringWithFormat:@"%@/%@/%@.torrent",sandboxdocpath,@"torrents",hashtagWord];
        [data writeToFile:[NSURL URLWithString:folder].relativePath atomically:YES];
        NSFileManager *fm = [[NSFileManager alloc] init];
        NSError *error;
        NSString *filetorrent = [NSString stringWithFormat:@"%@/%@",sandboxdocpath,@"torrents"];
        NSArray *contents = [fm contentsOfDirectoryAtPath:filetorrent error:&error];
        [self loadTorrents];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"成功" message:@"磁力转种子成功" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *conform = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [alert dismissViewControllerAnimated:YES completion:nil];
            }];
        [alert addAction:conform];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}


- (void) loadTorrents
{
    _torrentmodels = [NSMutableArray new];
    NSString *sandboxdocpath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)lastObject];
    NSString *folder = [NSString stringWithFormat:@"%@/%@",sandboxdocpath,@"torrents"];
    
    NSError *error;
    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"File Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *conform = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSLog(@"点击了确认按钮");
                [alert dismissViewControllerAnimated:YES completion:nil];
            }];
        [alert addAction:conform];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSArray *contents = [fm contentsOfDirectoryAtPath:folder error:&error];
    
    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"File Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *conform = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSLog(@"点击了确认按钮");
                [alert dismissViewControllerAnimated:YES completion:nil];
            }];
        [alert addAction:conform];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    for (NSString *filename in contents) {    
        NSString *path = [folder stringByAppendingPathComponent:filename];
        error_code ec;
        std::shared_ptr<torrent_info> ti1 = std::make_shared<torrent_info>([path UTF8String], ec);
        TorrentModel *model = [TorrentModel new];
        model.total_wanted = ti1->total_size();
        model.torrentname = filename;
        model.torrentstate = TorrentStateClosed;
        model.filepath = path;
        [_torrentmodels addObject:model];
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:_torrentmodels.count-1 inSection:0];
        [_tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationRight];
    }
    [self.tableView reloadData];
}




- (void) toggleRun:(id)sender
{
    TorrentCell *cell = (TorrentCell*)[[sender superview] superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath)
        return;
    const NSUInteger row = indexPath.row;
    NSString *path = [NSString stringWithFormat:@"%lu",(unsigned long)row];
    __block TorrentModel *model = [_torrentmodels objectAtIndex:row];
    if(model.torrentstate == TorrentStateClosed){
        cell.startButton.enabled = NO;
        model.torrentstate = TorrentStateSearching;
        __weak TorrentsViewController *weakSelf = self;
        [cell updateFromModel:model];
        PTTorrentStreamer *torrentsession;
        if([_torrentsessions objectForKey:path]){
            torrentsession = [_torrentsessions objectForKey:path];
        }else{
            torrentsession = [[PTTorrentStreamer alloc] init];
    //        _torrentsessions[row] = torrentsession;
            [_torrentsessions setObject:torrentsession forKey:path];
        }
        
        [torrentsession startStreamingFromFile:model.filepath progress:^(PTTorrentStatus status){
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong TorrentsViewController *strongSelf = weakSelf;
                if (strongSelf && strongSelf.isViewLoaded && strongSelf.view.window)
                    model.downrate = status.downloadSpeed;
                    if(model.downrate == 0){
                        model.torrentstate = TorrentStateSeeding;
                    }else{
                        model.torrentstate = TorrentStateDownloading;
                    }
                    model.total_wanted = status.total_wanted;
                    model.total_wanted_done = status.total_wanted_done;
                    cell.startButton.enabled = YES;
                    [cell updateFromModel:model];
            });
        } readyToPlay:^(NSString *filePath){
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"下载完成" message:[NSString stringWithFormat:@"文件已下载到%@",filePath] preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *conform = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [alert dismissViewControllerAnimated:YES completion:nil];
                }];
            [alert addAction:conform];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        } failure:^(NSError *error){
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Torrent Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *conform = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [alert dismissViewControllerAnimated:YES completion:nil];
                }];
            [alert addAction:conform];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }];
    }else{
        model.downrate = 0;
        model.torrentstate = TorrentStateClosed;
        [cell updateFromModel:model];
        PTTorrentStreamer* session =  [_torrentsessions objectForKey:path];
        [session cancelStreamingAndDeleteData:false];
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 65.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _torrentmodels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TorrentCell *cell = (TorrentCell*)[tableView dequeueReusableCellWithIdentifier:[TorrentCell identifier]];
    if (cell) {
        TorrentModel *model = [_torrentmodels objectAtIndex:indexPath.row];
        cell.nameLabel.text = model.torrentname;
        cell.startButton.titleLabel.text = @"";
        switch (model.torrentstate) {
            case TorrentStateClosed:
                cell.stateLabel.text = @"未开始";
                break;
            case TorrentStateCheckingHash:
                cell.stateLabel.text = @"验证资源";
                break;
            case TorrentStateStarting:
                cell.stateLabel.text = @"开始中";
                break;
            case TorrentStateSearching:
                cell.stateLabel.text = @"搜索资源中";
                break;
            case TorrentStateConnecting:
                cell.stateLabel.text = @"连接中";
                break;
            case TorrentStateDownloading:
                cell.stateLabel.text = @"下载中";
                break;
            case TorrentStateEndgame:
                cell.stateLabel.text = @"下载完成";
                break;
            case TorrentStateSeeding:
                cell.stateLabel.text = @"寻找种子中";
                break;
            default:
                cell.stateLabel.text = @"未开始";
                break;
        }
        cell.progressLabel.text = [NSString stringWithFormat:@"0MB of %ldMB",(long)model.total_wanted/1024/1024];
        cell.infoLabel.text = @"--";
        [cell.startButton addTarget:self
                             action:@selector(toggleRun:)
                   forControlEvents:UIControlEventTouchUpInside];
        //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

- (IBAction)unwindSegueToRedViewController:(UIStoryboardSegue *)segue {

}
@end
