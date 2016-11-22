//
//  NOZXBrotliCompressionCoder.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 11/21/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#include <brotli/encode.h>
#include <brotli/decode.h>

#import <ZipUtilities/ZipUtilities.h>
#import "NOZXBrotliCompressionCoder.h"

#define kBUFFER_SIZE                    (1024 * 16)
#define kBROTLI_QUALITY_LEVELS          (BROTLI_MAX_QUALITY)
#define kBROTLI_QUALITY_LEVEL_DEFAULT   (kBROTLI_QUALITY_LEVELS / 2)

static uint32_t NOZXBrotliQualityFromNOZCompressionLevel(NOZCompressionLevel level);

@interface NOZXBrotliEncoderContext : NSObject <NOZEncoderContext>
@property (nonatomic, readonly) BOOL encodedDataWasText;
@property (nonatomic, readonly) uint32_t quality;
@property (nonatomic, readonly, unsafe_unretained, nonnull) id<NOZEncoder> encoder;
@property (nonatomic, readonly, copy, nonnull) NOZFlushCallback flushCallback;
- (instancetype)initWithEncoder:(nonnull id<NOZEncoder>)encoder quality:(uint32_t)quality flushCallback:(NOZFlushCallback)callback;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData;
- (BOOL)encodeBytes:(const Byte*)bytes length:(size_t)length;
- (BOOL)finalize;
@end

@interface NOZXBrotliDecoderContext : NSObject <NOZDecoderContext>
@property (nonatomic, readonly) BOOL hasFinished;
@property (nonatomic, readonly, copy, nonnull) NOZFlushCallback flushCallback;
@property (nonatomic, readonly, nonnull, unsafe_unretained) id<NOZDecoder> decoder;
- (instancetype)initWithDecoder:(id<NOZDecoder>)decoder flushCallback:(NOZFlushCallback)callback;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData;
- (BOOL)decodeBytes:(const Byte*)bytes length:(size_t)length;
- (BOOL)finalize;
@end

@interface NOZXBrotliEncoder : NSObject <NOZEncoder>
@property (nonatomic, readonly, nullable) NSData *dictionaryData;
- (instancetype)initWithDictionaryData:(nullable NSData *)dict;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface NOZXBrotliDecoder : NSObject <NOZDecoder>
@property (nonatomic, readonly, nullable) NSData *dictionaryData;
- (instancetype)initWithDictionaryData:(nullable NSData *)dict;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation NOZXBrotliCompressionCoder

+ (id<NOZEncoder>)encoder
{
    return [self encoderWithDictionaryData:nil];
}

+ (id<NOZEncoder>)encoderWithDictionaryData:(NSData *)dict
{
    return [[NOZXBrotliEncoder alloc] initWithDictionaryData:dict];
}

+ (id<NOZDecoder>)decoder
{
    return [self decoderWithDictionaryData:nil];
}

+ (id<NOZDecoder>)decoderWithDictionaryData:(NSData *)dict
{
    return [[NOZXBrotliDecoder alloc] initWithDictionaryData:dict];
}

@end

@implementation NOZXBrotliEncoderContext
{
    BrotliEncoderState *_encoderState;

    struct {
        BOOL initialized:1;
        BOOL failureEncountered:1;
    } _flags;


    Byte _encoderBuffer[kBUFFER_SIZE];
    Byte *_encoderBufferPointer;
    size_t _encoderBufferRemainingBytesCount;
}

- (instancetype)initWithEncoder:(id<NOZEncoder>)encoder quality:(uint32_t)quality flushCallback:(NOZFlushCallback)callback
{
    if (self = [super init]) {
        if (quality < 1) {
            quality = 1;
        } else if (quality > BROTLI_MAX_QUALITY) {
            quality = BROTLI_MAX_QUALITY;
        }

        _quality = quality;
        _flushCallback = [callback copy];
        _encoder = encoder;

        _encoderState = BrotliEncoderCreateInstance(0, 0, NULL);
    }
    return self;
}

- (void)dealloc
{
    if (_encoderState) {
        BrotliEncoderDestroyInstance(_encoderState);
    }
}

- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData
{
    if (!_flags.initialized) {
        static uint32_t lgwin = 21; // 2MB
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            unsigned long long physMemory = [NSProcessInfo processInfo].physicalMemory;
            if (physMemory < (1024ULL * 1024ULL * 768ULL)) {
                lgwin--; // 1MB
            } else if (physMemory > (1024ULL * 1024ULL * 1024ULL * 3ULL / 2ULL)) {
                lgwin++; // 4MB
            }
        });
        (void)BrotliEncoderSetParameter(_encoderState, BROTLI_PARAM_QUALITY, _quality);
        (void)BrotliEncoderSetParameter(_encoderState, BROTLI_PARAM_LGWIN, lgwin);
        if (dictionaryData.length) {
            (void)BrotliEncoderSetParameter(_encoderState, BROTLI_PARAM_LGWIN, BROTLI_DEFAULT_WINDOW);
            BrotliEncoderSetCustomDictionary(_encoderState, dictionaryData.length, dictionaryData.bytes);
        }

        _encoderBufferPointer = _encoderBuffer;
        _encoderBufferRemainingBytesCount = sizeof(_encoderBuffer);

        _flags.initialized = 1;
    }
    return _flags.initialized;
}

- (BOOL)encodeBytes:(const Byte*)bytes length:(size_t)length
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    size_t availableInputByteCount = length;
    const Byte *availableInputBytePointer = bytes;

    while (availableInputByteCount > 0 && !_flags.failureEncountered) {

        if (BROTLI_TRUE != BrotliEncoderCompressStream(_encoderState,
                                                       BROTLI_OPERATION_PROCESS,
                                                       &availableInputByteCount,
                                                       &availableInputBytePointer,
                                                       &_encoderBufferRemainingBytesCount,
                                                       &_encoderBufferPointer,
                                                       NULL /* total so far */)) {
            _flags.failureEncountered = 1;
            break;
        }

        [self flush];
    }

    return !_flags.failureEncountered;
}

- (BOOL)finalize
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    size_t availableInputByteCount = 0;
    const Byte *availableInputBytePointer = NULL;

    do {

        if (BROTLI_TRUE != BrotliEncoderCompressStream(_encoderState,
                                                       BROTLI_OPERATION_FINISH,
                                                       &availableInputByteCount,
                                                       &availableInputBytePointer,
                                                       &_encoderBufferRemainingBytesCount,
                                                       &_encoderBufferPointer,
                                                       NULL /* total so far */)) {
            _flags.failureEncountered = 1;
            break;
        } else {
            [self flush];
        }

    } while (!_flags.failureEncountered && !BrotliEncoderIsFinished(_encoderState));

    return !_flags.failureEncountered;
}

- (void)flush
{
    const size_t bufferSize = sizeof(_encoderBuffer);
    if (_encoderBufferRemainingBytesCount == bufferSize) {
        return;
    }

    if (!_flushCallback(_encoder, self, _encoderBuffer, bufferSize - _encoderBufferRemainingBytesCount)) {
        _flags.failureEncountered = 1;
    }
    _encoderBufferRemainingBytesCount = bufferSize;
    _encoderBufferPointer = _encoderBuffer;
}

@end

@implementation NOZXBrotliEncoder

- (NSUInteger)numberOfCompressionLevels
{
    return kBROTLI_QUALITY_LEVELS + 1;
}

- (NSUInteger)defaultCompressionLevel
{
    return kBROTLI_QUALITY_LEVEL_DEFAULT;
}

- (instancetype)initWithDictionaryData:(NSData *)dict
{
    if (self = [super init]) {
        _dictionaryData = dict;
    }
    return self;
}

- (UInt16)bitFlagsForEntry:(id<NOZZipEntry>)entry
{
    return 0;
}

- (id<NOZEncoderContext>)createContextWithBitFlags:(UInt16)bitFlags
                                  compressionLevel:(NOZCompressionLevel)level
                                     flushCallback:(NOZFlushCallback)callback
{
    return [[NOZXBrotliEncoderContext alloc] initWithEncoder:self quality:NOZXBrotliQualityFromNOZCompressionLevel(level) flushCallback:callback];
}

- (BOOL)initializeEncoderContext:(id<NOZEncoderContext>)context
{
    return [(NOZXBrotliEncoderContext *)context initializeWithDictionaryData:_dictionaryData];
}

- (BOOL)encodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(id<NOZEncoderContext>)context
{
    return [(NOZXBrotliEncoderContext *)context encodeBytes:bytes length:length];
}

- (BOOL)finalizeEncoderContext:(id<NOZEncoderContext>)context
{
    return [(NOZXBrotliEncoderContext *)context finalize];
}

@end

@implementation NOZXBrotliDecoderContext
{
    BrotliDecoderState *_decoderState;

    struct {
        BOOL initialized:1;
        BOOL failureEncountered:1;
    } _flags;

    Byte _decoderBuffer[kBUFFER_SIZE];
    Byte *_decoderBufferPointer;
    size_t _decoderBufferRemainingBytesCount;
}

- (instancetype)initWithDecoder:(id<NOZDecoder>)decoder flushCallback:(NOZFlushCallback)callback
{
    if (self = [super init]) {
        _decoder = decoder;
        _flushCallback = [callback copy];

        _decoderState = BrotliDecoderCreateInstance(0, 0, NULL);
    }
    return self;
}

- (void)dealloc
{
    if (_decoderState) {
        BrotliDecoderDestroyInstance(_decoderState);
    }
}

- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData
{
    if (!_flags.initialized) {
        if (dictionaryData.length) {
            (void)BrotliDecoderSetCustomDictionary(_decoderState, dictionaryData.length, dictionaryData.bytes);
        }
        _decoderBufferPointer = _decoderBuffer;
        _decoderBufferRemainingBytesCount = sizeof(_decoderBuffer);
        _flags.initialized = 1;
    }
    return _flags.initialized;
}

- (BOOL)decodeBytes:(const Byte*)bytes length:(size_t)length
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    size_t availableInputBytesCount = length;
    const Byte *availableInputBytesPointer = bytes;

    BrotliDecoderResult result = BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT;
    do {
        result = BrotliDecoderDecompressStream(_decoderState,
                                               &availableInputBytesCount,
                                               &availableInputBytesPointer,
                                               &_decoderBufferRemainingBytesCount,
                                               &_decoderBufferPointer,
                                               NULL /* total decoded */);
        if (BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT == result) {
            [self flush];
        } else if (BROTLI_DECODER_RESULT_ERROR == result) {
            _flags.failureEncountered = 1;
        } else {
            break;
        }
    } while (!_flags.failureEncountered);

    if (BROTLI_DECODER_RESULT_SUCCESS == result) {
        _hasFinished = YES;
        [self flush];
    } else if (length == 0) {
        // a zero length message is for the final flush.
        // if we didn't succeed now, we'll never succeed.
        _flags.failureEncountered = YES;
    }

    return !_flags.failureEncountered;
}

- (BOOL)finalize
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    return (BROTLI_TRUE == BrotliDecoderIsFinished(_decoderState));
}

- (void)flush
{
    const size_t bufferSize = sizeof(_decoderBuffer);
    if (bufferSize != _decoderBufferRemainingBytesCount) {
        _flags.failureEncountered = !_flushCallback(_decoder, self, _decoderBuffer, bufferSize - _decoderBufferRemainingBytesCount);
        _decoderBufferPointer = _decoderBuffer;
        _decoderBufferRemainingBytesCount = bufferSize;
    }
}

@end

@implementation NOZXBrotliDecoder

- (instancetype)initWithDictionaryData:(NSData *)dict
{
    if (self = [super init]) {
        _dictionaryData = dict;
    }
    return self;
}

- (id<NOZDecoderContext>)createContextForDecodingWithBitFlags:(UInt16)flags
                                                flushCallback:(NOZFlushCallback)callback
{
    return [[NOZXBrotliDecoderContext alloc] initWithDecoder:self flushCallback:callback];
}

- (BOOL)initializeDecoderContext:(id<NOZDecoderContext>)context
{
    return [(NOZXBrotliDecoderContext *)context initializeWithDictionaryData:_dictionaryData];
}

- (BOOL)decodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(id<NOZDecoderContext>)context
{
    return [(NOZXBrotliDecoderContext *)context decodeBytes:bytes length:length];
}

- (BOOL)finalizeDecoderContext:(id<NOZDecoderContext>)context
{
    return [(NOZXBrotliDecoderContext *)context finalize];
}

@end

static uint32_t NOZXBrotliQualityFromNOZCompressionLevel(NOZCompressionLevel level)
{
    return (uint32_t)NOZCompressionLevelToCustomEncoderLevel(level, BROTLI_MIN_QUALITY, BROTLI_MAX_QUALITY, kBROTLI_QUALITY_LEVEL_DEFAULT);
}
