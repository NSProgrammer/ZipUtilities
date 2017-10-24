//
//  NOZDecoder.h
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
 Can be provided zero _length_ if no more bytes to decode,
 but the _context_ still has `hasFinished` as `NO`
 */
- (BOOL)decodeBytes:(nullable const Byte*)bytes
             length:(size_t)length
            context:(nonnull id<NOZDecoderContext>)context;

/**
 Finalize the decoding process.
 */
- (BOOL)finalizeDecoderContext:(nonnull id<NOZDecoderContext>)context;

@end
