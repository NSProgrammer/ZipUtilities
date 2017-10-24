//
//  NSData+NOZAdditions.h
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
 @param decoder the `NOZDecoder` to decompress with
 @return The decompressed data or `nil` if an error was encountered
 */
- (nullable NSData *)noz_dataByDecompressing:(nonnull id<NOZDecoder>)decoder;

@end
