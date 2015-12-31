//
//  NOZCompress.m
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
#import "NOZCompress.h"
#import "NOZZipper.h"

#define kWEIGHT (1000ll)

typedef NS_ENUM(NSUInteger, NOZCompressStep)
{
    NOZCompressStepPrep = 0,
    NOZCompressStepOpen,
    NOZCompressStepZip,
    NOZCompressStepClose
};

static NSArray<NOZFileZipEntry *> * __nonnull NOZEntriesFromDirectory(NSString * __nonnull directoryPath);

#define kCancelledError NOZError(NOZErrorCodeCompressCancelled, nil)

@interface NOZCompressDelegateInternal : NSObject <NOZCompressDelegate>
@property (nonatomic, readonly, nonnull) NOZCompressCompletionBlock completionBlock;
- (nonnull instancetype)initWithCompletion:(nonnull NOZCompressCompletionBlock)completion;
- (nonnull instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)new NS_UNAVAILABLE;
@end

@interface NOZCompressRequest ()
@property (nonatomic, nonnull) NSMutableArray<id<NOZZippableEntry>> *mutableEntries;
@end

@interface NOZCompressResult ()
@property (nonatomic, copy) NSString *destinationPath;
@property (nonatomic, nullable) NSError *operationError;
@property (nonatomic) BOOL didSucceed;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) SInt64 uncompressedSize;
@property (nonatomic) SInt64 compressedSize;
@end

@interface NOZCompressOperation (Private)

#pragma mark Steps
- (nullable NSError *)private_prepareProgress;
- (nullable NSError *)private_openFile;
- (nullable NSError *)private_addEntries;
- (nullable NSError *)private_closeFile;

#pragma mark Helpers
- (nullable NSError *)private_addEntry:(nonnull id<NOZZippableEntry>)entry;
- (void)private_didCompressBytes:(SInt64)byteCount;

@end

@implementation NOZCompressOperation
{
    NOZZipper *_zipper;
    __strong id<NOZCompressDelegate> _strongDelegate;
    __weak id<NOZCompressDelegate> _weakDelegate;
    NOZCompressRequest *_request;
    CFAbsoluteTime _startTime;
    SInt64 _totalUncompressedBytes;
    SInt64 _finishedUncompressedBytes;

    struct {
        BOOL delegateUpdatesProgress:1;
    } _flags;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (id<NOZCompressDelegate>)delegate
{
    return _weakDelegate;
}

- (NOZCompressRequest *)request
{
    return [_request copy];
}

- (instancetype)initWithRequest:(NOZCompressRequest *)request delegate:(id<NOZCompressDelegate>)delegate
{
    if (self = [super init]) {
        if ([delegate respondsToSelector:@selector(requiresStrongReference)]) {
            _strongDelegate = delegate;
        }
        _weakDelegate = delegate;
        _request = [request copy];
        _flags.delegateUpdatesProgress = !![delegate respondsToSelector:@selector(compressOperation:didUpdateProgress:)];
    }
    return self;
}

- (instancetype)initWithRequest:(NOZCompressRequest *)request completion:(NOZCompressCompletionBlock)completion
{
    NOZCompressDelegateInternal *delegate = (completion) ? [[NOZCompressDelegateInternal alloc] initWithCompletion:completion] : nil;
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
    NOZCompressStep step = stepIndex;
    switch (step) {
        case NOZCompressStepPrep:
            return 0;
        case NOZCompressStepOpen:
            return 1 * kWEIGHT;
        case NOZCompressStepZip:
            return 95 * kWEIGHT;
        case NOZCompressStepClose:
            return 4 * kWEIGHT;
    }

    return 0;
}

- (BOOL)runStep:(NSUInteger)stepIndex error:(out NSError **)error
{
    NSError *stepError = nil;
    NOZCompressStep step = stepIndex;
    switch (step) {
        case NOZCompressStepPrep:
            stepError = [self private_prepareProgress];
            break;
        case NOZCompressStepOpen:
            stepError = [self private_openFile];
            break;
        case NOZCompressStepZip:
            stepError = [self private_addEntries];
            break;
        case NOZCompressStepClose:
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
        [self.delegate compressOperation:self didUpdateProgress:progress];
    }
}

- (void)handleFinishing
{
    id<NOZCompressDelegate> delegate = self.delegate;
    dispatch_queue_t completionQueue = [delegate respondsToSelector:@selector(completionQueue)] ? [delegate completionQueue] : NULL;
    if (!completionQueue) {
        completionQueue = dispatch_get_main_queue();
    }

    NSError *error = self.operationError;
    NOZCompressResult *result = [[NOZCompressResult alloc] init];
    result.destinationPath = _request.destinationPath;
    result.duration = CFAbsoluteTimeGetCurrent() - _startTime;
    if (error) {
        result.operationError = error;

        // Clean up
        if (_zipper) {
            [self private_closeFile];
            [[NSFileManager defaultManager] removeItemAtPath:result.destinationPath error:NULL];
        }
    } else {
        result.didSucceed = YES;
        result.uncompressedSize = _totalUncompressedBytes;
        result.compressedSize = (SInt64)[[[NSFileManager defaultManager] attributesOfItemAtPath:result.destinationPath error:NULL] fileSize];
    }
    _result = result;

    if ([delegate respondsToSelector:@selector(compressOperation:didCompleteWithResult:)]) {
        dispatch_async(completionQueue, ^{
            [delegate compressOperation:self didCompleteWithResult:result];
        });
    }
}

@end

@implementation NOZCompressOperation (Private)

#pragma mark Steps

- (NSError *)private_prepareProgress
{
    for (id<NOZZippableEntry> entry in _request.entries) {
        _totalUncompressedBytes += entry.sizeInBytes;
    }
    if (!_totalUncompressedBytes) {
        return NOZError(NOZErrorCodeCompressNoEntriesToCompress, nil);
    }

    return nil;
}

- (NSError *)private_openFile
{
    noz_defer(^{ [self updateProgress:1.f forStep:NOZCompressStepOpen]; });

    NSError *error = nil;
    NSString *path = [_request.destinationPath stringByStandardizingPath];
    if ([[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error]) {
        _zipper = [[NOZZipper alloc] initWithZipFile:path];
        _zipper.globalComment = _request.comment;
        [_zipper openWithMode:NOZZipperModeCreate error:&error];
    }

    if (error) {
        _zipper = nil;
        return NOZError(NOZErrorCodeCompressFailedToOpenNewZipFile, @{ @"path" : _request.destinationPath ?: @"<null>", NSUnderlyingErrorKey : error });
    }
    return nil;
}

- (NSError *)private_addEntries
{
    NSError *error = NOZError(NOZErrorCodeCompressNoEntriesToCompress, nil);
    for (id<NOZZippableEntry> entry in _request.entries) {
        @autoreleasepool {
            if (self.isCancelled) {
                return kCancelledError;
            }
            error = [self private_addEntry:entry];
            if (error) {
                break;
            }
        }
    }

    return error;
}

- (NSError *)private_closeFile
{
    if (_zipper) {
        noz_defer(^{ [self updateProgress:1.f forStep:NOZCompressStepClose]; });
        NSError *error;
        if ([_zipper closeAndReturnError:&error]) {
            _zipper = nil;
        } else {
            return NOZError(NOZErrorCodeCompressFailedToFinalizeNewZipFile, @{ NSUnderlyingErrorKey : error });            return error;
        }
    }
    return nil;
}

#pragma mark Helpers

- (NSError *)private_addEntry:(id<NOZZippableEntry>)entry
{
    // Start
    if (!entry.name) {
        return NOZError(NOZErrorCodeCompressMissingEntryName, @{ @"entry" : entry });
    }
    if (!entry.canBeZipped) {
        return NOZError(NOZErrorCodeCompressEntryCannotBeZipped, @{ @"entry" : entry });
    }

    NSError *error = nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"

    [_zipper addEntry:entry
        progressBlock:^(SInt64 totalBytesToWrite, SInt64 bytesWritten, SInt64 bytesThisPass, BOOL *abort) {
            [self private_didCompressBytes:bytesThisPass];
            if (self.isCancelled) {
                *abort = YES;
            }
        }
                error:&error];

#pragma clang diagnostic pop

    if (error) {
        return NOZError(NOZErrorCodeCompressFailedToAppendEntryToZip, @{ @"entry" : entry, NSUnderlyingErrorKey : error });
    }

    return nil;
}

- (void)private_didCompressBytes:(SInt64)byteCount
{
    _finishedUncompressedBytes += byteCount;
    float progress = 1.f;
    if (_finishedUncompressedBytes < 0.f) {
        progress = -1.f;
    } else if (_finishedUncompressedBytes < _totalUncompressedBytes) {
        progress = (float)((double)_finishedUncompressedBytes / (double)_totalUncompressedBytes);
    }
    [self updateProgress:progress forStep:NOZCompressStepZip];
}

@end

@implementation NOZCompressDelegateInternal

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithCompletion:(NOZCompressCompletionBlock)completion
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

- (void)compressOperation:(NOZCompressOperation *)op didCompleteWithResult:(NOZCompressResult *)result
{
    if (_completionBlock) {
        _completionBlock(op, result);
    }
}

@end

@implementation NOZCompressResult

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
    if (self.destinationPath) {
        values[@"destinationPath"] = self.destinationPath;
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

@implementation NOZCompressRequest

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithDestinationPath:(NSString *)path
{
    if (self = [super init]) {
        _destinationPath = [path copy];
        _mutableEntries = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NOZCompressRequest *copy = [[[self class] allocWithZone:zone] initWithDestinationPath:self.destinationPath];
    copy.destinationPath = self.destinationPath;
    copy.comment = self.comment;
    copy->_mutableEntries = [self.entries mutableCopy];
    return copy;
}

- (NSArray<id<NOZZippableEntry>> *)entries
{
    NSMutableArray<id<NOZZippableEntry>> *entries = [[NSMutableArray alloc] initWithCapacity:_mutableEntries.count];
    for (id<NOZZippableEntry> entry in _mutableEntries) {
        [entries addObject:[entry copy]];
    }
    return [entries copy];
}

- (void)setEntries:(NSArray<id<NOZZippableEntry>> *)entries
{
    [_mutableEntries removeAllObjects];
    for (id<NOZZippableEntry> entry in entries) {
        [self addEntry:entry];
    }
}

- (void)addEntry:(id<NOZZippableEntry>)entry
{
    [_mutableEntries addObject:[entry copy]];
}

- (void)addEntriesInDirectory:(NSString *)directoryPath compressionSelectionBlock:(NOZCompressionSelectionBlock)block
{
    [self addEntriesInDirectory:directoryPath filterBlock:NULL compressionSelectionBlock:block];
}

- (void)addEntriesInDirectory:(NSString *)directoryPath filterBlock:(NOZCompressionShouldExcludeFileBlock)filterBlock compressionSelectionBlock:(NOZCompressionSelectionBlock)selectionBlock
{
    for (NOZFileZipEntry *entry in NOZEntriesFromDirectory(directoryPath)) {
        if (filterBlock) {
            if (filterBlock(entry.filePath)) {
                // skip this file
                continue;
            }
        }

        if (selectionBlock) {
            NOZCompressionMethod method = NOZCompressionMethodDeflate;
            NOZCompressionLevel level = NOZCompressionLevelDefault;
            selectionBlock(entry.filePath, &method, &level);
            entry.compressionLevel = level;
            entry.compressionMethod = method;
        }
        [self addEntry:entry];
    }
}

- (void)addFileEntry:(NSString *)filePath
{
    [self addFileEntry:filePath name:filePath.lastPathComponent];
}

- (void)addFileEntry:(NSString *)filePath name:(NSString *)name
{
    NOZFileZipEntry *entry = [[NOZFileZipEntry alloc] initWithFilePath:filePath name:name];
    [self addEntry:entry];
}

- (void)addDataEntry:(NSData *)data name:(NSString *)name
{
    NOZDataZipEntry *entry = [[NOZDataZipEntry alloc] initWithData:data name:name];
    [self addEntry:entry];
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@ %p :", NSStringFromClass([self class]), self];
    if (self.destinationPath) {
        [string appendFormat:@", dstPath='%@'", self.destinationPath];
    }
    [string appendFormat:@", entries=%@", self.entries];
    [string appendString:@">"];
    return string;
}

@end

static NSArray<NOZFileZipEntry *> * NOZEntriesFromDirectory(NSString * directoryPath)
{
    NSMutableArray<NOZFileZipEntry *> *entries = [[NSMutableArray alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:directoryPath];
    NSString *filePath = nil;
    while (nil != (filePath = enumerator.nextObject)) {
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:filePath];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) {
            NOZFileZipEntry *entry = [[NOZFileZipEntry alloc] initWithFilePath:fullPath name:filePath];
            [entries addObject:entry];
        }
    }
    return entries;
}
