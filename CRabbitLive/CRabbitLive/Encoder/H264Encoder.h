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
@interface H264Encoder : NSObject {
    VTCompressionSessionRef EncodingSession;
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef  format;
    CMSampleTimingInfo * timingInfo;
    BOOL initialized;
    int  frameCount;
    NSData *sps;
    NSData *pps;
}


- (void) initEncode:(int)width  height:(int)height;
- (void) initWithConfiguration;
@end
