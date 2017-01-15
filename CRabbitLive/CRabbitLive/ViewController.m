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
    flvMuxer = [[FFmpegmuxer alloc]initOut:@"rtmp://123.206.206.239:1935/live/wwj"];
//    flvMuxer = [[FFmpegmuxer alloc]initOut:@"rtmp://120.76.157.99:1935/live/test"];
    firstFrame = YES;
    firstAudio = YES;
    [self initH264Encoder];
    [self initAACEncoder];
    [self createCaptureDevice];
    [self createOutput];
    
    [self createCaptureSession];
    [self createPreviewLayer];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)initH264Encoder {
    h264Encoder = [[H264Encoder alloc]init];
    h264Encoder.delegate = self;
    [h264Encoder initWithConfiguration];
}

-(void)initAACEncoder {
    iosAACEncoder = [[IOSAACEncoder alloc]init];
    iosAACEncoder.delegate = self;
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
    self.videoInputDevice = self.backCamera;
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
    [self.captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset1280x720]];
    
}

- (void)setDirection:(int)Direction{
    videoConnection.videoOrientation = Direction;
    previewLayer.connection.videoOrientation = videoConnection.videoOrientation;
}

//创建预览
-(void) createPreviewLayer {
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    previewLayer.frame = self.view.bounds;
    previewLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds));
    previewLayer.connection.videoOrientation = videoConnection.videoOrientation;
    [self.view.layer addSublayer:previewLayer];
 
    [self.captureSession startRunning];
    [self.captureSession beginConfiguration];
    
    videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    audioConnection = [self.audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    [self setDirection:UIDeviceOrientationPortrait];
    [self.captureSession commitConfiguration];
    
    [self.captureSession startRunning];
    

   
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (connection == videoConnection){
        if (firstFrame) {
            firstFrame = NO;
            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            int width = (int)CVPixelBufferGetHeight(pixelBuffer);
            int height = (int)CVPixelBufferGetWidth(pixelBuffer);
            [self gotVideoFmt:width height:height];
            [h264Encoder initEncode:width height:height];
        }
        [h264Encoder encode:sampleBuffer];
    }else if (connection == audioConnection) {
        if (firstAudio) {
            AudioStreamBasicDescription inputFormat = *(CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer)));
            if ([iosAACEncoder initEncode:inputFormat]) {
                [self gotAudioFmt:inputFormat.mSampleRate Channels:inputFormat.mChannelsPerFrame SampleBytes:[iosAACEncoder GetAudioFmt:inputFormat.mFormatFlags FmtBits:inputFormat.mBitsPerChannel]];
                
                firstAudio = NO;
            }else {
                return;
            }
        }
        int nSize = (int)CMSampleBufferGetTotalSampleSize(sampleBuffer);
        char szBuf[8192];
        if ([iosAACEncoder encoderAAC:sampleBuffer aacData:szBuf aacLen:&nSize]){
            NSData *aacdata = [NSData dataWithBytes:szBuf length:nSize];
            [self gotAudioData:aacdata];
        }
    }
}

-(void)gotAudioData:(NSData*)data{
    if (videoinited && audioinited && spsPPSseted){
        int ret = [flvMuxer WriteStreamAudioData:((uint8_t*)[data bytes]) DataLen:(int)[data length]];
        //int ret = WriteStreamAudioData(((uint8_t*)[data bytes]),  (int)[data length]);
        if(ret < 0)
            NSLog(@"audio write error %d",ret);
    }
}

-(void)gotVideoFmt:(int)width height:(int)height{
    NSLog(@"width:%d height:%d",width,height);
    [flvMuxer InitVideoStream:width VideoHeight:height FrameRate:25];
    videoinited = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - H264Encoder
-(void)gotVideoData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame {
    static BOOL first = YES;
    if (videoinited && audioinited && spsPPSseted){
        if(first){
            if (isKeyFrame == NO) return;
            first = NO;
        }
        int ret = [flvMuxer WriteStreamVideoData:((uint8_t*)[data bytes]) DataLen:(int)[data length] KeyFlag:isKeyFrame];
        //int ret = WriteStreamVideoData(((uint8_t*)[data bytes]) ,  (int)[data length]);
        if(ret < 0) {
            NSLog(@"video write error %d",ret);
        }
    }
}

-(BOOL)gotSPSPPS:(NSData*)SPSPPS {
    if (videoinited == NO) {
        return NO;
    }
    [flvMuxer SetH264SPSPPS:SPSPPS];
    spsPPSseted = YES;
    return YES;
}

#pragma mark - AACEncoder
-(void)gotAudioFmt:(int)SampleRate Channels:(int)channels SampleBytes:(enum Audio_Format_Type)SampleBytes {
    [flvMuxer InitAudioStream:channels AudioSampleRate:SampleRate SampleDataFmt:0];
    audioinited = YES;
}

@end
