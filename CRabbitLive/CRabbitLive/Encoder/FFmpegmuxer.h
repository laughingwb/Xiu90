//
//  FFmpegmuxer.h
//  CRabbitLive
//
//  Created by wangbo on 17/1/4.
//  Copyright © 2017年 wb. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "libavutil/fifo.h"
#include "libavutil/time.h"
#include "libavutil/pixfmt.h"
#include "libavutil/common.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libavcodec/avcodec.h"
#include "libavutil/pixdesc.h"
#include <pthread.h>



@interface FFmpegmuxer : NSObject {
    AVFormatContext *Out_Format_Ctx;
    AVStream *Out_Audio_Stream;
    AVStream *Out_Video_Stream;
    AVCodecContext *Out_Audio_Codec_Ctx;
    AVCodecContext *Out_Video_Codec_Ctx;
    AVCodec *Out_Audio_Codec;
    AVCodec *Out_Video_Codec;
    BOOL Out_Format_Inited;
    //AVBitStreamFilterContext* AudioFilter;
    //AVBitStreamFilterContext* avcbsfc;
    uint8_t* AudioFrameBuf;
    AVFrame* AudioFrame;
    AVFrame* VideoFrame;
    pthread_mutex_t OutMutex;
    int64_t AudioStartTime;
}

-(id) initOut:(NSString*)OutUrl;
-(BOOL) InitVideoStream:(int)VideoWidth VideoHeight:(int)VideoHeight FrameRate:(int)FrameRate;
-(BOOL) WriteStreamVideoData:(uint8_t*)VideoData DataLen:(int)DataLen KeyFlag:(BOOL)KeyFlag;
-(void) SetH264SPSPPS:(NSData*)SPSPPS;
-(BOOL) InitAudioStream:(int)AudioChannels AudioSampleRate:(int)AudioSampleRate SampleDataFmt:(int)SampleDataFmt;
-(BOOL) WriteStreamAudioData:(uint8_t*)AudioData DataLen:(int)DataLen;
-(void) Close;
@end
