//
//  NOZCompressionLibrary.h
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

#import <ZipUtilities/NOZCompression.h>

@protocol NOZDecoder;
@protocol NOZEncoder;

/**
 Library of encoders and decoders for __ZipUtilities__
 */
@interface NOZCompressionLibrary : NSObject

/** All the encoders */
@property (atomic, nonnull, copy, readonly) NSDictionary<NSNumber *, id<NOZEncoder>> *allEncoders;
/** all the decoders */
@property (atomic, nonnull, copy, readonly) NSDictionary<NSNumber *, id<NOZDecoder>> *allDecoders;

/** singleton accessor */
+ (nonnull instancetype)sharedInstance;

/** unavailable */
- (nonnull instancetype)init NS_UNAVAILABLE;
/** unavailable */
+ (nonnull instancetype)new NS_UNAVAILABLE;

/**
 Retrieve the compression encoder for a given method.
 Will return `nil` if nothing is registered.
 */
- (nullable id<NOZEncoder>)encoderForMethod:(NOZCompressionMethod)method;
/**
 Retrieve the compression decoder for a given method.
 Will return `nil` if nothing is registered.
 */
- (nullable id<NOZDecoder>)decoderForMethod:(NOZCompressionMethod)method;

/**
 Set the compression encoder for a given method.
 Setting `nil` will clear the encoder.
 Whatever encoder is registered for a given method will be used when _ZipUtilities_ compression occurs.
 */
- (void)setEncoder:(nullable id<NOZEncoder>)encoder forMethod:(NOZCompressionMethod)method;
/**
 Set the compression decoder for a given method.
 Setting `nil` will clear the decoder.
 Whatever decoder is registered for a given method will be used when _ZipUtilities_ compression occurs.
 */
- (void)setDecoder:(nullable id<NOZDecoder>)decoder forMethod:(NOZCompressionMethod)method;

@end
