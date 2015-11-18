//
//  NSStream+NOZAdditions.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/30/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

#include <sys/socket.h>

#import "NSStream+NOZAdditions.h"
#import "NOZ_Project.h"
#import "NOZEncoder.h"
#import "NOZError.h"

typedef void (*StreamCreateBoundPairFunc)(CFAllocatorRef,
                                          CFReadStreamRef *,
                                          CFWriteStreamRef *,
                                          CFIndex);
static void NOZStreamCreateBoundPairCompat(CFAllocatorRef       alloc,
                                           CFReadStreamRef *    readStreamPtr,
                                           CFWriteStreamRef *   writeStreamPtr,
                                           CFIndex              transferBufferSize);

@interface NOZEncodingInputStream : NSInputStream <NSStreamDelegate>

- (nonnull instancetype)initWithInputStream:(nonnull NSInputStream *)stream
                                    encoder:(nonnull id<NOZEncoder>)encoder
                           compressionLevel:(NOZCompressionLevel)compressionLevel NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithData:(nonnull NSData *)data NS_UNAVAILABLE;
- (nullable instancetype)initWithURL:(nonnull NSURL *)url NS_UNAVAILABLE;

@end

@implementation NSInputStream (NOZAdditions)

+ (nonnull NSInputStream *)noz_compressedInputStream:(nonnull NSInputStream *)stream
                                         withEncoder:(nonnull id<NOZEncoder>)encoder
                                    compressionLevel:(NOZCompressionLevel)compressionLevel
{
    return [[NOZEncodingInputStream alloc] initWithInputStream:stream encoder:encoder compressionLevel:compressionLevel];
}

@end

@implementation NOZEncodingInputStream
{
    NSInputStream *_stream;
    id<NOZEncoder> _encoder;
    id<NOZEncoderContext> _encoderContext;
    NOZCompressionLevel _compressionLevel;

    NSError *_encoderError;

    NSMutableData *_excessData;
    size_t _excessDataRead;

    Byte *_currentReadBuffer;
    size_t _currentReadBufferLength;
    size_t _currentReadBufferUsed;

    CFReadStreamClientCallBack _copiedCallback;
    CFStreamClientContext _copiedContext;
    CFOptionFlags _requestedEvents;
}

/*
 NSInputStreams MUST call [super init] when subclassing (will crash with unrecognized selector before iOS 9).
 But there are designated initializers making warnings show.
 Suppress the warnings and get things working again without complaint.
 */

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

- (nonnull instancetype)initWithInputStream:(nonnull NSInputStream *)stream
                                    encoder:(nonnull id<NOZEncoder>)encoder
                           compressionLevel:(NOZCompressionLevel)compressionLevel
{
    if (self = [super init]) {
        _stream = stream;
        _encoder = encoder;
        _compressionLevel = compressionLevel;
        _stream.delegate = self;
    }

    return self;
}

#pragma clang diagnostic pop

- (void)dealloc
{
    _stream.delegate = nil;
    _requestedEvents = kCFStreamEventNone;
    if (_copiedCallback) {
        _copiedCallback = NULL;
        bzero(&_copiedContext, sizeof(CFStreamClientContext));
    }
}

- (void)open
{
    [_stream open];

    _encoderContext = [_encoder createContextWithBitFlags:0
                                         compressionLevel:_compressionLevel
                                            flushCallback:^BOOL(id<NOZEncoder> encoder, id<NOZEncoderContext> context, const Byte *bufferToFlush, size_t length) {
                                                return [self private_flushBytes:bufferToFlush length:length];
                                            }];

    if (![_encoder initializeEncoderContext:_encoderContext]) {
        _encoderError = NOZErrorCreate(NOZErrorCodeZipFailedToCompressEntry, nil);
        _encoder = nil;
    }
}

- (void)close
{
    _encoderContext = nil;
    _excessData = nil;

    [_stream close];
}

- (NSStreamStatus)streamStatus
{
    return _encoderError ? NSStreamStatusError : _stream.streamStatus;
}

- (NSError *)streamError
{
    return _encoderError ?: _stream.streamError;
}

- (BOOL)private_flushBytes:(const Byte *)bufferToFlush length:(size_t)length
{
    size_t bytesFlushed = 0;
    if (_currentReadBufferUsed < _currentReadBufferLength) {
        bytesFlushed = MIN(length, (_currentReadBufferLength - _currentReadBufferUsed));
        memcpy(_currentReadBuffer, bufferToFlush, bytesFlushed);
        _currentReadBufferUsed += bytesFlushed;
    }

    if (bytesFlushed < length) {
        length -= bytesFlushed;
        bufferToFlush += bytesFlushed;

        if (!_excessData) {
            _excessData = [NSMutableData dataWithBytes:bufferToFlush length:length];
            _excessDataRead = 0;
        } else {
            [_excessData appendBytes:bufferToFlush length:length];
        }
    }

    return YES;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    if (len == 0) {
        _encoderError = NOZErrorCreate(NOZErrorCodeZipFailedToCompressEntry, @{ @"reason" : @"cannot read with zero length buffer" });
        return -1;
    }

    if (self.streamError) {
        return -1;
    }

    size_t excessBytesAvailable = _excessData.length - _excessDataRead;
    if (excessBytesAvailable > 0) {
        size_t bytesToRead = MIN(len, excessBytesAvailable);
        memcpy(buffer, _excessData.bytes + _excessDataRead, bytesToRead);
        _excessDataRead += bytesToRead;
        if (_excessDataRead == _excessData.length) {
            _excessData = nil;
            _excessDataRead = 0;
        }
        return (NSInteger)bytesToRead;
    }

    _currentReadBuffer = buffer;
    _currentReadBufferLength = len;
    _currentReadBufferUsed = 0;
    noz_defer(^{
        _currentReadBufferUsed = 0;
        _currentReadBufferLength = 0;
        _currentReadBuffer = NULL;
    });

    const size_t intermediateBufferSize = len;
    uint8_t intermediateBuffer[intermediateBufferSize];
    NSInteger rawBytesRead = 0;

    do {
        rawBytesRead = [_stream read:intermediateBuffer maxLength:intermediateBufferSize];

        if (rawBytesRead < 0) {
            return rawBytesRead;
        } else if (rawBytesRead == 0) {
            [_encoder finalizeEncoderContext:_encoderContext];
            break;
        }

        if (![_encoder encodeBytes:intermediateBuffer length:(size_t)rawBytesRead context:_encoderContext]) {
            _encoderError = NOZErrorCreate(NOZErrorCodeZipFailedToCompressEntry, nil);
            return -1;
        }
    } while (rawBytesRead > 0 && _currentReadBufferUsed < _currentReadBufferLength);

    NSInteger returnValue = (NSInteger)_currentReadBufferUsed;
    return returnValue;
}

- (BOOL)getBuffer:(uint8_t * __nullable * __nonnull)buffer length:(NSUInteger *)len
{
    return NO;
}

- (BOOL)hasBytesAvailable
{
    return [_stream hasBytesAvailable] || ((_excessData.length - _excessDataRead) > 0);
}

#pragma mark Delegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    NSAssert(aStream == _stream, @"Got an unexpected stream calling stream:handleEvent:");
    if (aStream != _stream) {
        return;
    }

    CFStreamEventType cfEventCode = (CFStreamEventType)eventCode;
    if ((_requestedEvents & cfEventCode) && _copiedCallback) {
        _copiedCallback((__bridge CFReadStreamRef)self, cfEventCode, _copiedContext.info);
    }

    id<NSStreamDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(stream:handleEvent:)]) {
        [delegate stream:aStream handleEvent:eventCode];
    }
}

#pragma mark Undocumented CFReadStream methods

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode
{

    CFReadStreamScheduleWithRunLoop((CFReadStreamRef)_stream, aRunLoop, aMode);
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)inFlags
                 callback:(CFReadStreamClientCallBack)inCallback
                  context:(CFStreamClientContext *)inContext
{

    if (inCallback != NULL) {
        _requestedEvents = inFlags;
        _copiedCallback = inCallback;
        memcpy(&_copiedContext, inContext, sizeof(CFStreamClientContext));

        if (_copiedContext.info && _copiedContext.retain) {
            _copiedContext.retain(_copiedContext.info);
        }
    } else {
        _requestedEvents = kCFStreamEventNone;
        _copiedCallback = NULL;
        if (_copiedContext.info && _copiedContext.release) {
            _copiedContext.release(_copiedContext.info);
        }

        memset(&_copiedContext, 0, sizeof(CFStreamClientContext));
    }

    return YES;
}

- (void)_unscheduleFromCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode
{
    CFReadStreamUnscheduleFromRunLoop((CFReadStreamRef)_stream, aRunLoop, aMode);
}

@end

@implementation NSStream (NOZAdditions)

+ (void)noz_createBoundInputStream:(NSInputStream **)inputStreamPtr
                      outputStream:(NSOutputStream **)outputStreamPtr
                        bufferSize:(NSUInteger)bufferSize
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;

    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );

    readStream = NULL;
    writeStream = NULL;

    // there is a bug in CFStreamCreateBoundPair prior to iOS 5 / Mac OS X 10.7
    const BOOL isCFStreamCreateBoundPairSafe = ((&NSStreamNetworkServiceTypeBackground) != NULL);
    StreamCreateBoundPairFunc createBoundPair = (isCFStreamCreateBoundPairSafe) ? CFStreamCreateBoundPair : NOZStreamCreateBoundPairCompat;

    createBoundPair(NULL,
                    ((inputStreamPtr  != nil) ? &readStream : NULL),
                    ((outputStreamPtr != nil) ? &writeStream : NULL),
                    (CFIndex) bufferSize);

    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}

@end

static void NOZStreamCreateBoundPairCompat(CFAllocatorRef       alloc,
                                           CFReadStreamRef *    readStreamPtr,
                                           CFWriteStreamRef *   writeStreamPtr,
                                           CFIndex              transferBufferSize)
// This is a drop-in replacement for CFStreamCreateBoundPair that is necessary because that
// code is broken on iOS versions prior to iOS 5.0 <rdar://problem/7027394> <rdar://problem/7027406>.
// This emulates a bound pair by creating a pair of UNIX domain sockets and wrapper each end in a
// CFSocketStream.  This won't give great performance, but it doesn't crash!
{
#pragma unused(transferBufferSize)
    int                 err;
    Boolean             success;
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    int                 fds[2];

    assert(readStreamPtr != NULL);
    assert(writeStreamPtr != NULL);

    readStream = NULL;
    writeStream = NULL;

    // Create the UNIX domain socket pair.

    err = socketpair(AF_UNIX, SOCK_STREAM, 0, fds);
    if (err == 0) {
        CFStreamCreatePairWithSocket(alloc, fds[0], &readStream,  NULL);
        CFStreamCreatePairWithSocket(alloc, fds[1], NULL, &writeStream);

        // If we failed to create one of the streams, ignore them both.

        if ( (readStream == NULL) || (writeStream == NULL) ) {
            if (readStream != NULL) {
                CFRelease(readStream);
                readStream = NULL;
            }
            if (writeStream != NULL) {
                CFRelease(writeStream);
                writeStream = NULL;
            }
        }
        assert( (readStream == NULL) == (writeStream == NULL) );

        // Make sure that the sockets get closed (by us in the case of an error,
        // or by the stream if we managed to create them successfull).

        if (readStream == NULL) {
            err = close(fds[0]);
            assert(err == 0);
            err = close(fds[1]);
            assert(err == 0);
        } else {
            success = CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            assert(success);
            success = CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            assert(success);
        }
    }
    
    *readStreamPtr = readStream;
    *writeStreamPtr = writeStream;
}
