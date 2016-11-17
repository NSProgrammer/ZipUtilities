//
//  NOZXZStandardCompressionCoder.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 11/15/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NOZEncoder;
@protocol NOZDecoder;

@interface NOZXZStandardCompressionCoder : NSObject

+ (nullable id<NOZEncoder>)encoder;
+ (nullable id<NOZEncoder>)encoderWithDictionaryData:(nullable NSData *)dict;
+ (nullable id<NOZDecoder>)decoder;
+ (nullable id<NOZDecoder>)decoderWithDictionaryData:(nullable NSData *)dict;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end
