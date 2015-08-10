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

@interface NOZCompressOperation : NOZSyncStepOperation

@property (nonatomic, readonly) NOZCompressRequest *request;
@property (nonatomic, readonly, weak, nullable) id<NOZCompressDelegate> delegate;
@property (nonatomic, readonly) NOZCompressResult *result;

- (instancetype)initWithRequest:(NOZCompressRequest *)request delegate:(nullable id<NOZCompressDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithRequest:(NOZCompressRequest *)request completion:(nullable NOZCompressCompletionBlock)completion;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

@end

@protocol NOZCompressDelegate <NSObject>
@optional
- (BOOL)requiresStrongReference;
- (dispatch_queue_t)completionQueue; // default or NULL == main queue
- (void)compressOperation:(NOZCompressOperation *)op didCompleteWithResult:(NOZCompressResult *)result;
- (void)compressOperation:(NOZCompressOperation *)op didUpdateProgress:(float)progress;
@end

@interface NOZCompressRequest : NSObject <NSCopying>

@property (nonatomic, copy) NSString *destinationPath;
@property (nonatomic, copy) NSArray *entries; // read/write perform deep copy
@property (nonatomic) NOZCompressionLevel compressionLevel;

- (void)addEntry:(NOZCompressEntry *)entry;
- (void)addFileEntry:(NSString *)filePath;
- (void)addFileEntry:(NSString *)filePath name:(NSString *)name;
- (void)addDataEntry:(NSData *)data name:(NSString *)name;
- (void)addEntriesInDirectory:(NSString *)directoryPath;

- (instancetype)initWithDestinationPath:(NSString *)path NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface NOZCompressEntry : NSObject <NSCopying>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *path;
@property (nonatomic, copy, nullable) NSData *data;

- (NSDate *)fileDate;
- (int64_t)sizeInBytes;
- (BOOL)hasDataOrFile;

- (instancetype)initWithFilePath:(NSString *)path;
- (instancetype)initWithFilePath:(NSString *)path name:(NSString *)name;
- (instancetype)initWithData:(NSData *)data name:(NSString *)name;

@end

@interface NOZCompressResult : NSObject

@property (nonatomic, readonly, copy) NSString *destinationPath;
@property (nonatomic, readonly, nullable) NSError *operationError;
@property (nonatomic, readonly) BOOL didSucceed;

@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) int64_t uncompressedSize;
@property (nonatomic, readonly) int64_t compressedSize;
- (float)compressionRatio;

@end

NS_ASSUME_NONNULL_END
