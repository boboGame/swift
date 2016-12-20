//
//  MLYRequest.m
//  Network
//
//  Created by eric on 16/12/8.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "MLYRequest.h"
#import "MLYNetworkPrivate.h"
#import "MLYNetworkConfig.h"

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_QoS_Available 1140.11
#else
#define NSFoundationVersionNumber_With_QoS_Available NSFoundationVersionNumber_iOS_8_0
#endif

NSString *const MLYRequestCacheErrorDomain = @"com.beautyyan.request.caching";

static dispatch_queue_t mlyrequest_cache_write_queue(){
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t attr = DISPATCH_QUEUE_SERIAL;
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_8_0) {
            attr = dispatch_queue_attr_make_with_qos_class(attr, QOS_CLASS_BACKGROUND,0);
        }
        queue = dispatch_queue_create("com.beautyyan.mlyrequest.caching", attr);
    });
    return queue;
}

@interface MLYCacheMetadata : NSObject<NSSecureCoding>

@property (nonatomic, assign) long long version;
@property (nonatomic, strong) NSString *sensitiveDataString;
@property (nonatomic, assign) NSStringEncoding stringEncoding;
@property (nonatomic, strong) NSDate *createDate;
@property (nonatomic, strong) NSString *appVersionString;

@end

@implementation MLYCacheMetadata

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(self.version) forKey:NSStringFromSelector(@selector(version))];
    [aCoder encodeObject:self.sensitiveDataString forKey:NSStringFromSelector(@selector(sensitiveDataString))];
    [aCoder encodeObject:@(self.stringEncoding) forKey:NSStringFromSelector(@selector(stringEncoding))];
    [aCoder encodeObject:self.createDate forKey:NSStringFromSelector(@selector(createDate))];
    [aCoder encodeObject:self.appVersionString forKey:NSStringFromSelector(@selector(appVersionString))];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.version = [[aDecoder decodeObjectForKey:NSStringFromSelector(@selector(version))] longLongValue];
        self.sensitiveDataString = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(sensitiveDataString))];
        self.stringEncoding = [[aDecoder decodeObjectForKey:NSStringFromSelector(@selector(stringEncoding))] integerValue];
        self.createDate = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(createDate))];
        self.appVersionString = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(appVersionString))];
    }
    return self;
}

@end

@interface MLYRequest ()

@property (nonatomic, strong) NSData *cacheData;
@property (nonatomic, strong) NSString *cacheString;
@property (nonatomic, strong) id cacheJSON;
@property (nonatomic, strong) NSXMLParser *cacheXML;

@property (nonatomic, strong) MLYCacheMetadata *cacheMetadata;
@property (nonatomic, assign) BOOL dataFromCache;

@end

@implementation MLYRequest

- (void)start {
    if (self.ignoreCache) {
        [self startWithoutCache];
        return;
    }
    
    if (self.resumableDownloadPath) {
        [self startWithoutCache];
        return;
    }
    
    if (![self loadCacheWithError:nil]) {
        [self startWithoutCache];
        return;
    }
    
    _dataFromCache = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self requestCompletePreprocessor];
        [self requestCompleteFilter];
        MLYRequest *strongSelf = self;
        if (strongSelf.successCompeleteBlock) {
            strongSelf.successCompeleteBlock(strongSelf);
        }
        [strongSelf clearCompeletionBlock];
    });
}

- (void)startWithoutCache {
    [self clearCacheVariables];
    [super start];
}

#pragma mark - 网络请求的代理
- (void)requestCompletePreprocessor {
    [super requestCompletePreprocessor];
    
    if (self.writeCacheAsynchronously) {
        dispatch_async(mlyrequest_cache_write_queue(), ^{
            [self saveResponseDataToCacheFile:[super responseData]];
        });
    }else {
        [self saveResponseDataToCacheFile:[super responseData]];
    }
}

#pragma mark - 子类需要覆盖的方法

- (NSInteger)cacheTimeInSeconds {
    return -1;
}

- (long long)cacheVersion {
    return 0;
}

- (id)cacheSensitiveData {
    return nil;
}

- (BOOL)writeCacheAsynchronously {
    return YES;
}

#pragma mark - 
- (BOOL)isDataFromCache {
    return _dataFromCache;
}

- (NSData *)responseData {
    if (_cacheData) {
        return _cacheData;
    }
    return [super responseData];
}

- (id)cacheJSON {
    if (_cacheJSON) {
        return _cacheJSON;
    }
    return [super responseJSONObject];
}

- (id)responseObject {
    if (_cacheJSON) {
        return _cacheJSON;
    }
    if (_cacheXML) {
        return _cacheXML;
    }
    if (_cacheData) {
        return _cacheData;
    }
    return [super responseObject];
}

#pragma mark - 
- (BOOL)loadCacheWithError:(NSError * _Nullable __autoreleasing *)error {
    if ([self cacheTimeInSeconds] < 0) {
        if (error) {
            *error = [NSError errorWithDomain:MLYRequestCacheErrorDomain code:MLYRequestCacheErrorInvalidCacheTime userInfo:@{NSLocalizedDescriptionKey:@"Invalid cache time."}];
        }
        return NO;
    }
    
    if (![self loadCacheMetaData]) {
        if (error) {
            *error = [NSError errorWithDomain:MLYRequestCacheErrorDomain code:MLYRequestCacheErrorInvalidMetadata userInfo:@{NSLocalizedDescriptionKey:@"Invalid metadata, Cache may not exits"}];
        }
        return NO;
    }
    
    if (![self validateCacheWithError:error]) {
        return NO;
    }
    
    if (![self loadCacheData]) {
        if (error) {
            *error = [NSError errorWithDomain:MLYRequestCacheErrorDomain code:MLYRequestCacheErrorInvalidMetadata userInfo:@{NSLocalizedDescriptionKey:@"Invalid cache data"}];
        }
        return NO;
    }
    return YES;
}

- (BOOL)validateCacheWithError:(NSError * _Nullable __autoreleasing *)error {
    //1.判断是否过期
    NSDate *createDate = self.cacheMetadata.createDate;
    NSTimeInterval duration = -[createDate timeIntervalSinceNow];
    if (duration < 0 || duration > [self cacheTimeInSeconds]) {
        if (error) {
            *error = [NSError errorWithDomain:MLYRequestCacheErrorDomain code:MLYRequestCacheErrorExpired userInfo:@{NSLocalizedDescriptionKey:@"Cache expired"}];
        }
        return NO;
    }
    //2.判断版本是否正确
    long long cacheVersionFileContent = self.cacheMetadata.version;
    if (cacheVersionFileContent != [self cacheVersion]) {
        if (error) {
            *error = [NSError errorWithDomain:MLYRequestCacheErrorDomain code:MLYRequestCacheErrorVersionMismatch userInfo:@{NSLocalizedDescriptionKey : @"Cache version mismatch"}];
        }
        return NO;
    }
    //3.判断隐私数据是否正确
    NSString *sensitiveDateString = self.cacheMetadata.sensitiveDataString;
    NSString *currentSensitiveDateString = ((NSObject *)[self cacheSensitiveData]).description;
    if (sensitiveDateString || currentSensitiveDateString) {
        if (sensitiveDateString.length != currentSensitiveDateString.length || ![sensitiveDateString isEqualToString:currentSensitiveDateString]) {
            if (error) {
                *error = [NSError errorWithDomain:MLYRequestCacheErrorDomain code:MLYRequestCacheErrorSensitiveDataMismatch userInfo:@{NSLocalizedDescriptionKey : @"Cache sensitive data mismatch"}];
            }
            return NO;
        }
    }
    
    //4.判断应用的版本号是否一致
    NSString *appVersionString = self.cacheMetadata.appVersionString;
    NSString *currentAppVersionString = [MLYNetworkUtils appVersionString];
    if (appVersionString || currentAppVersionString) {
        if (appVersionString.length != currentAppVersionString.length || ![appVersionString isEqualToString:currentAppVersionString]) {
            if (error) {
                *error = [NSError errorWithDomain:MLYRequestCacheErrorDomain code:MLYRequestCacheErrorAppVersionMismatch userInfo:@{NSLocalizedDescriptionKey : @"App version mismatch"}];
            }
            return NO;
        }
    }
    return YES;
}

- (BOOL)loadCacheMetaData {
    NSString *path = [self cacheMetadataFilePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:nil]) {
        @try {
            _cacheData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
            return YES;
        } @catch (NSException *exception) {
            NSLog(@"Load cache faile, reason: %@",exception.reason);
            return NO;
        }
    }
    
    return NO;
}

- (BOOL)loadCacheData {
    NSString *path = [self cacheFilePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fileManager fileExistsAtPath:path isDirectory:nil]) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        _cacheData = data;
        _cacheString = [[NSString alloc] initWithData:_cacheData encoding:self.cacheMetadata.stringEncoding];
        switch (self.responseSerializerType) {
            case MLYResponseSerializerTypeHTTP:
                return YES;
            case MLYResponseSerializerTypeJSON:
                _cacheJSON = [NSJSONSerialization JSONObjectWithData:_cacheData options:(NSJSONReadingOptions)0 error:&error];
                return error == nil;
            case MLYResponseSerializerTypeXMLParser:
                _cacheXML = [[NSXMLParser alloc] initWithData:_cacheData];
                return YES;
            default:
                break;
        }
    }
    return NO;
}

- (void)saveResponseDataToCacheFile:(NSData *)data {
    if ([self cacheTimeInSeconds] > 0 && ![self dataFromCache]) {
        if (data) {
            @try {
                [data writeToFile:[self cacheFilePath] atomically:YES];
                MLYCacheMetadata *metaData = [[MLYCacheMetadata alloc] init];
                metaData.version = [self cacheVersion];
                metaData.sensitiveDataString = ((NSObject *)[self cacheSensitiveData]).description;
                metaData.stringEncoding = [MLYNetworkUtils stringEncodingWithRequest:self];
                metaData.createDate = [NSDate date];
                metaData.appVersionString = [MLYNetworkUtils appVersionString];
                [NSKeyedArchiver archiveRootObject:metaData toFile:[self cacheMetadataFilePath]];
            } @catch (NSException *exception) {
                NSLog(@"Save cache fail, reason: %@",exception.reason);
            }
        }
    }
}

- (void)clearCacheVariables {
    _cacheData = nil;
    _cacheXML = nil;
    _cacheJSON = nil;
    _cacheString = nil;
    _cacheMetadata = nil;
    _dataFromCache = NO;
}

#pragma mark - 
- (void)createDirectoryIfNeeded:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDir]) {
        [self createDirectoryIfNeeded:path];
    }else {
        if (!isDir) {
            [fileManager removeItemAtPath:path error:nil];
            [self createDirectoryIfNeeded:path];
        }
    }
}

- (void)ceaterBaseDirectoryAtPath:(NSString *)path {
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        NSLog(@"Ceate cache directory failed, error: %@",error);
    }else {
        [MLYNetworkUtils setDoNotBackupAttribute:path];
    }
}

- (NSString *)createBasePath {
    NSString *pathOfLibrary = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [pathOfLibrary stringByAppendingPathComponent:@"LazyRequestCache"];
    
    NSArray<id<MLYCacheDirPathFilterProtocol>> *filters = [[MLYNetworkConfig sharedConfig] cacheDirPathFilters];
    if (filters.count > 0) {
        for (id<MLYCacheDirPathFilterProtocol> f in filters) {
            [f filterCacheDirPath:path withRequest:self];
        }
    }
    [self createDirectoryIfNeeded:path];
    return path;
}

- (NSString *)cacheFileName {
    NSString *requestUrl = [self requestUrl];
    NSString *baseUrl = [[MLYNetworkConfig sharedConfig] baseUrl];
    id argument = [self cacheFileNameFilterForRequestArgument:[self requestArgument]];
    NSString *requestInfo = [NSString stringWithFormat:@"Method:%ld Host:%@ Url:%@ Argument:%@",
                             (long)self.requestMethod,baseUrl,requestUrl,argument];
    NSString *cacheFileName = [MLYNetworkUtils md5StringFromString:requestInfo];
    return cacheFileName;
}

- (NSString *)cacheFilePath {
    NSString *cacheFileName = [self cacheFileName];
    NSString *path = [self createBasePath];
    path = [path stringByAppendingPathComponent:cacheFileName];
    return path;
}

- (NSString *)cacheMetadataFilePath {
    NSString *cacheMetadataFileName = [NSString stringWithFormat:@"%@.metadata",[self cacheFileName]];
    NSString *path = [self createBasePath];
    path = [path stringByAppendingPathComponent:cacheMetadataFileName];
    return path;
}

@end
