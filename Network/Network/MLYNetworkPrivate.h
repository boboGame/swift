//
//  MLYNetworkPrivate.h
//  Network
//
//  Created by eric on 16/12/8.
//  Copyright © 2016年 eric. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MLYBaseRequest.h"
NS_ASSUME_NONNULL_BEGIN

@interface MLYNetworkUtils : NSObject

+ (BOOL)validateJSON:(id)json withValidator:(id)jsonValidator;

+ (NSString *)appVersionString;

+ (NSStringEncoding)stringEncodingWithRequest:(MLYBaseRequest *)request;

+ (void)setDoNotBackupAttribute:(NSString *)path;

+ (NSString *)md5StringFromString:(NSString *)string;

+ (BOOL)validateResumeData:(NSData *)data;

@end

@interface MLYBaseRequest (Setter)

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite, nullable) NSData *responseData;
@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;
@property (nonatomic, strong, readwrite, nullable) id responseObject;
@property (nonatomic, strong, readwrite, nullable) NSString *responseString;
@property (nonatomic, strong, readwrite, nullable) NSError *error;

@end

@interface MLYBaseRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack;
- (void)toggleAccessoriesWillStopCallBack;
- (void)toggleAccessoriesDidStopCallBack;

@end

NS_ASSUME_NONNULL_END
