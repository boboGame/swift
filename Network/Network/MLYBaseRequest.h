//
//  MLYBaseRequest.h
//  Network
//
//  Created by eric on 16/12/7.
//  Copyright © 2016年 eric. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const MLYRequestValidationErrorDomain;

NS_ENUM(NSInteger) {
    MLYRequestValidationErrorInvalidStatusCode = -8,
    MLYRequestValidationErrorInvalidJsonFormat = -9,
};

typedef NS_ENUM(NSUInteger, MLYRequestMethod) {
    MLYRequestMethodGET = 0,
    MLYRequestMethodPOST,
};

typedef NS_ENUM(NSUInteger, MLYRequestSerializerType) {
    MLYRequestSerializerTypeHTTP = 0,
    MLYRequestSerializerTypeJSON,
};

typedef NS_ENUM(NSUInteger, MLYResponseSerializerType) {
    MLYResponseSerializerTypeJSON,
    MLYResponseSerializerTypeHTTP,
    MLYResponseSerializerTypeXMLParser,
};

typedef NS_ENUM(NSUInteger, MLYRequestPriority) {
    MLYRequestPriorityLow = -4L,
    MLYRequestPriorityDefault = 0,
    MLYRequestPriorityHigh = 4,
};

@protocol AFMultipartFormData;

typedef void(^AFConstructingBlock)(id<AFMultipartFormData> formData);
typedef void(^AFURLSessionTaskProgressBlock)(NSProgress *progress);

@class MLYBaseRequest;

typedef void(^MLYRequestCompeleteBlock)(__kindof MLYBaseRequest *request);

@protocol MLYRequestDelegate <NSObject>

@optional
- (void)requestFinished:(__kindof MLYBaseRequest *)request;
- (void)requestFailed:(__kindof MLYBaseRequest *)request;

@end

@protocol MLYRequestAccesory <NSObject>

- (void)requestWillStart:(id)request;
- (void)requestWillStop:(id)request;
- (void)requestDidStop:(id)request;

@end

@interface MLYBaseRequest : NSObject

#pragma mark - 网络的请求和相应信息
/// 原始的网络请求的Task 在发起请求之前为空
@property (nonatomic, strong, readonly) NSURLSessionTask *requestTask;
/// 当前的请求
@property (nonatomic, strong, readonly) NSURLRequest *currentRequest;
/// 原始的请求
@property (nonatomic, strong, readonly) NSURLRequest *originalRequest;
/// 网络请求的相应
@property (nonatomic, strong, readonly) NSHTTPURLResponse *respons;
/// 网络请求的相应的状态码
@property (nonatomic, readonly) NSInteger responseStatusCode;
/// 网络请求的相应头
@property (nonatomic, strong, readonly, nullable) NSDictionary *responseHeaders;
/// 网络请求的返回的实际的数据
@property (nonatomic, strong, readonly, nullable) NSData *responseData;
/// 网络请求的相应的字符串
@property (nonatomic, strong, readonly, nullable) NSString *responseString;
/// 网络请求的返回的序列化的对象
/// @discussion 当设置了resumableDownloadPath和DownloadTask被启用的时候 这个值将会是路径
@property (nonatomic, strong, readonly, nullable) id responseObject;
/// 便利获取相应对象
@property (nonatomic, strong, readonly, nullable) id responseJSONObject;
/// 序列化错误或网络请求错误相关的信息
@property (nonatomic, strong, readonly, nullable) NSError *error;
/// 任务的取消状态
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
/// 任务的执行状态
@property (nonatomic, readonly, getter=isExecuting) BOOL executing;

#pragma mark - 请求的配置信息
/// 可以用来标记请求 默认为0
@property (nonatomic) NSUInteger tag;
/// 保存请求的额外信息 默认为空
@property (nonatomic, strong, nullable) NSDictionary *userInfo;
/// 网络请求的返回数据的代理 当选择使用block去接受数据的时候讲会忽略该代理
@property (nonatomic, weak, nullable) id<MLYRequestDelegate> delegate;
/// 网络请求成功将会调用的Block
@property (nonatomic, copy, nullable) MLYRequestCompeleteBlock successCompeleteBlock;
/// 网络请求失败将会调用的Block
@property (nonatomic, copy, nullable) MLYRequestCompeleteBlock failureCompeleteBlock;
/// 保存相关的插件
@property (nonatomic, strong, nullable) NSMutableArray<id<MLYRequestAccesory>> *requestAccessories;
/// 构建请求提的Block
@property (nonatomic, copy, nullable) AFConstructingBlock constructingBodyBlock;
/// 用于缓存可恢复下载信息的路径
@property (nonatomic, strong, nullable) NSString *resumableDownloadPath;
/// 可以用于监听下载的进度
@property (nonatomic, copy, nullable) AFURLSessionTaskProgressBlock resumableDownloadProgresBlock;
/// 该请求的优先级 ios8+ 默认为 MLYRequestPriorityDefault
@property (nonatomic) MLYRequestPriority requestPriority;
/// 设置请求成功的相关的回调
- (void)setCompeletionBlockWithSuccess:(MLYRequestCompeleteBlock)success
                               failure:(MLYRequestCompeleteBlock)failure;
/// 清空请求成功的Block
- (void)clearCompeletionBlock;
/// 便利天津爱相关插件的方法
- (void)addAssesory:(id<MLYRequestAccesory>)assesory;

#pragma mark - 请求的相关的操作
- (void)start;
- (void)stop;

- (void)startWithCompletionBlockWithSuccess:(MLYRequestCompeleteBlock)success
                                    failure:(MLYRequestCompeleteBlock)failure;

#pragma mark - 需要子类重写的方法
/// 预处理请求成功的数据 (在请求成功回到主线程之前调用)
- (void)requestCompletePreprocessor;
/// 回到主线程的时候调用
- (void)requestCompleteFilter;
///预处理请求失败的数据 (在请求成功回到主线程之前调用)
- (void)requestFailedPreprocessor;
- (void)requestFailedFilter;

- (NSString *)baseUrl;
- (NSString *)requestUrl;
- (NSString *)cdnUrl;

/// 网络请求超时时间 默认60s
- (NSTimeInterval)requestTimeoutInterval;
/// 网络请求的argument
- (nullable id)requestArgument;
- (id)cacheFileNameFilterForRequestArgument:(id)argument;

- (MLYRequestMethod)requestMethod;
- (MLYRequestSerializerType)requestSerializerType;
- (MLYResponseSerializerType)responseSerializerType;

- (nullable NSArray<NSString *> *)requestAuthorizationHeaderFieldArray;
- (nullable NSDictionary<NSString *, NSString *> *)requestHeaderFieldValueDictionary;

- (NSURLRequest *)buildCustomUrlRequest;

- (BOOL)useCDN;
- (BOOL)allowsCellularAccess;

- (nullable id)jsonValidator;
- (BOOL)statusCodeValidator;

@end
NS_ASSUME_NONNULL_END
