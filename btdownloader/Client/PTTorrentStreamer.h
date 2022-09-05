#import <Foundation/Foundation.h>
#import "PTTorrentStatus.h"

@class PTSize;

/**
 Block called when the status of the currently streamed torrent is called.
 
 @param status  The buffering progress of the current piece of the torrent, overall buffering of the torrent, the current download speed, the current upload speed, the amount of active seeds downloading from and the amount of peers connected to.
 */
typedef void (^PTTorrentStreamerProgress)(PTTorrentStatus status);

/**
 Block called when the first piece of the torrent has sufficiently buffered enough for streaming.
 
 @param videoFileURL    The `GCDWebServer` url that the torrent should be streamed from.
 @param videoFilePath   The local path to the video file. This should not be used for streaming.
 */
typedef void (^PTTorrentStreamerReadyToPlay)(NSString * _Nonnull filePath);

/**
 Block called if there is a fatal error processing the torrent.
 
 @param error    The underlying error.
 */
typedef void (^PTTorrentStreamerFailure)(NSError * _Nonnull error);

/**
 Block called when the torrent metadata have been downloaded and the user has to select the torrent to play
 
 @param torrentsAvailable  The available torrents names that the user can select from
 
 @return The index of the item in the array torrentsAvailable the user has selected
 */
typedef int (^PTTorrentStreamerSelection)(NSArray<NSString*> * _Nonnull torrentsAvailable);

NS_ASSUME_NONNULL_BEGIN

/**
 Posted when the status of the current Torrent changes finishes executing. Torrent status can be retrieved by accessing the `torrentStatus` variable of the posting object.
 */
FOUNDATION_EXPORT NSNotificationName const PTTorrentStatusDidChangeNotification;

/**
 A class that streams magnet links or `.torrent` files to a `GCDWebServer`.
 */
@interface PTTorrentStreamer : NSObject
/**
 The directory to which all torrents are saved. Defaults to `NSTemporaryDirectory`. Will return `nil` if there is an error creating the directory.
 */
+ (NSString * _Nullable)downloadDirectory;

/**
 Begins streaming of a torrent.
 
 @param filePathOrMagnetLink    The direct link of a locally stored `.torrent` file or a `magnet:?` link.
 @param progress                Block containing useful information about the torrent currently being streamed. Called every time the `torrentStatus` variable changes.
 @param readyToPlay             Block called when the torrent has finished processing and is ready to begin being played.
 @param failure                 Block called if there is an error while processing the torrent.
 @param callback                Block called when the torrent data are received and user needs to chose file to play
 */
- (void)startStreamingFromMultiTorrentFile:(NSString *)filePathOrMagnetLink
                                  progress:(PTTorrentStreamerProgress)progress
                               readyToPlay:(PTTorrentStreamerReadyToPlay)readyToPlay
                                   failure:(PTTorrentStreamerFailure)failure
                        selectFileToStream:(PTTorrentStreamerSelection)callback;

/**
 Begins streaming of a torrent.
 
 @param filePathOrMagnetLink    The direct link of a locally stored `.torrent` file or a `magnet:?` link.
 @param progress                Block containing useful information about the torrent currently being streamed. Called every time the `torrentStatus` variable changes.
 @param readyToPlay             Block called when the torrent has finished processing and is ready to begin being played.
 @param failure                 Block called if there is an error while processing the torrent.
*/
- (void)startStreamingFromFile:(NSString *)filePathOrMagnetLink
                      progress:(PTTorrentStreamerProgress _Nullable)progress
                   readyToPlay:(PTTorrentStreamerReadyToPlay _Nullable)readyToPlay
                       failure:(PTTorrentStreamerFailure _Nullable)failure;

/**
 Cancels loading of the current torrent and optionally clears the download directory.
 
 @param deleteData  Pass `YES` to clear the download directory, `NO` to keep the downloaded directory.
 */
- (void)cancelStreamingAndDeleteData:(BOOL)deleteData;
    
/**
 Status of the torrent that is currently streaming. Will return all 0 struct if no torrent is being streamed.
 */
@property (nonatomic, readonly) PTTorrentStatus torrentStatus;

/**
 The name of the torrent that is currently streaming. Will be `nil` if no torrent is being streamed or the currently streaming torrent has not been processed yet.
 */
@property (strong, nonatomic, readonly, nullable) NSString *fileName;

/**
 The size of the torrent that is currently streaming. Will be 0 if no torrent is being streamed or the currently streaming torrent has not been processed yet.
 */
@property (nonatomic, readonly, strong) PTSize *fileSize;

/**
 The total size of the torrent that has been downloaded. Will be 0 if no torrent is being streamed or the currently streaming torrent has not been processed yet.
 */
@property (nonatomic, readonly, strong) PTSize *totalDownloaded;

/**
 The local path to the torrent directory. Will be `nil` if no torrent is being streamed or if the torrent is still processing.
 */
@property (strong, nonatomic, readonly, nullable) NSString *savePath;

@end

NS_ASSUME_NONNULL_END
