//
//  NSData+NOZAdditions.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/25/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
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

    if (wasError || ![decoder finalizeDecoderContext:context]) {
        return nil;
    }

    return encodedData;
}

@end
