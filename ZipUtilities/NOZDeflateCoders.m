//
//  NOZCompression.m
//  ZipUtilities
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Nolan O'Brien
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import "NOZ_Project.h"
#import "NOZDecoder.h"
#import "NOZEncoder.h"
#import "NOZUtils_Project.h"
#import "NOZZipEntry.h"

#include "zlib.h"

#pragma mark - Deflate Encoder

@interface NOZDeflateEncoderContext : NSObject <NOZEncoderContext>
@property (nonatomic, copy, nullable) NOZFlushCallback flushCallback;
@property (nonatomic) NOZCompressionLevel compressionLevel;
@property (nonatomic) BOOL zStreamOpen;

@property (nonatomic, readonly) z_stream *zStream;
@property (nonatomic, readonly) Byte *compressedDataBuffer;
@property (nonatomic, readonly) size_t compressedDataBufferSize;
@property (nonatomic) size_t compressedDataPosition;
@property (nonatomic) BOOL encodedDataWasText;
@end

@implementation NOZDeflateEncoderContext
{
    z_stream _zStream;
}

- (z_stream *)zStream
{
    return &_zStream;
}

- (nonnull instancetype)init
{
    if (self = [super init]) {
        _compressedDataBuffer = malloc(NSPageSize());
        _compressedDataBufferSize = NSPageSize();

        _zStream.avail_in = 0;
        _zStream.avail_out = (UInt32)NSPageSize();
        _zStream.next_out = _compressedDataBuffer;
        _zStream.total_in = 0;
        _zStream.total_out = 0;
        _zStream.data_type = Z_BINARY;
        _zStream.zalloc = NULL;
        _zStream.zfree = NULL;
        _zStream.opaque = NULL;

        _compressionLevel = NOZCompressionLevelDefault;
    }
    return self;
}

- (void)dealloc
{
    free(_compressedDataBuffer);
    if (_zStreamOpen) {
        deflateEnd(&_zStream);
    }
}

@end

@implementation NOZDeflateEncoder

- (UInt16)bitFlagsForEntry:(nonnull id<NOZZipEntry>)entry
{
    switch (entry.compressionLevel) {
        case 9:
        case 8:
            return NOZFlagBitsMaxDeflate;
        case 2:
            return NOZFlagBitsFastDeflate;
        case 1:
            return NOZFlagBitsSuperFastDeflate;
        default:
            return NOZFlagBitsNormalDeflate;
    }
}

- (nonnull NOZDeflateEncoderContext *)createContextWithBitFlags:(UInt16)bitFlags
                                               compressionLevel:(NOZCompressionLevel)level
                                                  flushCallback:(nonnull NOZFlushCallback)callback;
{
    NOZDeflateEncoderContext *context = [[NOZDeflateEncoderContext alloc] init];
    context.flushCallback = callback;
    context.compressionLevel = level;
    return context;
}

- (BOOL)initializeEncoderContext:(nonnull NOZDeflateEncoderContext *)context
{
    if (Z_OK != deflateInit2(context.zStream,
                             context.compressionLevel,
                             Z_DEFLATED,
                             -MAX_WBITS,
                             8 /* default memory level */,
                             Z_DEFAULT_STRATEGY)) {
        return NO;
    }

    context.zStreamOpen = YES;
    return YES;
}

- (BOOL)encodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull NOZDeflateEncoderContext *)context
{
    if (!context.zStreamOpen) {
        return NO;
    }

    BOOL success = YES;

    z_stream *zStream = context.zStream;
    zStream->next_in = (Byte*)bytes;
    zStream->avail_in = (UInt32)length;

    while (success && zStream->avail_in > 0) {
        if (zStream->avail_out == 0) {
            if (!context.flushCallback(self, context, context.compressedDataBuffer, context.compressedDataPosition)) {
                success = NO;
            }
            zStream->total_in = 0;
            context.compressedDataPosition = 0;
            zStream->avail_out = (UInt32)context.compressedDataBufferSize;
            zStream->next_out = context.compressedDataBuffer;
        }

        if (!success) {
            break;
        }

        uLong previousTotalOut = zStream->total_out;
        success = deflate(zStream, Z_NO_FLUSH) == Z_OK;
        if (previousTotalOut > zStream->total_out) {
            success = NO;
        } else {
            context.compressedDataPosition += (zStream->total_out - previousTotalOut);
        }
    } // endwhile

    return success;
}

- (BOOL)finalizeEncoderContext:(nonnull NOZDeflateEncoderContext *)context
{
    if (!context.zStreamOpen) {
        return NO;
    }

    BOOL success = YES;
    BOOL finishedDeflate = NO;
    z_stream* zStream = context.zStream;
    zStream->avail_in = 0;
    while (success && !finishedDeflate) {
        uLong previousTotalOut;
        if (zStream->avail_out == 0) {
            if (!context.flushCallback(self, context, context.compressedDataBuffer, context.compressedDataPosition)) {
                success = NO;
            }
            zStream->total_in = 0;
            context.compressedDataPosition = 0;
            zStream->avail_out = (UInt32)context.compressedDataBufferSize;
            zStream->next_out = context.compressedDataBuffer;
        }

        previousTotalOut = zStream->total_out;
        if (success) {
            int err = deflate(zStream, Z_FINISH);
            if (err != Z_OK) {
                if (err == Z_STREAM_END) {
                    finishedDeflate = YES;
                } else {
                    success = NO;
                }
            }
        }
        context.compressedDataPosition += zStream->total_out - previousTotalOut;
    }

    if (success && context.compressedDataPosition > 0) {
        success = context.flushCallback(self, context, context.compressedDataBuffer, context.compressedDataPosition);
        zStream->total_in = 0;
        context.compressedDataPosition = 0;
    }

    context.encodedDataWasText = (zStream->data_type == Z_ASCII);

    do {
        int err = deflateEnd(zStream);
        if (success) {
            success = (err == Z_OK);
        }
        context.zStreamOpen = NO;
        context.flushCallback = NULL;
    } while (0);

    return success;
}

@end

#pragma mark - Deflate Decoder

@interface NOZDeflateDecoderContext : NSObject <NOZDecoderContext>
@property (nonatomic, copy, nullable) NOZFlushCallback flushCallback;
@property (nonatomic) BOOL zStreamOpen;
@property (nonatomic) BOOL hasFinished;

@property (nonatomic, readonly) z_stream *zStream;
@property (nonatomic, readonly) Byte *decompressedDataBuffer;
@property (nonatomic, readonly) size_t decompressedDataBufferSize;
//@property (nonatomic) size_t decompressedDataPosition;

- (void)doubleDecompressDataBuffer;

@end

@implementation NOZDeflateDecoderContext
{
    z_stream _zStream;
}

- (instancetype)init
{
    if (self = [super init]) {
        _zStream.zalloc = NULL;
        _zStream.zfree = NULL;
        _zStream.opaque = NULL;
        _zStream.next_in = 0;
        _zStream.avail_in = 0;

        _decompressedDataBufferSize = NSPageSize();
        _decompressedDataBuffer = malloc(_decompressedDataBufferSize);
    }
    return self;
}

- (void)dealloc
{
    free(_decompressedDataBuffer);
    if (_zStreamOpen) {
        inflateEnd(&_zStream);
    }
}

- (z_stream *)zStream
{
    return &_zStream;
}

- (void)doubleDecompressDataBuffer
{
    static const size_t kMaxBufferSize = 5 * 1024 * 1024; // 5MBs
    if (_decompressedDataBufferSize == kMaxBufferSize) {
        _decompressedDataBufferSize = 0;
        free(_decompressedDataBuffer);
        _decompressedDataBuffer = NULL;
        return;
    }

    size_t newSize = _decompressedDataBufferSize * 2;
    if (newSize > kMaxBufferSize) {
        newSize = kMaxBufferSize;
    }
    _decompressedDataBuffer = reallocf(_decompressedDataBuffer, newSize);
    if (NULL != _decompressedDataBuffer) {
        _decompressedDataBufferSize = newSize;
    }
}

@end

@implementation NOZDeflateDecoder

- (nonnull NOZDeflateDecoderContext *)createContextForDecodingWithBitFlags:(UInt16)bitFlags
                                                             flushCallback:(nonnull NOZFlushCallback)callback
{
    NOZDeflateDecoderContext *context = [[NOZDeflateDecoderContext alloc] init];
    context.flushCallback = callback;
    return context;
}

- (BOOL)initializeDecoderContext:(nonnull NOZDeflateDecoderContext *)context
{
    if (Z_OK != inflateInit2(context.zStream, -MAX_WBITS)) {
        return NO;
    }
    context.zStreamOpen = YES;
    return YES;
}

- (BOOL)decodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull NOZDeflateDecoderContext *)context
{
    if (context.hasFinished) {
        return YES;
    }

    if (!context.zStreamOpen) {
        return NO;
    }

    z_stream *zStream = context.zStream;
    int zErr = Z_OK;
    zStream->avail_in = (UInt32)length;
    zStream->next_in = (Byte*)bytes;

    do {

        zStream->avail_out = (UInt32)context.decompressedDataBufferSize;
        zStream->next_out = context.decompressedDataBuffer;

        if (zStream->avail_out > 0) {
            zErr = inflate(zStream, Z_NO_FLUSH);
        } else {
            // no memory provided (likely due to running out of memory)
            zErr = Z_MEM_ERROR;
        }

        if (zErr == Z_OK || zErr == Z_STREAM_END || zErr == Z_BUF_ERROR) {

            size_t consumed = context.decompressedDataBufferSize - zStream->avail_out;
            if (consumed > 0) {
                if (!context.flushCallback(self, context, context.decompressedDataBuffer, consumed)) {
                    zErr = Z_UNKNOWN;
                }
            }

            // Z_BUF_ERROR is not fatal
            if (zErr == Z_BUF_ERROR) {

                // did we run out of output buffer?
                if (zStream->avail_out == 0 && zStream->avail_in > 0) {
                    // not enough buffer, double it
                    [context doubleDecompressDataBuffer];

                    // retry
                    zStream->avail_out = 0;
                    zErr = Z_OK;
                }
                // else, we ran out of input buffer... move along!

            }

        }

    } while (zStream->avail_out == 0 && zErr == Z_OK);

    if (zErr == Z_STREAM_END) {
        context.hasFinished = YES;
    } else if (zErr == Z_BUF_ERROR && length > 0) {
        // continue
    } else if (zErr != Z_OK) {
        return NO;
    }

    if (!length) {
        context.hasFinished = YES;
    }

    return YES;
}

- (BOOL)finalizeDecoderContext:(nonnull NOZDeflateDecoderContext *)context
{
    if (context.zStreamOpen) {
        inflateEnd(context.zStream);
        context.zStreamOpen = NO;
    }
    return YES;
}

@end
