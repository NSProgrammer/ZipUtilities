//
//  NOZEncoder.h
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
 @param bitFlags The bit flags that were specified for this encoder.
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
