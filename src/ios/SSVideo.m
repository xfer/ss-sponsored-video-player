#import "SSVideo.h"
#import <Cordova/CDVPlugin.h>
#import "SmiSdk.h"
#import "AppDelegate+datami.h"

@interface HelperViewController : UIViewController {
    
}
@end

@implementation HelperViewController

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    [super dismissViewControllerAnimated:flag
                              completion:completion];
}

@end

@interface SSVideo()
@property (nonatomic, strong) AVPlayerViewController *currentPlayer;
@property (nonatomic, strong) HelperViewController *presentationController;
@end

@implementation SSVideo

- (NSURL *) sponsored:(NSString *)url {
    AppDelegate *app = UIApplication.sharedApplication.delegate;
    SmiResult *result = [SmiSdk getSDAuth:app.apiKey url:url userId:@""];
    if (result.url) {
        return [NSURL URLWithString:result.url];
    } else {
        return [NSURL URLWithString:url];
    }
}

- (AVPlayerViewController *) createPlayerForUrl:(NSURL *)url {
    AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
    if (@available(iOS 11.0, *)) {
        vc.entersFullScreenWhenPlaybackBegins = true;
    
    }
    
    AVPlayer *player = [[AVPlayer alloc] initWithURL:url];
    vc.player = player;
    if (@available(iOS 12.0, *)) {
        vc.player.preventsDisplaySleepDuringVideoPlayback = true;
    }
    
    return vc;
}

- (void) play:(CDVInvokedUrlCommand *)command {
    CDVPluginResult* pluginResult = nil;
    NSString* parameter = [command.arguments objectAtIndex:0];
    if (parameter != nil && [parameter length] > 0) {
//          pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
//        [pluginResult setKeepCallbackAsBool:TRUE];
        
        [self.commandDelegate runInBackground:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.currentPlayer = [self createPlayerForUrl:[self sponsored:parameter]];
                AVPlayer *player = self.currentPlayer.player;
                
                self.presentationController = [[HelperViewController alloc] init];
                
                [self.presentationController.view addSubview:self.currentPlayer.view];
                [self.presentationController addChildViewController:self.currentPlayer];
                                
                [self.viewController presentViewController:self.presentationController animated:true completion:^{
                    [player play];
                    NSLog(@"Duration : %f", CMTimeGetSeconds(player.currentItem.duration));
                }];
                
                
            });
            for (int i = 0; i < 10; i ++) {
                NSString* payload = [NSString stringWithFormat:@"TIMER :%d", i];
                // Some blocking logic...
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:payload];
                [pluginResult setKeepCallback:@YES];
                // The sendPluginResult method is thread-safe.
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                
                sleep(2);
            }
        }];
        
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

//    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
