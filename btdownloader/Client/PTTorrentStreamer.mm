

#import "PTTorrentStreamer.h"
#import <Foundation/Foundation.h>
#import <string>
#import <libtorrent/alert.hpp>
#import <libtorrent/alert_types.hpp>
#import <libtorrent/bencode.hpp>
#import "CocoaSecurity.h"
#import "PTTorrentStreamer+Protected.h"
#import <UIKit/UIApplication.h>
#import "PTSize.h"

#define ALERTS_LOOP_WAIT_MILLIS 500
#define PIECE_DEADLINE_MILLIS 100
#define LIBTORRENT_PRIORITY_SKIP 0
#define LIBTORRENT_PRIORITY_MAXIMUM 7

int MIN_PIECES = 0, selectedFileIndex = -1; //they are calculated by divind the 5% of a torrent file size with the size of a torrent piece / selected file in case we load a multi movie torrent
bool shouldUserSelectFiles = FALSE;

NSNotificationName const PTTorrentStatusDidChangeNotification = @"com.popcorntimetv.popcorntorrent.status.change";


using namespace libtorrent;

@implementation PTTorrentStreamer

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupSession];
    }
    return self;
}

- (NSString *)fileName {
    return _fileName;
}

- (NSString *)savePath {
    return _savePath;
}

- (PTTorrentStatus)torrentStatus {
    return _torrentStatus;
}

- (PTSize *)fileSize {
    return [PTSize sizeWithLongLong:_requiredSpace];
}

- (PTSize *)totalDownloaded {
    return [PTSize sizeWithLongLong:_totalDownloaded];
}


+ (NSString *)downloadDirectory {
    NSString *sandboxdocpath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)lastObject];
    NSString *downloadDirectory = [NSString stringWithFormat:@"%@/%@",sandboxdocpath,@"files"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:downloadDirectory]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:downloadDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) return nil;
    }
    
    return downloadDirectory;
}

- (void)setupSession {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    error_code ec;
    
    firstPiece = -1;
    endPiece = 0;
    
    _session = new session();
    _session->listen_on(std::make_pair(6881, 6889), ec);
    
    NSAssert(ec.failed() == false, @"FATAL ERROR: Failed to open listen socket: %s", ec.message().c_str());
    settings_pack pack = default_settings();
    pack.set_int(settings_pack::alert_mask, alert::status_notification |
                 alert::piece_progress_notification |
                 alert::storage_notification);
    pack.set_bool(settings_pack::listen_system_port_fallback, false);
    pack.set_bool(settings_pack::use_read_cache, false);
    // libtorrent 1.1 enables UPnP & NAT-PMP by default
    // turn them off before `libt::session` ctor to avoid split second effects
    pack.set_bool(settings_pack::enable_upnp, false);
    pack.set_bool(settings_pack::enable_natpmp, false);
    pack.set_bool(settings_pack::upnp_ignore_nonrouters, true);
    pack.set_int(settings_pack::file_pool_size, 2);
    _session->apply_settings(pack);
    
    _requestedRangeInfo = [[NSMutableDictionary alloc] init];
    
    _status = torrent_status();
}

- (void)startStreamingFromFile:(NSString *)filePathOrMagnetLink
                      progress:(PTTorrentStreamerProgress)progress
                   readyToPlay:(PTTorrentStreamerReadyToPlay)readyToPlay
                       failure:(PTTorrentStreamerFailure)failure {
    [self startStreamingFromFile:filePathOrMagnetLink
                   directoryName:nil
                        progress:progress
                     readyToPlay:readyToPlay
                         failure:failure];
    
}

- (void)startStreamingFromMultiTorrentFile:(NSString *)filePathOrMagnetLink
                                  progress:(PTTorrentStreamerProgress)progress
                               readyToPlay:(PTTorrentStreamerReadyToPlay)readyToPlay
                                   failure:(PTTorrentStreamerFailure)failure
                                    selectFileToStream:(PTTorrentStreamerSelection)callback{
    shouldUserSelectFiles = TRUE;
    self.selectionBlock = callback;
    [self startStreamingFromFile:filePathOrMagnetLink
                   directoryName:nil
                        progress:progress
                     readyToPlay:readyToPlay
                         failure:failure];
    
}


- (void)startStreamingFromFile:(NSString *)filePathOrMagnetLink
                 directoryName:(NSString * _Nullable)directoryName
                      progress:(PTTorrentStreamerProgress)progress
                   readyToPlay:(PTTorrentStreamerReadyToPlay)readyToPlay
                       failure:(PTTorrentStreamerFailure)failure {
    self.progressBlock = progress;
    self.readyToPlayBlock = readyToPlay;
    self.failureBlock = failure;
    
    
    self.alertsLoopActive = YES;
    // 后台播放静音音频保活
    NSString *soundFilePath = [[NSBundle mainBundle]    pathForResource:@"mute"   ofType:@"caf"];
    NSURL *url = [NSURL fileURLWithPath:soundFilePath];
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    if (!_audioPlayer)
        NSLog(@"error");
    _audioPlayer.numberOfLoops = -1; //设置音乐播放次数  -1为一直循环
    [_audioPlayer  prepareToPlay];
    [_audioPlayer   setDelegate:self];
    [_audioPlayer   play];
    NSTimer *preventSleepTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                                              interval:1.0
                                                                target:self
                                                              selector:@selector(alertsLoop)
                                                              userInfo:nil
                                                               repeats:YES];
    self.preventSleepTimer = preventSleepTimer;
    // Add the timer to the current run loop.
    [[NSRunLoop currentRunLoop] addTimer:self.preventSleepTimer
                                     forMode:NSDefaultRunLoopMode];
    error_code ec;
    add_torrent_params tp;
    
    NSString *MD5String = nil;
    
    if ([filePathOrMagnetLink hasPrefix:@"magnet"]) {
        NSString *magnetLink = filePathOrMagnetLink;
        tp = parse_magnet_uri(std::string([magnetLink UTF8String]));//std::string([magnetLink UTF8String]);
        
        MD5String = [CocoaSecurity md5:magnetLink].hexLower;
    } else {
        NSString *filePath = filePathOrMagnetLink;
        NSError *error;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            NSData *fileData = [NSData dataWithContentsOfFile:filePath];
            MD5String = [CocoaSecurity md5WithData:fileData].hexLower;
            std::shared_ptr<torrent_info> ti1 = std::make_shared<torrent_info>([filePathOrMagnetLink UTF8String], ec);
            tp.ti = ti1;
            if (ec) {
                error = [[NSError alloc] initWithDomain:@"com.popcorntimetv.popcorntorrent.error" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithCString:ec.message().c_str() encoding:NSUTF8StringEncoding]}];
            }
            MIN_PIECES = ((tp.ti->file_at([self indexOfLargestFileInTorrentWithTorrentInfo:tp.ti]).size*0.03)/tp.ti->piece_length());
        } else {
            error = [[NSError alloc] initWithDomain:@"com.popcorntimetv.popcorntorrent.error" code:-2 userInfo:@{NSLocalizedDescriptionKey: [NSString localizedStringWithFormat:@"文件不存在于%@", filePath]}];
        }
        
        if (error) {
            if (failure)
                failure(error);
            return [self cancelStreamingAndDeleteData:NO];
        }
    }
    
    //construct the folder path for downloads
    NSString *pathComponent = directoryName != nil ? directoryName : [MD5String substringToIndex:16];
    
    NSString *basePath = [[self class] downloadDirectory];
    
    if (!basePath) {
        NSError *error = [NSError errorWithDomain:@"com.popcorntimetv.popcorntorrent.error" code:-412 userInfo:@{NSLocalizedDescriptionKey: @"无法创建下载目录"}];
        if (failure) failure(error);
        return [self cancelStreamingAndDeleteData:NO];
    }
    
    _savePath = [basePath stringByAppendingPathComponent:pathComponent];
    //create folder for torrents
    if (![[NSFileManager defaultManager] fileExistsAtPath:_savePath]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:self.savePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        //if we cannot create folder clear all data and exit
        if (error) {
            if (failure) failure(error);
            return [self cancelStreamingAndDeleteData:NO];
        }
    }else if([filePathOrMagnetLink hasPrefix:@"magnet"]){
        //if folder exists already and we are loading a magnet search for resume file
        NSData *resumeData = [NSData dataWithContentsOfFile:[_savePath stringByAppendingString:@"/resumeData.fastresume"] ];
        if (resumeData != nil){
            unsigned long int len = resumeData.length;
            //read resume file
            std::vector<char> resumeVector((char *)resumeData.bytes, (char *)resumeData.bytes + len);
            tp = read_resume_data(resumeVector, ec);//load it into the torrent
            if (ec) std::printf("  failed to load resume data: %s\n", ec.message().c_str());
        }
        ec.clear();
    }
    
    tp.save_path = std::string([self.savePath UTF8String]);
    tp.storage_mode = storage_mode_allocate;
    
    torrent_handle th = _session->add_torrent(tp, ec);
    th.set_sequential_download(true);
    th.set_max_connections(60);
    th.set_max_uploads(10);
    
    if (ec) {
        NSError *error = [[NSError alloc] initWithDomain:@"com.popcorntimetv.popcorntorrent.error" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithCString:ec.message().c_str() encoding:NSUTF8StringEncoding]}];
        if (failure) failure(error);
        return [self cancelStreamingAndDeleteData:NO];
    }
    
    if (![filePathOrMagnetLink hasPrefix:@"magnet"]) {
        [self metadataReceivedAlert:th];
    }
    
    if(_session->is_paused())
        _session->resume();
    
#if TARGET_OS_IOS
  dispatch_async(dispatch_get_main_queue(), ^{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
  });
#endif
}


#pragma mark - Fast Forward


- (BOOL)fastForwardTorrentForRange:(NSRange)range
{
    std::vector<torrent_handle> ths = _session->get_torrents();
    
    for(std::vector<torrent_handle>::size_type i = 0; i != ths.size(); i++) {
        std::shared_ptr<const torrent_info> ti = ths[i].torrent_file();
        
        //get all the pieces in the movie
        int totalTorrentPieces = ti->num_pieces();
        
        //find the torrent piece corresponding to the requested piece of the movie
        peer_request request = ti->map_file(selectedFileIndex != -1 ? selectedFileIndex : [self indexOfLargestFileInTorrent:ths[i]], range.location, (int)range.length);
        
        //set first and last pieces
        int startPiece = request.piece;
        int finalPiece = startPiece + MIN_PIECES - 1;
        
        NSLog(@"new startPiece: %d", startPiece);
        
        //check if we are over the total pieces of the torrent
        if (finalPiece > totalTorrentPieces) {
            finalPiece = totalTorrentPieces - 1;
        }
        
        //set global variables
        firstPiece = startPiece;
        endPiece = finalPiece;
        
        //if we already have the requested part of the movie return immediately
        for(int j=startPiece; j<=finalPiece;j++){
            if (!ths[i].have_piece(j)) {
                break;
            }else if(j==finalPiece){
                return YES;
            }
        }
        
        //take control of the array from all of the other threads that might be accessing it
        mtx.lock();
        required_pieces.clear(); //clear all the pieces we wanted to download previously
        mtx.unlock();
        
        //start to download the requested part of the movie
        [self prioritizeNextPieces:ths[i]];
    }
    
    return NO;
    
}


- (void)cancelStreamingAndDeleteData:(BOOL)deleteData {
    
    std::vector<torrent_handle> ths = _session->get_torrents();
    for(std::vector<torrent_handle>::size_type i = 0; i != ths.size(); i++) {
        ths[i].pause();
        if (!deleteData && ths[i].need_save_resume_data())
            ths[i].save_resume_data();
        ths[i].flush_cache();
        _session->pause();
        if (deleteData)_session->remove_torrent(ths[i]);
    }
    
    required_pieces.clear();
    required_pieces.shrink_to_fit();
    
    [self.requestedRangeInfo removeAllObjects];
    _status = torrent_status();
    
    self.progressBlock = nil;
    self.readyToPlayBlock = nil;
    self.failureBlock = nil;
    self.selectionBlock =  nil;
    selectedFileIndex = -1;
    
    _fileName = nil;
    _requiredSpace = 0;
    _totalDownloaded = 0;
    firstPiece = -1;
    endPiece = 0;
    
    self.streaming = NO;
    _torrentStatus = (PTTorrentStatus){0, 0, 0, 0, 0, 0};
    _isFinished = false;
    
#if TARGET_OS_IOS
  dispatch_async(dispatch_get_main_queue(), ^{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  });
#endif
    
    if (deleteData) {
        self.alertsQueue = nil;
        self.subThread = nil;
        [_audioPlayer stop];
        self.alertsLoopActive = NO;
        [self.preventSleepTimer invalidate];
        [[NSFileManager defaultManager] removeItemAtPath:self.savePath error:nil];
        _savePath = nil;
        _session->abort();
        _session = nil;
        [self setupSession];
    }
}


#pragma mark - Alerts Loop


- (void)alertsLoop {
    std::vector<alert *> deque;
    time_duration max_wait = milliseconds(ALERTS_LOOP_WAIT_MILLIS);
    
    if ([self isAlertsLoopActive]) {
        const alert *ptr = _session->wait_for_alert(max_wait);
        if (ptr != nullptr && _session != nullptr) {
            _session->pop_alerts(&deque);
            for (std::vector<alert *>::iterator it = deque.begin(); it != deque.end(); ++it) {
                std::auto_ptr<alert> alert(*it);
                switch (alert->type())
                {
                    case metadata_received_alert::alert_type:
                        [self metadataReceivedAlert:((metadata_received_alert *)alert.get())->handle];
                        break;
                        
                    case piece_finished_alert::alert_type:
                        [self pieceFinishedAlert:((piece_finished_alert *)alert.get())->handle forPieceIndex:((piece_finished_alert *)alert.get())->piece_index];
                        break;
                        // In case the video file is already fully downloaded
                    case torrent_finished_alert::alert_type:
                        [self torrentFinishedAlert:((torrent_finished_alert *)alert.get())->handle];
                        break;
                    case save_resume_data_alert::alert_type: {
                        torrent_status st = (((save_resume_data_alert *)alert.get())->handle).status(torrent_handle::query_save_path
                                                                                                     | torrent_handle::query_name);
                        [self resumeDataReadyAlertWithData:((save_resume_data_alert *)alert.get())->params andSaveDirectory:[NSString stringWithUTF8String:(st.save_path + "/resumeData.fastresume").c_str()]];
                        break;
                    }
                    case listen_succeeded_alert::alert_type: {

                    }
                    default:
                        break;
                }
                alert.release();
            }
            deque.clear();
            deque.shrink_to_fit();
        }
    }
}

- (void)prioritizeNextPieces:(torrent_handle)th {
    int next_required_piece = 0;
    
    if (firstPiece != -1) {
        next_required_piece = (int)firstPiece;
    } else {
        next_required_piece = required_pieces.size() >0 ? required_pieces[MIN_PIECES - 1] + 1 : 0;
    }
    
    firstPiece = -1;
    
    mtx.lock();
    
    required_pieces.clear();
    
    std::vector<int> piece_priorities = th.piece_priorities();
    std::shared_ptr<const torrent_info> ti = th.torrent_file();
    th.clear_piece_deadlines();//clear all deadlines on all pieces before we set new ones
    std::fill(piece_priorities.begin(), piece_priorities.end(), 1);
    
    for (int i = next_required_piece; i < next_required_piece + MIN_PIECES; i++) {
        if (i < ti->num_pieces()) {
            piece_priorities[i] = LIBTORRENT_PRIORITY_MAXIMUM;
            th.set_piece_deadline(i, PIECE_DEADLINE_MILLIS, torrent_handle::alert_when_available);
            required_pieces.push_back(i);
        }
    }
    th.prioritize_pieces(piece_priorities);
    mtx.unlock();
}

- (void)processTorrent:(torrent_handle)th {
    if ([self isStreaming]) return;
    
    self.streaming = YES;
    _status = th.status();
    
    std::shared_ptr<const torrent_info> ti = th.torrent_file();
    int file_index = selectedFileIndex != -1 ? selectedFileIndex : [self indexOfLargestFileInTorrent:th];
    file_entry fe = ti->file_at(file_index);
    std::string path = fe.path;
    _fileName = [NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding];

    if (self.readyToPlayBlock) {
        [self startWebServerAndPlay];
    }
}

- (void)startWebServerAndPlay {
    self.alertsLoopActive = false;
    [self.preventSleepTimer invalidate];
    NSString *filePath = [self.savePath stringByAppendingPathComponent:_fileName];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.readyToPlayBlock)
            self.readyToPlayBlock(filePath);
    });
}


- (int)indexOfLargestFileInTorrent:(torrent_handle)th {
    std::shared_ptr<const torrent_info> ti = th.torrent_file();
    return [self indexOfLargestFileInTorrentWithTorrentInfo:ti];
}

- (int)indexOfLargestFileInTorrentWithTorrentInfo:(std::shared_ptr<const torrent_info>)ti {
    if (shouldUserSelectFiles == TRUE){
        shouldUserSelectFiles = FALSE;
        if (selectedFileIndex != -1)return selectedFileIndex;
        auto files = ti->files();
        NSMutableArray* file_names = [[NSMutableArray alloc]init];
        for (int i=0; i<ti->num_files();i++)[file_names addObject:[NSString stringWithFormat:@"%s",files.file_name(i).to_string().c_str()]];
        selectedFileIndex = self.selectionBlock([file_names copy]);
        return selectedFileIndex;
    }
    int files_count = ti->num_files();
    if (files_count > 1) {
        int64_t largest_size = -1;
        int largest_file_index = -1;
        for (int i = 0; i < files_count; i++) {
            file_entry fe = ti->file_at(i);
            if (fe.size > largest_size) {
                largest_size = fe.size;
                largest_file_index = i;
            }
        }
        selectedFileIndex = largest_file_index;
        return largest_file_index;
    }
    return 0;
}

#pragma mark - Alerts

- (void)metadataReceivedAlert:(torrent_handle)th {
    
    _requiredSpace = th.status().total_wanted;
    NSURL* savePathURL = [NSURL fileURLWithPath:self.savePath];
    NSDictionary *results = [savePathURL resourceValuesForKeys:@[NSURLVolumeAvailableCapacityKey] error:nil];
    NSNumber *availableSpace = results[NSURLVolumeAvailableCapacityKey];//get available space on device
    
    if (_requiredSpace > availableSpace.longLongValue) {
        NSString *description = [NSString localizedStringWithFormat:@"手机缺乏足够的空间下载文件，请预留至少 %@ 并重试。", self.fileSize.stringValue];
        NSError *error = [[NSError alloc] initWithDomain:@"com.popcorntimetv.popcorntorrent.error" code:-4 userInfo:@{NSLocalizedDescriptionKey: description}];
        if (_failureBlock) _failureBlock(error);
        [self cancelStreamingAndDeleteData:NO];
        return;
    }
    
    int file_index = [self indexOfLargestFileInTorrent:th];
    
    std::vector<int> file_priorities = th.file_priorities();
    std::fill(file_priorities.begin(), file_priorities.end(), LIBTORRENT_PRIORITY_SKIP);
    file_priorities[file_index] = LIBTORRENT_PRIORITY_MAXIMUM;
    th.prioritize_files(file_priorities);
    
    std::shared_ptr<const torrent_info> ti = th.torrent_file();
    MIN_PIECES = ((ti->file_at(file_index).size*0.03)/ti->piece_length());
    int first_piece = ti->map_file(file_index, 0, 0).piece;
    for (int i = first_piece; i < first_piece + MIN_PIECES; i++) {
        required_pieces.push_back(i);
    }
    
    int64_t file_size = ti->file_at(file_index).size;
    int last_piece = ti->map_file(file_index, file_size - 1, 0).piece;
    for (int i = 0; i < 10; i++) {
        required_pieces.push_back(last_piece - i);
    }
    
    th.clear_piece_deadlines();
    std::vector<int> piece_priorities = th.piece_priorities();
    std::fill(piece_priorities.begin(), piece_priorities.end(), 1);
    th.prioritize_pieces(piece_priorities);
    for(std::vector<int>::size_type i = 0; i != required_pieces.size(); i++) {
        int piece = required_pieces[i];
        th.piece_priority(piece, LIBTORRENT_PRIORITY_MAXIMUM);
        th.set_piece_deadline(piece, PIECE_DEADLINE_MILLIS, torrent_handle::alert_when_available);
    }
    _status = th.status();
}

- (void)pieceFinishedAlert:(torrent_handle)th forPieceIndex:(int)index{
    _status = th.status();
    
    int requiredPiecesDownloaded = 0;
    BOOL allRequiredPiecesDownloaded = YES;
    
    auto copyRequired(required_pieces);
    
    for(std::vector<int>::size_type i = 0; i != copyRequired.size(); i++) {
        int piece = copyRequired[i];
        if(_session->is_paused())
            break;
        if (th.have_piece(piece) == false) {
            allRequiredPiecesDownloaded = NO;
        }else{
            requiredPiecesDownloaded++;
        }
    }
    
    int requiredPieces = (int)copyRequired.size();
    float bufferingProgress = 1.0 - (requiredPieces - requiredPiecesDownloaded)/(float)requiredPieces;
    _torrentStatus = {
        bufferingProgress,
        _status.progress,
        _status.download_rate,
        _status.upload_rate,
        _status.num_seeds,
        _status.num_peers,
        _status.total_wanted,
        _status.total_wanted_done,
    };
    
    _totalDownloaded = _status.total_wanted_done;
    _isFinished = _status.is_finished;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_progressBlock)
            _progressBlock(_torrentStatus);
        [[NSNotificationCenter defaultCenter] postNotificationName:PTTorrentStatusDidChangeNotification object:self];
    });
    
    
    
    if (allRequiredPiecesDownloaded) {
        if (MIN_PIECES == 0)[self metadataReceivedAlert:th];
        [self prioritizeNextPieces:th];
//        [self processTorrent:th];
    }
}

- (void)torrentFinishedAlert:(torrent_handle)th {
    [self processTorrent:th];
    
    _torrentStatus = {
        1, 1,
        _status.download_rate,
        _status.upload_rate,
        _status.num_seeds,
        _status.num_peers
    };
    
    _totalDownloaded = _status.total_wanted_done;
    _isFinished = _status.is_finished;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_progressBlock) _progressBlock(_torrentStatus);
        [[NSNotificationCenter defaultCenter] postNotificationName:PTTorrentStatusDidChangeNotification object:self];
    });
    
#if TARGET_OS_IOS
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    });
#endif
    
    // Remove the torrent when its finished
    th.pause(torrent_handle::graceful_pause);
    _session->remove_torrent(th);
}

- (void) resumeDataReadyAlertWithData:(add_torrent_params)resumeData andSaveDirectory:(NSString*)directory{
    self.alertsQueue = nil;
    self.subThread = nil;
    [_audioPlayer stop];
    self.alertsLoopActive = NO;
    _savePath = nil;
    std::vector<torrent_handle> ths = _session->get_torrents();
    for(std::vector<torrent_handle>::size_type i = 0; i != ths.size(); i++) {
        _session->remove_torrent(ths[i]);
    }

    auto const buf = write_resume_data_buf(resumeData);
    
    std::stringstream ss;
    ss.unsetf(std::ios_base::skipws);
    bencode(std::ostream_iterator<char>(ss), buf);
    
    NSData *resumeDataFile = [[NSData alloc] initWithBytesNoCopy:(void*)ss.str().c_str() length:ss.str().size() freeWhenDone:false];
    NSAssert(resumeDataFile != nil, @"Resume data failed to be generated");
    [resumeDataFile writeToFile:[NSURL URLWithString:directory].relativePath atomically:NO];
//    _session->abort();
//    _session = nil;
//    [self setupSession];
}

@end

