//
//  NOZXAppleCompressionCoder.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/12/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

#import <ZipUtilities/ZipUtilities.h>

#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#define COMPRESSION_LIB_AVAILABLE 1
#elif TARGET_OS_MAC && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1011
#define COMPRESSION_LIB_AVAILABLE 1
#else
#define COMPRESSION_LIB_AVAILABLE 0
#endif

#if COMPRESSION_LIB_AVAILABLE

#import <compression.h>

@interface NOZXAppleCompressionCoder : NSObject

+ (BOOL)isSupported;

+ (nullable id<NOZCompressionEncoder>)encoderWithAlgorithm:(compression_algorithm)algorithm;
+ (nullable id<NOZCompressionDecoder>)decoderWithAlgorithm:(compression_algorithm)algorithm;

- (nullable instancetype)init NS_UNAVAILABLE;
+ (nullable instancetype)new NS_UNAVAILABLE;

@end

#endif // COMPRESSION_LIB_AVAILABLE
