//
//  NSData+NOZAdditions.m
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

#import "NOZ_Project.h"
#import "NOZDecoder.h"
#import "NOZEncoder.h"
#import "NOZError.h"
#import "NSData+NOZAdditions.h"

@implementation NSData (NOZAdditions)

- (NSData *)noz_dataByCompressing:(id<NOZEncoder>)encoder compressionLevel:(NOZCompressionLevel)compressionLevel
{
    __block NSMutableData *encodedData = [NSMutableData data];
    id<NOZEncoderContext> context =
        [encoder createContextWithBitFlags:0
                          compressionLevel:compressionLevel
                             flushCallback:^BOOL(id<NOZEncoder> callbackEncoder, id<NOZEncoderContext> encoderContext, const Byte *bufferToFlush, size_t length) {
                                 [encodedData appendBytes:bufferToFlush length:length];
                                 return YES;
                             }];

    if (![encoder initializeEncoderContext:context]) {
        return nil;
    }

    __block BOOL wasError = NO;
    [self enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        wasError = ![encoder encodeBytes:(const Byte *)bytes length:byteRange.length context:context];
        if (wasError) {
            *stop = YES;
        }
    }];

    if (wasError || ![encoder finalizeEncoderContext:context]) {
        return nil;
    }

    return encodedData;
}

- (NSData *)noz_dataByDecompressing:(id<NOZDecoder>)decoder
{
    __block NSMutableData *encodedData = [NSMutableData data];
    id<NOZDecoderContext> context =
        [decoder createContextForDecodingWithBitFlags:0
                                        flushCallback:^BOOL(id<NOZDecoder> callbackDecoder, id<NOZDecoderContext> decoderContext, const Byte *bufferToFlush, size_t length) {
                                            [encodedData appendBytes:bufferToFlush length:length];
                                            return YES;
                                        }];

    if (![decoder initializeDecoderContext:context]) {
        return nil;
    }

    __block BOOL wasError = NO;
    [self enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        wasError = ![decoder decodeBytes:(const Byte *)bytes length:byteRange.length context:context];
        if (wasError) {
            *stop = YES;
        }
    }];

    while (!wasError && !context.hasFinished) {
        wasError = ![decoder decodeBytes:NULL length:0 context:context];
    }

    if (wasError) {
        return nil;
    }

    if (![decoder finalizeDecoderContext:context]) {
        return nil;
    }

    return encodedData;
}

@end
