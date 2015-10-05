//
//  NSStream+NOZAdditions.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/30/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

@import Foundation;

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
