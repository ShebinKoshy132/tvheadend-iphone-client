//
//  TVHTagStore.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/9/13.
//  Copyright 2013 Luis Fernandes
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "TVHTagStore.h"
#import "TVHSettings.h"
#import "TVHServer.h"

@interface TVHTagStore()
@property (nonatomic, weak) TVHServer *tvhServer;
@property (nonatomic, strong) TVHJsonClient *jsonClient;
@property (nonatomic, strong) NSArray *tags;
@property (nonatomic, weak) id <TVHTagStoreDelegate> delegate;
@property (nonatomic, strong) NSDate *profilingDate;
@end


@implementation TVHTagStore

- (id)initWithTvhServer:(TVHServer*)tvhServer {
    self = [super init];
    if (!self) return nil;
    self.tvhServer = tvhServer;
    self.jsonClient = [self.tvhServer jsonClient];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetTagStore)
                                                 name:@"resetAllObjects"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fetchTagList)
                                                 name:@"channeltagsNotificationClassReceived"
                                               object:nil];

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.tags = nil;
}

- (void)fetchedData:(NSData *)responseData {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingTagStore:)]) {
            [self.delegate didErrorLoadingTagStore:error];
        }
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *tags = [[NSMutableArray alloc] init];
    
    for (id entry in entries) {
        NSInteger enabled = [[entry objectForKey:@"enabled"] intValue];
        if( enabled ) {
            TVHTag *tag = [[TVHTag alloc] init];
            [tag updateValuesFromDictionary:entry];
            [tags addObject:tag];
        }
    }
     
    NSMutableArray *orderedTags = [[tags sortedArrayUsingSelector:@selector(compareByName:)] mutableCopy];
    
    // All channels
    TVHTag *t = [[TVHTag alloc] initWithAllChannels];
    [orderedTags insertObject:t atIndex:0];
    
    self.tags = [orderedTags copy];
#ifdef TESTING
    NSLog(@"[Loaded Tags]: %d", [self.tags count]);
#endif
}

- (void)fetchTagList {
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"get", @"op", @"channeltags", @"table", nil];
    self.profilingDate = [NSDate date];
    [self.jsonClient postPath:@"/tablemgr" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:self.profilingDate];
#ifdef TVH_GOOGLEANALYTICS_KEY
        [[GAI sharedInstance].defaultTracker sendTimingWithCategory:@"Network Profiling"
                                                          withValue:time
                                                           withName:@"TagStore"
                                                          withLabel:nil];
#endif
#ifdef TESTING
        NSLog(@"[TagStore Profiling Network]: %f", time);
#endif
        [self fetchedData:responseObject];
        if ([self.delegate respondsToSelector:@selector(didLoadTags)]) {
            [self.delegate didLoadTags];
        }
        
        //NSString *responseStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        //NSLog(@"Request Successful, response '%@'", responseStr);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingTagStore:)]) {
            [self.delegate didErrorLoadingTagStore:error];
        }
        NSLog(@"[TagList HTTPClient Error]: %@", error.description);
    }];
}

- (void)resetTagStore {
    self.tags = nil;
    self.profilingDate = nil;
}


- (void)setDelegate:(id <TVHTagStoreDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

@end
