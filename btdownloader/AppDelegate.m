//
//  AppDelegate.m
//  btdownloader
//
//  Created by 陈越 on 2022/8/29.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // check first run
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
    NSNumber *n = [userDefaults objectForKey:@"firstRun"];
    if (!n || !n.boolValue)
    {
        [userDefaults setBool:YES forKey:@"firstRun"];
        [userDefaults synchronize];

        NSString *srcFolder = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"torrents"];
        NSString *sandboxdocpath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)lastObject];
        NSString *destFolder = [sandboxdocpath stringByAppendingPathComponent:@"torrents"];
        NSFileManager *fm = [[NSFileManager alloc] init];
        NSError *error = nil;
        if (![fm fileExistsAtPath:destFolder])
        {
            [fm createDirectoryAtPath:destFolder withIntermediateDirectories:YES attributes:nil error:&error];
        }
        NSArray *contents = [fm contentsOfDirectoryAtPath:srcFolder error:&error];
        if (error) {
            NSLog(@"file error %@", error);
        }else{
            for (NSString *filename in contents) {
                if (filename.length &&
                    [filename characterAtIndex:0] != '.') {
                    NSString *from = [srcFolder stringByAppendingPathComponent:filename];
                    NSString *to = [destFolder stringByAppendingPathComponent:filename];
                    if (![fm copyItemAtPath:from toPath:to error:&error]) {
                        NSLog(@"file error %@", error);
                    }
                }
        }
        }
    }
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

@end
