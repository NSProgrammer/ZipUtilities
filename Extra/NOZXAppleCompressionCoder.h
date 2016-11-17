//
//  NOZXAppleCompressionCoder.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/12/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

#import <compression.h>
#import <Foundation/Foundation.h>

@protocol NOZEncoder;
@protocol NOZDecoder;

@interface NOZXAppleCompressionCoder : NSObject

+ (BOOL)isSupported;

+ (nullable id<NOZEncoder>)encoderWithAlgorithm:(compression_algorithm)algorithm;
+ (nullable id<NOZDecoder>)decoderWithAlgorithm:(compression_algorithm)algorithm;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end
