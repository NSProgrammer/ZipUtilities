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

NS_ASSUME_NONNULL_BEGIN

@class NOZCompressEntry;
@class NOZCompressOperation;
@class NOZCompressRequest;
@class NOZCompressResult;
@protocol NOZCompressDelegate;

/**
 The compression level to use.
 Lower levels execute faster, while higher levels will achieve a higher compression ratio.
 */
typedef NS_ENUM(NSInteger, NOZCompressionLevel)
{
    NOZCompressionLevelNone = 0,
    NOZCompressionLevelMin = 1,
    NOZCompressionLevelVeryLow = 2,
    NOZCompressionLevelLow = 3,
    NOZCompressionLevelMediumLow = 4,
    NOZCompressionLevelMedium = 5,
    NOZCompressionLevelMediumHigh = 6,
    NOZCompressionLevelHigh = 7,
    NOZCompressionLevelVeryHigh = 8,
    NOZCompressionLevelMax = 9,

    NOZCompressionLevelDefault = -1,
};

typedef void(^NOZCompressCompletionBlock)(NOZCompressOperation * op, NOZCompressResult * result);

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
/** The array of `NOZCompressEntry` objects to compress.  Read and write of perform a deep copy. */
@property (nonatomic, copy) NSArray *entries;
/** The `NOZCompressionLevel` to compress at.  Default is `NOZCompressionLevelDefault`. */
@property (nonatomic) NOZCompressionLevel compressionLevel;

/** Add a `NOZCompressEntry` */
- (void)addEntry:(NOZCompressEntry *)entry;
/** Add an entry via a _filePath_.  _name will be `filePath.lastPathComponent`. */
- (void)addFileEntry:(NSString *)filePath;
/** Add an entry via a _filePath_ with a _name_ for the entry (used as the file name when decompressed) */
- (void)addFileEntry:(NSString *)filePath name:(NSString *)name;
/** Add an entry via `NSData` with a _name_ for the entry (used as the file name when decompressed) */
- (void)addDataEntry:(NSData *)data name:(NSString *)name;
/** Recursively add a directory of files as entries */
- (void)addEntriesInDirectory:(NSString *)directoryPath;

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
 `NOZCompressEntry` encapsulates the information needed for an entry of a zip archive
 */
@interface NOZCompressEntry : NSObject <NSCopying>

/** The name of the entry.  Cannot be `nil`. */
@property (nonatomic, copy) NSString *name;
/** The path to a file for the entry.  Must provide either `path` or `data`. */
@property (nonatomic, copy, nullable) NSString *path;
/** The data for the entry.  Must provide either `path` or `data`. */
@property (nonatomic, copy, nullable) NSData *data;

/** Timestamp for the entry.  `nil` for `data`, read from the modification date of the file at `path`. */
- (NSDate *)fileDate;
/** The size in bytes of the entry */
- (int64_t)sizeInBytes;
/** Method to validate the entry has either `data` or `path` with `path` being a valid file on disk. */
- (BOOL)hasDataOrFile;

/** Convenience initializer.  `name` will be set to `path.lastPathComponent` */
- (instancetype)initWithFilePath:(NSString *)path;
/** Convenience initializer */
- (instancetype)initWithFilePath:(NSString *)path name:(NSString *)name;
/** Convenience initializer */
- (instancetype)initWithData:(NSData *)data name:(NSString *)name;

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
@property (nonatomic, readonly) int64_t uncompressedSize;
/** The size of the archive compressed */
@property (nonatomic, readonly) int64_t compressedSize;
/** Computed from the uncompressed and compressed sizes.  `_uncompressedSize_ / _compressedSize_`. */
- (float)compressionRatio;

@end

NS_ASSUME_NONNULL_END
