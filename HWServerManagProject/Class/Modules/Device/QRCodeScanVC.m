//
//  QRCodeScanVC.m
//  QRDemo
//
//  这是一个最简化的二维码/条形码扫描VC可以在此基础上添加扫描动画等效果
//
//  Created by 陈主祥 on 16/1/25.
//  Copyright © 2016年 陈主祥. All rights reserved.
//

#import "QRCodeScanVC.h"
#import "DeviceDetailViewController.h"
#import "AppDelegate.h"

#define BOXWIDTH  250 //扫描范围宽度
#define BOXHEIGHT 250 //扫描范围高度

@interface QRCodeScanVC () <AVCaptureMetadataOutputObjectsDelegate>

@property (strong, nonatomic) AVCaptureSession * captureSession;//捕获会话
@property (strong, nonatomic) AVCaptureVideoPreviewLayer * captureVideoPreviewLayer;//视频预览层

@end

@implementation QRCodeScanVC {
    UILabel *sLabel;
    UIButton *sdtBtn;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    self.title = LocalString(@"scan");
//    [self createBackBtn];
    self.view.backgroundColor = [UIColor blackColor];
    
   
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    //要在页面完全显示之后执行
    [self lazyExcute];
    if (sdtBtn == nil) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, 0, 30, 30);
        btn.center = CGPointMake(ScreenWidth/2, (ScreenHeight-NavHeight)/2 + BOXHEIGHT/2 - 40);
        [self.view addSubview:btn];
        [btn setImage:[UIImage imageNamed:@"one_sdt"] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(turnTorchOn:) forControlEvents:UIControlEventTouchUpInside];
        sdtBtn = btn;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (sdtBtn.selected) {
        [self turnTorchOn:sdtBtn];
    }
}

//- (void)createBackBtn {
//
//    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
//    if (@available(iOS 11.0, *)) {
//        btn.frame = CGRectMake(0,0, 60, 44);
//    } else {
//        btn.frame = CGRectMake(0,0, 70, 44);
//    }
//    [btn setImage:[UIImage imageNamed:@"one_navBackicon"] forState:UIControlStateNormal];
//    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//    [btn setTitle:@" 返回" forState:UIControlStateNormal];
//    btn.titleLabel.font = [UIFont systemFontOfSize:15];
//    [btn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
//
//    UIBarButtonItem *nextbuttonitem = [[UIBarButtonItem alloc] initWithCustomView:btn];
//
//    self.navigationItem.leftBarButtonItem = nextbuttonitem;
//    [nextbuttonitem setTintColor:HEXCOLOR(0xffffff)];
//
//}
//
//- (void)backAction {
//    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
//}


#pragma mark - 延迟执行
- (void)lazyExcute{
    if (![self isAuthorizationCamera]) {
        return ;
    }
    
    //添加通知设置 扫描范围
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationHandle:) name:AVCaptureInputPortFormatDescriptionDidChangeNotification object:nil];
    
    [self startScan];
    [self addMask];
}

#pragma mark - 判断是否具有调用摄像头权限
- (BOOL)isAuthorizationCamera{
    AVAuthorizationStatus authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authorizationStatus == AVAuthorizationStatusRestricted ||
        authorizationStatus == AVAuthorizationStatusDenied) {
        UIAlertController * alertVC = [UIAlertController alertControllerWithTitle:@"" message:LocalString(@"scan_device_access") preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertVC animated:YES completion:nil];
        
        UIAlertAction * action = [UIAlertAction actionWithTitle:LocalString(@"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }];
        
        UIAlertAction * action1 = [UIAlertAction actionWithTitle:LocalString(@"scan_device_Setting") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            dispatch_after(0.2, dispatch_get_main_queue(), ^{//添加多线程消除错误
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs:root=Privacy"]];//隐私设置
            });
        }];
        
        [alertVC addAction:action];
        [alertVC addAction:action1];
        return NO;
    }
    
    return YES;
}

#pragma mark - Notification 处理
- (void)notificationHandle:(NSNotification *)notification{
    AVCaptureMetadataOutput * output = (AVCaptureMetadataOutput*)_captureSession.outputs[0];
    CGRect rect = CGRectMake((CGRectGetWidth(self.view.frame)-BOXWIDTH)/2.0, (CGRectGetHeight(self.view.frame)-BOXHEIGHT)/2.0, BOXWIDTH, BOXHEIGHT);
    
    output.rectOfInterest = [_captureVideoPreviewLayer metadataOutputRectOfInterestForRect:rect];
}

#pragma mark - 设置遮罩层
- (void)addMask{
    
    UIView * maskView = [[UIView alloc] init];
    maskView.frame = CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds), CGRectGetHeight([UIScreen mainScreen].bounds));
    maskView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    [self.view addSubview:maskView];
    
    //创建路径
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, CGRectGetWidth(maskView.frame), CGRectGetHeight(maskView.frame))];//绘制和透明黑色遮盖层一样的矩形
    
    //路径取反
    [path appendPath:[[UIBezierPath bezierPathWithRect:CGRectMake((CGRectGetWidth(self.view.frame)-BOXWIDTH)/2.0, (CGRectGetHeight(self.view.frame)-BOXHEIGHT)/2.0, BOXWIDTH, BOXHEIGHT)] bezierPathByReversingPath]];//绘制中间空白透明的矩形，并且取反路径。这样整个绘制的范围就只剩下，中间的矩形和边界之间的部分
    
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = path.CGPath;//将路径交给layer绘制
    [maskView.layer setMask:shapeLayer];//设置遮罩层
    
    
    if (!sLabel) {
        sLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, (CGRectGetHeight(self.view.frame)-BOXHEIGHT)/2.0 + BOXHEIGHT + 10, ScreenWidth, 15)];
        sLabel.textAlignment = NSTextAlignmentCenter;
        sLabel.textColor = [UIColor whiteColor];
        sLabel.text = LocalString(@"scanqralert2");
        [self.view addSubview:sLabel];
        sLabel.font = [UIFont systemFontOfSize:14];
    }
}

#pragma mark - 开始扫描
- (void)startScan{
    NSError * error;
    //设置设备
    AVCaptureDevice * captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];//设置媒体类型AVMediaTypeVideo:视频类型；AVMediaTypeAudio:音频类型；AVMediaTypeMuxed：混合类型
    
    //设置获取设备输入
    AVCaptureDeviceInput * deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (!deviceInput) {//如果无法获取设备输入
        BLLog(@"%@",error.localizedDescription);
        return ;
    }
    
    //设置设备输出
    AVCaptureMetadataOutput * captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    
    //设置捕获会话
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession addInput:deviceInput];//设置设备输入
    [_captureSession addOutput:captureMetadataOutput];//设置设备输出
    
    //设置输出代理
    dispatch_queue_t dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    //设置解析数据类型 自行在这里添加需要识别的各种码
    [captureMetadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeQRCode,AVMetadataObjectTypeUPCECode]];
    
    //设置展示layer
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    _captureVideoPreviewLayer.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    [self.view.layer addSublayer:_captureVideoPreviewLayer];
    
    //放大1.5倍
    _captureVideoPreviewLayer.affineTransform = CGAffineTransformMakeScale(1.5, 1.5);
    AVCaptureOutput * output = (AVCaptureOutput *)_captureSession.outputs[0];
    AVCaptureConnection * focus = [output connectionWithMediaType:AVMediaTypeVideo];//获得摄像头焦点
    focus.videoScaleAndCropFactor = 1.5;//焦点放大
    
    //开始执行摄像头
    [_captureSession startRunning];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject * metadataObj = [metadataObjects objectAtIndex:0];
        //在这里获取解析出来的值
        //打印扫描出来的字符串
        [_captureSession stopRunning];//停止运行
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            AppDelegate *appdelete = (AppDelegate *)[UIApplication sharedApplication].delegate;
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.serialNumber = %@", [metadataObj stringValue]];
            
            NSArray *filterdArray = [[HWGlobalData shared].deviceDataArray filteredArrayUsingPredicate:predicate];
            if (filterdArray && filterdArray.count > 0) {
                [HWGlobalData shared].curDevice = [filterdArray firstObject];
                
                if ([HWGlobalData shared].curDevice.isKeepPwd) {
                    DeviceDetailViewController *vc = [DeviceDetailViewController new];
                    [weakSelf.navigationController pushViewController:vc animated:YES];
                } else {
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:LocalString(@"validation")
                                                                                             message:[HWGlobalData shared].curDevice.otherName
                                                                                      preferredStyle:UIAlertControllerStyleAlert];
                    
                    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                        textField.placeholder = LocalString(@"Pleaseenterpassword");
                        textField.secureTextEntry = YES;
                    }];
                    
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:LocalString(@"cancel") style:UIAlertActionStyleCancel handler:nil];
                    UIAlertAction *sureAction = [UIAlertAction actionWithTitle:LocalString(@"sure") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        UITextField *textF = alertController.textFields.firstObject;
                        
                        if ([textF.text isEqualToString:[HWGlobalData shared].curDevice.password]) {
                            DeviceDetailViewController *vc = [DeviceDetailViewController new];
                            [weakSelf.navigationController pushViewController:vc animated:YES];
                        } else {
                            [appdelete.window makeToast:LocalString(@"pwdmistake")];
                            [_captureSession startRunning];
                        }
                        
                        
                    }];
                    
                    [alertController addAction:cancelAction];
                    [alertController addAction:sureAction];
                    
                    
                    [weakSelf.navigationController presentViewController:alertController animated:YES completion:nil];
                }
            } else {
                [appdelete.window makeToast:LocalString(@"scan_device_is_not_available")];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            }

            
        });
        
    }
}

- (void)turnTorchOn:(UIButton *)btn {
    
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    
    if (captureDeviceClass != nil) {
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if ([device hasTorch] && [device hasFlash]){
            
            [device lockForConfiguration:nil];
            
            if (!btn.selected) {
                
                [device setTorchMode:AVCaptureTorchModeOn];
                
                [device setFlashMode:AVCaptureFlashModeOn];
                
                btn.selected = !btn.selected;
                
            } else {
                
                [device setTorchMode:AVCaptureTorchModeOff];
                
                [device setFlashMode:AVCaptureFlashModeOff];
                
                btn.selected = !btn.selected;

            }
            
            [device unlockForConfiguration];
            
        }
        
    }
    
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
