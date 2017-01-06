//
//  H264Encoder.h
//  CRabbitLive
//
//  Created by wangbo on 17/1/4.
//  Copyright © 2017年 wb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VTCompressionProperties.h>
@import VideoToolbox;
@import AVFoundation;

@protocol H264EncoderDelegate <NSObject>
-(void)gotVideoData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame;
-(void)gotVideoFmt:(int)width height:(int)height;
-(void)gotAudioData:(NSData*)data;
-(void)gotAudioFmt:(int)SampleRate Channels:(int)channels SampleBytes:(enum Audio_Format_Type)SampleBytes;
-(BOOL)gotSPSPPS:(NSData*)SPSPPS;
@end

@interface H264Encoder : NSObject {
    VTCompressionSessionRef EncodingSession;
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef  format;
    CMSampleTimingInfo * timingInfo;
    BOOL initialized;
    int  frameCount;
    NSData *sps;
    NSData *pps;
    dispatch_queue_t queue;
    NSMutableData *videoEncodeData;
    BOOL spsSended;
}

@property(nonatomic,assign)id<H264EncoderDelegate>delegate;
- (void) initEncode:(int)width  height:(int)height;
- (void) initWithConfiguration;
- (void) encode:(CMSampleBufferRef )sampleBuffer;
@end
