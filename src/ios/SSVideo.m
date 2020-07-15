#import "SSVideo.h"
#import <Cordova/CDVPlugin.h>
#import "SmiSdk.h"
#import "AppDelegate+datami.h"

/// Uma UIViewController que aceita uma closure na hora de dismiss. Útil pra limpar recursos, que é o que faremos em breve
@interface HelperViewController : UIViewController {
    
}
@property (nonatomic, copy) void (^onDismiss)(void);
@end

@implementation HelperViewController

- (void)viewDidDisappear:(BOOL)animated {
    if (self.onDismiss) { // sei que é obj-c, mas né
        self.onDismiss();
    }
    [super viewDidDisappear:animated];
}

@end

@interface SSVideo()
@property (nonatomic, strong) AVPlayer *mainPlayer;
@property (nonatomic, strong) AVPlayerViewController *currentPlayerController;
@property (nonatomic, strong) HelperViewController *presentationController;

@property (nonatomic) float positionInSeconds;
@property (nonatomic) float percentage;

/// atualizo tempo com o que vem no JS?
@property (nonatomic) bool needTimeAdjustement;
@property (nonatomic, strong) id periodicTimer;

@property (nonatomic, strong)CDVInvokedUrlCommand *lastCommand;

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

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.mainPlayer) {
        AVPlayerItem *item = self.mainPlayer.currentItem;
        if (item.status == AVPlayerItemStatusReadyToPlay && self.needTimeAdjustement) {
            self.needTimeAdjustement = false;
            if (self.positionInSeconds > 0) {
                [item seekToTime:CMTimeMakeWithSeconds(self.positionInSeconds, 1)];
            } else {
                [item seekToTime:CMTimeMakeWithSeconds(CMTimeGetSeconds(item.duration) * self.percentage, 1)];
            }
            // time to move
        }
    }
}

- (AVPlayerViewController *) createPlayerForUrl:(NSURL *)url {
    AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
    
    AVPlayer *player = [[AVPlayer alloc] initWithURL:url];
    
    [player addObserver:self forKeyPath:@"currentItem.status" options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:nil];
    
    __weak SSVideo *me = self;
    
    self.periodicTimer = [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:NULL usingBlock:^(CMTime time) {
        [me sendDataToJS:false];
    }];
    
    if (@available(iOS 12.0, *)) {
        vc.player.preventsDisplaySleepDuringVideoPlayback = true;
    }

    self.mainPlayer = player;
    vc.player = player;
    return vc;
}

- (void) sendDataToJS:(bool) done {
    float time = CMTimeGetSeconds(self.mainPlayer.currentTime);
    if (isnan(time)) {
        time = 0.0;
    }
    
    float percentage = 0.0;
    float duration = CMTimeGetSeconds(self.mainPlayer.currentItem.duration);
    if (isnan(duration)) {
        duration = 0.0;
    }
    
    if (duration != 0.0) {
        percentage = time / duration;
    };
    
    NSDictionary *result = @{
        @"percentage": [NSNumber numberWithFloat:percentage],
        @"time": [NSNumber numberWithFloat:time],
        @"duration": [NSNumber numberWithFloat:duration],
        @"done": [NSNumber numberWithBool:done]
    };
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                  messageAsDictionary:result];
    [pluginResult setKeepCallback:@YES];
    
    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:self.lastCommand.callbackId];

}

- (void) play:(CDVInvokedUrlCommand *)command {
    
    if (self.mainPlayer) { // ignore all commands while there's a player around.
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString* url = [command.arguments objectAtIndex:0];
    float positionInSeconds = [[command.arguments objectAtIndex:2] floatValue];
    float percentage = [[command.arguments objectAtIndex:1] floatValue];
    
    if (url != nil && [url length] > 0) {
        self.positionInSeconds = positionInSeconds;
        self.percentage = percentage;
        self.needTimeAdjustement = true;
        self.lastCommand = command;

//          pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
//        [pluginResult setKeepCallbackAsBool:TRUE];
        
        [self.commandDelegate runInBackground:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                __weak SSVideo *me = self;
                
                self.currentPlayerController = [self createPlayerForUrl:[self sponsored:url]];
                AVPlayer *player = self.mainPlayer;
                
                self.presentationController = [[HelperViewController alloc] init];
                self.presentationController.onDismiss = ^{
                    [me sendDataToJS:true];
                    
                    [player pause];
                    
                    if (player == me.currentPlayerController.player) {
                        [player removeTimeObserver:me.periodicTimer];
                        [player removeObserver:me forKeyPath:@"currentItem.status"];
                    } else {
                        NSLog(@"probably leaking time observer");
                    }
                    
                    me.currentPlayerController = nil;
                    me.presentationController = nil;
                    me.mainPlayer = nil;
                };
                
                [self.presentationController.view addSubview:self.currentPlayerController.view];
                [self.presentationController addChildViewController:self.currentPlayerController];
                                
                [self.viewController presentViewController:self.presentationController animated:true completion:^{
                    [player play];
                }];
            });
//            for (int i = 0; i < 10; i ++) {
//                NSString* payload = [NSString stringWithFormat:@"TIMER :%d", i];
//                // Some blocking logic...
//                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:payload];
//                [pluginResult setKeepCallback:@YES];
//                // The sendPluginResult method is thread-safe.
//                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//
//                sleep(2);
//            }
        }];
        
    }
}

@end
