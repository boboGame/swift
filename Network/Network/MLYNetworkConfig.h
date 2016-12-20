//
//  MLYNetworkConfig.h
//  Network
//
//  Created by eric on 16/12/7.
//  Copyright © 2016年 eric. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class MLYBaseRequest;
@class AFSecurityPolicy;

@protocol MLYUrlFilterProtocol <NSObject>
- (NSString *)filterUrl:(NSString *)originalUrl withRequest:(MLYBaseRequest *)request;
@end

@protocol MLYCacheDirPathFilterProtocol <NSObject>
- (NSString *)filterCacheDirPath:(NSString *)originalPath withRequest:(MLYBaseRequest *)request;
@end

@interface MLYNetworkConfig : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedConfig;

/// 请求的host地址
@property (nonatomic, strong) NSString *baseUrl;
/// cdn资源的请求地址
@property (nonatomic, strong) NSString *cdnUrl;

@property (nonatomic, strong, readonly) NSArray<id<MLYUrlFilterProtocol>> *urlFilters;
@property (nonatomic, strong, readonly) NSArray<id<MLYCacheDirPathFilterProtocol>> *cacheDirPathFilters;

@property (nonatomic, strong) AFSecurityPolicy *securityPolicy;

@property (nonatomic) BOOL debugEnable;

@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;

- (void)addUrlFilter:(id<MLYUrlFilterProtocol>)filter;
- (void)clearUrlFilter;

- (void)addCacheDirPathFilter:(id<MLYCacheDirPathFilterProtocol>)filter;
- (void)clearCacheDirPathFilter;

@end
NS_ASSUME_NONNULL_END
