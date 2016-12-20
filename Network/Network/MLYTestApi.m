//
//  MLYTestApi.m
//  Network
//
//  Created by eric on 16/12/9.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "MLYTestApi.h"

@implementation MLYTestApi

- (id)requestArgument {
    return @{};
}

- (NSString *)requestUrl {
    return @"api/4/version/ios/2.3.0";
}

- (NSString *)baseUrl {
    return @"http://news-at.zhihu.com";
}

@end
