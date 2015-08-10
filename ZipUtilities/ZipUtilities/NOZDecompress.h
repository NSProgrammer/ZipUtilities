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

typedef void(^NOZDecompressCompletionBlock)(NOZDecompressOperation * op, NOZDecompressResult * result);

@interface NOZDecompressOperation : NOZSyncStepOperation

@property (nonatomic, readonly) NOZDecompressRequest *request;
@property (nonatomic, readonly, weak, nullable) id<NOZDecompressDelegate> delegate;
@property (nonatomic, readonly) NOZDecompressResult *result;

- (instancetype)initWithRequest:(NOZDecompressRequest *)request delegate:(nullable id<NOZDecompressDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithRequest:(NOZDecompressRequest *)request completion:(NOZDecompressCompletionBlock)completion;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

@end

@protocol NOZDecompressDelegate <NSObject>
@optional
- (BOOL)requiresStrongReference;
- (dispatch_queue_t)completionQueue; // default or NULL == main queue
- (void)decompressOperation:(NOZDecompressOperation *)op didCompleteWithResult:(NOZDecompressResult *)result;
- (void)decompressOperation:(NOZDecompressOperation *)op didUpdateProgress:(float)progress;
- (BOOL)shouldDecompressOperation:(NOZDecompressOperation *)op overwriteFileAtPath:(NSString *)path;
@end

@interface NOZDecompressRequest : NSObject <NSCopying>

@property (nonatomic, copy, readonly, nullable) NSString *destinationDirectoryPath;
@property (nonatomic, copy, readonly) NSString *sourceFilePath;

- (instancetype)initWithSourceFilePath:(NSString *)path NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSourceFilePath:(NSString *)path destinationDirectoryPath:(NSString *)destinationDirectoryPath;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

@end

@interface NOZDecompressResult : NSObject

@property (nonatomic, readonly, copy) NSString *destinationDirectoryPath;
@property (nonatomic, readonly, copy, nullable) NSArray *destinationFiles; // paths relative to destinationDirectoryPath
@property (nonatomic, readonly, nullable) NSError *operationError;
@property (nonatomic, readonly) BOOL didSucceed;

@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) int64_t uncompressedSize;
@property (nonatomic, readonly) int64_t compressedSize;
- (float)compressionRatio;

@end

NS_ASSUME_NONNULL_END
