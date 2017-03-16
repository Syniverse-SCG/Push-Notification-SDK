//
//  SCGPush.m
//  SCGPushSDK
//
//  Created by Angel Terziev on 3/13/17.
//  Copyright © 2017 Syniverse. All rights reserved.
//

#import "SCGPush.h"
#import "HttpRedirectDecisionMaker.h"

#import "SCGPushCoreDataManager.h"

#import <MobileCoreServices/UTCoreTypes.h>

static SCGPush *_sharedInstance = nil;

@interface SCGPush()
@property (nonatomic, strong) HttpRedirectDecisionMaker* redirectDecisionMaker;
@property (nonatomic, strong) SCGPushCoreDataManager* coreDataManager;

@property (nonatomic, copy, nonnull) NSString* accessTokenInternal;
@property (nonatomic, copy, nonnull) NSString* callbackURIInternal;
@property (nonatomic, copy, nonnull) NSString* appIDInternal;

@end

@implementation SCGPush

+ (instancetype) sharedInstanceWithDelegate: (id<SCGPushDelegate>) delegate
{
    // 2
    static dispatch_once_t oncePredicate;
    
    // 3
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[SCGPush alloc] initWithDelegate: delegate];
    });
    
    return _sharedInstance;
}

+ (instancetype) sharedInstance
{
    return [[self class] sharedInstanceWithDelegate: nil];
}

- (instancetype) initWithDelegate: (id<SCGPushDelegate>) delegate
{
    if (nil != (self = [super init])) {
        NSLog(@"Debug: [SCGPush] Initialzing  <%p>", self);
        _delegate = delegate;
        
        self.accessTokenInternal = @"";
        self.appIDInternal = @"";
        self.callbackURIInternal = @"";
    }
    
    return self;
}

+ (instancetype _Nonnull) startWithAccessToken: (NSString* _Nonnull) accessToken
                                         appId: (NSString* _Nonnull) appId
                                   callbackUri: (NSString* _Nonnull) callbackUri
                                      delegate: (id<SCGPushDelegate> _Nullable) delegate
{
    SCGPush* scgPush = [[self class] sharedInstanceWithDelegate: delegate];
    
    scgPush.accessToken = accessToken;
    scgPush.appID = appId;
    scgPush.callbackURI = callbackUri;
    
    [scgPush initializeInbox];
    
    return scgPush;
}


//MARK: - Push Token

- (void) registerPushToken:( NSString* _Nonnull) pushToken
     withCompletionHandler:( void (^)(NSString * _Nullable token)) completionBlock
              failureBlock:( void (^)(NSError * _Nullable error)) failureBlock
{
    if (nil == pushToken) {
        if (failureBlock) {
            NSError* error = [NSError errorWithDomain: @"SCGPush" code: 1 userInfo: nil];
            failureBlock(error);
        }
        
        return;
    }
    
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration: configuration];
    NSString* urlString = [NSString stringWithFormat: @"%@/push_tokens/register",
                           self.callbackURI];
    NSURL* url = [NSURL URLWithString: urlString];
    if (nil == url) {
        if (failureBlock) {
            NSError* error = [NSError errorWithDomain: @"SCGPush" code: 2 userInfo: nil];
            failureBlock(error);
        }
        return;
    }
    
    NSLog(@"Debug: [SCGPush] URL: %@", url.absoluteString);
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 30;

    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString* bearer = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
    [request addValue: bearer forHTTPHeaderField:@"Authorization"];
    NSError* jsonError = nil;
    NSDictionary* params = @{@"app_id": self.appID,
                             @"type": @"APN",
                             @"token": pushToken};
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error: &jsonError];
    if (nil == jsonData) {
        if (failureBlock) {
            failureBlock(jsonError);
        }
        return;
    }
    
    request.HTTPBody = jsonData;

    NSURLSessionDataTask* dataTask =
    [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*) response;
        if (error != nil) {
            if (failureBlock) {
                failureBlock(error);
            }
            return;
        }

        switch (httpResponse.statusCode) {
            case 200:
            case 204:
            {
                if (completionBlock != nil) {
                    completionBlock(pushToken);
                }
            }
                break;
            default:
            {
                if (failureBlock) {
                    NSError* error = [NSError errorWithDomain: @"SCGPush" code: httpResponse.statusCode userInfo: nil];
                    failureBlock(error);
                }
            }
                break;
                
        }
    }];

    [dataTask resume];
}

// MARK: - Report Status
- (NSString*) messageStateToString: (MessageState) state {

    NSString* stateAsString = nil;
    switch (state) {
        case MessageStateDelivered:
            stateAsString = @"DELIVERED";
            break;
        case MessageStateRequested:
            stateAsString = @"MEDIA_REQUESTED";
            break;
        case MessageStateRead:
            stateAsString = @"READ";
            break;
        case MessageStateClicked:
            stateAsString = @"CLICKTHRU";
            break;
        case MessageStateConverted:
            stateAsString = @"CONVERTED";
            break;
        default:
            break;
    }
    
    return stateAsString;
}

- (void) reportStatusWithMessageId: ( NSString* _Nonnull) messageId
                   andMessageState: ( MessageState ) state
                   completionBlock: ( void(^ _Nullable)()    ) completionBlock
                     failureBlock : ( void(^ _Nullable) (NSError* _Nullable error)) failureBlock
{

    NSString* stringifiedMessageState = [self messageStateToString: state];
    if (nil == stringifiedMessageState) {
        if (failureBlock) {
            NSError* error = [NSError errorWithDomain: @"SCGPush" code: 1 userInfo: nil];
            failureBlock(error);
        }
        return;
    }
    
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration: configuration];
    NSString* urlString = [NSString stringWithFormat: @"%@/messages/%@/confirm/%@",
                           self.callbackURI,
                           messageId,
                           stringifiedMessageState];

    NSURL* url = [NSURL URLWithString: urlString];
    if (nil == url) {
        if (failureBlock) {
            NSError* error = [NSError errorWithDomain: @"SCGPush" code: 2 userInfo: nil];
            failureBlock(error);
        }
        return;
    }
    
    NSLog(@"Debug: [SCGPush] URL: %@", url.absoluteString);
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 30;
    
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString* bearer = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
    [request addValue: bearer forHTTPHeaderField:@"Authorization"];

    NSURLSessionDataTask* dataTask =
    [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*) response;
        if (error != nil) {
            if (failureBlock) {
                failureBlock(error);
            }
            return;
        }
        
        switch (httpResponse.statusCode) {
            case 200:
            case 204:
            {
                if (completionBlock != nil) {
                    completionBlock();
                }
            }
                break;
            default:
            {
                if (failureBlock) {
                    NSError* error = [NSError errorWithDomain: @"SCGPush" code: httpResponse.statusCode userInfo: nil];
                    failureBlock(error);
                }
            }
                break;
        }
    }];
    
    [dataTask resume];
}

// MARK: Resolve Tracked Link
- (void) resolveTrackedLink:(NSString* _Nonnull) urlString
{
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration delegate:self.redirectDecisionMaker delegateQueue:nil];
    NSURL* url = [NSURL URLWithString: urlString];

    NSLog(@"Debug: [SCGPush] URL: %@", url.absoluteString);
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: url];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 30;
    
    NSURLSessionDataTask* dataTask =
    [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*) response;
        if (error != nil) {
            return;
        }
        
        switch (httpResponse.statusCode) {
            case 300:
            case 301:
            case 307:
            {
                if (self.delegate != nil) {
                    
                    NSString* redirectLocation = httpResponse.allHeaderFields[@"Location"];
                    if (nil != redirectLocation) {
                        [self.delegate resolveTrackedLinkDidSuccess:redirectLocation withrequest:request];
                    } else {
                        [self.delegate resolveTrackedLinkHasNotRedirect:request];
                    }
                }
            }
                break;
            default:
            {
                if (self.delegate != nil) {
                    [self.delegate resolveTrackedLinkHasNotRedirect:request];
                }
            }
                break;
        }
    }];
    
    [dataTask resume];

}

// MARK: - Load Attachment

- (NSString*) translateContentTypeHeader: (NSHTTPURLResponse* _Nonnull) httpResponse
{
    NSString* translatedContentType = @"";
    NSString* contentType = httpResponse.allHeaderFields[@"Content-Type"];
    
    if (contentType != nil) {
        if (NSOrderedSame == [contentType caseInsensitiveCompare: @"video/mpeg"]) {
            translatedContentType = (NSString*) kUTTypeMPEG4;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"video/mp4"]) {
            translatedContentType = (NSString*) kUTTypeMPEG4;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"video/webm"]) {
            translatedContentType = (NSString*) kUTTypeVideo;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"video/ogg"]) {
            translatedContentType = (NSString*) kUTTypeVideo;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"audio/ogg"]) {
            translatedContentType = (NSString*) kUTTypeAudio;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"audio/webm"]) {
            translatedContentType = (NSString*) kUTTypeAudio;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"audio/mpeg"]) {
            translatedContentType = (NSString*) kUTTypeAudio;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"audio/mp3"]) {
            translatedContentType = (NSString*) kUTTypeMP3;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"image/gif"]) {
            translatedContentType = (NSString*) kUTTypeGIF;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"image/png"]) {
            translatedContentType = (NSString*) kUTTypePNG;
        } else if (NSOrderedSame == [contentType caseInsensitiveCompare: @"image/jpeg"]) {
            translatedContentType = (NSString*) kUTTypeJPEG;
        }
    }
    
    return translatedContentType;
    
}

- (void) loadAttachmentWithMessageId:(NSString* _Nonnull) messageId
                     andAttachmentId:(NSString* _Nonnull) attachmentId
                     completionBlock:(void(^_Nullable)(NSURL* _Nonnull contentUrl, NSString* _Nonnull contentType))completionBlock
                        failureBlock:(void(^_Nullable)(NSError* _Nullable error))failureBlock
{
    NSLog(@"Debug: [SCGPush] '<%p>', will load attachment '%@' for message '%@'",
          self,
          attachmentId,
          messageId);
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration];
    NSString* urlString = [NSString stringWithFormat: @"%@/attachment/%@/%@",
                           self.callbackURI,
                           messageId,
                           attachmentId];
    NSURL* url = [NSURL URLWithString: urlString];
    
    NSLog(@"Debug: [SCGPush] URL: %@", url.absoluteString);
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: url];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 30;

    NSString* bearer = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
    [request addValue: bearer forHTTPHeaderField:@"Authorization"];

    NSURLSessionDownloadTask* downloadTask =
    [session downloadTaskWithRequest:request completionHandler:^(NSURL * _Nullable location,
                                                                 NSURLResponse * _Nullable response,
                                                                 NSError * _Nullable error) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*) response;
        if (error != nil) {
            if (failureBlock) {
                failureBlock(error);
            }
            return;
        }
        
        NSURL* contentUrl;
        NSString* contentType = [self translateContentTypeHeader: httpResponse];
        
        if (nil != location ) {
            // Move temporary file to remove .tmp extension
            NSString* tmpDirectory = NSTemporaryDirectory();
            NSString*  tmpFile = [[@"file://" stringByAppendingString:tmpDirectory] stringByAppendingString:url.lastPathComponent];
            NSURL* tmpUrl = [NSURL URLWithString:tmpFile];
            if ([[NSFileManager defaultManager] fileExistsAtPath:tmpUrl.path isDirectory:nil])
                [[NSFileManager defaultManager] removeItemAtURL:tmpUrl error:nil];
            
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:tmpUrl error:nil];
            contentUrl = tmpUrl;
        }

        switch (httpResponse.statusCode) {
            case 200:
            case 204:
            {
                if (completionBlock != nil) {
                    completionBlock(contentUrl, contentType);
                }
            }
                break;
            default:
            {
                if (failureBlock) {
                    NSError* error = [NSError errorWithDomain: @"SCGPush" code: httpResponse.statusCode userInfo: nil];
                    failureBlock(error);
                }
            }
                break;
        }
    }];
    
    [downloadTask resume];
}

// MARK: - Save Device Token
- (void) saveDeviceToken: (NSString* _Nonnull) token
{
}

- (void) saveDeviceTokenData: (NSData* _Nonnull) tokenData
{
}

//MARK: - PushInbox
- (void) initializeInbox
{
    self.coreDataManager = [SCGPushCoreDataManager sharedInstance];
}

- (BOOL) pushToInbox: (NSDictionary* _Nonnull) payload
{
    BOOL fOk = NO;
    id identifier = payload[@"scg-message-id"];
    id body = payload[@"body"];
    id deepLink = payload[@"deep_link"];
    id attachmentId = payload[@"scg-attachment-id"];
    id showNotification = payload[@"show-notification"];
    
    if (nil == identifier || ![identifier isKindOfClass: [NSString class]])
        return fOk;
    
    NSString* messageId = (NSString*) identifier;
    NSString* messageBody = @"";
    
    if (nil != body && [body isKindOfClass:[NSString class]]) {
        messageBody = (NSString*) body;
    }
    
    SCGPushMessage* message =
    [[SCGPushMessage alloc] initWithId: messageId
                           dateCreated: [NSDate date]
                               andBody: messageBody];
    
    if (!message)
        return fOk;
    
    if (deepLink && [deepLink isKindOfClass:[NSString class]]) {
        message.deepLink = (NSString*) deepLink;
    }
    if (attachmentId && [attachmentId isKindOfClass:[NSString class]]) {
        message.attachmentId = (NSString*) attachmentId;
    }
    
    if (showNotification && [showNotification isKindOfClass:[NSNumber class]]) {
        message.showNotification = [showNotification boolValue];
    }
    
    fOk = [self.coreDataManager addNewMessage: message];
    
    return fOk;
}

//MARK: - accessors
- (HttpRedirectDecisionMaker *)redirectDecisionMaker {

    if (nil == _redirectDecisionMaker) {
        _redirectDecisionMaker = [[HttpRedirectDecisionMaker alloc] initWithPreventRedirect: YES];
    }
    
    return _redirectDecisionMaker;
}

-(void)setAccessToken:(NSString *)newValue {
    @synchronized (self) {
        if ([newValue length]) {
            NSLog(@"Debug: [SCGPush] set accessToken %@", newValue);
            self.accessTokenInternal = [newValue copy];
        } else{
            NSLog(@"Debug: [SCGPush] clear accessToken");
            self.accessTokenInternal = [@"" copy];
        }
    }
}

-(NSString *)accessToken {
    @synchronized (self) {
        return self.accessTokenInternal;
    }
}

-(void)setAppID:(NSString *)newValue {
    @synchronized (self) {
        if ([newValue length]) {
            NSLog(@"Debug: [SCGPush] set appID %@", newValue);
            self.appIDInternal = [newValue copy];
        } else{
            NSLog(@"Debug: [SCGPush] clear appID");
            self.appIDInternal = [@"" copy];
        }
    }
}

-(NSString *)appID {
    @synchronized (self) {
        return self.appIDInternal;
    }
}

-(void)setCallbackURI:(NSString *)newValue{
    @synchronized (self) {
        if ([newValue length]) {
            NSLog(@"Debug: [SCGPush] set callbackURI %@", newValue);
            self.callbackURIInternal = [newValue copy];
        } else{
            NSLog(@"Debug: [SCGPush] clear callbackURI");
            self.callbackURIInternal = [@"" copy];
        }
    }
    
}

-(NSString *)callbackURI {
    @synchronized (self) {
        return self.callbackURIInternal;
    }
}
@end
