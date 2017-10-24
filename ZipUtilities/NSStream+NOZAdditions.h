//
//  NSStream+NOZAdditions.h
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

#import "NOZCompression.h"

@protocol NOZEncoder;
@protocol NOZDecoder;

/**
 Category for __ZipUtilities__ specific convenience methods
 */
@interface NSInputStream (NOZAdditions)

/**
 Create a stream that compresses it's bytes as they are read.  Useful for something like an `NSURLConnection`'s `NSURLRequest` or an `NSURLSessionUploadTask` that provide an `NSInputStream`.
 @param stream The uncompressed `NSInputStream` to wrap
 @param encoder The encoder to use for compressing (often best to use `NOZEncoderForCompressionMethod` to get an encoder)
 @param compressionLevel The level at which to compress (if supported by the _encoder_).
 @return an `NSInputStream` that compressed it's wrapped _stream_ as bytes are read.
 NOTE: The implementation of the wrapping `NSInputStream` could probably be further optimized.
 */
+ (nonnull NSInputStream *)noz_compressedInputStream:(nonnull NSInputStream *)stream
                                         withEncoder:(nonnull id<NOZEncoder>)encoder
                                    compressionLevel:(NOZCompressionLevel)compressionLevel;

@end

/**
 Category for __ZipUtilities__ specific convenience methods
 */
@interface NSStream (NOZAdditions)

/**
 Convenience method to acquire a pair of bount `NSInputStream` and `NSOutputStream` streams.
 Code comes directly from Apple sample code:
 https://developer.apple.com/library/ios/samplecode/SimpleURLConnections/Listings/PostController_m.html
 */
+ (void)noz_createBoundInputStream:(NSInputStream * __nonnull * __nullable)inputStreamPtr
                      outputStream:(NSOutputStream * __nonnull * __nullable)outputStreamPtr
                        bufferSize:(NSUInteger)bufferSize;

@end
