//
//  MLYNetworkConfig.m
//  Network
//
//  Created by eric on 16/12/7.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "MLYNetworkConfig.h"

@implementation MLYNetworkConfig

+ (instancetype)sharedConfig {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

@end
