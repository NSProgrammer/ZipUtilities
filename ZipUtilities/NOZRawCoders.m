//
//  NOZCompression.m
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
#import "NOZUtils_Project.h"
#import "NOZZipEntry.h"

#pragma mark - Raw Encoder

@interface NOZRawEncoderContext : NSObject <NOZEncoderContext>
@property (nonatomic) BOOL encodedDataWasText;
@end

NOZ_OBJC_DIRECT_MEMBERS
@interface NOZRawEncoderContext (/* direct declarations */)
@property (nonatomic, copy, nullable) NOZFlushCallback flushCallback;
@end

NOZ_OBJC_DIRECT_MEMBERS
@implementation NOZRawEncoderContext
@end

NOZ_OBJC_DIRECT_MEMBERS
@implementation NOZRawEncoder

- (UInt16)bitFlagsForEntry:(id<NOZZipEntry>)entry
{
    return 0;
}

- (NOZRawEncoderContext *)createContextWithBitFlags:(UInt16)bitFlags
                                   compressionLevel:(NOZCompressionLevel)level
                                      flushCallback:(NOZFlushCallback)callback
{
    NOZRawEncoderContext *context = [[NOZRawEncoderContext alloc] init];
    context.flushCallback = callback;
    return context;
}

- (BOOL)initializeEncoderContext:(NOZRawEncoderContext *)context
{
    return YES;
}

- (BOOL)encodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(NOZRawEncoderContext *)context
{
    // direct passthrough
    if (!context.flushCallback(self, context, bytes, length)) {
        return NO;
    }

    return YES;
}

- (BOOL)finalizeEncoderContext:(NOZRawEncoderContext *)context
{
    context.flushCallback = NULL;
    return YES;
}

@end

#pragma mark - Raw Decoder

@interface NOZRawDecoderContext : NSObject <NOZDecoderContext>
@property (nonatomic) BOOL hasFinished;
@end

NOZ_OBJC_DIRECT_MEMBERS
@interface NOZRawDecoderContext (/* direct declarations */)
@property (nonatomic, copy, nullable) NOZFlushCallback flushCallback;
@end

NOZ_OBJC_DIRECT_MEMBERS
@implementation NOZRawDecoderContext
@end

NOZ_OBJC_DIRECT_MEMBERS
@implementation NOZRawDecoder

- (NOZRawDecoderContext *)createContextForDecodingWithBitFlags:(UInt16)bitFlags
                                                 flushCallback:(NOZFlushCallback)callback
{
    NOZRawDecoderContext *context = [[NOZRawDecoderContext alloc] init];
    context.flushCallback = callback;
    return context;
}

- (BOOL)initializeDecoderContext:(NOZRawDecoderContext *)context
{
    return YES;
}

- (BOOL)decodeBytes:(const Byte*)bytes
             length:(size_t)length
            context:(NOZRawDecoderContext *)context
{
    if (context.hasFinished) {
        return YES;
    }

    // direct passthrough
    if (!context.flushCallback(self, context, bytes, length)) {
        return NO;
    }

    if (!length) {
        context.hasFinished = YES;
    }

    return YES;
}

- (BOOL)finalizeDecoderContext:(NOZRawDecoderContext *)context
{
    context.flushCallback = NULL;
    return YES;
}

@end
