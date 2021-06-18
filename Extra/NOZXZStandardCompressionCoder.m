//
//  NOZXZStandardCompressionCoder.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 11/15/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#define ZSTD_STATIC_LINKING_ONLY 1
#include <zstd/zstd.h>

#import <ZipUtilities/ZipUtilities.h>
#import "NOZXZStandardCompressionCoder.h"

#define kZSTD_DEFAULT_LEVEL (7)

static int NOZXZStandardLevelFromNOZCompressionLevel(NOZCompressionLevel level);

@interface NOZXZStandardEncoderContext : NSObject <NOZEncoderContext>
@property (nonatomic, readonly) BOOL encodedDataWasText;
@property (nonatomic, readonly) int level;
@property (nonatomic, readonly, unsafe_unretained, nonnull) id<NOZEncoder> encoder;
@property (nonatomic, readonly, copy, nonnull) NOZFlushCallback flushCallback;
- (instancetype)initWithEncoder:(nonnull id<NOZEncoder>)encoder level:(int)level flushCallback:(NOZFlushCallback)callback;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData;
- (BOOL)encodeBytes:(const Byte*)bytes length:(size_t)length;
- (BOOL)finalizeEncoding;
@end

@interface NOZXZStandardDecoderContext : NSObject <NOZDecoderContext>
@property (nonatomic, readonly) BOOL hasFinished;
@property (nonatomic, readonly, copy, nonnull) NOZFlushCallback flushCallback;
@property (nonatomic, readonly, nonnull, unsafe_unretained) id<NOZDecoder> decoder;
- (instancetype)initWithDecoder:(id<NOZDecoder>)decoder flushCallback:(NOZFlushCallback)callback;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData;
- (BOOL)decodeBytes:(const Byte*)bytes length:(size_t)length;
- (BOOL)finalizeDecoding;
@end

@interface NOZXZStandardEncoder : NSObject <NOZEncoder>
@property (nonatomic, readonly, nullable) NSData *dictionaryData;
- (instancetype)initWithDictionaryData:(nullable NSData *)dict;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface NOZXZStandardDecoder : NSObject <NOZDecoder>
@property (nonatomic, readonly, nullable) NSData *dictionaryData;
- (instancetype)initWithDictionaryData:(nullable NSData *)dict;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation NOZXZStandardCompressionCoder

+ (id<NOZEncoder>)encoder
{
    return [self encoderWithDictionaryData:nil];
}

+ (id<NOZEncoder>)encoderWithDictionaryData:(NSData *)dict
{
    return [[NOZXZStandardEncoder alloc] initWithDictionaryData:dict];
}

+ (id<NOZDecoder>)decoder
{
    return [self decoderWithDictionaryData:nil];
}

+ (id<NOZDecoder>)decoderWithDictionaryData:(NSData *)dict
{
    return [[NOZXZStandardDecoder alloc] initWithDictionaryData:dict];
}

@end

@implementation NOZXZStandardEncoderContext
{
    ZSTD_CStream *_stream;
    ZSTD_outBuffer _outBuffer;

    struct {
        BOOL initialized:1;
        BOOL failureEncountered:1;
    } _flags;
}

- (instancetype)initWithEncoder:(id<NOZEncoder>)encoder level:(int)level flushCallback:(NOZFlushCallback)callback
{
    if (self = [super init]) {
        if (level < 1) {
            level = 1;
        } else if (level > ZSTD_maxCLevel()) {
            level = ZSTD_maxCLevel();
        }

        _level = level;
        _flushCallback = [callback copy];
        _encoder = encoder;

        _stream = ZSTD_createCStream();
    }
    return self;
}

- (void)dealloc
{
    if (_flags.initialized) {
        free(_outBuffer.dst);
    }
    if (_stream) {
        ZSTD_freeCStream(_stream);
    }
}

- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData
{
    if (!_flags.initialized) {
        size_t initResult = 0;
        if (dictionaryData.length > 0) {
            initResult = ZSTD_CCtx_reset(_stream, ZSTD_reset_session_only);
            if (!ZSTD_isError(initResult)) {
                initResult = ZSTD_CCtx_setParameter(_stream, ZSTD_c_compressionLevel, _level);
                if (!ZSTD_isError(initResult)) {
                    initResult = ZSTD_CCtx_loadDictionary(_stream, dictionaryData.bytes, dictionaryData.length);
                }
            }
        } else {
            initResult = ZSTD_initCStream(_stream, _level);
        }

        if (!ZSTD_isError(initResult)) {
            _outBuffer.pos = 0;
            _outBuffer.size = ZSTD_CStreamOutSize();
            _outBuffer.dst = malloc(_outBuffer.size);
            _flags.initialized = 1;
        }
    }
    return _flags.initialized;
}

- (BOOL)encodeBytes:(const Byte*)bytes length:(size_t)length
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    if (length == 0) {
        return YES;
    }

    ZSTD_inBuffer inBuffer;
    inBuffer.src = bytes;
    inBuffer.size = length;
    inBuffer.pos = 0;

    while (!_flags.failureEncountered && inBuffer.pos < inBuffer.size) {
        const size_t compressReturnValue = ZSTD_compressStream(_stream, &_outBuffer, &inBuffer);
        if (ZSTD_isError(compressReturnValue)) {
            _flags.failureEncountered = 1;
            break;
        }

        if (inBuffer.pos < inBuffer.size) {
            [self flush:NO];
        }
    }

    return !_flags.failureEncountered;
}

- (BOOL)finalizeEncoding
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    [self flush:YES];

    return !_flags.failureEncountered;
}

- (void)flush:(BOOL)end
{
    size_t remainingBytesToFlush = 0;
    do {
        remainingBytesToFlush = (end) ? ZSTD_endStream(_stream, &_outBuffer) : ZSTD_flushStream(_stream, &_outBuffer);
        if (ZSTD_isError(remainingBytesToFlush)) {
            _flags.failureEncountered = 1;
        } else if (_outBuffer.pos > 0) {
            _flags.failureEncountered = !_flushCallback(_encoder, self, _outBuffer.dst, _outBuffer.pos);
            _outBuffer.pos = 0; // reset buffer
        }
    } while (!_flags.failureEncountered && remainingBytesToFlush > 0);
}

@end

@implementation NOZXZStandardEncoder

- (NSUInteger)numberOfCompressionLevels
{
    return (NSUInteger)ZSTD_maxCLevel(); // levels 1 through X == X levels
}

- (NSUInteger)defaultCompressionLevel
{
    return kZSTD_DEFAULT_LEVEL - 1; // zero indexed, so subtract 1
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
    return [[NOZXZStandardEncoderContext alloc] initWithEncoder:self level:NOZXZStandardLevelFromNOZCompressionLevel(level) flushCallback:callback];
}

- (BOOL)initializeEncoderContext:(id<NOZEncoderContext>)context
{
    return [(NOZXZStandardEncoderContext *)context initializeWithDictionaryData:_dictionaryData];
}

- (BOOL)encodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(id<NOZEncoderContext>)context
{
    return [(NOZXZStandardEncoderContext *)context encodeBytes:bytes length:length];
}

- (BOOL)finalizeEncoderContext:(id<NOZEncoderContext>)context
{
    return [(NOZXZStandardEncoderContext *)context finalizeEncoding];
}

@end

@implementation NOZXZStandardDecoderContext
{
    ZSTD_DStream *_stream;
    ZSTD_outBuffer _outBuffer;

    struct {
        BOOL initialized:1;
        BOOL failureEncountered:1;
    } _flags;
}

- (instancetype)initWithDecoder:(id<NOZDecoder>)decoder flushCallback:(NOZFlushCallback)callback
{
    if (self = [super init]) {
        _decoder = decoder;
        _flushCallback = [callback copy];

        _stream = ZSTD_createDStream();
    }
    return self;
}

- (void)dealloc
{
    if (_flags.initialized) {
        free(_outBuffer.dst);
    }
    if (_stream) {
        ZSTD_freeDStream(_stream);
    }
}

- (BOOL)initializeWithDictionaryData:(NSData *)dictionaryData
{
    if (!_flags.initialized) {
        const size_t initResult = (dictionaryData.length > 0) ? ZSTD_initDStream_usingDict(_stream, dictionaryData.bytes, dictionaryData.length) : ZSTD_initDStream(_stream);
        if (!ZSTD_isError(initResult)) {
            _outBuffer.pos = 0;
            _outBuffer.size = ZSTD_DStreamOutSize();
            _outBuffer.dst = malloc(_outBuffer.size);
            _flags.initialized = 1;
        }
    }
    return _flags.initialized;
}

- (BOOL)decodeBytes:(const Byte*)bytes length:(size_t)length
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    if (length == 0) {
        return YES;
    }

    ZSTD_inBuffer inBuffer;
    inBuffer.src = bytes;
    inBuffer.size = length;
    inBuffer.pos = 0;

    do {
        const size_t decompressReturnValue = ZSTD_decompressStream(_stream, &_outBuffer, &inBuffer);
        if (ZSTD_isError(decompressReturnValue)) {
            _flags.failureEncountered = 1;
        } else if (_outBuffer.pos > 0) {
            _flags.failureEncountered = !_flushCallback(_decoder, self, _outBuffer.dst, _outBuffer.pos);
            _outBuffer.pos = 0;
            if (decompressReturnValue == 0 && inBuffer.pos >= inBuffer.size) {
                _hasFinished = YES;
                break;
            }
        } else if (inBuffer.pos >= inBuffer.size) {
            break;
        }
    } while (!_flags.failureEncountered);

    return !_flags.failureEncountered;
}

- (BOOL)finalizeDecoding
{
    if (!_flags.initialized || _flags.failureEncountered) {
        return NO;
    }

    return !_flags.failureEncountered;
}

@end

@implementation NOZXZStandardDecoder

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
    return [[NOZXZStandardDecoderContext alloc] initWithDecoder:self flushCallback:callback];
}

- (BOOL)initializeDecoderContext:(id<NOZDecoderContext>)context
{
    return [(NOZXZStandardDecoderContext *)context initializeWithDictionaryData:_dictionaryData];
}

- (BOOL)decodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(id<NOZDecoderContext>)context
{
    return [(NOZXZStandardDecoderContext *)context decodeBytes:bytes length:length];
}

- (BOOL)finalizeDecoderContext:(id<NOZDecoderContext>)context
{
    return [(NOZXZStandardDecoderContext *)context finalizeDecoding];
}

@end

static int NOZXZStandardLevelFromNOZCompressionLevel(NOZCompressionLevel level)
{
    return (int)NOZCompressionLevelToCustomEncoderLevel(level, (NSUInteger)1, (NSUInteger)ZSTD_maxCLevel(), (NSUInteger)kZSTD_DEFAULT_LEVEL);
}
