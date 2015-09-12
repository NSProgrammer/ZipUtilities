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
@end

@interface NOZXAppleCompressionCoderContext : NSObject <NOZCompressionDecoderContext, NOZCompressionEncoderContext>
@end

@interface NOZXAppleCompressionCoder (Protected)

- (nonnull NOZXAppleCompressionCoderContext *)createContextForAlgorithm:(compression_algorithm)algorithm
                                                              operation:(compression_stream_operation)operation
                                                               bitFlags:(UInt16)bitFlags
                                                          flushCallback:(nonnull NOZFlushCallback)callback;

- (BOOL)initializeWithContext:(nonnull NOZXAppleCompressionCoderContext *)context;

- (BOOL)codeBytes:(nullable const Byte*)bytes
           length:(size_t)length
            final:(BOOL)final
          context:(nonnull NOZXAppleCompressionCoderContext *)context;

- (BOOL)finalizeWithContext:(nonnull NOZXAppleCompressionCoderContext *)context;

@end

#endif // COMPRESSION_LIB_AVAILABLE
