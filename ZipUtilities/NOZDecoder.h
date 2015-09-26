//
//  NOZDecoder.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/25/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

@import Foundation;

#import "NOZCompression.h"

/**
 Protocol for encapsulating the context and state of a decoding process.
 A context object must always be able to clean itself up on dealloc and should
 not rely on `finalize` to clean it up.
 */
@protocol NOZDecoderContext <NSObject>
/**
 return `YES` once if the decoding is known to have completed and
 any future call to decodeBytes will be a considered no-op (returning `YES`).
 If the decoder is provided a zero length buffer to decode, there is no more
 data to decode, but the decoder may continue decoding.
 The decoder will have it's decode method called until an error is encountered
 or hasFinished returns `YES`.
 */
- (BOOL)hasFinished;
@end


/**
 Protocol to implement for constructing a compression decoder.
 */
@protocol NOZDecoder <NSObject>

/**
 Create a new context object to track the decoding process.
 @param flags The bit flags that were specefied for this encoder.
 @param callback The `NOZFlushCallback` that will be used to output the decompressed data
 @return the new context object
 */
- (nonnull id<NOZDecoderContext>)createContextForDecodingWithBitFlags:(UInt16)flags
                                                        flushCallback:(nonnull NOZFlushCallback)callback;

/**
 Initialize the decoding process.
 Call this first for each decoding process.
 If it succeeds, be sure to pair it with a call to `finalizeDecoderContext:error:`.
 */
- (BOOL)initializeDecoderContext:(nonnull id<NOZDecoderContext>)context;

/**
 Decode the provided byte buffer.
 Call this as many times as necessary to get all bytes of a source decoded
 (or until a failure occurs).
 */
- (BOOL)decodeBytes:(nonnull const Byte*)bytes
             length:(size_t)length
            context:(nonnull id<NOZDecoderContext>)context;

/**
 Finalize the decoding process.
 */
- (BOOL)finalizeDecoderContext:(nonnull id<NOZDecoderContext>)context;

@end
