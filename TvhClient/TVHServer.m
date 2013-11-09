//
//  TVHServer.m
//  TvhClient
//
//  Created by zipleen on 16/05/2013.
//  Copyright (c) 2013 zipleen. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import "TVHServer.h"

@interface TVHServer() {
    BOOL inProcessing;
}
@property (strong, nonatomic) NSTimer *timer;
@end

@implementation TVHServer 

- (void)appWillResignActive:(NSNotification*)note {
    [self.timer invalidate];
}

- (void)appWillEnterForeground:(NSNotification*)note {
    [self processTimerEvents];
    [self startTimer];
}

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(processTimerEvents) userInfo:nil repeats:YES];
}

- (void)processTimerEvents {
    if ( ! inProcessing ) {
        inProcessing = YES;
        [self.channelStore updateChannelsProgress];
        inProcessing = NO;
    }
}

- (TVHServer*)initVersion:(NSString*)version {
    self = [super init];
    if (self) {
        inProcessing = NO;
        [self setVersion:version];
        [self.tagStore fetchTagList];
        [self.channelStore fetchChannelList];
        [self.statusStore fetchStatusSubscriptions];
        [self.adapterStore fetchAdapters];
        [self logStore];
        [self fetchServerVersion];
        if ( [self.version isEqualToString:@"34"] ) {
            [self fetchCapabilities];
        }
        [self.configNameStore fetchConfigNames];
        [self fetchConfigSettings];
        [self cometStore];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [self startTimer];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (TVHTagStore*)tagStore {
    if( ! _tagStore ) {
        _tagStore = [[TVHTagStore alloc] initWithTvhServer:self];
    }
    return _tagStore;
}

- (TVHChannelStore*)channelStore {
    if( ! _channelStore ) {
        _channelStore = [[TVHChannelStore alloc] initWithTvhServer:self];
    }
    return _channelStore;
}

- (id <TVHDvrStore>)dvrStore {
    if( ! _dvrStore ) {
        Class myClass = NSClassFromString([@"TVHDvrStore" stringByAppendingString:self.version]);
        _dvrStore = [[myClass alloc] initWithTvhServer:self];
    }
    return _dvrStore;
}

- (TVHAutoRecStore*)autorecStore {
    if( ! _autorecStore ) {
        _autorecStore = [[TVHAutoRecStore alloc] initWithTvhServer:self];
    }
    return _autorecStore;
}

- (TVHStatusSubscriptionsStore*)statusStore {
    if( ! _statusStore ) {
        _statusStore = [[TVHStatusSubscriptionsStore alloc] initWithTvhServer:self];
    }
    return _statusStore;
}

- (TVHAdaptersStore*)adapterStore {
    if( ! _adapterStore ) {
        _adapterStore = [[TVHAdaptersStore alloc] initWithTvhServer:self];
    }
    return _adapterStore;
}

- (TVHLogStore*)logStore {
    if( ! _logStore ) {
        _logStore = [[TVHLogStore alloc] init];
    }
    return _logStore;
}

- (TVHCometPollStore*)cometStore {
    if( ! _cometStore ) {
        _cometStore = [[TVHCometPollStore alloc] initWithTvhServer:self];
        if ( [[TVHSettings sharedInstance] autoStartPolling] ) {
            [_cometStore startRefreshingCometPoll];
        }
    }
    return _cometStore;
}

- (TVHJsonClient*)jsonClient {
    if( ! _jsonClient ) {
        _jsonClient = [[TVHJsonClient alloc] init];
    }
    return _jsonClient;
}

- (TVHConfigNameStore*)configNameStore {
    if( ! _configNameStore ) {
        _configNameStore = [[TVHConfigNameStore alloc] initWithTvhServer:self];
    }
    return _configNameStore;
}

- (NSString*)version {
    if ( _version ) {
        int ver = [_version intValue];
        if ( ver >= 30 && ver <= 32 ) {
            return @"32";
        }
    }
    return @"34";
}

- (void)handleFetchedServerVersion:(NSString*)response {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<title>HTS Tvheadend (.*?)</title>" options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *versionRange = [regex firstMatchInString:response
                                                           options:0
                                                             range:NSMakeRange(0, [response length])];
    if ( versionRange ) {
        NSString *versionString = [response substringWithRange:[versionRange rangeAtIndex:1]];
        _realVersion = versionString;
        [TVHDebugLytics setObjectValue:_realVersion forKey:@"realVersion"];
        versionString = [versionString stringByReplacingOccurrencesOfString:@"." withString:@""];
        if ([versionString length] > 1) {
            self.version = [versionString substringWithRange:NSMakeRange(0, 2)];
#ifdef TESTING
            NSLog(@"[TVHServer getVersion]: %@", self.version);
#endif
            [TVHDebugLytics setObjectValue:self.version forKey:@"version"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"didLoadTVHVersion"
                                                                object:self];
        }
    }
}

- (void)fetchServerVersion {
    
    [self.jsonClient getPath:@"extjs.html" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *response = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        [self handleFetchedServerVersion:response];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"[TVHServer getVersion]: %@", error.localizedDescription);
    }];
}

- (void)fetchCapabilities {
    [self.jsonClient getPath:@"capabilities" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSError *error;
        NSArray *json = [TVHJsonClient convertFromJsonToArray:responseObject error:&error];
        if( error ) {
            NSLog(@"[TVHServer fetchCapabilities]: error %@", error.description);
            return ;
        }
        _capabilities = json;
#ifdef TESTING
        NSLog(@"[TVHServer capabilities]: %@", _capabilities);
#endif
        [TVHDebugLytics setObjectValue:_capabilities forKey:@"server.capabilities"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"didLoadTVHCapabilities"
                                                            object:self];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"[TVHServer capabilities]: %@", error.localizedDescription);
    }];

}

- (void)fetchConfigSettings {
    [self.jsonClient getPath:@"config" parameters:@{@"op":@"loadSettings"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSError *error;
        NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseObject error:&error];
        
        if( error ) {
            NSLog(@"[TVHServer fetchConfigSettings]: error %@", error.description);
            return ;
        }
        
        NSArray *entries = [json objectForKey:@"config"];
        NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
        
        [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [config setValue:obj forKey:key];
            }];
        }];
        
        self.configSettings = [config copy];
#ifdef TESTING
        NSLog(@"[TVHServer configSettings]: %@", self.configSettings);
#endif
        [TVHDebugLytics setObjectValue:self.configSettings forKey:@"server.configSettings"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"didLoadTVHConfigSettings"
                                                            object:self];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"[TVHServer capabilities]: %@", error.localizedDescription);
    }];
    
}

- (BOOL)isTranscodingCapable {
    if ( self.capabilities ) {
        NSInteger idx = [self.capabilities indexOfObject:@"transcoding"];
        if ( idx != NSNotFound ) {
            // check config settings now
            NSNumber *transcodingEnabled = [self.configSettings objectForKey:@"transcoding_enabled"];
            if ( [transcodingEnabled integerValue] == 1 ) {
                return true;
            }
        }
    }
    return false;
}

- (NSString*)htspUrl {
    TVHSettings *settings = [TVHSettings sharedInstance];
    NSString *userAndPass = @"";
    if ( ![[settings username] isEqualToString:@""] ) {
        userAndPass = [NSString stringWithFormat:@"%@:%@@", [settings username], [settings password]];
    }
    return [NSString stringWithFormat:@"htsp://%@%@:%@", userAndPass, [settings ipForCurrentServer], [settings htspPortForCurrentServer]];
}

- (void)resetData {
    [self.timer invalidate];
    self.timer = nil;
    
    self.jsonClient = nil;
    self.tagStore = nil;
    self.channelStore = nil;
    self.dvrStore = nil;
    self.autorecStore = nil;
    self.statusStore = nil;
    self.adapterStore = nil;
    self.cometStore = nil;
    self.configNameStore = nil;
    self.capabilities = nil;
    self.version = nil;
    self.realVersion = nil;
    self.configSettings = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
