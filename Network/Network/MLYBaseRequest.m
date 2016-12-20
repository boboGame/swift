//
//  MLYBaseRequest.m
//  Network
//
//  Created by eric on 16/12/7.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "MLYBaseRequest.h"
#import "MLYNetworkPrivate.h"
#import "MLYNetworkAgent.h"

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

NSString *const MLYRequestValidationErrorDomain = @"com.beautyyan.request.validation";

@interface MLYBaseRequest ()

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite) NSData *responseData;
@property (nonatomic, strong, readwrite) id responseJSONObject;
@property (nonatomic, strong, readwrite) id responseObject;
@property (nonatomic, strong, readwrite) NSString *responseString;
@property (nonatomic, strong, readwrite) NSError *error;

@end

@implementation MLYBaseRequest

#pragma mark - 网络的相关的请求和相应的信息
- (NSHTTPURLResponse *)respons {
    return (NSHTTPURLResponse *)self.requestTask.response;
}

- (NSInteger)responseStatusCode {
    return self.respons.statusCode;
}

- (NSDictionary *)responseHeaders {
    return self.respons.allHeaderFields;
}

- (NSURLRequest *)currentRequest {
    return self.currentRequest;
}

- (NSURLRequest *)originalRequest {
    return self.originalRequest;
}

- (BOOL)isCancelled {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateCanceling;
}

- (BOOL)isExecuting {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateRunning;
}

#pragma mark - 网络请求的配置信息
- (void)setCompeletionBlockWithSuccess:(MLYRequestCompeleteBlock)success
                               failure:(MLYRequestCompeleteBlock)failure {
    self.successCompeleteBlock = success;
    self.failureCompeleteBlock = failure;
}

- (void)clearCompeletionBlock {
    self.successCompeleteBlock = nil;
    self.failureCompeleteBlock = nil;
}

- (void)addAssesory:(id<MLYRequestAccesory>)assesory {
    if (!assesory) return;
    if (!self.requestAccessories) {
        self.requestAccessories = @[].mutableCopy;
    }
    [self.requestAccessories addObject:assesory];
}

- (void)start {
    [self toggleAccessoriesWillStartCallBack];
    [[MLYNetworkAgent sharedAgent] addRequest:self];
}

- (void)stop {
    [self toggleAccessoriesWillStopCallBack];
    self.delegate = nil;
    [[MLYNetworkAgent sharedAgent] cancelRequest:self];
    [self toggleAccessoriesDidStopCallBack];
}

- (void)startWithCompletionBlockWithSuccess:(MLYRequestCompeleteBlock)success
                                    failure:(MLYRequestCompeleteBlock)failure {
    [self setCompeletionBlockWithSuccess:success failure:failure];
    [self start];
}

#pragma mark - 需要子类覆盖
- (void)requestCompletePreprocessor {
}

- (void)requestCompleteFilter {
}

- (void)requestFailedPreprocessor {
}

- (void)requestFailedFilter {
}

- (NSString *)requestUrl {
    return @"";
}

- (NSString *)cdnUrl {
    return @"";
}

- (NSString *)baseUrl {
    return @"";
}

- (NSTimeInterval)requestTimeoutInterval {
    return 60;
}

- (id)requestArgument {
    return nil;
}

- (id)cacheFileNameFilterForRequestArgument:(id)argument {
    return argument;
}

- (MLYRequestMethod)requestMethod {
    return MLYRequestMethodGET;
}

- (MLYRequestSerializerType)requestSerializerType {
    return MLYRequestSerializerTypeHTTP;
}

- (MLYResponseSerializerType)responseSerializerType {
    return MLYResponseSerializerTypeJSON;
}

- (NSArray *)requestAuthorizationHeaderFieldArray {
    return nil;
}

- (NSDictionary *)requestHeaderFieldValueDictionary {
    return nil;
}

- (NSURLRequest *)buildCustomUrlRequest {
    return nil;
}

- (BOOL)useCDN {
    return NO;
}

- (BOOL)allowsCellularAccess {
    return YES;
}

- (id)jsonValidator {
    return nil;
}

- (BOOL)statusCodeValidator {
    NSInteger statusCode = [self responseStatusCode];
    return (statusCode >= 200 && statusCode <= 299);
}

#pragma mark - NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ URL: %@ } { method: %@ } { arguments: %@ }", NSStringFromClass([self class]), self, self.currentRequest.URL, self.currentRequest.HTTPMethod, self.requestArgument];
}


@end
