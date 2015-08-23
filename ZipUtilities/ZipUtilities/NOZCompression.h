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

 ### `NOZUpdateCompressionMethodEncoder(NOZCompressionMethod method, id<NOZCompressionEncoder> __nullable encoder);`

 Updates the known compression method encoder to be _encoder_.
 Provide `nil` to make the _method_ unsupported for compression.

 ### `NOZUpdateCompressionMethodDecoder(NOZCompressionMethod method, id<NOZCompressionDecoder> __nullable decoder);`
 
 Updates the known compression method decoder to be _decoder_.
 Provide `nil` to make the _method_ unsupported for decompression.

 */
typedef NS_ENUM(UInt16, NOZCompressionMethod)
{
    /** No compression is supported by default. */
    NOZCompressionMethodNone        = 0,
    NOZCompressionMethodShrink      = 1,
    NOZCompressionMethodReduce1     = 2,
    NOZCompressionMethodReduce2     = 3,
    NOZCompressionMethodReduce3     = 4,
    NOZCompressionMethodReduce4     = 5,
    NOZCompressionMethodImplode     = 6,
    NOZCompressionMethodReserved7   = 7,
    /** Deflate is supported by default via zlib. */
    NOZCompressionMethodDeflate     = 8,
    NOZCompressionMethodDeflate64   = 9,
    NOZCompressionMethodIBMTERSEOld = 10,
    NOZCompressionMethodReserved11  = 11,
    NOZCompressionMethodBZip2       = 12,
    NOZCompressionMethodReserved13  = 13,
    NOZCompressionMethodLZMA        = 14,
    NOZCompressionMethodReserved15  = 15,
    NOZCompressionMethodReserved16  = 16,
    NOZCompressionMethodReserved17  = 17,
    NOZCompressionMethodIBMTERSENew = 18,
    NOZCompressionMethodLZ77        = 19,


    NOZCompressionMethodWAVPack     = 97,
    NOZCompressionMethodPPMv1rev1   = 98,
};

typedef BOOL(^NOZFlushCallback)(id __nonnull coder, id __nonnull context, const Byte* __nonnull bufferToFlush, size_t length);

/**
 Protocol for encapsulating the context and state of an encoding process.
 */
@protocol NOZCompressionEncoderContext <NSObject>
/** return `YES` if the encoded data was known to be text.  `NO` otherwise. */
- (BOOL)encodedDataWasText;
@end

/**
 Protocol for encapsulating the context and state of a decoding process.
 */
@protocol NOZCompressionDecoderContext <NSObject>
@end

/**
 Protocol to implement for constructing a compression encoder.
 */
@protocol NOZCompressionEncoder <NSObject>

/**
 Create a new context object to track the encoding process.
 @param entry The `NOZZipEntry` that will be encoded
 @param callback The `NOZFlushCallback` that will be used to output the compressed data
 @return the new context object
 */
- (nonnull id<NOZCompressionEncoderContext>)createContextForEncodingEntry:(nonnull id<NOZZipEntry>)entry flushCallback:(nonnull NOZFlushCallback)callback;

/**
 Initialize the encoding process.
 Call this first for each encoding process.
 If it succeeds, be sure to pair it with a call to `finalizeEncoderContext:error:`.
 */
- (BOOL)initializeEncoderContext:(nonnull id<NOZCompressionEncoderContext>)context
                           error:(out NSError * __nullable * __nullable)error;

/**
 Encode the provided byte buffer.
 Call this as many times as necessary to get all bytes of a source encoded
 (or until a failure occurs).
 */
- (BOOL)encodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull id<NOZCompressionEncoderContext>)context
              error:(out NSError * __nullable * __nullable)error;

/**
 Finalize the encoding process.
 */
- (BOOL)finalizeEncoderContext:(nonnull id<NOZCompressionEncoderContext>)context
                         error:(out NSError * __nullable * __nullable)error;
@end

/**
 Protocol to implement for constructing a compression decoder.
 */
@protocol NOZCompressionDecoder <NSObject>

/**
 Create a new context object to track the decoding process.
 @param callback The `NOZFlushCallback` that will be used to output the decompressed data
 @return the new context object
 */
- (nonnull id<NOZCompressionDecoderContext>)createContextForDecodingWithFlushCallback:(nonnull NOZFlushCallback)callback;

/**
 Initialize the decoding process.
 Call this first for each decoding process.
 If it succeeds, be sure to pair it with a call to `finalizeDecoderContext:error:`.
 */
- (BOOL)initializeDecoderContext:(nonnull id<NOZCompressionDecoderContext>)context
                           error:(out NSError * __nullable * __nullable)error;
/**
 Decode the provided byte buffer.
 Call this as many times as necessary to get all bytes of a source decoded
 (or until a failure occurs).
 */
- (BOOL)decodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull id<NOZCompressionEncoderContext>)context
              error:(out NSError * __nullable * __nullable)error;

/**
 Finalize the decoding process.
 */
- (BOOL)finalizeDecoderContext:(nonnull id<NOZCompressionDecoderContext>)context
                         error:(out NSError * __nullable * __nullable)error;
@end


FOUNDATION_EXTERN id<NOZCompressionEncoder> __nullable NOZEncoderForCompressionMethod(NOZCompressionMethod method);
FOUNDATION_EXTERN void NOZUpdateCompressionMethodEncoder(NOZCompressionMethod method, id<NOZCompressionEncoder> __nullable encoder);

FOUNDATION_EXTERN id<NOZCompressionDecoder> __nullable NOZDecoderForCompressionMethod(NOZCompressionMethod method);
FOUNDATION_EXTERN void NOZUpdateCompressionMethodDecoder(NOZCompressionMethod method, id<NOZCompressionDecoder> __nullable decoder);
