//
//  NOZXLZMACoders.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/9/15.
//  Copyright (c) 2015 NSProgrammer. All rights reserved.
//

#import "NOZXLZMACoders.h"

#if COMPRESSION_LIB_AVAILABLE

#define kLZMABitFlagEOSMarkerPresent (1 << 1)

@implementation NOZXLZMAEncoder

- (instancetype)init
{
    if (self = [super init]) {
        
    }
    return self;
}

- (UInt16)bitFlagsForEntry:(id<NOZZipEntry>)entry
{
    return 0;
}

- (id<NOZCompressionEncoderContext>)createContextWithBitFlags:(UInt16)bitFlags
                                                     compressionLevel:(NOZCompressionLevel)level
                                                        flushCallback:(NOZFlushCallback)callback
{
    return [self createContextForAlgorithm:COMPRESSION_LZMA
                                 operation:COMPRESSION_STREAM_ENCODE
                                  bitFlags:bitFlags
                             flushCallback:callback];
}

- (BOOL)initializeEncoderContext:(NOZXAppleCompressionCoderContext *)context
{
    return [self initializeWithContext:context];
}

- (BOOL)encodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(NOZXAppleCompressionCoderContext *)context
{
    return [self codeBytes:bytes length:length final:NO context:context];
}

- (BOOL)finalizeEncoderContext:(NOZXAppleCompressionCoderContext *)context
{
    return [self finalizeWithContext:context];
}

@end

@implementation NOZXLZMADecoder

- (id<NOZCompressionDecoderContext>)createContextForDecodingWithBitFlags:(UInt16)flags
                                                           flushCallback:(NOZFlushCallback)callback
{
    return [self createContextForAlgorithm:COMPRESSION_LZMA
                                 operation:COMPRESSION_STREAM_DECODE
                                  bitFlags:flags
                             flushCallback:callback];
}

- (BOOL)initializeDecoderContext:(NOZXAppleCompressionCoderContext *)context
{
    return [self initializeWithContext:context];
}

- (BOOL)decodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(NOZXAppleCompressionCoderContext *)context
{
    return [self codeBytes:bytes length:length final:NO context:context];
}

- (BOOL)finalizeDecoderContext:(NOZXAppleCompressionCoderContext *)context
{
    return [self finalizeWithContext:context];
}

@end

#endif // COMPRESSION_LIB_AVAILABLE
