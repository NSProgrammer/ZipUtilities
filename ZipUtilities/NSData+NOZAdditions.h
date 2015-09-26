//
//  NSData+NOZAdditions.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/25/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

@import Foundation;

#import "NOZCompression.h"

@protocol NOZEncoder;
@protocol NOZDecoder;

/**
 Convenience category on `NSData` to permit easy compressing/decompressing of `NSData` to `NSData`
 */
@interface NSData (NOZAdditions)

/**
 Compress the receiver
 @param encoder the `NOZEncoder` to compress with
 @param compressionLevel the level to compress at (if supported by the _encoder_)
 @return The compressed data or `nil` if an error was encountered
 */
- (nullable NSData *)noz_dataByCompressing:(nonnull id<NOZEncoder>)encoder
                          compressionLevel:(NOZCompressionLevel)compressionLevel;

/**
 Decompress the receiver
 @param encoder the `NOZDecoder` to decompress with
 @return The decompressed data or `nil` if an error was encountered
 */
- (nullable NSData *)noz_dataByDecompressing:(nonnull id<NOZDecoder>)decoder;

@end
