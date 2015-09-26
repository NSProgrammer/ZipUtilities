//
//  NOZCompression.m
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

#import "NOZ_Project.h"
#import "NOZCompression.h"
#import "NOZEncoder.h"
#import "NOZDecoder.h"
#import "NOZUtils_Project.h"
#import "NOZZipEntry.h"

static dispatch_queue_t sCoderQueue = NULL;
static NSMutableDictionary<NSNumber *, id<NOZEncoder>> *sEncoders = nil;
static NSMutableDictionary<NSNumber *, id<NOZDecoder>> *sDecoders = nil;

__attribute__((constructor))
static void NOZCompressionConstructor(void)
{
    sCoderQueue = dispatch_queue_create("com.ziputilities.coders", DISPATCH_QUEUE_CONCURRENT);
    sEncoders = [NSMutableDictionary dictionary];
    sDecoders = [NSMutableDictionary dictionary];

    sEncoders[@(NOZCompressionMethodDeflate)] = [[NOZDeflateEncoder alloc] init];
    sEncoders[@(NOZCompressionMethodNone)] = [[NOZRawEncoder alloc] init];

    sDecoders[@(NOZCompressionMethodDeflate)] = [[NOZDeflateDecoder alloc] init];
    sDecoders[@(NOZCompressionMethodNone)] = [[NOZRawDecoder alloc] init];
}

id<NOZEncoder> __nullable NOZEncoderForCompressionMethod(NOZCompressionMethod method)
{
    __block id<NOZEncoder> encoder;
    dispatch_sync(sCoderQueue, ^{
        encoder = sEncoders[@(method)];
    });
    return encoder;
}

void NOZUpdateCompressionMethodEncoder(NOZCompressionMethod method, id<NOZEncoder> __nullable encoder)
{
    dispatch_barrier_async(sCoderQueue, ^{
        if (encoder) {
            sEncoders[@(method)] = encoder;
        } else {
            [sEncoders removeObjectForKey:@(method)];
        }
    });
}

id<NOZDecoder> __nullable NOZDecoderForCompressionMethod(NOZCompressionMethod method)
{
    __block id<NOZDecoder> decoder;
    dispatch_sync(sCoderQueue, ^{
        decoder = sDecoders[@(method)];
    });
    return decoder;
}

void NOZUpdateCompressionMethodDecoder(NOZCompressionMethod method, id<NOZDecoder> __nullable decoder)
{
    dispatch_barrier_async(sCoderQueue, ^{
        if (decoder) {
            sDecoders[@(method)] = decoder;
        } else {
            [sDecoders removeObjectForKey:@(method)];
        }
    });
}
