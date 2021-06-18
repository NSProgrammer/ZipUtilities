//
//  NOZCompression.h
//  ZipUtilities
//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Nolan O'Brien
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

#import <Foundation/Foundation.h>

@protocol NOZZipEntry;
@protocol NOZEncoder;

//! The compression level for use with encoding, from `0.0f` to `1.0f`
typedef float NOZCompressionLevel;
//! The max compression level
static const NOZCompressionLevel NOZCompressionLevelMax = 1.f;
//! The min compression level
static const NOZCompressionLevel NOZCompressionLevelMin = 0.f;
//! The default compression level for any decoder
static const NOZCompressionLevel NOZCompressionLevelDefault = -1.f;

FOUNDATION_EXTERN NSUInteger NOZCompressionLevelsForEncoder(id<NOZEncoder> __nullable encoder);
FOUNDATION_EXTERN NSUInteger NOZCompressionLevelToEncoderSpecificLevel(id<NOZEncoder> __nullable encoder,
                                                                       NOZCompressionLevel level);
FOUNDATION_EXTERN NOZCompressionLevel NOZCompressionLevelFromEncoderSpecificLevel(id<NOZEncoder> __nullable encoder,
                                                                                  NSUInteger encoderSpecificLevel);
FOUNDATION_EXTERN NSUInteger NOZCompressionLevelToCustomEncoderLevel(NOZCompressionLevel level,
                                                                     NSUInteger firstCustomLevel,
                                                                     NSUInteger lastCustomLevel,
                                                                     NSUInteger defaultCustomLevel);
FOUNDATION_EXTERN NOZCompressionLevel NOZCompressionLevelFromCustomEncoderLevel(NSUInteger firstCustomLevel,
                                                                                NSUInteger lastCustomLevel,
                                                                                NSUInteger customLevel);

/**
 The compression method to use.
 Only 0 (don't compress) and 8 (deflate) are supported by default.
 Additional methods can be supported by updating the compression encoders and decoders.
 See `NOZCompressionLibrary` for updating encoders/decoders.
 */
typedef NS_ENUM(UInt16, NOZCompressionMethod)
{
    /** No compression is supported by default. */
    NOZCompressionMethodNone        = 0,
    /** Shrink */
    NOZCompressionMethodShrink      = 1,
    /** Reduce #1 */
    NOZCompressionMethodReduce1     = 2,
    /** Reduce #2 */
    NOZCompressionMethodReduce2     = 3,
    /** Reduce #3 */
    NOZCompressionMethodReduce3     = 4,
    /** Reduce #4 */
    NOZCompressionMethodReduce4     = 5,
    /** Implode */
    NOZCompressionMethodImplode     = 6,
    /** Reserved by PKWare */
    NOZCompressionMethodReserved7   = 7,
    /** Deflate.  Supported by default via zlib. */
    NOZCompressionMethodDeflate     = 8,
    /** Deflate64 */
    NOZCompressionMethodDeflate64   = 9,
    /** IBM TERSE (old) */
    NOZCompressionMethodIBMTERSEOld = 10,
    /** Reserved by PKWare */
    NOZCompressionMethodReserved11  = 11,
    /** BZip2 */
    NOZCompressionMethodBZip2       = 12,
    /** Reserved by PKWare */
    NOZCompressionMethodReserved13  = 13,
    /** LZMA */
    NOZCompressionMethodLZMA        = 14,
    /** Reserved by PKWare */
    NOZCompressionMethodReserved15  = 15,
    /** Reserved by PKWare */
    NOZCompressionMethodReserved16  = 16,
    /** Reserved by PKWare */
    NOZCompressionMethodReserved17  = 17,
    /** IBM TERSE (new) */
    NOZCompressionMethodIBMTERSENew = 18,
    /** LZ77 */
    NOZCompressionMethodLZ77        = 19,
    /** Deprecated, Do Not Use */
    NOZCompressionMethodDeprecated20 = 20,

    /** ZStandard (Facebook) */
    NOZCompressionMethodZStandard   = 93, // added to v6.3.7 (circa 2019)
    /** MP3 Compression */
    NOZCompressionMethodMP3         = 94,
    /** XZ Compression */
    NOZCompressionMethodXZ          = 95,
    /** JPEG variant */
    NOZCompressionMethodJPEG        = 96,
    /** WAV Pack */
    NOZCompressionMethodWAVPack     = 97,
    /** PPM version 1 revision 1 */
    NOZCompressionMethodPPMv1rev1   = 98,
    /** AE-x encryption marker */
    NOZCompressionMethodAEXEncryption = 99,
};

//! Block for flushing a buffer of bytes
typedef BOOL(^NOZFlushCallback)(id __nonnull coder,
                                id __nonnull context,
                                const Byte* __nonnull bufferToFlush,
                                size_t length);
