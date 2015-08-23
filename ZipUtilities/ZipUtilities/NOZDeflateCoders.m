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
#import "NOZCompression.h"
#import "NOZUtils_Project.h"
#import "NOZZipEntry.h"

#include "zlib.h"

#pragma mark - Deflate Encoder

@interface NOZDeflateEncoderContext : NSObject <NOZCompressionEncoderContext>
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
    struct {
        z_stream zStream;
        Byte* compressedDataBuffer;
        size_t compressedDataBufferSize;

        SInt16 compressionLevel;
        BOOL zStreamOpen:1;
    } _internal;
}

- (BOOL)zStreamOpen
{
    return _internal.zStreamOpen;
}

- (void)setZStreamOpen:(BOOL)zStreamOpen
{
    _internal.zStreamOpen = !!zStreamOpen;
}

- (z_stream *)zStream
{
    return &_internal.zStream;
}

- (Byte*)compressedDataBuffer
{
    return _internal.compressedDataBuffer;
}

- (NOZCompressionLevel)compressionLevel
{
    return _internal.compressionLevel;
}

- (void)setCompressionLevel:(NOZCompressionLevel)compressionLevel
{
    _internal.compressionLevel = compressionLevel;
}

- (size_t)compressedDataBufferSize
{
    return _internal.compressedDataBufferSize;
}

- (nonnull instancetype)init
{
    if (self = [super init]) {
        _internal.compressedDataBuffer = malloc(NSPageSize());
        _internal.compressedDataBufferSize = NSPageSize();

        _internal.zStream.avail_in = 0;
        _internal.zStream.avail_out = (UInt32)NSPageSize();
        _internal.zStream.next_out = _internal.compressedDataBuffer;
        _internal.zStream.total_in = 0;
        _internal.zStream.total_out = 0;
        _internal.zStream.data_type = Z_BINARY;
        _internal.zStream.zalloc = NULL;
        _internal.zStream.zfree = NULL;
        _internal.zStream.opaque = NULL;

        _internal.compressionLevel = NOZCompressionLevelDefault;
    }
    return self;
}

- (void)dealloc
{
    free(_internal.compressedDataBuffer);
    if (_internal.zStreamOpen) {
        deflateEnd(&_internal.zStream);
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

- (nonnull NOZDeflateEncoderContext *)createContextForEncodingEntry:(nonnull id<NOZZipEntry>)entry flushCallback:(nonnull NOZFlushCallback)callback;
{
    NOZDeflateEncoderContext *context = [[NOZDeflateEncoderContext alloc] init];
    context.flushCallback = callback;
    context.compressionLevel = entry.compressionLevel;
    return context;
}

- (BOOL)initializeEncoderContext:(nonnull NOZDeflateEncoderContext *)context
                           error:(out NSError * __nullable * __nullable)error
{
    if (Z_OK != deflateInit2(context.zStream,
                             context.compressionLevel,
                             Z_DEFLATED,
                             -MAX_WBITS,
                             8 /* default memory level */,
                             Z_DEFAULT_STRATEGY)) {
        if (error) {
            *error = NOZError(NOZErrorCodeZipFailedToCompressEntry, nil);
        }
        return NO;
    }

    context.zStreamOpen = YES;
    return YES;
}

- (BOOL)encodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull NOZDeflateEncoderContext *)context
              error:(out NSError * __nullable * __nullable)error
{
    __block BOOL success = YES;
    noz_defer(^{
        if (!success && error && !*error) {
            *error = NOZError(NOZErrorCodeZipFailedToCompressEntry, nil);
        }
    });

    if (!context.zStreamOpen) {
        success = NO;
        return NO;
    }

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
                         error:(out NSError * __nullable * __nullable)error
{
    __block BOOL success = YES;
    noz_defer(^{
        if (!success && error && !*error) {
            *error = NOZError(NOZErrorCodeZipFailedToCompressEntry, nil);
        }
    });

    if (!context.zStreamOpen) {
        success = NO;
        return NO;
    }

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

@interface NOZDeflateDecoderContext : NSObject <NOZCompressionDecoderContext>
@property (nonatomic, copy, nullable) NOZFlushCallback flushCallback;
@property (nonatomic) BOOL zStreamOpen;
@property (nonatomic) BOOL hasFinished;

@property (nonatomic, readonly) z_stream *zStream;
@property (nonatomic, readonly) Byte *decompressedDataBuffer;
@property (nonatomic, readonly) size_t decompressedDataBufferSize;
//@property (nonatomic) size_t decompressedDataPosition;
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

@end

@implementation NOZDeflateDecoder

- (nonnull NOZDeflateDecoderContext *)createContextForDecodingWithFlushCallback:(nonnull NOZFlushCallback)callback
{
    NOZDeflateDecoderContext *context = [[NOZDeflateDecoderContext alloc] init];
    context.flushCallback = callback;
    return context;
}

- (BOOL)initializeDecoderContext:(nonnull NOZDeflateDecoderContext *)context
                           error:(out NSError * __nullable * __nullable)error
{
    if (Z_OK != inflateInit2(context.zStream, -MAX_WBITS)) {
        if (error) {
            *error = NOZError(NOZErrorCodeUnzipCannotDecompressFileEntry, nil);
        }
        return NO;
    }
    context.zStreamOpen = YES;
    return YES;
}

- (BOOL)decodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull NOZDeflateDecoderContext *)context
              error:(out NSError * __nullable * __nullable)error
{
    if (context.hasFinished) {
        return YES;
    }

    if (!context.zStreamOpen) {
        if (error) {
            *error = NOZError(NOZErrorCodeUnzipCannotDecompressFileEntry, nil);
        }
        return NO;
    }

    z_stream *zStream = context.zStream;
    int zErr = Z_OK;
    zStream->avail_in = (UInt32)length;
    zStream->next_in = (Byte*)bytes;

    do {

        zStream->avail_out = (UInt32)context.decompressedDataBufferSize;
        zStream->next_out = context.decompressedDataBuffer;

        zErr = inflate(zStream, Z_NO_FLUSH);

        if (zErr == Z_OK || zErr == Z_STREAM_END) {

            size_t consumed = context.decompressedDataBufferSize - zStream->avail_out;
            if (!context.flushCallback(self, context, context.decompressedDataBuffer, consumed)) {
                zErr = Z_UNKNOWN;
            }

        }

    } while (zStream->avail_out == 0 && zErr == Z_OK);

    if (zErr == Z_STREAM_END) {
        context.hasFinished = YES;
    } else if (zErr != Z_OK) {
        if (error) {
            *error = NOZError(NOZErrorCodeUnzipCannotDecompressFileEntry, nil);
        }
        return NO;
    }

    if (!length) {
        context.hasFinished = YES;
    }

    return YES;
}

- (BOOL)finalizeDecoderContext:(nonnull NOZDeflateDecoderContext *)context
                         error:(out NSError * __nullable * __nullable)error
{
    if (context.zStreamOpen) {
        inflateEnd(context.zStream);
        context.zStreamOpen = NO;
    }
    return YES;
}

@end
