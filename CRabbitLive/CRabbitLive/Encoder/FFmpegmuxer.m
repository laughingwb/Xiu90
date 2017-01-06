//
//  FFmpegmuxer.m
//  CRabbitLive
//
//  Created by wangbo on 17/1/4.
//  Copyright © 2017年 wb. All rights reserved.
//

#import "FFmpegmuxer.h"

@implementation FFmpegmuxer

-(id) initOut:(NSString*)OutUrl{
    self = [super init];
    if (self){
        av_register_all();
        avformat_network_init();
        Out_Format_Inited = NO;
        if (avformat_alloc_output_context2(&Out_Format_Ctx, NULL, "flv", [OutUrl UTF8String]) < 0)
        {
            return nil;
        }
        if (avio_open(&Out_Format_Ctx->pb, [OutUrl UTF8String], AVIO_FLAG_WRITE) < 0){
            printf("Could not open '%s'\n", [OutUrl UTF8String]);
            return nil;
        }else {
            printf("Could open '%s'\n", [OutUrl UTF8String]);
        }
        //avcbsfc = av_bitstream_filter_init("h264_mp4toannexb");
        pthread_mutex_init(&OutMutex,NULL);
        return self;
    }
    return self;
}


-(BOOL) InitVideoStream:(int)VideoWidth VideoHeight:(int)VideoHeight FrameRate:(int)FrameRate {
    Out_Format_Ctx->oformat->video_codec = AV_CODEC_ID_H264;
    
    Out_Video_Stream = avformat_new_stream(Out_Format_Ctx, NULL);
    if (!Out_Video_Stream)
    {
        fprintf(stderr, "Could not alloc stream\n");
        return NO;
    }
    Out_Video_Stream->time_base =  av_make_q(1,1000);
    Out_Video_Stream->start_time = 0;
    Out_Video_Stream->duration = 0;
    Out_Video_Codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    Out_Video_Codec_Ctx = Out_Video_Stream->codec;
    if (!Out_Video_Codec)
    {
        return NO;
    }
    avcodec_get_context_defaults3(Out_Video_Codec_Ctx, Out_Video_Codec);
    Out_Video_Codec_Ctx->width = VideoWidth;
    Out_Video_Codec_Ctx->height = VideoHeight;
    Out_Video_Codec_Ctx->codec_id = AV_CODEC_ID_H264;
    Out_Video_Codec_Ctx->codec_type = AVMEDIA_TYPE_VIDEO;
    Out_Video_Codec_Ctx->time_base = av_make_q(1,FrameRate);//timebase;
    Out_Video_Codec_Ctx->pix_fmt = AV_PIX_FMT_YUV420P;   //支持的像素格式（仅视频
    Out_Video_Codec_Ctx->profile = FF_PROFILE_H264_BASELINE;
    if (Out_Format_Ctx->oformat->flags & AVFMT_GLOBALHEADER)
        Out_Video_Codec_Ctx->flags |= CODEC_FLAG_GLOBAL_HEADER;
    avcodec_open2(Out_Video_Codec_Ctx, Out_Video_Codec, NULL);
    return YES;
}


@end
