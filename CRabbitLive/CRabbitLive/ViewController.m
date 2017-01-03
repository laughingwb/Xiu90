//
//  ViewController.m
//  CRabbitLive
//
//  Created by wangbo on 17/1/3.
//  Copyright © 2017年 wb. All rights reserved.
//

#import "ViewController.h"
#include "avformat.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
 
    av_register_all();
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
