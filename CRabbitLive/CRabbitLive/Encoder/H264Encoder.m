//
//  H264Encoder.m
//  CRabbitLive
//
//  Created by wangbo on 17/1/4.
//  Copyright © 2017年 wb. All rights reserved.
//

#import "H264Encoder.h"

@implementation H264Encoder

- (void) initWithConfiguration{
    /*yuvFile = [documentsDirectory stringByAppendingPathComponent:@"test.i420"];
     
     if ([fileManager fileExistsAtPath:yuvFile] == NO) {
     NSLog(@"H264: File does not exist");
     return;
     }*/
    
    EncodingSession = nil;
    initialized = true;
    aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    frameCount = 0;
    sps = NULL;
    pps = NULL;
    
}

- (void) initEncode:(int)width  height:(int)height{
    dispatch_sync(aQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &EncodingSession);
        
        if (status != 0)
        {
            return ;
        }
        
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        int keyrat = 25;
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, CFNumberCreate(NULL, kCFNumberIntType, &keyrat));
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
    });
}
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer ) {
    
}

@end
