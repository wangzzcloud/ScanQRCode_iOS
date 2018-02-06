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

@interface ScanViewController ()<AVCaptureMetadataOutputObjectsDelegate, UIAlertViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

/** 是否是iPhone X */
@property (nonatomic, assign) BOOL isIphoneX;
/** 进入到此页面时状态栏的颜色，防止对自定义状态栏产生影响 */
@property (nonatomic, strong) UIColor *oldColor;

/** 扫描区域宽度 */
@property (nonatomic, assign) CGFloat scanWindowW;
/** 网格的父视图 */
@property (nonatomic, strong) UIView *scanWindow;
/** 网格 */
@property (nonatomic, strong) UIImageView *scanNetImageView;

/** 屏幕中的提示 */
@property (nonatomic, strong) UILabel *tipLabel;

/** 闪光灯所在父视图 */
@property (nonatomic, strong) UIView *tipsBgView;
/** 闪光灯文字提示 */
@property (nonatomic, strong) UILabel *tipTextLab;

/** 摄像设备 */
@property (nonatomic, strong) AVCaptureDevice *captureDevice;
/** 链接对象 */
@property (nonatomic, strong) AVCaptureSession *captureSession;
/** 摄像头捕捉内容显示图层 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;


@property (nonatomic) UIImagePickerController *imagePicker;



@end

@implementation ScanViewController

/** 摄像头设备初始化 */
- (AVCaptureDevice *)captureDevice {
    
    if (_captureDevice == nil) {
        _captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return _captureDevice;
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIView *statusBar = [[[UIApplication sharedApplication] valueForKey:@"statusBarWindow"] valueForKey:@"statusBar"];
    self.oldColor = statusBar.backgroundColor;
    statusBar.backgroundColor = [UIColor clearColor];

    self.navigationController.navigationBar.hidden = YES;
  
    [self resumeAnimation];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //如果不想让其他页面的状态栏变为透明 需要重置
    UIView *statusBar = [[[UIApplication sharedApplication] valueForKey:@"statusBarWindow"] valueForKey:@"statusBar"];
    statusBar.backgroundColor = self.oldColor;
    self.navigationController.navigationBar.hidden = NO;
    
    [_captureSession stopRunning];

    //如果闪光灯是亮着的，就熄灭闪光灯
    if (self.captureDevice.torchMode == AVCaptureTorchModeOn) {
        [self.captureDevice lockForConfiguration:nil];
        [self.captureDevice setTorchMode:AVCaptureTorchModeOff];
        [self.captureDevice unlockForConfiguration];
    }
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.isIphoneX = ([[UIApplication sharedApplication] statusBarFrame].size.height==20) ? NO:YES;
    /** 区分iPhone和iPad，对iPad横屏的情况适配，设定中间的显示框的宽度为屏幕窄边的0.67倍 */
    if (IS_PAD) {
        self.scanWindowW = (SCREEN_WIDTH > SCREEN_HEIGHT) ? (0.6*SCREEN_HEIGHT):(0.6*SCREEN_WIDTH);
    }else {
        self.scanWindowW = (SCREEN_WIDTH > SCREEN_HEIGHT) ? (0.67*SCREEN_HEIGHT):(0.67*SCREEN_WIDTH);
    }

    [self setupNavigationBar];
    
    [self setupTipView];
    
    [self setupScanWindow];
    
    [self beginScanAnimation];
    
    /** 如果App进入后台，关闭 */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeAnimation) name:@"EnterForeground" object:nil];
    
}

#pragma mark - 导航栏

- (void)setupNavigationBar {
    
    //1.下边栏
    UIView *TopBar = [[UIView alloc] init];
    TopBar.backgroundColor = TopColor;
    TopBar.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:TopBar];
    
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(TopBar) format:@"H:|[TopBar]|"]];
    [self.view addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(TopBar) format:[NSString stringWithFormat:@"V:|[TopBar(%d)]", self.isIphoneX ? 88:64]]];
    
    //取消
    UIButton *CancleBtn=[UIButton buttonWithType:UIButtonTypeSystem];
    CancleBtn.translatesAutoresizingMaskIntoConstraints = false;
    [CancleBtn setTitle:@"取消" forState:UIControlStateNormal];
    [CancleBtn setTintColor:[UIColor whiteColor]];
    [CancleBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [TopBar addSubview:CancleBtn];
    
    //相册按钮
    UIButton *albumBtn=[UIButton buttonWithType:UIButtonTypeSystem];
    albumBtn.translatesAutoresizingMaskIntoConstraints = false;
    [albumBtn setTitle:@"相册" forState:UIControlStateNormal];
    [albumBtn setTintColor:[UIColor whiteColor]];
    [albumBtn addTarget:self action:@selector(openAlbum) forControlEvents:UIControlEventTouchUpInside];
    [TopBar addSubview:albumBtn];
    
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(CancleBtn) format:@"H:|-20-[CancleBtn(60)]"]];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(albumBtn) format:@"H:[albumBtn(60)]-20-|"]];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(CancleBtn) format:[NSString stringWithFormat:@"V:|-%d-[CancleBtn(44)]", self.isIphoneX ? 44:20]]];
    [TopBar addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(albumBtn) format:[NSString stringWithFormat:@"V:|-%d-[albumBtn(44)]", self.isIphoneX ? 44:20]]];
    
    //title
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
    [_tipsBgView addSubview:lightImgView];
    
    _tipTextLab = [[UILabel alloc] init];
    _tipTextLab.translatesAutoresizingMaskIntoConstraints = false;
    _tipTextLab.text = @"轻击照亮";
    _tipTextLab.textColor = [UIColor whiteColor];
    _tipTextLab.font = [UIFont systemFontOfSize:TextSize];
    _tipTextLab.textAlignment = NSTextAlignmentCenter;
    [_tipsBgView addSubview:_tipTextLab];
    
    [_tipsBgView addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(lightImgView) format:@"H:[lightImgView(20)]"]];
    [_tipsBgView addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(_tipTextLab) format:@"H:|[_tipTextLab]|"]];
    [_tipsBgView addConstraints:[ScanViewController GetNSLayoutCont:NSDictionaryOfVariableBindings(lightImgView, _tipTextLab) format:@"V:[lightImgView(20)][_tipTextLab(26)]-16-|"]];
    [_tipsBgView addConstraint:[NSLayoutConstraint constraintWithItem:lightImgView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_tipsBgView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    
    _tipsBgView.userInteractionEnabled = YES;
    [_tipsBgView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openLightTorch)]];
    _tipsBgView.hidden = YES;
    
}

- (void)openLightTorch {

    [self.captureDevice lockForConfiguration:nil];

    if ([_tipTextLab.text isEqualToString:@"轻击照亮"]) {
        [self.captureDevice setTorchMode:AVCaptureTorchModeOn];
        _tipTextLab.text = @"轻击关闭";
    }else {
        _tipTextLab.text = @"轻击照亮";
        [self.captureDevice setTorchMode:AVCaptureTorchModeOff];
    }
    
   [self.captureDevice unlockForConfiguration];
}


#pragma mark - 开始扫描动画

- (void)beginScanAnimation {
    
    /** 创建输入流 */
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:nil];
    if (!deviceInput) {
        return;
    }
    /** 创建输出流 */
    AVCaptureMetadataOutput *deviceOutput = [[AVCaptureMetadataOutput alloc] init];
    /** 设置代理，在主线程刷新 */
    [deviceOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    /** 设置有效扫描区域 */
    deviceOutput.rectOfInterest = self.view.bounds;
    
    /** 创建另一个输出流：主要用来实时检测光线的 */
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    /** 初始化链接对象 */
    _captureSession = [[AVCaptureSession alloc] init];
    /** 设置采集质量 */
    [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    
    /** 配置 */
    [_captureSession addInput:deviceInput];
    if ([_captureSession canAddOutput:deviceOutput]) {
        [_captureSession addOutput:deviceOutput];
    }

    if ([_captureSession canAddOutput:videoDataOutput]) {
        [_captureSession addOutput:videoDataOutput];
    }
    
    /** 设置扫码支持的格式，兼容二维码、条形码 */
    deviceOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];

    /** 设置显示层 */
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _videoPreviewLayer.frame = self.view.layer.bounds;
    if (IS_PAD) {
        /** 因为在iPad中，屏幕是支持旋转的，所以在这里添加方法，支持屏幕旋转 */
        _videoPreviewLayer.connection.videoOrientation = [self captureVideoOrientationFromCurrentDeviceOrientation];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    }
    [self.view.layer insertSublayer:_videoPreviewLayer atIndex:0];
    
}
- (AVCaptureVideoOrientation)captureVideoOrientationFromCurrentDeviceOrientation {
    
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
            
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
            
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft;
            
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight;
            
        default:
            break;
    }
    /** 屏幕朝上或朝下时 */
    return AVCaptureVideoOrientationLandscapeLeft;
}

/** 屏幕旋转后，刷新界面 */
- (void)deviceOrientationDidChange:(NSNotification *)note {
    
    self.videoPreviewLayer.frame = CGRectMake(0, 0, self.navigationController.view.frame.size.width, self.navigationController.view.frame.size.height);
    self.videoPreviewLayer.connection.videoOrientation = [self captureVideoOrientationFromCurrentDeviceOrientation];
    
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


#pragma mark - AVCaptureMetadataOutputObjectsDelegate
/** 在此处处理扫描的结果 */
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
/** 检测光线 */
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary *)metadataDict];
    CFRelease(metadataDict);
    
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    NSLog(@"%f", brightnessValue);
    
    /** 判断是否有闪关灯 */
    BOOL result = [self.captureDevice hasTorch];
    if (brightnessValue<0 && result) {
        if (self.tipsBgView.hidden == NO) {
            return;
        }
        self.tipsBgView.hidden = NO;
        NSLog(@"需要开启闪光灯");
        
    } else {
        if (self.tipsBgView.hidden == YES) {
            return;
        }
        /** 开启闪关灯之后，就不能隐藏了，需要手动关闭 */
        if (self.captureDevice.torchMode == AVCaptureTorchModeOn) {
            return;
        }
        self.tipsBgView.hidden = YES;
        NSLog(@"不需要开启闪光灯");
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

#pragma mark - 识别相册中的二维码或条码

- (UIImagePickerController *)imagePicker {
    
    if (nil == _imagePicker) {
        _imagePicker = [[UIImagePickerController alloc] init];
        _imagePicker.modalPresentationStyle = UIModalPresentationFullScreen;
        _imagePicker.delegate = self;
    }
    return _imagePicker;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
    UIImage *selectImage = info[UIImagePickerControllerOriginalImage];
    NSLog(@"大哥选择的图片是%@", selectImage);
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    
}

/** 从本地相册中获取目标 */
- (void)openAlbum {
    
    if (!IS_PAD) {
        
        self.imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//        self.imagePicker.mediaTypes = @[(NSString *)kUTTypeImage];
        [self presentViewController:self.imagePicker animated:YES completion:nil];
        
    } else {
        
    }
    
}






- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}
#pragma mark - 采用VFL布局

+(NSArray<NSLayoutConstraint*> *) GetNSLayoutCont:(NSDictionary *) views  format:(NSString *)format
{
    NSArray<NSLayoutConstraint *> *data=[NSLayoutConstraint constraintsWithVisualFormat:format
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
