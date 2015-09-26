//
//  NOZCompression.h
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

@import Foundation;

@protocol NOZZipEntry;

/**
 The compression level to use.
 Lower levels execute faster, while higher levels will achieve a higher compression ratio.
 */
typedef NS_ENUM(SInt16, NOZCompressionLevel)
{
    NOZCompressionLevelNone = 0,
    NOZCompressionLevelMin = 1,
    NOZCompressionLevelVeryLow = 2,
    NOZCompressionLevelLow = 3,
    NOZCompressionLevelMediumLow = 4,
    NOZCompressionLevelMedium = 5,
    NOZCompressionLevelMediumHigh = 6,
    NOZCompressionLevelHigh = 7,
    NOZCompressionLevelVeryHigh = 8,
    NOZCompressionLevelMax = 9,

    NOZCompressionLevelDefault = -1,
};

/**

 The compression method to use.
 Only 0 (don't compress) and 8 (deflate) are supported by default.
 Additional methods can be supported by updating the compression encoders and decoders.

 ### `NOZUpdateCompressionMethodEncoder(NOZCompressionMethod method, id<NOZEncoder> __nullable encoder);`

 Updates the known compression method encoder to be _encoder_.
 Provide `nil` to make the _method_ unsupported for compression.

 ### `NOZUpdateCompressionMethodDecoder(NOZCompressionMethod method, id<NOZDecoder> __nullable decoder);`
 
 Updates the known compression method decoder to be _decoder_.
 Provide `nil` to make the _method_ unsupported for decompression.

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


    /** WAV Pack */
    NOZCompressionMethodWAVPack     = 97,
    /** PPM version 1 revision 1 */
    NOZCompressionMethodPPMv1rev1   = 98,
};

//! Block for flushing a buffer of bytes
typedef BOOL(^NOZFlushCallback)(id __nonnull coder, id __nonnull context, const Byte* __nonnull bufferToFlush, size_t length);

@protocol NOZDecoder;
@protocol NOZEncoder;

//! Retrieve the compression encoder for a given method.  Will return `nil` if nothing is registered.
FOUNDATION_EXTERN id<NOZEncoder> __nullable NOZEncoderForCompressionMethod(NOZCompressionMethod method);
//! Set the compression encoder for a given method.  Setting `nil` will clear the encoder.  Whatever encoder is registered for a given method will be used when _ZipUtilities_ compression occurs.
FOUNDATION_EXTERN void NOZUpdateCompressionMethodEncoder(NOZCompressionMethod method, id<NOZEncoder> __nullable encoder);

//! Retrieve the compression decoder for a given method.  Will return `nil` if nothing is registered.
FOUNDATION_EXTERN id<NOZDecoder> __nullable NOZDecoderForCompressionMethod(NOZCompressionMethod method);
//! Set the compression decoder for a given method.  Setting `nil` will clear the decoder.  Whatever decoder is registered for a given method will be used when _ZipUtilities_ compression occurs.
FOUNDATION_EXTERN void NOZUpdateCompressionMethodDecoder(NOZCompressionMethod method, id<NOZDecoder> __nullable decoder);
