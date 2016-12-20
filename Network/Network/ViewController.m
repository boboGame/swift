//
//  ViewController.m
//  Network
//
//  Created by eric on 16/12/7.
//  Copyright © 2016年 eric. All rights reserved.
//

#import "ViewController.h"
#import "MLYTestApi.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [[MLYTestApi new] startWithCompletionBlockWithSuccess:^(__kindof MLYBaseRequest * _Nonnull request) {
        
    } failure:^(__kindof MLYBaseRequest * _Nonnull request) {
        
    }];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
