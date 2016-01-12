//
//  NOZDecompress.m
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

#import "NOZ_Project.h"
#import "NOZDecompress.h"
#import "NOZUnzipper.h"

#define kWEIGHT (1000ll)

typedef NS_ENUM(NSUInteger, NOZDecompressStep)
{
    NOZDecompressStepOpen = 0,
    NOZDecompressStepReadEntrySizes,
    NOZDecompressStepUnzip,
    NOZDecompressStepClose,
};

#define kCancelledError NOZError(NOZErrorCodeDecompressCancelled, nil)

@interface NOZDecompressResult ()
@property (nonatomic, copy) NSString *destinationDirectoryPath;
@property (nonatomic, copy, nullable) NSArray<NSString *> *destinationFiles;
@property (nonatomic, nullable) NSError *operationError;
@property (nonatomic) BOOL didSucceed;

@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) SInt64 uncompressedSize;
@property (nonatomic) SInt64 compressedSize;
@end

@interface NOZDecompressDelegateInternal : NSObject <NOZDecompressDelegate>
@property (nonatomic, readonly, nonnull) NOZDecompressCompletionBlock completionBlock;
- (nonnull instancetype)initWithCompletion:(nonnull NOZDecompressCompletionBlock)completion;
- (nonnull instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)new NS_UNAVAILABLE;
@end

@interface NOZDecompressOperation ()
@property (nonatomic) NOZDecompressResult *result;
@end

@interface NOZDecompressOperation (Private);

#pragma mark Steps
- (nullable NSError *)private_openFile;
- (nullable NSError *)private_readExpectedSizes;
- (nullable NSError *)private_unzipAllEntries;
- (nullable NSError *)private_closeFile;

#pragma mark Helpers
- (void)private_didDecompressBytes:(SInt64)bytes;

@end

@implementation NOZDecompressOperation
{
    NOZUnzipper *_unzipper;
    __weak id<NOZDecompressDelegate> _weakDelegate;
    __strong id<NOZDecompressDelegate> _strongDelegate;
    NOZDecompressRequest *_request;
    NSString *_sanitizedDestinationDirectoryPath;
    CFAbsoluteTime _startTime;
    NSUInteger _expectedEntryCount;
    SInt64 _expectedUncompressedSize;
    SInt64 _bytesUncompressed;
    NSMutableArray<NSString *> *_entryPaths;

    struct {
        BOOL delegateUpdatesProgress:1;
        BOOL delegateHasOverwriteCheck:1;
    } _flags;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (id<NOZDecompressDelegate>)delegate
{
    return _weakDelegate;
}

- (NOZDecompressRequest *)request
{
    return [_request copy];
}

- (instancetype)initWithRequest:(NOZDecompressRequest *)request delegate:(id<NOZDecompressDelegate>)delegate
{
    if (self = [super init]) {
        if ([delegate respondsToSelector:@selector(requiresStrongReference)]) {
            _strongDelegate = delegate;
        }
        _weakDelegate = delegate;
        _request = [request copy];
        _flags.delegateUpdatesProgress = !![delegate respondsToSelector:@selector(decompressOperation:didUpdateProgress:)];
        _flags.delegateHasOverwriteCheck = !![delegate respondsToSelector:@selector(shouldDecompressOperation:overwriteFileAtPath:)];
    }
    return self;
}

- (instancetype)initWithRequest:(NOZDecompressRequest *)request completion:(NOZDecompressCompletionBlock)completion
{
    NOZDecompressDelegateInternal *delegate = (completion) ? [[NOZDecompressDelegateInternal alloc] initWithCompletion:completion] : nil;
    return [self initWithRequest:request delegate:delegate];
}

- (void)main
{
    _startTime = CFAbsoluteTimeGetCurrent();
    [super main];
}

+ (NSError *)operationCancelledError
{
    return kCancelledError;
}

- (NSUInteger)numberOfSteps
{
    return 4;
}

- (SInt64)weightForStep:(NSUInteger)stepIndex
{
    NOZDecompressStep step = stepIndex;
    switch (step) {
        case NOZDecompressStepOpen:
            return (kWEIGHT * 3) / 2;
        case NOZDecompressStepReadEntrySizes:
            return kWEIGHT / 2;
        case NOZDecompressStepUnzip:
            return kWEIGHT * 95;
        case NOZDecompressStepClose:
            return kWEIGHT * 3;
    }
    return 0;
}

- (BOOL)runStep:(NSUInteger)stepIndex error:(out NSError **)error
{
    NSError *stepError = nil;
    NOZDecompressStep step = stepIndex;
    switch (step) {
        case NOZDecompressStepOpen:
            stepError = [self private_openFile];
            break;
        case NOZDecompressStepReadEntrySizes:
            stepError = [self private_readExpectedSizes];
            break;
        case NOZDecompressStepUnzip:
            stepError = [self private_unzipAllEntries];
            break;
        case NOZDecompressStepClose:
            stepError = [self private_closeFile];
            break;
    }

    if (stepError && error) {
        *error = stepError;
    }

    return !stepError;
}

- (void)handleProgressUpdated:(float)progress
{
    if (_flags.delegateUpdatesProgress) {
        [self.delegate decompressOperation:self didUpdateProgress:progress];
    }
}

- (void)handleFinishing
{
    id<NOZDecompressDelegate> delegate = self.delegate;
    dispatch_queue_t completionQueue = [delegate respondsToSelector:@selector(completionQueue)] ? [delegate completionQueue] : NULL;
    if (!completionQueue) {
        completionQueue = dispatch_get_main_queue();
    }

    NSError *error = self.operationError;
    NSFileManager *fm = [NSFileManager defaultManager];
    NOZDecompressResult *result = [[NOZDecompressResult alloc] init];
    result.destinationDirectoryPath = _sanitizedDestinationDirectoryPath;
    result.duration = CFAbsoluteTimeGetCurrent() - _startTime;
    if (error) {
        result.operationError = error;

        // cleanup anything necessary
        [self private_closeFile];
        for (NSString *filePath in _entryPaths) {
            [fm removeItemAtPath:filePath error:NULL];
        }
    } else {
        result.didSucceed = YES;
        result.destinationFiles = _entryPaths;

        result.uncompressedSize = _expectedUncompressedSize;
        result.compressedSize = (SInt64)[[fm attributesOfItemAtPath:_request.sourceFilePath error:NULL] fileSize];
    }
    _result = result;

    if ([delegate respondsToSelector:@selector(decompressOperation:didCompleteWithResult:)]) {
        dispatch_async(completionQueue, ^{
            [delegate decompressOperation:self didCompleteWithResult:result];
        });
    }
}

@end

@implementation NOZDecompressOperation (Private)

#pragma mark Steps

- (NSError *)private_openFile
{
    noz_defer(^{ [self updateProgress:1.f forStep:NOZDecompressStepOpen]; });

    NSError *error = nil;
    _unzipper = [[NOZUnzipper alloc] initWithZipFile:_request.sourceFilePath];
    if (![_unzipper openAndReturnError:&error]) {
        return NOZError(NOZErrorCodeDecompressFailedToOpenZipArchive, @{ NSUnderlyingErrorKey : error });
    }

    _sanitizedDestinationDirectoryPath = _request.destinationDirectoryPath;
    if (!_sanitizedDestinationDirectoryPath) {
        _sanitizedDestinationDirectoryPath = [_request.sourceFilePath stringByDeletingPathExtension];
    }
    _sanitizedDestinationDirectoryPath = [_sanitizedDestinationDirectoryPath stringByStandardizingPath];

    if (![[NSFileManager defaultManager] createDirectoryAtPath:_sanitizedDestinationDirectoryPath withIntermediateDirectories:YES attributes:nil error:NULL]) {
        return NOZError(NOZErrorCodeDecompressFailedToCreateDestinationDirectory, @{ @"destinationDirectoryPath" : (_request.destinationDirectoryPath ?: [NSNull null]) });
    }

    return nil;
}

- (NSError *)private_readExpectedSizes
{
    noz_defer(^{ [self updateProgress:1.f forStep:NOZDecompressStepReadEntrySizes]; });

    NSError *error;
    if (![_unzipper readCentralDirectoryAndReturnError:&error]) {
        return NOZError(NOZErrorCodeDecompressFailedToReadArchiveEntry, @{ NSUnderlyingErrorKey : error });
    }

    _expectedEntryCount = _unzipper.centralDirectory.recordCount;
    _expectedUncompressedSize = _unzipper.centralDirectory.totalUncompressedSize;

    _entryPaths = [[NSMutableArray alloc] initWithCapacity:_expectedEntryCount];

    return nil;
}

- (NSError *)private_unzipAllEntries
{
    __block NSError *stackError = nil;
    [_unzipper enumerateManifestEntriesUsingBlock:^(NOZCentralDirectoryRecord * __nonnull record, NSUInteger index, BOOL * __nonnull stop) {

        // Skip these entries
        if (record.isZeroLength || record.isMacOSXDSStore || record.isMacOSXAttribute) {
            return;
        }

        BOOL overwrite = NO;
        if (_flags.delegateHasOverwriteCheck) {
            overwrite = [self.delegate shouldDecompressOperation:self overwriteFileAtPath:[_sanitizedDestinationDirectoryPath stringByAppendingPathComponent:record.name]];
        }

        NSError *innerError = nil;
        [_unzipper saveRecord:record
                  toDirectory:_sanitizedDestinationDirectoryPath
                      options:(overwrite) ? NOZUnzipperSaveRecordOptionOverwriteExisting : NOZUnzipperSaveRecordOptionsNone
                progressBlock:^(int64_t totalBytes, int64_t bytesComplete, int64_t byteWrittenThisPass, BOOL *abort) {
                    if (self.isCancelled) {
                        stackError = kCancelledError;
                        *abort = YES;
                    } else {
                        [self private_didDecompressBytes:byteWrittenThisPass];
                    }
                }
                        error:&innerError];

        if (!stackError) {
            if (innerError) {
                stackError = innerError;
            } else if (self.isCancelled) {
                stackError = kCancelledError;
            }
        }

        if (stackError) {
            *stop = YES;
        } else {
            [_entryPaths addObject:record.name];
        }

    }];

    if (!stackError) {
        // There can be ignored bytes
        [self updateProgress:1.f forStep:NOZDecompressStepUnzip];
    }

    return stackError;
}

- (NSError *)private_closeFile
{
    if (_unzipper) {
        noz_defer(^{ [self updateProgress:1.f forStep:NOZDecompressStepClose]; });
        [_unzipper closeAndReturnError:NULL];
        _unzipper = nil;
    }
    return nil;
}

#pragma mark Helpers

- (void)private_didDecompressBytes:(SInt64)bytes
{
    _bytesUncompressed += bytes;
    float progress = 1.f;
    if (_bytesUncompressed < 0.f) {
        progress = -1.f;
    } else if (_bytesUncompressed < _expectedUncompressedSize) {
        progress = (float)((double)_bytesUncompressed / (double)_expectedUncompressedSize);
    }
    [self updateProgress:progress forStep:NOZDecompressStepUnzip];
}

@end

@implementation NOZDecompressRequest

- (instancetype)initWithSourceFilePath:(NSString *)path
{
    if (self = [super init]) {
        _sourceFilePath = [path copy];
    }
    return self;
}

- (instancetype)initWithSourceFilePath:(NSString *)path destinationDirectoryPath:(NSString *)destinationDirectoryPath
{
    if (self = [self initWithSourceFilePath:path]) {
        _destinationDirectoryPath = [destinationDirectoryPath copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NOZDecompressRequest *request = [[NOZDecompressRequest alloc] initWithSourceFilePath:_sourceFilePath];
    request->_destinationDirectoryPath = _destinationDirectoryPath;
    return request;
}

@end

@implementation NOZDecompressDelegateInternal

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithCompletion:(NOZDecompressCompletionBlock)completion
{
    if (self = [super init]) {
        _completionBlock = [completion copy];
    }
    return self;
}

- (BOOL)requiresStrongReference
{
    return YES;
}

- (void)decompressOperation:(NOZDecompressOperation *)op didCompleteWithResult:(NOZDecompressResult *)result
{
    if (_completionBlock) {
        _completionBlock(op, result);
    }
}

@end

@implementation NOZDecompressResult

- (float)compressionRatio
{
    if (!_uncompressedSize || !_compressedSize) {
        return 0.0f;
    }

    return (float)((double)_uncompressedSize / (double)_compressedSize);
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@ %p", NSStringFromClass([self class]), self];
    NSMutableDictionary *values = [[NSMutableDictionary alloc] init];
    if (self.destinationDirectoryPath) {
        values[@"destinationPath"] = self.destinationDirectoryPath;
    }
    if (self.destinationFiles.count > 0) {
        values[@"destinationFiles"] = self.destinationFiles;
    }
    if (self.operationError) {
        values[@"operationError"] = self.operationError;
    }
    values[@"duration"] = @(self.duration);
    if (self.compressionRatio > 0.0f) {
        values[@"compressionRatio"] = @(self.compressionRatio);
    }
    values[@"didSucceed"] = @(self.didSucceed);
    if (values.count) {
        [string appendFormat:@" : %@", values];
    }
    [string appendString:@">"];
    return string;
}

@end
