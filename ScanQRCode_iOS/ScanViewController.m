//
//  ScanViewController.m
//  ScanQRCode_iOS
//
//  Created by 王增战 on 2018/1/9.
//  Copyright © 2018年 Mr. Wang. All rights reserved.
//

#import "ScanViewController.h"

#import <AVFoundation/AVFoundation.h>

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

//iPad
#define IS_PAD (UI_USER_INTERFACE_IDIOM()== UIUserInterfaceIdiomPad)
//iPhone
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM()== UIUserInterfaceIdiomPhone)

#define TopColor [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6]

#define TextSize 13

@interface ScanViewController ()<AVCaptureMetadataOutputObjectsDelegate, UIAlertViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, assign) CGFloat scanWindowW;
@property (nonatomic, strong) UIView *scanWindow;
@property (nonatomic, strong) UIImageView *scanNetImageView;

@property (nonatomic, strong) UILabel *tipLabel;


@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic, strong) UIColor *oldColor;

@property (nonatomic, strong) UIView *tipsBgView;

@property (nonatomic, assign) BOOL isIphoneX;

@end

@implementation ScanViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIView *statusBar = [[[UIApplication sharedApplication] valueForKey:@"statusBarWindow"] valueForKey:@"statusBar"];
    self.oldColor = statusBar.backgroundColor;
    statusBar.backgroundColor = [UIColor clearColor];
    self.navigationController.navigationBar.hidden = YES;
  
    [self resumeAnimation];

//   self.navigationController.navigationBar.backgroundColor = TopColor;
//    //设置导航栏背景图片为一个空的image，这样就透明了
//    [self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    //去掉透明后导航栏下边的黑边
//    [self.navigationController.navigationBar setShadowImage:[[UIImage alloc] init]];
    
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //如果不想让其他页面的导航栏变为透明 需要重置
    UIView *statusBar = [[[UIApplication sharedApplication] valueForKey:@"statusBarWindow"] valueForKey:@"statusBar"];
    statusBar.backgroundColor = self.oldColor;
    self.navigationController.navigationBar.hidden = NO;
    
    [_captureSession stopRunning];

    //熄灭闪关灯
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    [device setTorchMode:AVCaptureTorchModeOff];
    [device unlockForConfiguration];

    
    
//    [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
//    self.navigationController.navigationBar.backgroundColor = [UIColor whiteColor];
//    [self.navigationController.navigationBar setShadowImage:nil];
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.isIphoneX = ([[UIApplication sharedApplication] statusBarFrame].size.height==20) ? NO:YES;
    
    [self setupNavigationBar];
    
    /** 区分iPhone和iPad，对iPad横屏的情况适配，设定中间的显示框的宽度为屏幕窄边的0.67倍 */
    self.scanWindowW = (SCREEN_WIDTH > SCREEN_HEIGHT) ? (0.67*SCREEN_HEIGHT):(0.67*SCREEN_WIDTH);
    
    [self setupTipView];
    
    [self setupScanWindow];
    
//    [self beginScanAnimation];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeAnimation) name:@"EnterForeground" object:nil];
    
}

#pragma mark - 导航栏

- (void)setupNavigationBar {
    
//    self.title = @"二维码/条码";
    self.view.backgroundColor = [UIColor whiteColor];
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"相册" style:UIBarButtonItemStylePlain target:self action:@selector(openAlbum)];

    //1.下边栏
    UIView *TopBar = [[UIView alloc] init];
    TopBar.backgroundColor = TopColor;
    TopBar.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:TopBar];
    
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(TopBar) format:@"H:|[TopBar]|"]];
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(TopBar) format:[NSString stringWithFormat:@"V:|[TopBar(%d)]", self.isIphoneX ? 88:64]]];
    
    // 取消
    UIButton *CancleBtn=[UIButton buttonWithType:UIButtonTypeSystem];
    CancleBtn.translatesAutoresizingMaskIntoConstraints = false;
    [CancleBtn setTitle:@"取消" forState:UIControlStateNormal];
    [CancleBtn setTintColor:[UIColor whiteColor]];
//    CancleBtn.titleLabel.font = [UIFont systemFontOfSize:<#(CGFloat)#>];
    [CancleBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [TopBar addSubview:CancleBtn];
    
    //闪光灯
//    UIButton * flashBtn=[UIButton buttonWithType:UIButtonTypeSystem];
//    flashBtn.translatesAutoresizingMaskIntoConstraints = false;
//    [flashBtn setTitle:@"开闪光" forState:UIControlStateNormal];
//    [flashBtn setTitle:@"关闪光" forState:UIControlStateSelected];
//    [flashBtn setTintColor:[UIColor whiteColor]];
////    flashBtn.titleLabel.font = systemFont(17);
//    [flashBtn addTarget:self action:@selector(openFlash:) forControlEvents:UIControlEventTouchUpInside];
//    [TopBar addSubview:flashBtn];
    
    //闪光灯
    UIButton *albumBtn=[UIButton buttonWithType:UIButtonTypeSystem];
    albumBtn.translatesAutoresizingMaskIntoConstraints = false;
    [albumBtn setTitle:@"相册" forState:UIControlStateNormal];
    [albumBtn setTintColor:[UIColor whiteColor]];
    //    flashBtn.titleLabel.font = systemFont(17);
    [albumBtn addTarget:self action:@selector(openAlbum) forControlEvents:UIControlEventTouchUpInside];
    [TopBar addSubview:albumBtn];
    
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(CancleBtn) format:@"H:|-20-[CancleBtn(60)]"]];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(albumBtn) format:@"H:[albumBtn(60)]-20-|"]];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(CancleBtn) format:[NSString stringWithFormat:@"V:|-%d-[CancleBtn(44)]", self.isIphoneX ? 44:20]]];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(albumBtn) format:[NSString stringWithFormat:@"V:|-%d-[albumBtn(44)]", self.isIphoneX ? 44:20]]];
    
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.translatesAutoresizingMaskIntoConstraints = false;
    titleLab.text = @"二维码/条码";
    titleLab.textColor = [UIColor whiteColor];
    [TopBar addSubview:titleLab];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(titleLab) format:@"H:[titleLab]"]];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(titleLab) format:[NSString stringWithFormat:@"V:|-%d-[titleLab(44)]", self.isIphoneX ? 44:20]]];
    [TopBar addConstraint:[NSLayoutConstraint constraintWithItem:titleLab attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:TopBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    
    
}

#pragma mark - 初始化提示语

- (void)setupTipView {
    
    _tipLabel = [[UILabel alloc] init];
    _tipLabel.translatesAutoresizingMaskIntoConstraints = false;
    _tipLabel.text = @"将取景框对准二维码，即可自动扫描";
    _tipLabel.layer.cornerRadius = 12;
    _tipLabel.layer.masksToBounds = YES;
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _tipLabel.font = [UIFont systemFontOfSize:TextSize];
    _tipLabel.backgroundColor = [UIColor whiteColor];
    _tipLabel.alpha = 0.5;
    [self.view addSubview:_tipLabel];
    
    CGFloat width = [_tipLabel.text sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:TextSize]}].width;
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_tipLabel) format:[NSString stringWithFormat:@"H:[_tipLabel(%f)]", width+16]]];
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_tipLabel) format:@"V:[_tipLabel(25)]-60-|"]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_tipLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    
}

#pragma mark - 初始化扫描区域

- (void)setupScanWindow {
    _scanWindow = [[UIView alloc] init];
    _scanWindow.translatesAutoresizingMaskIntoConstraints = false;
    _scanWindow.clipsToBounds = YES;//必须裁剪边界，否则，网络扫描动画会越界
    [self.view addSubview:_scanWindow];
    
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_scanWindow) format:[NSString stringWithFormat:@"H:[_scanWindow(%f)]", _scanWindowW]]];
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_scanWindow) format:[NSString stringWithFormat:@"V:[_scanWindow(%f)]", _scanWindowW]]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scanWindow attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scanWindow attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
    
    UIImageView *topLeftImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_1"]];
    topLeftImgView.translatesAutoresizingMaskIntoConstraints = false;
    [_scanWindow addSubview:topLeftImgView];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(topLeftImgView) format:@"H:|[topLeftImgView(18)]"]];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(topLeftImgView) format:@"V:|[topLeftImgView(18)]"]];
    
    
    UIImageView *topRightImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_2"]];
    topRightImgView.translatesAutoresizingMaskIntoConstraints = false;
    [_scanWindow addSubview:topRightImgView];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(topRightImgView) format:@"H:[topRightImgView(18)]|"]];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(topRightImgView) format:@"V:|[topRightImgView(18)]"]];
    
    UIImageView *bottomLeftImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_3"]];
    bottomLeftImgView.translatesAutoresizingMaskIntoConstraints = false;
    [_scanWindow addSubview:bottomLeftImgView];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(bottomLeftImgView) format:@"H:|[bottomLeftImgView(18)]"]];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(bottomLeftImgView) format:@"V:[bottomLeftImgView(18)]|"]];
    
    UIImageView *bottomRightImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_4"]];
    bottomRightImgView.translatesAutoresizingMaskIntoConstraints = false;
    [_scanWindow addSubview:bottomRightImgView];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(bottomRightImgView) format:@"H:[bottomRightImgView(18)]|"]];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(bottomRightImgView) format:@"V:[bottomRightImgView(18)]|"]];
    
    _scanNetImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_net"]];
    
    [self setupShowTipForLight];
}

#pragma mark - 初始化手电筒的提示，在较暗环境下就提示打开，其他环境下关闭
- (void)setupShowTipForLight {
    
    _tipsBgView = [[UIView alloc] init];
    _tipsBgView.translatesAutoresizingMaskIntoConstraints = false;
    _tipsBgView.backgroundColor = [UIColor clearColor];
    [_scanWindow addSubview:_tipsBgView];
    
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_tipsBgView) format:@"H:[_tipsBgView(80)]"]];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_tipsBgView) format:@"V:[_tipsBgView(80)]-10-|"]];
    [_scanWindow addConstraint:[NSLayoutConstraint constraintWithItem:_tipsBgView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_scanWindow attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    
    UIImageView *lightImgView = [[UIImageView alloc] init];
    lightImgView.translatesAutoresizingMaskIntoConstraints = false;
    lightImgView.image = [UIImage imageNamed:@"flash_light_open"];
    [_scanWindow addSubview:lightImgView];
    
    UILabel *tipTextLab = [[UILabel alloc] init];
    tipTextLab.translatesAutoresizingMaskIntoConstraints = false;
    tipTextLab.text = @"轻击照亮";
    tipTextLab.textColor = [UIColor whiteColor];
    tipTextLab.font = [UIFont systemFontOfSize:TextSize];
    tipTextLab.textAlignment = NSTextAlignmentCenter;
    [_scanWindow addSubview:tipTextLab];
    
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(lightImgView) format:@"H:[lightImgView(20)]"]];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(tipTextLab) format:@"H:|[tipTextLab]|"]];
    [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(lightImgView, tipTextLab) format:@"V:[lightImgView(20)][tipTextLab(26)]-16-|"]];
    [_scanWindow addConstraint:[NSLayoutConstraint constraintWithItem:lightImgView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_scanWindow attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    
    
    _tipsBgView.userInteractionEnabled = YES;
    [_tipsBgView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openLightTorch)]];
    _tipsBgView.hidden = YES;
    
}

- (void)openLightTorch {
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    [device setTorchMode:AVCaptureTorchModeOn];
    [device unlockForConfiguration];
}


#pragma mark - 开始扫描动画

- (void)beginScanAnimation {
    
    AVCaptureDevice *currentDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:currentDevice error:nil];
    if (!deviceInput) {
        return;
    }
    
    AVCaptureMetadataOutput *deviceOutput = [[AVCaptureMetadataOutput alloc] init];
    [deviceOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    deviceOutput.rectOfInterest = self.view.bounds;
    
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    [_captureSession addInput:deviceInput];
    if ([_captureSession canAddOutput:deviceOutput]) {
        [_captureSession addOutput:deviceOutput];
    }

    if ([_captureSession canAddOutput:videoDataOutput]) {
        [_captureSession addOutput:videoDataOutput];
    }
    
    deviceOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];


    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _videoPreviewLayer.frame = self.view.layer.bounds;
    if (IS_PAD) {
        _videoPreviewLayer.connection.videoOrientation = [self captureVideoOrientationFromCurrentDeviceOrientation];
    }
    [self.view.layer insertSublayer:_videoPreviewLayer atIndex:0];
    
}

#pragma mark - 恢复动画

- (void)resumeAnimation {
    
    //开始捕获
    [_captureSession startRunning];
    
    CAAnimation *animation = [_scanNetImageView.layer animationForKey:@"translationAnimation"];
    if (animation) {
        CFTimeInterval pauseTime = _scanNetImageView.layer.timeOffset;
        CFTimeInterval beginTime = CACurrentMediaTime() - pauseTime;
        
        [_scanNetImageView.layer setTimeOffset:0.0];
        [_scanNetImageView.layer setBeginTime:beginTime];
        [_scanNetImageView.layer setSpeed:1.0];
        
    } else {
        _scanNetImageView.translatesAutoresizingMaskIntoConstraints = false;

        CABasicAnimation *scanNetAnimation = [CABasicAnimation animation];
        scanNetAnimation.keyPath = @"transform.translation.y";
        scanNetAnimation.byValue = @(_scanWindowW);
        scanNetAnimation.duration = 2.0;
        scanNetAnimation.repeatCount = MAXFLOAT;
        [_scanNetImageView.layer addAnimation:scanNetAnimation forKey:@"translationAnimation"];
        
        [_scanWindow addSubview:_scanNetImageView];
        [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_scanNetImageView) format:@"H:|[_scanNetImageView]|"]];
        [_scanWindow addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_scanNetImageView) format:[NSString stringWithFormat:@"V:[_scanNetImageView(%f)]", _scanWindowW]]];
        [_scanWindow addConstraint:[NSLayoutConstraint constraintWithItem:_scanNetImageView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_scanWindow attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
        
    }
}

- (AVCaptureVideoOrientation)captureVideoOrientationFromCurrentDeviceOrientation {
    
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
       
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;
        
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;
            
        default:
            break;
    }
    /** 屏幕朝上或朝下时 */
    return AVCaptureVideoOrientationLandscapeLeft;
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {

    if (metadataObjects.count > 0) {
        [_captureSession stopRunning];
        
        AVMetadataMachineReadableCodeObject *codeObject = [metadataObjects objectAtIndex:0];
        
        /** 处理扫描结果 */
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"scan result" message:codeObject.stringValue delegate:self cancelButtonTitle:@"Close" otherButtonTitles:@"Next", nil];
        [alertView show];
    }
    
    
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary *)metadataDict];
    CFRelease(metadataDict);
    
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    NSLog(@"%f", brightnessValue);
    
    
    AVCaptureDevice *myLightDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    /** 判断是否有闪关灯 */
    BOOL result = [myLightDevice hasTorch];
    if (brightnessValue<0 && result) {
        NSLog(@"需要开启闪光灯");
        if (self.tipsBgView.hidden == NO) {
            return;
        }
        self.tipsBgView.hidden = NO;
        
    } else {
        NSLog(@"不需要开启闪光灯");
        if (self.tipsBgView.hidden == YES) {
            return;
        }
        self.tipsBgView.hidden = YES;
    }
        
        

}

#pragma mark - alert delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == 0) {
        [self dismiss];
    } else {
        NSLog(@"哥们，你可以执行下一步了");
        [self.captureSession startRunning];
    }
}

- (void)dismiss {
    
    [self.navigationController popViewControllerAnimated:YES];
}


/** 从本地相册中获取目标 */
- (void)openAlbum {
    
    
}



- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}
#pragma mark - 采用VFL布局

+(NSArray<NSLayoutConstraint*> *) GetNSLayoutCont:(NSDictionary *) views  format:(NSString*)format
{
    NSArray<NSLayoutConstraint*>* data=[NSLayoutConstraint constraintsWithVisualFormat:format
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:views];
    return data;
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
