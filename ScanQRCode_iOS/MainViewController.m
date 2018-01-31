//
//  MainViewController.m
//  ScanQRCode_iOS
//
//  Created by 王增战 on 2018/1/29.
//  Copyright © 2018年 Mr. Wang. All rights reserved.
//

#import "MainViewController.h"

#import "ScanViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Demo";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *scanBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [scanBtn setBackgroundColor:[UIColor lightGrayColor]];
    [scanBtn setTitle:@"扫一扫" forState:UIControlStateNormal];
    [scanBtn addTarget:self action:@selector(openCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:scanBtn];
    
    scanBtn.frame = CGRectMake(0, 0, 80, 30);
    scanBtn.center = self.view.center;
}
/** 打开相机,实现扫一扫功能 */
- (void)openCamera:(UIButton *)sender {
    
    ScanViewController *scanVC = [[ScanViewController alloc] init];
    [self.navigationController pushViewController:scanVC animated:YES];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
