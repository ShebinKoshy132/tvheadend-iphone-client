//
//  TVHStatusSubscriptionsStore.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/18/13.
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

#import "TVHStatusSubscriptionsStore.h"
#import "TVHServer.h"

@interface TVHStatusSubscriptionsStore()
@property (nonatomic, weak) TVHServer *tvhServer;
@property (nonatomic, strong) TVHJsonClient *jsonClient;
@property (nonatomic, strong) NSArray *subscriptions;
@property (nonatomic, weak) id <TVHStatusSubscriptionsDelegate> delegate;
@end

@implementation TVHStatusSubscriptionsStore

- (id)initWithTvhServer:(TVHServer*)tvhServer {
    self = [super init];
    if (!self) return nil;
    self.tvhServer = tvhServer;
    self.jsonClient = [self.tvhServer jsonClient];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveSubscriptionNotification:)
                                                 name:@"subscriptionsNotificationClassReceived"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetStatusSubscriptionsStore)
                                                 name:@"resetAllObjects"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fetchStatusSubscriptions)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.subscriptions = nil;
}

- (void)receiveSubscriptionNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"subscriptionsNotificationClassReceived"]) {
        NSDictionary *message = (NSDictionary*)[notification object];
        
        if ( [[message objectForKey:@"reload"] intValue] == 1 ) {
            [self fetchStatusSubscriptions];
        }
        
        [self.subscriptions enumerateObjectsUsingBlock:^(TVHStatusSubscription* obj, NSUInteger idx, BOOL *stop) {
            
            if ( obj.id == [[message objectForKey:@"id"] intValue] ) {
                [obj updateValuesFromDictionary:message];
            }
        }];
        
        if ( [self.delegate respondsToSelector:@selector(didLoadStatusSubscriptions)] ) {
            [self.delegate didLoadStatusSubscriptions];
        }
    }
}

- (void)resetStatusSubscriptionsStore {
    self.subscriptions = nil;
}

- (void)fetchedData:(NSData *)responseData {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorStatusSubscriptionsStore:)]) {
            [self.delegate didErrorStatusSubscriptionsStore:error];
        }
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *subscriptions = [[NSMutableArray alloc] init];
    
    [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TVHStatusSubscription *subscription = [[TVHStatusSubscription alloc] init];
        [subscription updateValuesFromDictionary:obj];
        
        [subscriptions addObject:subscription];
    }];
    
    self.subscriptions = [subscriptions copy];
    
#ifdef TESTING
    NSLog(@"[Loaded Subscription]: %d", [self.subscriptions count]);
#endif
}

- (void)fetchStatusSubscriptions {
    
    [self.jsonClient getPath:@"/subscriptions" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self fetchedData:responseObject];
        if ([self.delegate respondsToSelector:@selector(didLoadStatusSubscriptions)]) {
            [self.delegate didLoadStatusSubscriptions];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingTagStore:)]) {
            [self.delegate didErrorStatusSubscriptionsStore:error];
        }
        NSLog(@"[TagList HTTPClient Error]: %@", error.localizedDescription);
    }];
}

- (TVHStatusSubscription *) objectAtIndex:(int) row {
    if ( row < [self.subscriptions count] ) {
        return [self.subscriptions objectAtIndex:row];
    }
    return nil;
}

- (int) count {
    return [self.subscriptions count];
}


- (void)setDelegate:(id <TVHStatusSubscriptionsDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

@end
