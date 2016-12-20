//
//  MLYNetworkAgent.m
//  Network
//
//  Created by eric on 16/12/7.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "MLYNetworkAgent.h"
#import "MLYNetworkConfig.h"
#import "MLYBaseRequest.h"
#import "MLYNetworkPrivate.h"
#import <pthread/pthread.h>

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

#define Lock() pthread_mutex_lock(&_lock)
#define UnLock() pthread_mutex_unlock(&_lock)

#define MLYKNetworkIncompleteDownloadFolderName @"incompelete"

@implementation MLYNetworkAgent {
    AFHTTPSessionManager *_manager;
    MLYNetworkConfig *_config;
    AFJSONResponseSerializer *_jsonResponseSerializer;
    AFXMLParserResponseSerializer *_xmlParserResponseSerializer;
    NSMutableDictionary<NSNumber *, MLYBaseRequest *> *_requestRecord;
    
    dispatch_queue_t _progressingQueue;
    pthread_mutex_t _lock;
    NSIndexSet *_allStatusCodes;
}

+ (MLYNetworkAgent *)sharedAgent {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _config = [MLYNetworkConfig sharedConfig];
        _manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:_config.sessionConfiguration];
        _requestRecord = @{}.mutableCopy;
        _progressingQueue = dispatch_queue_create("com.beautyyan.networkagent.progressing", DISPATCH_QUEUE_CONCURRENT);
        _allStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 500)];
        pthread_mutex_init(&_lock,NULL);
        
        _manager.securityPolicy = _config.securityPolicy;
        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
        _manager.responseSerializer.acceptableStatusCodes = _allStatusCodes;
        _manager.completionQueue = _progressingQueue;
    }
    return self;
}

- (AFJSONResponseSerializer *)jsonResponseSerializer {
    if (!_jsonResponseSerializer) {
        _jsonResponseSerializer = [AFJSONResponseSerializer serializer];
        _jsonResponseSerializer.acceptableStatusCodes = _allStatusCodes;
    }
    return _jsonResponseSerializer;
}

- (AFXMLParserResponseSerializer *)xmlParserResponseSerializer {
    if (!_xmlParserResponseSerializer) {
        _xmlParserResponseSerializer = [AFXMLParserResponseSerializer serializer];
        _xmlParserResponseSerializer.acceptableStatusCodes = _allStatusCodes;
    }
    return _xmlParserResponseSerializer;
}

#pragma mark - 

- (NSString *)buildRequestUrl:(MLYBaseRequest *)request {
    NSParameterAssert(request);
    NSString *detailUrl = [request requestUrl];
    NSURL *temp = [NSURL URLWithString:detailUrl];
    if (temp && temp.host && temp.scheme) {
        return detailUrl;
    }
    
    NSArray *filters = [_config urlFilters];
    for (id<MLYUrlFilterProtocol> f in filters) {
        detailUrl = [f filterUrl:detailUrl withRequest:request];
    }
    
    NSString *baseUrl;
    if ([request useCDN]) {
        if ([request cdnUrl].length > 0) {
            baseUrl = [request cdnUrl];
        }else {
            baseUrl = [_config cdnUrl];
        }
    }else {
        if ([request baseUrl]) {
            baseUrl = [request baseUrl];
        }else {
            baseUrl = [_config baseUrl];
        }
    }
    
    NSURL *url = [NSURL URLWithString:baseUrl];
    if (baseUrl.length > 0 && ![baseUrl hasSuffix:@"/"]) {
        baseUrl = [baseUrl stringByAppendingString:@""];
    }
    
    return [NSURL URLWithString:detailUrl relativeToURL:url].absoluteString;
}

- (AFHTTPRequestSerializer *)requestSerializerForRequest:(MLYBaseRequest *)request {
    AFHTTPRequestSerializer *requestSerializer = nil;
    if (request.requestSerializerType == MLYRequestSerializerTypeHTTP) {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    }else if (request.requestSerializerType == MLYRequestSerializerTypeJSON) {
        requestSerializer = [AFJSONRequestSerializer serializer];
    }
    
    requestSerializer.timeoutInterval = [request requestTimeoutInterval];
    requestSerializer.allowsCellularAccess = [request allowsCellularAccess];
    
    NSArray<NSString *> *authorizationHeaderFieldArray = [request requestAuthorizationHeaderFieldArray];
    if (authorizationHeaderFieldArray != nil) {
        [requestSerializer setAuthorizationHeaderFieldWithUsername:authorizationHeaderFieldArray.firstObject
                                                          password:authorizationHeaderFieldArray.lastObject];
    }
    
    NSDictionary<NSString *,NSString *> *headerFieldDictionay = [request requestHeaderFieldValueDictionary];
    if (headerFieldDictionay) {
        for (NSString *httpHeaderField in headerFieldDictionay.allKeys) {
            NSString *value = headerFieldDictionay[httpHeaderField];
            [requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
        }
    }
    return requestSerializer;
}


- (NSURLSessionTask *)sessionTaskForRequest:(MLYBaseRequest *)request error:(NSError *_Nullable __autoreleasing *)error {
    MLYRequestMethod requestMethod = request.requestMethod;
    NSString *url = [self buildRequestUrl:request];
    id param = request.requestArgument;
    AFConstructingBlock constructingBlock = request.constructingBodyBlock;
    AFHTTPRequestSerializer *requestSerializer = [self requestSerializerForRequest:request];
    
    switch (requestMethod) {
        case MLYRequestMethodGET:
            if (request.resumableDownloadPath) {
                return [self downloadTaskWithDownloadPath:request.resumableDownloadPath requestSeralizer:requestSerializer URLString:url parameters:param progressBlock:request.resumableDownloadProgresBlock error:error];
            }else {
                return [self dataTaskWithHTTPMethod:@"GET" requestSerilizer:requestSerializer URLString:url parameters:param error:error];
            }
        case MLYRequestMethodPOST:
            return [self dataTaskWithHTTPMethod:@"POST" requestSerilizer:requestSerializer URLString:url constructingBodyWithBlock:constructingBlock parameters:param error:error];
    }
}

- (void)addRequest:(MLYBaseRequest *)request {
    NSParameterAssert(request != nil);
    NSError * __autoreleasing requestSerializationError = nil;
    NSURLRequest *customUrlRequest = [request buildCustomUrlRequest];
    if (customUrlRequest) {
        __block NSURLSessionTask *dataTask = nil;
        dataTask = [_manager dataTaskWithRequest:customUrlRequest
                               completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                   [self handleRequestResult:dataTask responseObject:responseObject error:error];
            
        }];
        request.requestTask = dataTask;
    }else {
        request.requestTask = [self sessionTaskForRequest:request error:&requestSerializationError];
    }
    
    if (requestSerializationError) {
        [self requestDidFailWithRequest:request error:requestSerializationError];
        return;
    }
    
    NSAssert(request.requestTask, @"requestTask should not be nil");
    
    if ([request.requestTask respondsToSelector:@selector(priority)]) {
        switch (request.requestPriority) {
            case MLYRequestPriorityHigh:
                request.requestTask.priority = NSURLSessionTaskPriorityHigh;
                break;
            case MLYRequestPriorityDefault:
                request.requestTask.priority = NSURLSessionTaskPriorityDefault;
                break;
            case  MLYRequestPriorityLow:
                request.requestTask.priority = NSURLSessionTaskPriorityLow;
                break;
            default:
                break;
        }
    }
    
    //持有该请求
    NSLog(@"Add request: %@",NSStringFromClass([request class]));
    [self addRequestToRecord:request];
    [request.requestTask resume];
}

- (void)cancelRequest:(MLYBaseRequest *)request {
    NSParameterAssert(request);
    [self removeRequestFromRecord:request];
    [request clearCompeletionBlock];
}

- (void)cancelAllRequest {
    Lock();
    NSArray *allKeys = [_requestRecord allKeys];
    UnLock();
    if (allKeys && allKeys.count > 0) {
        NSArray *copiedKeys = [allKeys copy];
        for (NSNumber *key in copiedKeys) {
            Lock();
            MLYBaseRequest *request = _requestRecord[key];
            UnLock();
            [request stop];
        }
    }
}

- (BOOL)validateResult:(MLYBaseRequest *)request error:(NSError *_Nullable __autoreleasing *)error {
    BOOL result = [request statusCodeValidator];
    if (!result) {
        if (error) {
            *error = [NSError errorWithDomain:MLYRequestValidationErrorDomain code:MLYRequestValidationErrorInvalidStatusCode userInfo:@{NSLocalizedDescriptionKey : @"Invalid status code"}];
        }
        return result;
    }
    id json = request.responseJSONObject;
    id validator = request.jsonValidator;
    if (json && validator) {
        result = [MLYNetworkUtils validateJSON:json withValidator:validator];
        if (!result) {
            if (error) {
                *error = [NSError errorWithDomain:MLYRequestValidationErrorDomain code:MLYRequestValidationErrorInvalidJsonFormat userInfo:@{NSLocalizedDescriptionKey : @"Invalid JSON format"}];
            }
            return result;
        }
    }
    return YES;
}

- (void)handleRequestResult:(NSURLSessionTask *)task responseObject:(id)responseObject error:(NSError *)error {
    Lock();
    MLYBaseRequest *request = _requestRecord[@(task.taskIdentifier)];
    UnLock();
    
    if (!request) {
        return;
    }
    NSLog(@"Finished Request: %@",NSStringFromClass([request class]));
    
    NSError *__autoreleasing serializationError = nil;
    NSError *__autoreleasing validationError = nil;
    
    NSError *requestError = nil;
    BOOL success = NO;
    
    request.responseObject = responseObject;
    if ([request.responseObject isKindOfClass:[NSData class]]) {
        request.responseData = responseObject;
        request.responseString = [[NSString alloc] initWithData:request.responseData encoding:[MLYNetworkUtils stringEncodingWithRequest:request]];
        
        switch (request.responseSerializerType) {
            case MLYResponseSerializerTypeHTTP:
                // 默认的序列化
                break;
            case MLYResponseSerializerTypeJSON:
                request.responseObject = [_jsonResponseSerializer responseObjectForResponse:task.response data:request.responseData error:&serializationError];
                break;
            case MLYResponseSerializerTypeXMLParser:
                request.responseObject = [_xmlParserResponseSerializer responseObjectForResponse:task.response data:request.responseData error:&serializationError];
                break;
                
            default:
                break;
        }
    }
    
    if (error) {
        success = NO;
        requestError = error;
    }else if (serializationError) {
        success = NO;
        requestError = serializationError;
    }else {
        success = [self validateResult:request error:&validationError];
        requestError = serializationError;
    }
    
    if (success) {
        [self requestDidSuccessWithRequest:request];
    }else {
        [self requestDidFailWithRequest:request error:requestError];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self removeRequestFromRecord:request];
        [request clearCompeletionBlock];
    });
}

- (void)requestDidSuccessWithRequest:(MLYBaseRequest *)request {
    @autoreleasepool {
        [request requestCompletePreprocessor];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [request requestCompleteFilter];
        
        if (request.delegate) {
            [request.delegate requestFinished:request];
        }
        
        if (request.successCompeleteBlock) {
            request.successCompeleteBlock(request);
        }
    });
}

- (void)requestDidFailWithRequest:(MLYBaseRequest *)request error:(NSError *)error {
    request.error = error;
    NSLog(@"Request %@ failed, status code: %ld, error: %@",NSStringFromClass([request class]), request.responseStatusCode,error.localizedDescription);
    NSData *incompeleteDownloadData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    if (incompeleteDownloadData) {
        [incompeleteDownloadData writeToURL:[self incompeleteDownloadTempPathForDownloadPath:request.resumableDownloadPath] atomically:YES];
    }
    
    if ([request.responseObject isKindOfClass:[NSURL class]]) {
        NSURL *url = request.responseObject;
        if (url.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            request.responseData = [NSData dataWithContentsOfURL:url];
            request.responseString = [[NSString alloc] initWithData:request.responseData encoding:[MLYNetworkUtils stringEncodingWithRequest:request]];
        
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
        request.responseObject = nil;
    }
    
    @autoreleasepool {
        [request requestFailedPreprocessor];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [request requestFailedFilter];
        if (request.delegate) {
            [request.delegate requestFailed:request];
        }
        if (request.failureCompeleteBlock) {
            request.failureCompeleteBlock(request);
        }
    });
}

- (void)addRequestToRecord:(MLYBaseRequest *)request {
    Lock();
    _requestRecord[@(request.requestTask.taskIdentifier)] = request;
    UnLock();
}

- (void)removeRequestFromRecord:(MLYBaseRequest *)request {
    Lock();
    [_requestRecord removeObjectForKey:@(request.requestTask.taskIdentifier)];
    UnLock();
}

#pragma mark - 

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                requestSerilizer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters error:(NSError *_Nullable __autoreleasing *)error {
    return [self dataTaskWithHTTPMethod:method requestSerilizer:requestSerializer URLString:URLString constructingBodyWithBlock:nil parameters:parameters error:error];
    
}

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                requestSerilizer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                       constructingBodyWithBlock:(nullable void (^)(id <AFMultipartFormData> formData))block
                                      parameters:(id)parameters error:(NSError *_Nullable __autoreleasing *)error {
    NSMutableURLRequest *request = nil;
    if (block) {
        request = [requestSerializer multipartFormRequestWithMethod:method URLString:URLString parameters:parameters constructingBodyWithBlock:block error:error];
    }else {
        request = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
    }
    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [_manager dataTaskWithRequest:request
                           completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        [self handleRequestResult:dataTask responseObject:responseObject error:error];
    }];
    
    return dataTask;
}


- (NSURLSessionDownloadTask *)downloadTaskWithDownloadPath:(NSString *)downloadPath
                                          requestSeralizer:(AFHTTPRequestSerializer *)requestSerializer
                                                 URLString:(NSString *)URLString
                                                parameters:(id)parameters
                                             progressBlock:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                                                     error:(NSError *_Nullable __autoreleasing *)error {
    NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:@"GET" URLString:URLString parameters:parameters error:error];
    
    NSString *downloadTargetPath;
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:downloadPath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    
    if (isDirectory) {
        NSString *filename = [urlRequest.URL lastPathComponent];
        downloadTargetPath = [NSString pathWithComponents:@[ downloadPath,filename]];
    }else {
        downloadTargetPath = downloadPath;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadTargetPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:downloadTargetPath error:nil];
    }
    
    BOOL resumeDataFileExists= [[NSFileManager defaultManager] fileExistsAtPath:[self incompeleteDownloadTempPathForDownloadPath:downloadPath].path];
    NSData *data = [NSData dataWithContentsOfURL:[self incompeleteDownloadTempPathForDownloadPath:downloadPath]];
    BOOL resumeDataIsValid = [MLYNetworkUtils validateResumeData:data];
    BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;
    BOOL ressumeSucceded = NO;
    __block NSURLSessionDownloadTask *downloadTask = nil;
    if (canBeResumed) {
        @try {
            downloadTask = [_manager downloadTaskWithResumeData:data progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
            } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                [self handleRequestResult:downloadTask responseObject:filePath error:error];
            }];
            ressumeSucceded = YES;
        } @catch (NSException *exception) {
            NSLog(@"Rssume donwload failed, reason:%@",exception.reason);
            ressumeSucceded = NO;
        }
    }
    
    if (!ressumeSucceded) {
        downloadTask = [_manager downloadTaskWithRequest:urlRequest progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            [self handleRequestResult:downloadTask responseObject:filePath error:error];
        }];
    }
    return downloadTask;
}

#pragma mark - 可恢复的下载
- (NSString *)incompeleteDownloadTempCacheFolder {
    NSFileManager *fileManager = [NSFileManager new];
    static NSString *cacheFolder;
    
    if (!cacheFolder) {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:MLYKNetworkIncompleteDownloadFolderName];
    }
    
    NSError *error;
    if (![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Failed to create cache directory at %@",cacheFolder);
        cacheFolder = nil;
    }
    return cacheFolder;
}

- (NSURL *)incompeleteDownloadTempPathForDownloadPath:(NSString *)path {
    NSString *tempPath = nil;
    NSString *md5URLString = [MLYNetworkUtils md5StringFromString:path];
    tempPath = [[self incompeleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLString];
    return [NSURL fileURLWithPath:tempPath];
}

@end
