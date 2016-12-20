//
//  MLYRequest.h
//  Network
//
//  Created by eric on 16/12/8.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "MLYBaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const MLYRequestCacheErrorDomain;

NS_ENUM(NSInteger) {
    MLYRequestCacheErrorExpired = -1,
    MLYRequestCacheErrorVersionMismatch = -2,
    MLYRequestCacheErrorSensitiveDataMismatch = -3,
    MLYRequestCacheErrorAppVersionMismatch = -4,
    MLYRequestCacheErrorInvalidCacheTime = -5,
    MLYRequestCacheErrorInvalidMetadata = -6,
    MLYRequestCacheErrorInvalidCacheData = -7,
};

@interface MLYRequest : MLYBaseRequest

@property (nonatomic) BOOL ignoreCache;
/// 数据是否来自于缓存
- (BOOL)isDataFromCache;

/// 手动从缓存加载数据
///
/// @param error 加载失败的错误信息
///
/// @return 加载是否成功
- (BOOL)loadCacheWithError:(NSError * __autoreleasing *)error;

/// 加载数据忽略缓存，加载完成的时候更新缓存的数据
- (void)startWithoutCache;

/// 保存相应的数据到缓存中
- (void)saveResponseDataToCacheFile:(NSData *)data;

#pragma mark - 需要子类实现的方法
/// 缓存时间 默认为-1
- (NSInteger)cacheTimeInSeconds;
/// 缓存的版本 默认为0
- (long long)cacheVersion;
/// 缓存是否异步写入存储 默认是YES
- (BOOL)writeCacheAsynchronously;
@end
    
    NS_ASSUME_NONNULL_END
