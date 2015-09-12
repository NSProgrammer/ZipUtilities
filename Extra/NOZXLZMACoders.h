//
//  NOZXLZMACoders.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/9/15.
//  Copyright (c) 2015 NSProgrammer. All rights reserved.
//

#import "NOZXAppleCompressionCoder.h"

#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#define COMPRESSION_LIB_AVAILABLE 1
#elif TARGET_OS_MAC && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1011
#define COMPRESSION_LIB_AVAILABLE 1
#else
#define COMPRESSION_LIB_AVAILABLE 0
#endif

#if COMPRESSION_LIB_AVAILABLE

@interface NOZXLZMAEncoder : NOZXAppleCompressionCoder <NOZCompressionEncoder>
@end

@interface NOZXLZMADecoder : NOZXAppleCompressionCoder <NOZCompressionDecoder>
@end

#endif
