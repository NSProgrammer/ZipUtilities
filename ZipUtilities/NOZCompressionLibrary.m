//
//  NOZCompressionLibrary.m
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
#import "NOZCompressionLibrary.h"
#import "NOZEncoder.h"
#import "NOZDecoder.h"
#import "NOZUtils_Project.h"
#import "NOZZipEntry.h"

@implementation NOZCompressionLibrary
{
    dispatch_queue_t _coderQueue;
    NSMutableDictionary<NSNumber *, id<NOZEncoder>> *_encoders;
    NSMutableDictionary<NSNumber *, id<NOZDecoder>> *_decoders;
}

+ (instancetype)sharedInstance
{
    static NOZCompressionLibrary *sInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[NOZCompressionLibrary alloc] initInternal];
    });
    return sInstance;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (nonnull instancetype)initInternal
{
    if (self = [super init]) {
        _coderQueue = dispatch_queue_create("com.ziputilities.coders", DISPATCH_QUEUE_CONCURRENT);
        _encoders = [NSMutableDictionary dictionary];
        _decoders = [NSMutableDictionary dictionary];

        _encoders[@(NOZCompressionMethodDeflate)] = [[NOZDeflateEncoder alloc] init];
        _encoders[@(NOZCompressionMethodNone)] = [[NOZRawEncoder alloc] init];

        _decoders[@(NOZCompressionMethodDeflate)] = [[NOZDeflateDecoder alloc] init];
        _decoders[@(NOZCompressionMethodNone)] = [[NOZRawDecoder alloc] init];
    }
    return self;
}

- (NSDictionary<NSNumber *, id<NOZEncoder>> *)allEncoders
{
    __block NSDictionary<NSNumber *, id<NOZEncoder>> *encoders;
    dispatch_sync(_coderQueue, ^{
        encoders = [_encoders copy];
    });
    return encoders;
}

- (NSDictionary<NSNumber *, id<NOZEncoder>> *)allDecoders
{
    __block NSDictionary<NSNumber *, id<NOZEncoder>> *decoders;
    dispatch_sync(_coderQueue, ^{
        decoders = [_decoders copy];
    });
    return decoders;
}

- (id<NOZEncoder>)encoderForMethod:(NOZCompressionMethod)method
{
    __block id<NOZEncoder> encoder;
    dispatch_sync(_coderQueue, ^{
        encoder = _encoders[@(method)];
    });
    return encoder;
}

- (id<NOZDecoder>)decoderForMethod:(NOZCompressionMethod)method
{
    __block id<NOZDecoder> decoder;
    dispatch_sync(_coderQueue, ^{
        decoder = _decoders[@(method)];
    });
    return decoder;
}

- (void)setEncoder:(nullable id<NOZEncoder>)encoder forMethod:(NOZCompressionMethod)method
{
    dispatch_barrier_async(_coderQueue, ^{
        if (encoder) {
            _encoders[@(method)] = encoder;
        } else {
            [_encoders removeObjectForKey:@(method)];
        }
    });
}

- (void)setDecoder:(nullable id<NOZDecoder>)decoder forMethod:(NOZCompressionMethod)method
{
    dispatch_barrier_async(_coderQueue, ^{
        if (decoder) {
            _decoders[@(method)] = decoder;
        } else {
            [_decoders removeObjectForKey:@(method)];
        }
    });
}

@end
