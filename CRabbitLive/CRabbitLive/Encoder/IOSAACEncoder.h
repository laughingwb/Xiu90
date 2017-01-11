//
//  IOSAACEncoder.h
//  CRabbitLive
//
//  Created by wangbo on 17/1/11.
//  Copyright © 2017年 wb. All rights reserved.
//

#import <Foundation/Foundation.h>

@import AVFoundation;
enum Audio_Format_Type
{
    FMT_S16_LE,
    FMT_S16_BE,
    FMT_S32_LE,
    FMT_S32_BE,
    FMT_FLOAT,
    FMT_UNKNOW
};

@protocol IOSAACEncoderDelegate <NSObject>
//-(void)gotAudioData:(NSData*)data;
//-(void)gotAudioFmt:(int)SampleRate Channels:(int)channels SampleBytes:(enum Audio_Format_Type)SampleBytes;
@end

@interface IOSAACEncoder : NSObject {
    AudioConverterRef AudioConverter;
}
@property(nonatomic,assign)id<IOSAACEncoderDelegate>delegate;
-(BOOL)initEncode:(AudioStreamBasicDescription)inputFormat;
-(BOOL)encoderAAC:(CMSampleBufferRef)sampleBuffer aacData:(char*)aacData aacLen:(int*)aacLen;
-(enum Audio_Format_Type)GetAudioFmt:(AudioFormatFlags)Flags FmtBits:(int)FmtBits;
@end
