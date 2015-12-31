//
//  NOZCompress.h
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
#import "NOZZipEntry.h"

NS_ASSUME_NONNULL_BEGIN

@class NOZCompressOperation;
@class NOZCompressRequest;
@class NOZCompressResult;
@protocol NOZCompressDelegate;

//! Block for when `NOZCompressOperation` completes
typedef void(^NOZCompressCompletionBlock)(NOZCompressOperation* op, NOZCompressResult* result);
//! Block for dynamically selecting an `NOZCompressionMethod` and `NOZCompressionLevel` for a `NOZCompressOperation` when using `[NOZCompressionRequest addEntriesInDirectory:filterBlock:compressionSelectionBlock:]`
typedef void(^NOZCompressionSelectionBlock)(NSString* filePath, NOZCompressionMethod* compressionMethodOut, NOZCompressionLevel* compressionLevelOut);
//! Block for dynamically filtering out files when using `[NOZCompressionRequest addEntriesInDirectory:filterBlock:compressionSelectionBlock:]`.
typedef BOOL(^NOZCompressionShouldExcludeFileBlock)(NSString* filePath);

/**
 `NOZCompressOperation` is an `NSOperation` for compressing one or more sources (`NSData` objects
 and/or files) into a zip archive on disk.
 
 Supports cancelling, dependencies and prioritization/QoS
 */
@interface NOZCompressOperation : NOZSyncStepOperation

/** The `NOZCompressRequest` of the operation */
@property (nonatomic, readonly) NOZCompressRequest *request;
/** The `NOZCompressDelegate` of the operation */
@property (nonatomic, readonly, weak, nullable) id<NOZCompressDelegate> delegate;
/** The `NOZCompressResult` of the operation.  Populated upon completion. */
@property (nonatomic, readonly) NOZCompressResult *result;

/**
 Designated initializer
 
 @param request The `NOZCompressRequest` of the what and how for compressing.
 @param delegate The `NOZCompressDelegate` for callbacks.
 */
- (instancetype)initWithRequest:(NOZCompressRequest *)request delegate:(nullable id<NOZCompressDelegate>)delegate NS_DESIGNATED_INITIALIZER;

/**
 Convenience initializer

 @param request The `NOZCompressRequest` of the what and how for compressing.
 @param delegate The `NOZCompressCompletionBlock` to call once operation is finished.
 */
- (instancetype)initWithRequest:(NOZCompressRequest *)request completion:(nullable NOZCompressCompletionBlock)completion;

/** Unavailable */
- (instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (instancetype)new NS_UNAVAILABLE;

@end

/**
 `NOZCompressDelegate` is the delegate to the `NOZCompressOperation` for callbacks.
 */
@protocol NOZCompressDelegate <NSObject>
@optional

/** To force a strong reference by the `NOZCompressOperation`, return `YES`.  Default == `NO`. */
- (BOOL)requiresStrongReference;
/** Override to provide a different GCD queue for the completion callback (default is the main queue) */
- (dispatch_queue_t)completionQueue;

/**
 Called when the operation is finished.

 @param op The `NOZCompressOperation` that finished.
 @param result The `NOZCompressResult` for the operation.
 */
- (void)compressOperation:(NOZCompressOperation *)op didCompleteWithResult:(NOZCompressResult *)result;

/**
 Called when the operation updates it's overall progress.

 _progress_ will be between `0.0f` and `1.0f`.  A negative value indicates progress is indeterminant.
 */
- (void)compressOperation:(NOZCompressOperation *)op didUpdateProgress:(float)progress;

@end

/**
 `NOZCompressRequest` encapusulates the what and how for the compression operation.
 */
@interface NOZCompressRequest : NSObject <NSCopying>

/** The on disk file to archive to */
@property (nonatomic, copy) NSString *destinationPath;
/** The array of objects conforming to `NOZZippableEntry` to compress.  Read and write of perform a deep copy. */
@property (nonatomic, copy) NSArray<id<NOZZippableEntry>> *entries;
/** A comment embedded in the resulting zip file */
@property (nonatomic, copy, nullable) NSString *comment;

/** Add an object conforming to `NOZZippableEntry` */
- (void)addEntry:(id<NOZZippableEntry>)entry;
/** Add an entry via a _filePath_.  _name will be `filePath.lastPathComponent`. */
- (void)addFileEntry:(NSString *)filePath;
/** Add an entry via a _filePath_ with a _name_ for the entry (used as the file name when decompressed) */
- (void)addFileEntry:(NSString *)filePath name:(NSString *)name;
/** Add an entry via `NSData` with a _name_ for the entry (used as the file name when decompressed) */
- (void)addDataEntry:(NSData *)data name:(NSString *)name;
/** Recursively add a directory of files as entries */
- (void)addEntriesInDirectory:(NSString *)directoryPath filterBlock:(nullable NOZCompressionShouldExcludeFileBlock)filterBlock compressionSelectionBlock:(nullable NOZCompressionSelectionBlock)selectionBlock;
/** See `addEntriesInDirectory:filterBlock:compressionSelectionBlock:` */
- (void)addEntriesInDirectory:(NSString *)directoryPath compressionSelectionBlock:(nullable NOZCompressionSelectionBlock)block;

/**
 Designated initializer
 @param path The on disk file to archive to 
 */
- (instancetype)initWithDestinationPath:(NSString *)path NS_DESIGNATED_INITIALIZER;

/** Unavailable */
- (instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (instancetype)new NS_UNAVAILABLE;

@end

/**
 `NOZCompressResult` encapsulates the results of a compression operation
 */
@interface NOZCompressResult : NSObject

/** The destination archive file */
@property (nonatomic, readonly, copy) NSString *destinationPath;
/** Any error that occurred for the operation */
@property (nonatomic, readonly, nullable) NSError *operationError;
/** Whether the operation succeeded or not */
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
