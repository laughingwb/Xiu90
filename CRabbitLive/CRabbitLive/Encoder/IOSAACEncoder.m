//
//  IOSAACEncoder.m
//  CRabbitLive
//
//  Created by wangbo on 17/1/11.
//  Copyright © 2017年 wb. All rights reserved.
//

#import "IOSAACEncoder.h"

@implementation IOSAACEncoder
@synthesize delegate;

-(BOOL)initEncode:(AudioStreamBasicDescription)inputFormat {
    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = inputFormat.mSampleRate; // 采样率保持一致
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;    // AAC编码
    outputFormat.mChannelsPerFrame = 2;
    outputFormat.mFramesPerPacket = 1024;                    // AAC一帧是1024个字节
    
    AudioClassDescription *desc = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    if (AudioConverterNewSpecific(&inputFormat, &outputFormat, 1, desc, &AudioConverter) != noErr)
    {
        return NO;
    }
    return YES;
}

-(AudioClassDescription*)getAudioClassDescriptionWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer { // 获得相应的编码器
    static AudioClassDescription audioDesc;
    
    UInt32 encoderSpecifier = type, size = 0;
    OSStatus status;
    
    memset(&audioDesc, 0, sizeof(audioDesc));
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size);
    if (status)
    {
        return nil;
    }
    
    uint32_t count = size / sizeof(AudioClassDescription);
    AudioClassDescription descs[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, descs);
    for (uint32_t i = 0; i < count; i++)
    {
        if ((type == descs[i].mSubType) && (manufacturer == descs[i].mManufacturer))
        {
            memcpy(&audioDesc, &descs[i], sizeof(audioDesc));
            break;
        }
    }
    return &audioDesc;
}

-(BOOL)encoderAAC:(CMSampleBufferRef)sampleBuffer aacData:(char*)aacData aacLen:(int*)aacLen { // 编码PCM成AAC
    CMBlockBufferRef blockBuffer = nil;
    AudioBufferList  inBufferList;
    if (CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &inBufferList, sizeof(inBufferList), NULL, NULL, 0, &blockBuffer) != noErr)
    {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer failed");
        return NO;
    }
    // 初始化一个输出缓冲列表
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers              = 1;
    outBufferList.mBuffers[0].mNumberChannels = 2;
    outBufferList.mBuffers[0].mDataByteSize   = *aacLen; // 设置缓冲区大小
    outBufferList.mBuffers[0].mData           = aacData; // 设置AAC缓冲区
    UInt32 outputDataPacketSize               = 1;
    if (AudioConverterFillComplexBuffer(AudioConverter, inputDataProc, &inBufferList, &outputDataPacketSize, &outBufferList, NULL) != noErr)
    {
        return NO;
    }
    
    *aacLen = outBufferList.mBuffers[0].mDataByteSize; //设置编码后的AAC大小
    CFRelease(blockBuffer);
    return YES;
}

OSStatus inputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,AudioStreamPacketDescription **outDataPacketDescription, void *inUserData){
    ///< style="font-family: Arial, Helvetica, sans-serif;">AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据</span>
    AudioBufferList bufferList = *(AudioBufferList*)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData           = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize   = bufferList.mBuffers[0].mDataByteSize;
    return noErr;
}

-(enum Audio_Format_Type)GetAudioFmt:(AudioFormatFlags)Flags FmtBits:(int)FmtBits{
    enum Audio_Format_Type result = FMT_UNKNOW;
    if (FmtBits == 16)
    {
        if(Flags == kAudioFormatFlagIsSignedInteger) result = FMT_S16_LE;
        if(Flags == (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian)) result = FMT_S16_BE;
    }
    if (FmtBits == 32)
    {
        if (Flags == kAudioFormatFlagIsSignedInteger) result = FMT_S32_LE;
        if (Flags == (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian)) result = FMT_S32_BE;
        if (Flags == kAudioFormatFlagIsFloat) result = FMT_FLOAT;
    }
    return result;
}


@end
