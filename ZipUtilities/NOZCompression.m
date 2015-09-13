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
#import "NOZUtils_Project.h"
#import "NOZZipEntry.h"

static dispatch_queue_t sCompressionCoderQueue = NULL;
static NSMutableDictionary<NSNumber *, id<NOZCompressionEncoder>> *sCompressionEncoders = nil;
static NSMutableDictionary<NSNumber *, id<NOZCompressionDecoder>> *sCompressionDecoders = nil;

__attribute__((constructor))
static void NOZCompressionConstructor(void)
{
    sCompressionCoderQueue = dispatch_queue_create("com.ziputilities.coders", DISPATCH_QUEUE_CONCURRENT);
    sCompressionEncoders = [NSMutableDictionary dictionary];
    sCompressionDecoders = [NSMutableDictionary dictionary];

    sCompressionEncoders[@(NOZCompressionMethodDeflate)] = [[NOZDeflateEncoder alloc] init];
    sCompressionEncoders[@(NOZCompressionMethodNone)] = [[NOZRawEncoder alloc] init];

    sCompressionDecoders[@(NOZCompressionMethodDeflate)] = [[NOZDeflateDecoder alloc] init];
    sCompressionDecoders[@(NOZCompressionMethodNone)] = [[NOZRawDecoder alloc] init];
}

id<NOZCompressionEncoder> __nullable NOZEncoderForCompressionMethod(NOZCompressionMethod method)
{
    __block id<NOZCompressionEncoder> encoder;
    dispatch_sync(sCompressionCoderQueue, ^{
        encoder = sCompressionEncoders[@(method)];
    });
    return encoder;
}

void NOZUpdateCompressionMethodEncoder(NOZCompressionMethod method, id<NOZCompressionEncoder> __nullable encoder)
{
    dispatch_barrier_async(sCompressionCoderQueue, ^{
        if (encoder) {
            sCompressionEncoders[@(method)] = encoder;
        } else {
            [sCompressionEncoders removeObjectForKey:@(method)];
        }
    });
}

id<NOZCompressionDecoder> __nullable NOZDecoderForCompressionMethod(NOZCompressionMethod method)
{
    __block id<NOZCompressionDecoder> decoder;
    dispatch_sync(sCompressionCoderQueue, ^{
        decoder = sCompressionDecoders[@(method)];
    });
    return decoder;
}

void NOZUpdateCompressionMethodDecoder(NOZCompressionMethod method, id<NOZCompressionDecoder> __nullable decoder)
{
    dispatch_barrier_async(sCompressionCoderQueue, ^{
        if (decoder) {
            sCompressionDecoders[@(method)] = decoder;
        } else {
            [sCompressionDecoders removeObjectForKey:@(method)];
        }
    });
}
