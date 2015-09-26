//
//  NOZEncoder.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/25/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

@import Foundation;

#import "NOZCompression.h"

/**
 Protocol for encapsulating the context and state of an encoding process.
 A context object must always be able to clean itself up on dealloc and should
 not rely on `finalize` to clean it up.
 */
@protocol NOZEncoderContext <NSObject>
/** return `YES` if the encoded data was known to be text.  `NO` otherwise. */
- (BOOL)encodedDataWasText;
@end


/**
 Protocol to implement for constructing a compression encoder.
 */
@protocol NOZEncoder <NSObject>

/**
 Return any bit flags related to the given entry for hinting at the compression that will be used.
 */
- (UInt16)bitFlagsForEntry:(nonnull id<NOZZipEntry>)entry;

/**
 Create a new context object to track the encoding process.
 @param flags The bit flags that were specefied for this encoder.
 @param level The level of compression requested
 @param callback The `NOZFlushCallback` that will be used to output the compressed data
 @return the new context object
 */
- (nonnull id<NOZEncoderContext>)createContextWithBitFlags:(UInt16)bitFlags
                                          compressionLevel:(NOZCompressionLevel)level
                                             flushCallback:(nonnull NOZFlushCallback)callback;

/**
 Initialize the encoding process.
 Call this first for each encoding process.
 If it succeeds, be sure to pair it with a call to `finalizeEncoderContext:`.
 */
- (BOOL)initializeEncoderContext:(nonnull id<NOZEncoderContext>)context;

/**
 Encode the provided byte buffer.
 Call this as many times as necessary to get all bytes of a source encoded
 (or until a failure occurs).
 */
- (BOOL)encodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull id<NOZEncoderContext>)context;

/**
 Finalize the encoding process.
 */
- (BOOL)finalizeEncoderContext:(nonnull id<NOZEncoderContext>)context;

@end
