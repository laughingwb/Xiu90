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

-(BOOL) WriteStreamVideoData:(uint8_t*)VideoData DataLen:(int)DataLen KeyFlag:(BOOL)KeyFlag {
    if (Out_Format_Inited == NO){
        int hret = avformat_write_header(Out_Format_Ctx,NULL);
        if (hret !=0 ){
            return hret;
        }
        Out_Format_Inited = YES;
    }
    AVPacket VideoPkt; //记录音视频相关的属性值
    av_init_packet(&VideoPkt);
    if (AudioStartTime == 0) {
        AudioStartTime = av_gettime();
    }
    VideoPkt.data = VideoData;
    VideoPkt.size = DataLen;
    int64_t DecTime =  av_gettime() - AudioStartTime;
    VideoPkt.pts = av_rescale_q_rnd(DecTime, AV_TIME_BASE_Q, Out_Video_Stream->time_base, (AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
    VideoPkt.dts = AV_NOPTS_VALUE;
    VideoPkt.pos = -1;
    VideoPkt.stream_index = Out_Video_Stream->index;
    if (KeyFlag){
        VideoPkt.flags |= AV_PKT_FLAG_KEY;
    }
    pthread_mutex_lock(&OutMutex);
    int ret = av_write_frame(Out_Format_Ctx, &VideoPkt);
    pthread_mutex_unlock(&OutMutex);
    av_free_packet(&VideoPkt);
    
    return ret == 0;
}

-(void)SetH264SPSPPS:(NSData *)SPSPPS {
    int len = (int)[SPSPPS length];
    if (Out_Video_Codec_Ctx->extradata_size < len){
        if (!Out_Video_Codec_Ctx->extradata){
            free(Out_Video_Codec_Ctx->extradata);
        }
        Out_Video_Codec_Ctx->extradata = malloc(len);
    }
    memset(Out_Video_Codec_Ctx->extradata, 0, len);
    memcpy(Out_Video_Codec_Ctx->extradata, [SPSPPS bytes], len);
    Out_Video_Codec_Ctx->extradata_size = len;
}

-(BOOL)InitAudioStream:(int)AudioChannels AudioSampleRate:(int)AudioSampleRate SampleDataFmt:(int)SampleDataFmt {
    Out_Format_Ctx->oformat->audio_codec = AV_CODEC_ID_AAC;
    
    Out_Audio_Stream = avformat_new_stream(Out_Format_Ctx, NULL);
    if (!Out_Audio_Stream)
    {
        return NO;
    }
    Out_Audio_Stream->time_base = av_make_q(1,1000);
    Out_Audio_Stream->start_time = 0;
    Out_Audio_Stream->duration = 0;
    Out_Audio_Codec_Ctx = Out_Audio_Stream->codec;
    Out_Audio_Codec = avcodec_find_decoder(AV_CODEC_ID_AAC);
    if (!Out_Audio_Codec)
    {
        return NO;
    }
    avcodec_get_context_defaults3(Out_Audio_Codec_Ctx, Out_Audio_Codec);
    Out_Audio_Codec_Ctx->sample_rate = AudioSampleRate;
    Out_Audio_Codec_Ctx->codec_id = AV_CODEC_ID_AAC;
    Out_Audio_Codec_Ctx->codec_type = AVMEDIA_TYPE_AUDIO;
    Out_Audio_Codec_Ctx->channel_layout = av_get_default_channel_layout(AudioChannels);
    Out_Audio_Codec_Ctx->codec_type = AVMEDIA_TYPE_AUDIO;
    
    
    switch(SampleDataFmt)
    {
        case 1:
            Out_Audio_Codec_Ctx->sample_fmt = AV_SAMPLE_FMT_S16P;
            break;
        case 5:
            Out_Audio_Codec_Ctx->sample_fmt = AV_SAMPLE_FMT_FLT;
            break;
        case 0:
        default:
            Out_Audio_Codec_Ctx->sample_fmt = AV_SAMPLE_FMT_S16;
            break;
    }
    Out_Audio_Codec_Ctx->channels = AudioChannels;
    Out_Audio_Codec_Ctx->profile = FF_PROFILE_AAC_MAIN;
    Out_Audio_Codec_Ctx->time_base = av_make_q(1,AudioSampleRate);
    
    if (Out_Format_Ctx->oformat->flags & AVFMT_GLOBALHEADER)
        Out_Audio_Codec_Ctx->flags |= CODEC_FLAG_GLOBAL_HEADER;
    //AudioFilter = av_bitstream_filter_init("aac_adtstoasc");
    
    AudioStartTime = 0;
    
    AVDictionary *dc = NULL;
    av_dict_set(&dc, "signaling", "explicit_hierarchical", 0);
    avcodec_open2(Out_Audio_Codec_Ctx, Out_Audio_Codec, &dc);
    Out_Audio_Codec_Ctx->extradata = malloc(2);
    //    8k     单通道 1588  双声道 1590
    //    16k    单通道 1408  双声道 1410
    //    32k    单通道 1288  双通道 1290
    //    24K    单通道 1308  双声道 1310
    //    22.05K 单声道 1388  双声道 1390
    //    44.1k  单声道 1208  双声道 1210
    switch (AudioSampleRate) {
            
        case 8000:
        {
            Out_Audio_Codec_Ctx->extradata[0] = 0x15;
            Out_Audio_Codec_Ctx->extradata[1] = 0x90;
        }
            break;
            
        case 16000:
        {
            Out_Audio_Codec_Ctx->extradata[0] = 0x14;
            Out_Audio_Codec_Ctx->extradata[1] = 0x10;
        }
            break;
            
        case 32000:
        {
            Out_Audio_Codec_Ctx->extradata[0] = 0x12;
            Out_Audio_Codec_Ctx->extradata[1] = 0x90;
        }
            break;
            
        case 24000:
        {
            Out_Audio_Codec_Ctx->extradata[0] = 0x13;
            Out_Audio_Codec_Ctx->extradata[1] = 0x10;
        }
            break;
            
        case 22050:
        {
            Out_Audio_Codec_Ctx->extradata[0] = 0x13;
            Out_Audio_Codec_Ctx->extradata[1] = 0x90;
        }
            break;
            
        case 44100:
        {
            Out_Audio_Codec_Ctx->extradata[0] = 0x12;
            Out_Audio_Codec_Ctx->extradata[1] = 0x10;
        }
            break;
            
        default:
            break;
    }
    Out_Audio_Codec_Ctx->extradata_size = 2;
    return YES;
}

-(BOOL) WriteStreamAudioData:(uint8_t*)AudioData DataLen:(int)DataLen{
    if (Out_Format_Inited == NO)
    {
        int hret = avformat_write_header(Out_Format_Ctx,NULL);
        if (hret !=0 )
        {
            return hret;
        }
        Out_Format_Inited = YES;
    }
    AVPacket AudioPkt;
    
    if (AudioStartTime == 0) AudioStartTime = av_gettime();
    av_init_packet(&AudioPkt);
    AudioPkt.data = AudioData;
    AudioPkt.size = DataLen;
    AudioPkt.stream_index = Out_Audio_Stream->index;
    int64_t DecTime = av_gettime() - AudioStartTime;
    AudioPkt.pts = av_rescale_q_rnd(DecTime
                                    , AV_TIME_BASE_Q
                                    , Out_Audio_Stream->time_base
                                    , (AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
    AudioPkt.dts = AV_NOPTS_VALUE;
    AudioPkt.pos = -1;
    AudioPkt.stream_index = Out_Audio_Stream->index;
    
    AudioPkt.flags |= AV_PKT_FLAG_KEY;
    pthread_mutex_lock(&OutMutex);
    int ret = av_write_frame(Out_Format_Ctx, &AudioPkt);
    pthread_mutex_unlock(&OutMutex);
    av_free_packet(&AudioPkt);
    
    return ret == 0;
}

-(void) Close{
    pthread_mutex_lock(&OutMutex);
    av_write_trailer(Out_Format_Ctx);
    pthread_mutex_unlock(&OutMutex);
    if (Out_Format_Ctx != NULL)
    {
        for (int i = 0; i < Out_Format_Ctx->nb_streams; i++)
        {
            Out_Format_Ctx->streams[i]->discard = AVDISCARD_ALL;
        }
        avio_closep(&Out_Format_Ctx->pb);
        avformat_free_context(Out_Format_Ctx);
        Out_Format_Ctx = NULL;
    }
    Out_Audio_Stream = NULL;
    Out_Video_Stream = NULL;
    Out_Audio_Codec_Ctx = NULL;
    Out_Video_Codec_Ctx = NULL;
    Out_Audio_Codec = NULL;
    Out_Video_Codec = NULL;
    
    if(VideoFrame)
    {
        av_frame_free(&VideoFrame);
        VideoFrame = NULL;
    }
    if (AudioFrame)
    {
        av_frame_free(&AudioFrame);
        AudioFrame = NULL;
    }
    if (AudioFrameBuf)
    {
        free(AudioFrameBuf);
        AudioFrameBuf = NULL;
    }
    AudioStartTime = 0;
    pthread_mutex_destroy(&OutMutex);
}

@end
