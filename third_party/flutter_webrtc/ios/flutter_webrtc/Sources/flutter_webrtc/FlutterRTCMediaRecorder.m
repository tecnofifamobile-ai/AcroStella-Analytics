#import <WebRTC/WebRTC.h>
#import "FlutterRTCMediaRecorder.h"
#import "FlutterRTCAudioSink.h"
#import "FlutterRTCFrameCapturer.h"

@import AVFoundation;
#import <QuartzCore/QuartzCore.h>

@implementation FlutterRTCMediaRecorder {
    int framesCount;
    bool isInitialized;
    CGSize _renderSize;
    FlutterRTCAudioSink* _audioSink;
    AVAssetWriterInput* _audioWriter;
    int64_t _startTime;
    NSLock* _frameLock;
    BOOL _framePending;
    BOOL _stopping;
    dispatch_queue_t _recordQueue;
    RTCVideoRotation _firstRotation;
}

- (instancetype)initWithVideoTrack:(RTCVideoTrack *)video audioTrack:(RTCAudioTrack *)audio outputFile:(NSURL *)out {
    self = [super init];
    isInitialized = false;
    _frameLock = [NSLock new];
    _recordQueue = dispatch_queue_create("com.acrostella.recording", DISPATCH_QUEUE_SERIAL);
    self.firstFrameClockUs = -1;
    self.videoTrack = video;
    self.output = out;
    [video addRenderer:self];
    framesCount = 0;
    if (audio != nil)
        _audioSink = [[FlutterRTCAudioSink alloc] initWithAudioTrack:audio];
    else
        NSLog(@"Audio track is nil");
    _startTime = -1;
    return self;
}

- (void)initialize:(CGSize)size {
    _renderSize = size;
    NSDictionary *videoSettings = @{
        AVVideoCompressionPropertiesKey: @{AVVideoAverageBitRateKey: @(6*1024*1024)},
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoHeightKey: @(size.height),
        AVVideoWidthKey: @(size.width),
    };
    self.writerInput = [[AVAssetWriterInput alloc]
            initWithMediaType:AVMediaTypeVideo
               outputSettings:videoSettings];
    // MP4 orientation is fixed at recording start, like the native camera app.
    switch (_firstRotation) {
        case RTCVideoRotation_90: self.writerInput.transform = CGAffineTransformMake(0, 1, -1, 0, size.height, 0); break;
        case RTCVideoRotation_180: self.writerInput.transform = CGAffineTransformMake(-1, 0, 0, -1, size.width, size.height); break;
        case RTCVideoRotation_270: self.writerInput.transform = CGAffineTransformMake(0, -1, 1, 0, 0, size.width); break;
        default: break;
    }
    self.writerInput.expectsMediaDataInRealTime = true;
    self.writerInput.mediaTimeScale = 30;

    if (_audioSink != nil) {
        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
        NSDictionary* audioSettings = @{
            AVFormatIDKey: [NSNumber numberWithInt: kAudioFormatMPEG4AAC],
            AVNumberOfChannelsKey: @1,
            AVSampleRateKey: @44100.0,
            AVChannelLayoutKey: [NSData dataWithBytes:&acl length:sizeof(AudioChannelLayout)],
            AVEncoderBitRateKey: @64000,
        };
        _audioWriter = [[AVAssetWriterInput alloc]
                        initWithMediaType:AVMediaTypeAudio
                        outputSettings:audioSettings
                        sourceFormatHint:_audioSink.format];
        _audioWriter.expectsMediaDataInRealTime = true;
    }
    
    NSError *error;
    self.assetWriter = [[AVAssetWriter alloc]
            initWithURL:self.output
               fileType:AVFileTypeMPEG4
                  error:&error];
    if (error != nil)
        NSLog(@"%@",[error localizedDescription]);
    self.assetWriter.shouldOptimizeForNetworkUse = true;
    [self.assetWriter addInput:self.writerInput];
    if (_audioWriter != nil) {
        [self.assetWriter addInput:_audioWriter];
        _audioSink.bufferCallback = ^(CMSampleBufferRef buffer){
            if (self->_audioWriter.readyForMoreMediaData) {
                if ([self->_audioWriter appendSampleBuffer:buffer])
                    NSLog(@"Audio frame appended");
                else
                    NSLog(@"Audioframe not appended %@", self.assetWriter.error);
            }
        };
    }
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    isInitialized = true;
}

- (void)setSize:(CGSize)size {
}

- (void)renderFrame:(nullable RTCVideoFrame *)frame {
    if (frame == nil) return;
    [_frameLock lock];
    if (_stopping || _framePending) {
        self.droppedFrames++;
        [_frameLock unlock];
        return;
    }
    _framePending = YES;
    [_frameLock unlock];
    int64_t receivedUs = (int64_t)(CACurrentMediaTime() * 1000000.0);
    dispatch_async(_recordQueue, ^{
        @try { [self appendFrame:frame receivedUs:receivedUs]; }
        @finally {
            [self->_frameLock lock]; self->_framePending = NO; [self->_frameLock unlock];
        }
    });
}

- (void)appendFrame:(RTCVideoFrame *)frame receivedUs:(int64_t)receivedUs {
    if (!isInitialized) {
        _firstRotation = frame.rotation;
        [self initialize:CGSizeMake((CGFloat) frame.width, (CGFloat) frame.height)];
    }
    if (!self.writerInput.readyForMoreMediaData) {
        NSLog(@"Drop frame, not ready");
        return;
    }
    id <RTCVideoFrameBuffer> buffer = frame.buffer;
    CVPixelBufferRef pixelBufferRef;
    BOOL shouldRelease = false;
    if ([buffer isKindOfClass:[RTCCVPixelBuffer class]]) {
        pixelBufferRef = ((RTCCVPixelBuffer *) buffer).pixelBuffer;
    } else {
        pixelBufferRef = [FlutterRTCFrameCapturer convertToCVPixelBuffer:frame];
        shouldRelease = true;
    }
    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBufferRef, &formatDescription);
    
    if (status != noErr || formatDescription == NULL) {
        NSLog(@"Failed to create format description: %d", (int)status);
        if (shouldRelease) {
            CVPixelBufferRelease(pixelBufferRef);
        }
        return;
    }

    CMSampleTimingInfo timingInfo = {0};
    
    timingInfo.decodeTimeStamp = kCMTimeInvalid;
    if (_startTime == -1) {
        _startTime = frame.timeStampNs / 1000;
    }
    int64_t frameTime = (frame.timeStampNs / 1000) - _startTime;
    timingInfo.presentationTimeStamp = CMTimeMake(frameTime, 1000000);
    framesCount++;

    CMSampleBufferRef outBuffer = NULL;

    status = CMSampleBufferCreateReadyWithImageBuffer(
        kCFAllocatorDefault,
        pixelBufferRef,
        formatDescription,
        &timingInfo,
        &outBuffer
    );

    if (status == noErr && outBuffer != NULL) {
        if (![self.writerInput appendSampleBuffer:outBuffer]) {
            NSLog(@"Frame not appended %@", self.assetWriter.error);
        } else if (self.firstFrameClockUs < 0) {
            self.firstFrameClockUs = receivedUs;
        }
    } else {
        NSLog(@"Failed to create sample buffer: %d", (int)status);
    }
    
    // Release Core Foundation objects to prevent memory leaks
    if (outBuffer != NULL) {
        CFRelease(outBuffer);
    }
    if (formatDescription != NULL) {
        CFRelease(formatDescription);
    }
    if (shouldRelease) {
        CVPixelBufferRelease(pixelBufferRef);
    }
}

- (void)stop:(FlutterResult _Nonnull)result {
    [_frameLock lock]; _stopping = YES; [_frameLock unlock];
    [self.videoTrack removeRenderer:self];
    dispatch_async(_recordQueue, ^{
        if (!self->isInitialized || self.assetWriter.status == AVAssetWriterStatusFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                result([FlutterError errorWithCode:@"recording_no_frames" message:@"No encoded frames" details:nil]);
            });
            return;
        }
        if (self->_audioSink != nil) {
            self->_audioSink.bufferCallback = nil;
            [self->_audioSink close];
        }
        [self.writerInput markAsFinished];
        [self->_audioWriter markAsFinished];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            NSError* error = self.assetWriter.error;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error == nil) result(nil);
                else result([FlutterError errorWithCode:@"recording_failed" message:error.localizedDescription details:nil]);
            });
        }];
    });
}
@end
