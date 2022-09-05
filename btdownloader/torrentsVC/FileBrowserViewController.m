//
//  FileBrowserViewController.m
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//
//  https://github.com/MeiKaslana/iosbtdownloader


#import "FileBrowserViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "AppDelegate.h"
#import "ColorTheme.h"
#import <QuickLook/QuickLook.h>
#import "KxMovieViewController.h"
#import "NSDate+Kolyvan.h"
typedef enum {

    FileDescTypeUnknown,
    FileDescTypeEmpty,
    FileDescTypeFolder,
    FileDescTypeAudio,
    FileDescTypeAudioLegacy,
    FileDescTypeVideo,
    FileDescTypeVideoLegacy,
    FileDescTypeImage,
    FileDescTypeTorrent,
    FileDescTypePDF,
    FileDescTypeHTML,
    FileDescTypeTXT,
    //FileDescTypeArchive,
    
} FileDescType;
#define KILO_FACTOR 1024.0
#define MEGA_FACTOR 1048576.0
#define GIGA_FACTOR 1073741824.0
#define TERA_FACTOR 1099511627776.0

double scaleSizeWithUint(double value, const char** punit)
{
    char *unit;
    
    if (value < KILO_FACTOR) {
        
        unit = "B";
        
    } else if (value < MEGA_FACTOR) {
        
        value /= KILO_FACTOR;
        unit = "KB";
        
    } else if (value < GIGA_FACTOR) {
        
        value /= MEGA_FACTOR;
        unit = "MB";
        
    } else if (value < TERA_FACTOR) {
        
        value /= GIGA_FACTOR;
        unit = "GB";
        
    } else {
        
        value /= TERA_FACTOR;
        unit = "TB";
    }
    
    if (punit)
        *punit = unit;
    return value;
}

NSString * scaleSizeToStringWithUnit(double value)
{
    if (value < 0.05)
        return @"0";
    
    const char *unit;
    value = scaleSizeWithUint(value, &unit);
    float integral;
    if (0 == modff(value, &integral))
        return [NSString stringWithFormat:@"%.0f%s", integral, unit];
    return [NSString stringWithFormat:@"%.1f%s", value, unit];
}

static FileDescType fileDescTypeFromFileExtension(NSString *path)
{
    FileDescType type;
    NSString *ext = path.pathExtension.lowercaseString;
    
    if ([ext isEqualToString:@"torrent"]){
        
        type = FileDescTypeTorrent;
           
    } else if ([ext isEqualToString:@"png"] ||
               [ext isEqualToString:@"jpg"] ||
               [ext isEqualToString:@"jpeg"] ||
               [ext isEqualToString:@"gif"] ||
               [ext isEqualToString:@"tiff"]) {
        
        type =  FileDescTypeImage;
        
    } else if ([ext isEqualToString:@"ogg"] ||
               [ext isEqualToString:@"mpga"] |
               [ext isEqualToString:@"mka"]) {
        
        type =  FileDescTypeAudio;
        
    } else if ([ext isEqualToString:@"mp3"] ||
               [ext isEqualToString:@"wav"] ||
               [ext isEqualToString:@"caf"] ||
               [ext isEqualToString:@"aif"] ||
               [ext isEqualToString:@"wma"] ||
               [ext isEqualToString:@"m4a"] ||
               [ext isEqualToString:@"aac"]) {
        
        type =  FileDescTypeAudioLegacy;
        
    } else if ([ext isEqualToString:@"avi"] ||
               [ext isEqualToString:@"mkv"] ||
               [ext isEqualToString:@"mpeg"] ||
               [ext isEqualToString:@"mpg"] ||
               [ext isEqualToString:@"flv"] ||               
               [ext isEqualToString:@"vob"]) {
        
        type =  FileDescTypeVideo;
        
    } else if ([ext isEqualToString:@"m4v"] ||
               [ext isEqualToString:@"3gp"] ||
               [ext isEqualToString:@"mp4"] ||
               [ext isEqualToString:@"mov"]) {
        
        type =  FileDescTypeVideoLegacy;
    
    } else if ([ext isEqualToString:@"pdf"]) {
            
        type = FileDescTypePDF;
        
    } else if ([ext isEqualToString:@"html"]){
        
        type = FileDescTypeHTML;
        
    } else if ([ext isEqualToString:@"txt"] ||
               [ext isEqualToString:@""]) {
        
        type =  FileDescTypeTXT;
        
    /*
    } else if ([ext isEqualToString:@"zip"] ||
               [ext isEqualToString:@"gz"]) {
        
        type =  FileDescTypeArchive;
    */
        
    } else {
        
        type = FileDescTypeUnknown;
    }
    
    return type;
}

/////////////////////////////////////////////////////

@interface FileDesc : NSObject
@property (readwrite, nonatomic) NSString *name;
@property (readwrite, nonatomic) NSString *path;
@property (readwrite, nonatomic) FileDescType type;
@property (readwrite, nonatomic) UInt64 size;
@property (readwrite, nonatomic) NSDate *modified;


+ (id) fileDesc: (NSString *)path
     attributes: (NSDictionary *) attr;

@end

@implementation FileDesc

+ (id) fileDesc: (NSString *)path
     attributes: (NSDictionary *) attr
{
    FileDesc *fd = [[FileDesc alloc] init];
    
    id fileType = [attr objectForKey:NSFileType];

    if ([fileType isEqual: NSFileTypeDirectory]) {
        
        fd.type = FileDescTypeFolder;
        
    } else if ([fileType isEqual: NSFileTypeRegular]) {

        fd.size = [[attr objectForKey:NSFileSize] unsignedLongLongValue];
        fd.type = fd.size > 0 ? fileDescTypeFromFileExtension(path) : FileDescTypeEmpty;
            
    } else  {
        
        return nil;
    }
    
    fd.path = path;
    fd.name = path.lastPathComponent;
    fd.modified = [attr objectForKey:NSFileModificationDate];
    
    return fd;
}

- (IBAction)exitbutton:(id)sender {
}

@end

/////////////////////////////////////////////////////
@interface FileBrowserViewController () <UITableViewDataSource,UITableViewDelegate,QLPreviewControllerDataSource> {
    
    NSMutableArray              *_files;
    FileBrowserViewController   *_childVC;
//    ImageViewController         *_imageViewController;
//    TextViewController          *_textViewController;
}
@property (weak, nonatomic) IBOutlet UIButton *closebutton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@end


@implementation FileBrowserViewController

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
    if(!self.tableView){
        self.tableView = [UITableView new];
    }
    if(!self.path)
    {
        _closebutton.hidden = YES;
        NSString *sandboxdocpath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)lastObject];
        NSString *folder = [NSString stringWithFormat:@"%@/%@",sandboxdocpath,@"files"];
        self.path = folder;
    }
    _files = [NSMutableArray new];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSError *error;
    
    if (![fm fileExistsAtPath:self.path])
    {
        [fm createDirectoryAtPath:self.path withIntermediateDirectories:YES attributes:nil error:&error];
    }
    [self reloadFiles];
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
}


#pragma mark - private

- (void) reloadFiles
{
    [_files removeAllObjects];
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    NSArray *contents = [fm contentsOfDirectoryAtPath:self.path error:&error];
    
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
        
        if ([filename length] > 0 &&
            [filename characterAtIndex:0] != '.') {
            
            NSString *path = [self.path stringByAppendingPathComponent:filename];
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr) {
                FileDesc *fd = [FileDesc fileDesc:path attributes:attr];
                if (fd)
                    [_files addObject:fd];
            }
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    FileDesc *fd = _files[indexPath.row];
    
    if (fd.type == FileDescTypeFolder) {
    
        cell = [self mkCell: @"FolderCell" withStyle:UITableViewCellStyleSubtitle];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else {
    
        cell = [self mkCell: @"FileCell" withStyle:UITableViewCellStyleSubtitle];
    }
    
    UIImage *image;    
    switch (fd.type) {
        case FileDescTypeUnknown:
            image = [UIImage imageNamed:@"fileimages/unknown"];
            break;
            
        case FileDescTypeEmpty:
            image = [UIImage imageNamed:@"fileimages/empty"];
            break;
            
        case FileDescTypeFolder:
            image = [UIImage imageNamed:@"fileimages/folder"];
            break;
            
        case FileDescTypeAudio:
        case FileDescTypeAudioLegacy:
            image = [UIImage imageNamed:@"fileimages/music"];
            break;
            
        case FileDescTypeVideo:
        case FileDescTypeVideoLegacy:
            image = [UIImage imageNamed:@"fileimages/movie"];            
            break;
            
        case FileDescTypeImage:
            image = [UIImage imageNamed:@"fileimages/picture"];
            break;
            
        case FileDescTypeTorrent:
            image = [UIImage imageNamed:@"fileimages/download"];
            break;
            
        case FileDescTypePDF:
        case FileDescTypeHTML:
        case FileDescTypeTXT:
            image = [UIImage imageNamed:@"fileimages/text"];
            break;
    }

    cell.imageView.image = image;
    cell.textLabel.text = fd.name;
    cell.detailTextLabel.text = [NSString stringWithFormat: @"%@ %@",
                                 fd.type == FileDescTypeFolder ? @"--" : scaleSizeToStringWithUnit(fd.size),
                                 fd.modified.dateTimeFormatted];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (id) mkCell: (NSString *) cellIdentifier
    withStyle: (UITableViewCellStyle) style
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        
        ColorTheme *theme = [ColorTheme theme];
        
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:cellIdentifier];
        cell.backgroundColor = theme.backgroundColor;
        cell.textLabel.textColor = theme.textColor;
        
        if (style == UITableViewCellStyleValue1 ||
            style == UITableViewCellStyleValue2) {
            
            cell.detailTextLabel.textColor = theme.altTextColor;
            
        } else if (style == UITableViewCellStyleSubtitle) {
            
            cell.detailTextLabel.textColor = theme.grayedTextColor;
        }
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
    FileDesc *fd = _files[indexPath.row];
    if (fd.type == FileDescTypeFolder) {
        
        if (!_childVC)
        {
            UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
            _childVC = [storyBoard instantiateViewControllerWithIdentifier:@"fileVC"];
        }
        _childVC.path = [_path stringByAppendingPathComponent:fd.name];
        [self presentViewController:_childVC animated:NO completion:nil];
        _childVC = nil;
        
    } else if (fd.type == FileDescTypeTorrent) {
        
//        UIActionSheetOpenTorrent *actionSheet;
//        actionSheet = [[UIActionSheetOpenTorrent alloc] initWithTitle:@"Open torrent?"
//                                                             delegate:self
//                                                    cancelButtonTitle:@"Cancel"
//                                               destructiveButtonTitle:@"Open"
//                                                    otherButtonTitles:nil];
//        actionSheet.filePath = fd.path;
//        [actionSheet showFromTabBar:self.tabBarController.tabBar];
        
    } else if (fd.type == FileDescTypeVideoLegacy ||
               fd.type == FileDescTypeAudioLegacy) {
        
        self.fileURL = [NSURL fileURLWithPath:fd.path isDirectory:NO];
        MPMoviePlayerViewController *player = [[MPMoviePlayerViewController alloc] initWithContentURL: self.fileURL];
        [self presentMoviePlayerViewControllerAnimated:player];
        
    } else if (fd.type == FileDescTypeVideo ||
               fd.type == FileDescTypeAudio) {

        UIViewController *vc = [KxMovieViewController movieViewControllerWithContentPath:fd.path];
        [self presentViewController:vc animated:YES completion:nil];
    
    } else if (fd.type == FileDescTypeImage) {
        
//        if (!_imageViewController)
//            _imageViewController = [[ImageViewController alloc] init];
//        _imageViewController.path = fd.path;
//         [self.navigationController pushViewController:_imageViewController animated:YES];
        
    } else if (fd.type == FileDescTypeHTML ||
               fd.type == FileDescTypePDF ||
               fd.type == FileDescTypeTXT) {
        QLPreviewController *previewController  =  [[QLPreviewController alloc]  init];
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        previewController.dataSource  = self;
        self.fileURL = [NSURL fileURLWithPath:fd.path isDirectory:NO];
        [self presentViewController:previewController animated:YES completion:nil];
        //刷新界面,如果不刷新的话，不重新走一遍代理方法，返回的url还是上一次的url
        [previewController refreshCurrentPreviewItem];
    }
}

#pragma mark - QLPreviewControllerDataSource
-(id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return self.fileURL;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)previewController{
    return 1;
}

- (IBAction)unwindSegueToRedViewController:(UIStoryboardSegue *)segue {
    
}
@end
