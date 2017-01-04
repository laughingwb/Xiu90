//
//  ViewController.h
//  CRabbitLive
//
//  Created by wangbo on 17/1/3.
//  Copyright © 2017年 wb. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "H264Encoder.h"

@interface ViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate> {
    AVCaptureConnection *videoConnection;
    AVCaptureVideoPreviewLayer *previewLayer;
    BOOL firstFrame;
    H264Encoder *h264Encoder;
}

@property (nonatomic, strong) AVCaptureDeviceInput *frontCamera;
@property (nonatomic, strong) AVCaptureDeviceInput *backCamera;
//当前使用的视频设备
@property (nonatomic, weak) AVCaptureDeviceInput *videoInputDevice;
//音频设备
@property (nonatomic, strong) AVCaptureDeviceInput *audioInputDevice;


//输出数据接收
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;

//会话
@property (nonatomic, strong) AVCaptureSession *captureSession;

@end

