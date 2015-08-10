//
//  NOZDecompress.m
//  ZipUtilities
//
//  Copyright (c) 2015 Nolan O'Brien.
//

#import "NOZ_Project.h"
#import "NOZDecompress.h"
#include "unzip.h"

#define kWEIGHT 1000ll

typedef NS_ENUM(NSUInteger, NOZDecompressStep)
{
    NOZDecompressStepOpen = 0,
    NOZDecompressStepReadEntrySizes,
    NOZDecompressStepUnzip,
    NOZDecompressStepClose,
};

#define kCancelledError NOZDecompressError(NOZErrorCodeDecompressCancelled, nil)

NS_INLINE NSError * __nonnull NOZDecompressError(NOZErrorCode code, NSDictionary * __nullable ui)
{
    return [NSError errorWithDomain:NOZErrorDomain code:code userInfo:ui];
}

@interface NOZDecompressResult ()
@property (nonatomic, copy) NSString *destinationDirectoryPath;
@property (nonatomic, copy, nullable) NSArray *destinationFiles;
@property (nonatomic, nullable) NSError *operationError;
@property (nonatomic) BOOL didSucceed;

@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) int64_t uncompressedSize;
@property (nonatomic) int64_t compressedSize;
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
- (nullable NSError *)private_unzipCurrentEntry;
- (nullable NSError *)private_unzipCurrentOpenEntry:(nonnull unz_file_info *)fileInfoPtr toFilePath:(nonnull NSString *)filePath;
- (void)private_didDecompressBytes:(int64_t)bytes;

@end

@implementation NOZDecompressOperation
{
    unzFile _unzipFile;
    __weak id<NOZDecompressDelegate> _weakDelegate;
    __strong id<NOZDecompressDelegate> _strongDelegate;
    NOZDecompressRequest *_request;
    NSString *_sanitizedDestinationDirectoryPath;
    CFAbsoluteTime _startTime;
    NSUInteger _expectedEntryCount;
    int64_t _expectedUncompressedSize;
    int64_t _bytesUncompressed;
    NSMutableArray *_entryPaths;

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

- (int64_t)weightForStep:(NSUInteger)stepIndex
{
    NOZDecompressStep step = stepIndex;
    switch (step) {
        case NOZDecompressStepOpen:
            return kWEIGHT / 2;
        case NOZDecompressStepReadEntrySizes:
            return (kWEIGHT * 3) / 2;
        case NOZDecompressStepUnzip:
            return kWEIGHT * 95;
        case NOZDecompressStepClose:
            return kWEIGHT * 3;
    }
    return 0;
}

- (NSError *)runStep:(NSUInteger)stepIndex
{
    NOZDecompressStep step = stepIndex;
    switch (step) {
        case NOZDecompressStepOpen:
            return [self private_openFile];
        case NOZDecompressStepReadEntrySizes:
            return [self private_readExpectedSizes];
        case NOZDecompressStepUnzip:
            return [self private_unzipAllEntries];
        case NOZDecompressStepClose:
            return [self private_closeFile];
    }
    return nil;
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

        result.uncompressedSize = (int64_t)[[fm attributesOfItemAtPath:_request.sourceFilePath error:NULL] fileSize];
        result.compressedSize = _expectedUncompressedSize;
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
    _unzipFile = unzOpen( (const char*)self.request.sourceFilePath.UTF8String );
    if (!_unzipFile) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToOpenZipArchive, (self.request.sourceFilePath) ? @{ @"souceFilePath" : self.request.sourceFilePath } : nil);
    }

    _sanitizedDestinationDirectoryPath = _request.destinationDirectoryPath;
    if (!_sanitizedDestinationDirectoryPath) {
        _sanitizedDestinationDirectoryPath = [_request.sourceFilePath stringByDeletingPathExtension];
    }
    _sanitizedDestinationDirectoryPath = [_sanitizedDestinationDirectoryPath stringByStandardizingPath];

    if (![[NSFileManager defaultManager] createDirectoryAtPath:_sanitizedDestinationDirectoryPath withIntermediateDirectories:YES attributes:nil error:NULL]) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToCreateDestinationDirectory, @{ @"destinationDirectoryPath" : (_request.destinationDirectoryPath ?: @"<null>") });
    }

    return nil;
}

- (NSError *)private_readExpectedSizes
{
    noz_defer(^{ [self updateProgress:1.f forStep:NOZDecompressStepReadEntrySizes]; });
    if (UNZ_OK != unzGoToFirstFile(_unzipFile)) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }

    unz_file_info fileInfo = {0};
    int nextFileError = UNZ_OK;
    do {
        if (UNZ_OK != unzGetCurrentFileInfo(_unzipFile, // unzFile
                                            &fileInfo,  // fileInfo ptr
                                            NULL,       // fileName buffer
                                            0,          // fileName buffer size
                                            NULL,       // extraField buffer
                                            0,          // extraField buffer size
                                            NULL,       // comment buffer
                                            0           // comment buffer size
                                            )) {
            return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
        }

        _expectedEntryCount++;
        _expectedUncompressedSize += fileInfo.uncompressed_size;

    } while ((nextFileError = unzGoToNextFile(_unzipFile)) == UNZ_OK);

    if (nextFileError != UNZ_END_OF_LIST_OF_FILE) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }

    _entryPaths = [[NSMutableArray alloc] initWithCapacity:_expectedEntryCount];

    return nil;
}

- (NSError *)private_unzipAllEntries
{
    if (UNZ_OK != unzGoToFirstFile(_unzipFile)) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }

    NSError *error = nil;
    int nextFileError = UNZ_OK;
    do {
        error = [self private_unzipCurrentEntry];
        if (self.isCancelled) {
            return kCancelledError;
        }
    } while ((nextFileError = unzGoToNextFile(_unzipFile)) == UNZ_OK);

    if (nextFileError != UNZ_END_OF_LIST_OF_FILE) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }
    
    return error;
}

- (NSError *)private_closeFile
{
    if (_unzipFile) {
        noz_defer(^{ [self updateProgress:1.f forStep:NOZDecompressStepClose]; });
        unzClose(_unzipFile); // nothing we can do if we fail to close the archive we are extracting
        _unzipFile = NULL;
    }
    return nil;
}

#pragma mark Helpers

- (NSError *)private_unzipCurrentEntry
{
    unz_file_info fileInfo = {0};
    if (UNZ_OK != unzGetCurrentFileInfo(_unzipFile, // unzFile
                                        &fileInfo,  // fileInfo ptr
                                        NULL,       // fileName buffer
                                        0,          // fileName buffer size
                                        NULL,       // extraField buffer
                                        0,          // extraField buffer size
                                        NULL,       // comment buffer
                                        0           // comment buffer size
                                        )) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }

    char *fileNameBuffer = (char *)malloc(fileInfo.size_filename);
    noz_defer(^{ free(fileNameBuffer); });

    if (UNZ_OK != unzGetCurrentFileInfo(_unzipFile, // unzFile
                                        &fileInfo,  // fileInfo ptr
                                        fileNameBuffer, // fileName buffer
                                        fileInfo.size_filename, // fileName buffer size
                                        NULL,       // extraField buffer
                                        0,          // extraField buffer size
                                        NULL,       // comment buffer
                                        0           // comment buffer size
                                        )) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }
    fileNameBuffer[fileInfo.size_filename] = '\0'; // null terminate

    NSString *filePathRelative = [[NSString alloc] initWithBytes:fileNameBuffer length:fileInfo.size_filename encoding:NSUTF8StringEncoding];
    NSString *filePath = [_sanitizedDestinationDirectoryPath stringByAppendingPathComponent:filePathRelative];
    NSString *fileDir = [filePath stringByDeletingLastPathComponent];

    if (filePath.length == 0 || filePathRelative.length == 0 || fileDir.length == 0) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }

    if (![[NSFileManager defaultManager] createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:NULL]) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToCreateUnarchivedFile, @{ @"filePath" : filePath });
    }

    if (UNZ_OK != unzOpenCurrentFile(_unzipFile)) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToReadArchiveEntry, nil);
    }
    noz_defer(^{ unzCloseCurrentFile(_unzipFile); /* if this fails, nothing we can really do */ });

    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir]) {
        if (isDir || !_flags.delegateHasOverwriteCheck || ![self.delegate shouldDecompressOperation:self overwriteFileAtPath:filePath]) {
            return NOZDecompressError(NOZErrorCodeDecompressCannotOverwriteExistingFile, @{ @"filePath" : filePath });
        }
    }

    [_entryPaths addObject:filePathRelative];
    return [self private_unzipCurrentOpenEntry:&fileInfo toFilePath:filePath];
}

- (NSError *)private_unzipCurrentOpenEntry:(unz_file_info *)fileInfoPtr toFilePath:(NSString *)filePath
{
    if (self.isCancelled) {
        return kCancelledError;
    }

    const size_t bufferSize = 4096;
    char buffer[bufferSize];
    FILE* file = fopen(filePath.UTF8String, "w");
    if (!file) {
        return NOZDecompressError(NOZErrorCodeDecompressFailedToCreateUnarchivedFile, @{ @"filePath" : filePath });
    }
    noz_defer(^{ fclose(file); });

    int bytesRead = 0;
    size_t bytesWritten = 0;
    do {
        @autoreleasepool {
            bytesRead = unzReadCurrentFile(_unzipFile, buffer, bufferSize);
            if (bytesRead < 0) {
                return NOZDecompressError(NOZErrorCodeDecompressFailedToCreateUnarchivedFile, @{ @"filePath" : filePath });
            }
            bytesWritten = fwrite(buffer, sizeof(char), (size_t)bytesRead, file);
            if (bytesWritten != (size_t)bytesRead) {
                return NOZDecompressError(NOZErrorCodeDecompressFailedToCreateUnarchivedFile, @{ @"filePath" : filePath });
            }
            [self private_didDecompressBytes:bytesRead];

            if (self.isCancelled) {
                return kCancelledError;
            }
        }
    } while (bytesRead > 0);

    if (fileInfoPtr->tmu_date.tm_year > 0) {
        NSDateComponents* components = [[NSDateComponents alloc] init];
        components.second = fileInfoPtr->tmu_date.tm_sec;
        components.minute = fileInfoPtr->tmu_date.tm_min;
        components.hour = fileInfoPtr->tmu_date.tm_hour;
        components.day = fileInfoPtr->tmu_date.tm_mday;
        components.month = fileInfoPtr->tmu_date.tm_mon + 1;
        components.year = fileInfoPtr->tmu_date.tm_year;

        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        NSDate* date = [calendar dateFromComponents:components];

        NSError *innerError = nil;
        if (![[NSFileManager defaultManager] setAttributes:@{ NSFileModificationDate : date } ofItemAtPath:filePath error:&innerError]) {
            // error occurred, ignore it...it's just the timestamp
        }
    }

    return nil;
}

- (void)private_didDecompressBytes:(int64_t)bytes
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

- (void)compressOperation:(NOZDecompressOperation *)op didCompleteWithResult:(NOZDecompressResult *)result
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
