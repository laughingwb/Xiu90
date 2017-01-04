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
    avformat_version();
    [self createCaptureDevice];
    [self createOutput];
    [self createCaptureSession];
    [self createPreviewLayer];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)createCaptureDevice {
    //创建视频设备
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    //初始化摄像头
    self.frontCamera = [AVCaptureDeviceInput deviceInputWithDevice:videoDevices.firstObject error:nil];
    self.backCamera =[AVCaptureDeviceInput deviceInputWithDevice:videoDevices.lastObject error:nil];
    
    //麦克风
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioInputDevice = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    self.videoInputDevice = self.frontCamera;
}

-(void)createOutput {
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    dispatch_queue_t captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self.videoDataOutput setSampleBufferDelegate:self queue:captureQueue];
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    [self.videoDataOutput setVideoSettings:@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)}];
    
    
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioDataOutput setSampleBufferDelegate:self queue:captureQueue];
}


//创建会话
-(void) createCaptureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    if ([self.captureSession canAddInput:self.videoInputDevice]) {
        [self.captureSession addInput:self.videoInputDevice];
    }
    
    if ([self.captureSession canAddInput:self.audioInputDevice]) {
        [self.captureSession addInput:self.audioInputDevice];
    }
    
    if([self.captureSession canAddOutput:self.videoDataOutput]){
        [self.captureSession addOutput:self.videoDataOutput];
    }
    
    if([self.captureSession canAddOutput:self.audioDataOutput]){
        [self.captureSession addOutput:self.audioDataOutput];
    }
    [self.captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPresetHigh]];
    [self.captureSession startRunning];
    [self.captureSession beginConfiguration];
    
    [self.captureSession commitConfiguration];
    
    [self.captureSession startRunning];
    
    videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
}

//创建预览
-(void) createPreviewLayer {
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    previewLayer.frame = self.view.bounds;
    previewLayer.connection.videoOrientation = videoConnection.videoOrientation;
    previewLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds));
    [self.view.layer addSublayer:previewLayer];
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (connection == videoConnection){
        
    }else {
        
    }
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
