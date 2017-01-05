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

- (void) initEncode:(int)width height:(int)height{
    dispatch_sync(aQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &EncodingSession);
        
        if (status != 0)
        {
            return ;
        }
        
        // 设置实时编码输出，降低编码延迟
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        NSLog(@"set realtime  return: %d", (int)status);
        
        // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
        status = VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        NSLog(@"set profile   return: %d", (int)status);
        
        // 设置编码码率(比特率)，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊
        int bitRate = width * height * 33 * 44 * 8;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        
        int bitRateLimit = width * height * 33 * 4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        NSLog(@"set bitrate   return: %d", (int)status);
       
        
        // 设置关键帧间隔，即gop size
        int keyrat = 25;
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, CFNumberCreate(NULL, kCFNumberIntType, &keyrat));
        
        // 设置帧率，只用于初始化session，不是实际FPS
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(keyrat));
        NSLog(@"set framerate return: %d", (int)status);
        
        // 开始编码
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        NSLog(@"start encode  return: %d", (int)status);
        
    });
}

// 编码回调，每当系统编码完一帧之后，会异步掉用该方法
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer ) {
    if (status != noErr) {
        NSLog(@"didCompressH264 error: with status %d, infoFlags %d", (int)status, (int)infoFlags);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)){
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264Encoder* encoder = (__bridge H264Encoder*)outputCallbackRefCon;
    // 判断当前帧是否为关键帧
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    // 获取sps & pps数据. sps pps只需获取一次，保存在h264文件开头即可
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found pps
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                dispatch_queue_t sendQueue = encoder->queue;
                dispatch_async(sendQueue, ^{
                    [encoder gotSpsPps:encoder->sps pps:encoder->pps];
                });
            }
        }
    }

    size_t lengthAtOffset, totalLength;
    char *dataPointer;
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    OSStatus error = CMBlockBufferGetDataPointer(dataBuffer, 0, &lengthAtOffset, &totalLength, &dataPointer);
    
    if (error == noErr) {
        size_t bufferOffset = 0;
        const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t naluLength = 0;
            memcpy(&naluLength, dataPointer + bufferOffset, AVCCHeaderLength); // 获取nalu的长度，
            
            // 大端模式转化为系统端模式
            naluLength = CFSwapInt32BigToHost(naluLength);
            NSLog(@"got nalu data, length=%d, totalLength=%zu", naluLength, totalLength);
             // 保存nalu数据到文件
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:naluLength];
           
            dispatch_queue_t sendQueue = encoder->queue;
            dispatch_async(sendQueue, ^{
                [encoder gotEncodedData:data isKeyFrame:keyframe];
            });
            
            // 读取下一个nalu，一次回调可能包含多个nalu
            bufferOffset += AVCCHeaderLength + naluLength;
        }
    }
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame{
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
//    if (VideoEncodeData == nil)
//    {
//        VideoEncodeData = [[NSMutableData alloc]init];
//    }
//    
//    [VideoEncodeData appendData:ByteHeader];
//    [VideoEncodeData appendData:spsdata];
//    [VideoEncodeData appendData:ByteHeader];
//    [VideoEncodeData appendData:ppsdata];
//    if(SPSSended == NO)
//    {
//        
//        SPSSended = [delegate gotSPSPPS:VideoEncodeData];
//    }
}

- (void)gotSpsPps:(NSData*)spsdata pps:(NSData*)ppsdata{
    
}

@end
