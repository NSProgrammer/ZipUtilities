//
//  NOZDecompress.h
//  ZipUtilities
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Nolan O'Brien
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

@import Foundation;

#import "NOZError.h"
#import "NOZSyncStepOperation.h"

@class NOZDecompressOperation;
@class NOZDecompressRequest;
@class NOZDecompressResult;
@protocol NOZDecompressDelegate;

NS_ASSUME_NONNULL_BEGIN

//! Callback block when the `NOZDecompressOperation` completes
typedef void(^NOZDecompressCompletionBlock)(NOZDecompressOperation * op, NOZDecompressResult * result);

/**
 `NOZDecompressOperation` is an `NSOperation` for decompressing a zip archive on disk into unarchived files on disk.

 Supports cancelling, dependencies and prioritization/QoS
 */
@interface NOZDecompressOperation : NOZSyncStepOperation

/** The `NOZDecompressRequest` of the operation */
@property (nonatomic, readonly) NOZDecompressRequest *request;
/** The `NOZDecompressDelegate` of the operation */
@property (nonatomic, readonly, weak, nullable) id<NOZDecompressDelegate> delegate;
/** The `NOZDecompressResult` of the operation.  Populated once operation finishes. */
@property (nonatomic, readonly) NOZDecompressResult *result;

/**
 Designated initializer
 
 @param request The `NOZDecompressRequest` to operate on
 @param delegate The `NOZDecompressDelegate` for callbacks
 */
- (instancetype)initWithRequest:(NOZDecompressRequest *)request delegate:(nullable id<NOZDecompressDelegate>)delegate NS_DESIGNATED_INITIALIZER;

/**
 Convenience initializer
 
 @param request The `NOZDecompressRequest` to operate on
 @param completion The `NOZDecompressCompletionBlock` block that will be called when the operation finishes
 */
- (instancetype)initWithRequest:(NOZDecompressRequest *)request completion:(NOZDecompressCompletionBlock)completion;

/** Unavailable */
- (instancetype)init NS_UNAVAILABLE;
/** Unavailable */
- (instancetype)new NS_UNAVAILABLE;

@end

/**
 `NOZDecompressDelegate` is the delegate to the `NOZDecompressOperation` for callbacks.
 */
@protocol NOZDecompressDelegate <NSObject>
@optional

/** To force a strong reference by the `NOZCompressOperation`, return `YES`.  Default == `NO`. */
- (BOOL)requiresStrongReference;
/** Override to provide a different GCD queue for the completion callback (default is the main queue) */
- (dispatch_queue_t)completionQueue;

/**
 Called when the operation is finished.

 @param op The `NOZDecompressOperation` that finished.
 @param result The `NOZDecompressResult` for the operation.
 */
- (void)decompressOperation:(NOZDecompressOperation *)op didCompleteWithResult:(NOZDecompressResult *)result;

/**
 Called when the operation updates it's overall progress.

 _progress_ will be between `0.0f` and `1.0f`.  A negative value indicates progress is indeterminant.
 */
- (void)decompressOperation:(NOZDecompressOperation *)op didUpdateProgress:(float)progress;

/**
 Called when unarchive a file would overwrite an existing file on disk.
 By default, returns `NO` and the operation fails with an error.
 
 @param op The `NOZDecompressOperation` that is running.
 @param path The path to the file on disk that would be overwritten.
 
 @return `YES` to overwrite.
 */
- (BOOL)shouldDecompressOperation:(NOZDecompressOperation *)op overwriteFileAtPath:(NSString *)path;

@end

/**
 `NOZDecompressRequest` encapusulates the what and how for the decompression operation.
 */
@interface NOZDecompressRequest : NSObject <NSCopying>

/** The directory for all files to be unarchived to.  If `nil`, `sourceFilePath` will be used for the directory (sans extension). */
@property (nonatomic, copy, readonly, nullable) NSString *destinationDirectoryPath;
/** The source zip archive to decompress */
@property (nonatomic, copy, readonly) NSString *sourceFilePath;

/**
 Designated initializer
 
 @param path The `sourceFilePath`
 */
- (instancetype)initWithSourceFilePath:(NSString *)path NS_DESIGNATED_INITIALIZER;

/**
 Designated initializer
 
 @param path The `sourceFilePath`
 @param destinationDirectoryPath The `destinationDirectoryPath`
 */
- (instancetype)initWithSourceFilePath:(NSString *)path destinationDirectoryPath:(NSString *)destinationDirectoryPath;

/** Unavailable */
- (instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (instancetype)new NS_UNAVAILABLE;

@end

/**
 `NOZDecompressResult` encapsulates the result of a decompression operation
 */
@interface NOZDecompressResult : NSObject

/** The path that acts as the root for all files to be unarchived to */
@property (nonatomic, readonly, copy) NSString *destinationDirectoryPath;
/** The files that were unarchived.  Items are relative paths to the `destinationDirectoryPath`. */
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *destinationFiles;
/** Any error that was encountered during the operation */
@property (nonatomic, readonly, nullable) NSError *operationError;
/** Whether or not the operation did succeed */
@property (nonatomic, readonly) BOOL didSucceed;

/** The duration that the operation took from start to finish.  Does not included wait time in a queue. */
@property (nonatomic, readonly) NSTimeInterval duration;
/** The size of the archive uncompressed */
@property (nonatomic, readonly) SInt64 uncompressedSize;
/** The size of the archive compressed */
@property (nonatomic, readonly) SInt64 compressedSize;
/** Computed from the uncompressed and compressed sizes.  `_uncompressedSize_ / _compressedSize_`. */
- (float)compressionRatio;

@end

NS_ASSUME_NONNULL_END
