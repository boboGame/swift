//
//  MLYNetworkAgent.h
//  Network
//
//  Created by eric on 16/12/7.
//  Copyright © 2016年 eric. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MLYBaseRequest;

NS_ASSUME_NONNULL_BEGIN

@interface MLYNetworkAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (MLYNetworkAgent *)sharedAgent;

/// 在Session中添加一个请求，并且开始网络请求
- (void)addRequest:(MLYBaseRequest *)request;
/// 取消指定的网络请求
- (void)cancelRequest:(MLYBaseRequest *)request;
/// 取消所有的网络请求
- (void)cancelAllRequest;

/// 返回一个通过Request构建的请求地址
///
/// @param request request作为参数不能为空
///
/// @return 返回一个url
- (NSString *)buildRequestUrl:(MLYBaseRequest *)request;

@end

NS_ASSUME_NONNULL_END
