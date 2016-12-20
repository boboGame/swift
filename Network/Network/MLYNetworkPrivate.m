//
//  MLYNetworkPrivate.m
//  Network
//
//  Created by eric on 16/12/8.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "MLYNetworkPrivate.h"
#import <CommonCrypto/CommonDigest.h>

@implementation MLYNetworkUtils

+ (BOOL)validateJSON:(id)json withValidator:(id)jsonValidator {
    if ([json isKindOfClass:[NSDictionary class]] && [jsonValidator isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = json;
        NSDictionary *validator = jsonValidator;
        BOOL result = YES;
        NSEnumerator *enumerator = [validator keyEnumerator];
        NSString *key;
        while ((key = enumerator.nextObject) != nil) {
            id value = dict[key];
            id format = validator[key];
            if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
                result = [self validateJSON:value withValidator:format];
                if (!result) {
                    break;
                }
            }else {
                if ([value isKindOfClass:format] == NO && [value isKindOfClass:[NSNull class]] == NO) {
                    result = NO;
                    break;
                }
            }
        }
        return result;
    }else if ([json isKindOfClass:[NSArray class]] && [jsonValidator isKindOfClass:[NSArray class]]) {
        NSArray *validatorArray = (NSArray *)jsonValidator;
        if (validatorArray.count > 0) {
            NSArray *array = json;
            NSDictionary *validator = validatorArray[0];
            for (id item in array) {
                BOOL result = [self validateJSON:item withValidator:validator];
                if (!result) {
                    return NO;
                }
            }
        }
        return YES;
    }else if ([json isKindOfClass:jsonValidator]){
        return YES;
    }else {
        return NO;
    }
}

+ (NSString *)appVersionString {
    return [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
}

+ (NSStringEncoding)stringEncodingWithRequest:(MLYBaseRequest *)request {
    NSStringEncoding stringEncoding = NSUTF8StringEncoding;
    if (request.respons.textEncodingName) {
        CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)request.respons.textEncodingName);
        stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);
    }
    return stringEncoding;
}

+ (void)setDoNotBackupAttribute:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
    if (error) {
        NSLog(@"error to set do not backup attribute error:%@",error);
    }
}

+ (NSString *)md5StringFromString:(NSString *)string {
    NSParameterAssert(string && string.length > 0);
    const char *value = [string UTF8String];
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    NSMutableString *outputString = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i ++) {
        [outputString stringByAppendingFormat:@"%02x",outputBuffer[i]];
    }
    return outputString;
}

+ (BOOL)validateResumeData:(NSData *)data {
    // From http://stackoverflow.com/a/22137510/3562486
    if (!data || [data length] < 1) return NO;
    
    NSError *error;
    NSDictionary *resumeDictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    if (!resumeDictionary || error) return NO;
    
    // Before iOS 9 & Mac OS X 10.11
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED < 90000)\
|| (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED < 101100)
    NSString *localFilePath = [resumeDictionary objectForKey:@"NSURLSessionResumeInfoLocalPath"];
    if ([localFilePath length] < 1) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:localFilePath];
#endif
    // After iOS 9 we can not actually detects if the cache file exists. This plist file has a somehow
    // complicated structue. Besides, the plist structure is different between iOS 9 and iOS 10.
    // We can only assume that the plist being successfully parsed means the resume data is valid.
    return YES;
}

@end

@implementation MLYBaseRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack {
    for (id<MLYRequestAccesory> accessory in self.requestAccessories) {
        [accessory requestWillStart:self];
    }
}

- (void)toggleAccessoriesWillStopCallBack {
    for (id<MLYRequestAccesory> accessory in self.requestAccessories) {
        [accessory requestWillStop:self];
    }
}

- (void)toggleAccessoriesDidStopCallBack {
    for (id<MLYRequestAccesory> accessory in self.requestAccessories) {
        [accessory requestDidStop:self];
    }
}

@end
