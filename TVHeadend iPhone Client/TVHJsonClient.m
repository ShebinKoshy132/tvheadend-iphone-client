//
//  TVHJsonClient.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/22/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "TVHJsonClient.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "TVHSettings.h"
#import "AFJSONRequestOperation.h"
#import "SDURLCache.h"

@implementation TVHJsonClient

#pragma mark - Methods

- (void)setUsername:(NSString *)username password:(NSString *)password {
    [self clearAuthorizationHeader];
    [self setAuthorizationHeaderWithUsername:username password:password];
    /*
     // for future reference, MD5 DIGEST. tvheadend uses basic
    NSURLCredential *newCredential;
    newCredential = [NSURLCredential credentialWithUser:username
                                               password:password
                                            persistence:NSURLCredentialPersistenceForSession];
    [self setDefaultCredential:newCredential];
     */
}

#pragma mark - Initialization

- (id)init {
    TVHSettings *settings = [TVHSettings sharedInstance];
    self = [super initWithBaseURL:[settings baseURL]];
    if( !self ) {
        return nil;
    }
    
    NSString *username = [settings username];
    if( ![username isEqualToString:@""] ) {
        NSString *password = [settings password];
        [self setUsername:username password:password];
    }
    
    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    //[self setDefaultHeader:@"Accept" value:@"application/json"];
    //[self setParameterEncoding:AFJSONParameterEncoding];
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    SDURLCache *urlCache = [[SDURLCache alloc] initWithMemoryCapacity:1024*1024   // 1MB mem cache
                                                         diskCapacity:1024*1024*5 // 5MB disk cache
                                                             diskPath:[SDURLCache defaultCachePath]];
    [NSURLCache setSharedURLCache:urlCache];
    
    return self;
}


+ (TVHJsonClient*)sharedInstance {
    static TVHJsonClient *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHJsonClient alloc] init];
    });
    
    return __sharedInstance;
}

#pragma JsonHelper

+(NSDictionary*) convertFromJsonToObjectFixUtf8:(NSData*)responseData error:(NSError*)error {
    
    NSMutableData *FileData = [NSMutableData dataWithLength:[responseData length]];
    for (int i = 0; i < [responseData length]; ++i)
    {
        char *a = &((char*)[responseData bytes])[i];
        if( ((int)*a >0 && (int)*a < 0x20)  ) {
            ((char*)[FileData mutableBytes])[i] = 0x20;
        } else {
            ((char*)[FileData mutableBytes])[i] = ((char*)[responseData bytes])[i];
        }
    }
    
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:FileData //1
                                                         options:kNilOptions
                                                           error:&error];
    
    if( error ) {
        NSLog(@"[JSON Error (2nd)]: %@ ", error.description);
        return nil;
    }
    
    return json;
}

+(NSDictionary*) convertFromJsonToObject:(NSData*)responseData error:(NSError*)error {
    NSError *errorForThisMethod;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:responseData
                                                         options:kNilOptions
                                                           error:&errorForThisMethod];
    
    if( errorForThisMethod ) {
        /*NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
         NSString *documentsDirectory = [paths objectAtIndex:0];
         NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"MyFile"];
         [responseData writeToFile:appFile atomically:YES];
         NSLog(@"%@",documentsDirectory);
         */
        NSLog(@"[JSON Error (1st)]: %@", errorForThisMethod.description);
        return [self convertFromJsonToObjectFixUtf8:responseData error:error];
    }
    
    return json;
}

@end
