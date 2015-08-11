//
//  NOZCompress.m
//  ZipUtilities
//
//  Copyright (c) 2015 Nolan O'Brien.
//

#import "NOZ_Project.h"
#import "NOZCompress.h"
#include "zip.h"

#define kWEIGHT (1000ll)

typedef NS_ENUM(NSUInteger, NOZCompressStep)
{
    NOZCompressStepPrep = 0,
    NOZCompressStepOpen,
    NOZCompressStepZip,
    NOZCompressStepClose
};

NS_INLINE NSError * __nonnull NOZCompressError(NOZErrorCode code, NSDictionary * __nullable ui)
{
    return [NSError errorWithDomain:NOZErrorDomain code:code userInfo:ui];
}

static NSArray * __nonnull NOZEntriesFromDirectory(NSString * __nonnull directoryPath);

#define kCancelledError NOZCompressError(NOZErrorCodeCompressCancelled, nil)

@interface NOZCompressDelegateInternal : NSObject <NOZCompressDelegate>
@property (nonatomic, readonly, nonnull) NOZCompressCompletionBlock completionBlock;
- (nonnull instancetype)initWithCompletion:(nonnull NOZCompressCompletionBlock)completion;
- (nonnull instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)new NS_UNAVAILABLE;
@end

@interface NOZCompressResult ()
@property (nonatomic, copy) NSString *destinationPath;
@property (nonatomic, nullable) NSError *operationError;
@property (nonatomic) BOOL didSucceed;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) int64_t uncompressedSize;
@property (nonatomic) int64_t compressedSize;
@end

@interface NOZCompressOperation (Private)

#pragma mark Steps
- (nullable NSError *)private_prepareProgress;
- (nullable NSError *)private_openFile;
- (nullable NSError *)private_addEntries;
- (nullable NSError *)private_closeFile;

#pragma mark Helpers
- (nullable NSError *)private_addEntry:(nonnull NOZCompressEntry *)entry;
- (void)private_didCompressBytes:(int64_t)byteCount;

@end

@implementation NOZCompressOperation
{
    zipFile _zipFile;
    __strong id<NOZCompressDelegate> _strongDelegate;
    __weak id<NOZCompressDelegate> _weakDelegate;
    NOZCompressRequest *_request;
    CFAbsoluteTime _startTime;
    int64_t _totalUncompressedBytes;
    int64_t _finishedUncompressedBytes;

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

- (int64_t)weightForStep:(NSUInteger)stepIndex
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

- (nullable NSError *)runStep:(NSUInteger)stepIndex
{
    NOZCompressStep step = stepIndex;
    switch (step) {
        case NOZCompressStepPrep:
            return [self private_prepareProgress];
        case NOZCompressStepOpen:
            return [self private_openFile];
        case NOZCompressStepZip:
            return [self private_addEntries];
        case NOZCompressStepClose:
            return [self private_closeFile];
    }

    return nil;
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
        if (_zipFile) {
            [self private_closeFile];
            [[NSFileManager defaultManager] removeItemAtPath:result.destinationPath error:NULL];
        }
    } else {
        result.didSucceed = YES;
        result.uncompressedSize = _totalUncompressedBytes;
        result.compressedSize = (int64_t)[[[NSFileManager defaultManager] attributesOfItemAtPath:result.destinationPath error:NULL] fileSize];
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
    for (NOZCompressEntry *entry in _request.entries) {
        _totalUncompressedBytes += entry.sizeInBytes;
    }
    if (!_totalUncompressedBytes) {
        return NOZCompressError(NOZErrorCodeCompressNoEntriesToCompress, nil);
    }

    return nil;
}

- (NSError *)private_openFile
{
    NSString *path = [_request.destinationPath stringByStandardizingPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    _zipFile = zipOpen(path.UTF8String, zip_append_status_create);
    [self updateProgress:1.f forStep:NOZCompressStepOpen];

    if (!_zipFile) {
        return NOZCompressError(NOZErrorCodeCompressFailedToOpenNewZipFile, @{ @"path" : _request.destinationPath ?: @"<null>" });
    }
    return nil;
}

- (NSError *)private_addEntries
{
    NSError *error = NOZCompressError(NOZErrorCodeCompressNoEntriesToCompress, nil);
    for (NOZCompressEntry *entry in _request.entries) {
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
    if (_zipFile) {
        noz_defer(^{ [self updateProgress:1.f forStep:NOZCompressStepClose]; });
        if (Z_OK == zipClose(_zipFile, NULL)) {
            _zipFile = NULL;
        } else {
            return NOZCompressError(NOZErrorCodeCompressFailedToFinalizeNewZipFile, nil);
        }
    }
    return nil;
}

#pragma mark Helpers

- (NSError *)private_addEntry:(NOZCompressEntry *)entry
{
    // Start
    if (!entry.name) {
        return NOZCompressError(NOZErrorCodeCompressMissingEntryName, @{ @"entry" : entry });
    }
    if (!entry.hasDataOrFile) {
        return NOZCompressError(NOZErrorCodeCompressMissingEntryDataOrFile, @{ @"entry" : entry });
    }

    zip_fileinfo zipInfo = { 0 };

    NSDate* fileDate = entry.fileDate ?: [NSDate date];

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents* components = [gregorianCalendar components:   NSCalendarUnitYear |
                                                                    NSCalendarUnitMonth |
                                                                    NSCalendarUnitDay |
                                                                    NSCalendarUnitHour |
                                                                    NSCalendarUnitMinute |
                                                                    NSCalendarUnitSecond
                                                        fromDate:fileDate];

    zipInfo.tmz_date.tm_sec = (uInt)components.second;
    zipInfo.tmz_date.tm_min = (uInt)components.minute;
    zipInfo.tmz_date.tm_hour = (uInt)components.hour;
    zipInfo.tmz_date.tm_mday = (uInt)components.day;
    zipInfo.tmz_date.tm_mon = (uInt)components.month;
    zipInfo.tmz_date.tm_year = (uInt)components.year;


    __block int status = zipOpenNewFileInZip(_zipFile,                  // file
                                             entry.name.UTF8String,     // name
                                             &zipInfo,                  // info
                                             NULL,                      // extra local
                                             0,                         // extra local size
                                             NULL,                      // extra global
                                             0,                         // extra global size
                                             NULL,                      // comment
                                             Z_DEFLATED,                // compression
                                             _request.compressionLevel  // compression level
                                             );
    if (status != Z_OK) {
        return NOZCompressError(NOZErrorCodeCompressFailedToAppendEntryToZip, @{ @"entry" : entry });
    }
    noz_defer(^{
        zipCloseFileInZip(_zipFile);
    });

    if (self.isCancelled) {
        return NOZCompressError(NOZErrorCodeCompressCancelled, nil);
    }

    // Add data (from NSData or from file)

    if (entry.data) {
        [entry.data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
            status = zipWriteInFileInZip(_zipFile, bytes, (unsigned int)byteRange.length);
            if (status != Z_OK || self.isCancelled) {
                *stop = YES;
            } else {
                [self private_didCompressBytes:(int64_t)byteRange.length];
            }
        }];
    } else if (entry.path) {
        NSString *path = [entry.path stringByStandardizingPath];
        FILE *file = fopen(path.UTF8String, "r");
        noz_defer(^{ if (file) { fclose(file); } });

        if (!file) {
            status = Z_DATA_ERROR;
        } else {
            const size_t bufferSize = 4096;
            unsigned char buffer[bufferSize];
            size_t bytesRead;
            do {
                @autoreleasepool {
                    bytesRead = fread(buffer, sizeof(unsigned char), bufferSize, file);
                    if (bytesRead > 0) {
                        status = zipWriteInFileInZip(_zipFile, buffer, (unsigned int)bytesRead);
                        if (status == Z_OK) {
                            [self private_didCompressBytes:(int64_t)bytesRead];
                        }
                    }

                    if (self.isCancelled) {
                        return kCancelledError;
                    }
                }
            } while (bytesRead == bufferSize && status == Z_OK);

            if (status == Z_OK && !feof(file)) {
                status = Z_DATA_ERROR;
            }
        }
    }

    if (status != Z_OK) {
        return NOZCompressError(NOZErrorCodeCompressFailedToAppendEntryToZip, @{ @"entry" : entry });
    } else if (self.isCancelled) {
        return kCancelledError;
    }

    return nil;
}

- (void)private_didCompressBytes:(int64_t)byteCount
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
{
    NSMutableArray *_entries;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithDestinationPath:(NSString *)path
{
    if (self = [super init]) {
        _compressionLevel = NOZCompressionLevelDefault;
        _destinationPath = [path copy];
        _entries = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NOZCompressRequest *copy = [[[self class] allocWithZone:zone] initWithDestinationPath:self.destinationPath];
    copy.destinationPath = self.destinationPath;
    copy->_entries = [self.entries mutableCopy];
    copy->_compressionLevel = self.compressionLevel;
    return copy;
}

- (NSArray *)entries
{
    NSMutableArray *entries = [[NSMutableArray alloc] initWithCapacity:_entries.count];
    for (NOZCompressEntry *entry in _entries) {
        [entries addObject:[entry copy]];
    }
    return [entries copy];
}

- (void)setEntries:(NSArray *)entries
{
    [_entries removeAllObjects];
    for (NOZCompressEntry *entry in entries) {
        [self addEntry:entry];
    }
}

- (void)addEntry:(NOZCompressEntry *)entry
{
    [_entries addObject:[entry copy]];
}

- (void)addEntriesInDirectory:(NSString *)directoryPath
{
    for (NOZCompressEntry *entry in NOZEntriesFromDirectory(directoryPath)) {
        [self addEntry:entry];
    }
}

- (void)addFileEntry:(NSString *)filePath
{
    [self addFileEntry:filePath name:filePath.lastPathComponent];
}

- (void)addFileEntry:(NSString *)filePath name:(NSString *)name
{
    NOZCompressEntry *entry = [[NOZCompressEntry alloc] initWithFilePath:filePath name:name];
    [self addEntry:entry];
}

- (void)addDataEntry:(NSData *)data name:(NSString *)name
{
    NOZCompressEntry *entry = [[NOZCompressEntry alloc] initWithData:data name:name];
    [self addEntry:entry];
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@ %p : compressionLevel=%zi", NSStringFromClass([self class]), self, self.compressionLevel];
    if (self.destinationPath) {
        [string appendFormat:@", dstPath='%@'", self.destinationPath];
    }
    [string appendFormat:@", entries=%@", self.entries];
    [string appendString:@">"];
    return string;
}

@end

@implementation NOZCompressEntry

- (instancetype)initWithFilePath:(NSString * __nonnull)path
{
    return [self initWithFilePath:path name:path.lastPathComponent];
}

- (instancetype)initWithFilePath:(NSString * __nonnull)path name:(NSString * __nonnull)name
{
    if (self = [self init]) {
        _path = [path copy];
        _name = [name copy];
    }
    return self;
}

- (instancetype)initWithData:(NSData * __nonnull)data name:(NSString * __nonnull)name
{
    if (self = [self init]) {
        _data = data;
        _name = [name copy];
    }
    return self;
}

- (BOOL)hasDataOrFile
{
    if (_data != nil) {
        return YES;
    }

    BOOL isDir = NO;
    if (_path != nil && [[NSFileManager defaultManager] fileExistsAtPath:_path isDirectory:&isDir] && !isDir) {
        return YES;
    }

    return NO;
}

- (int64_t)sizeInBytes
{
    if (_data) {
        return (int64_t)[_data length];
    }

    return (int64_t)[[[NSFileManager defaultManager] attributesOfItemAtPath:_path error:NULL] fileSize];
}

- (NSDate *)fileDate
{
    if (!_path) {
        return nil;
    }

    return [[[NSFileManager defaultManager] attributesOfItemAtPath:_path error:NULL] fileModificationDate];
}

- (id)copyWithZone:(NSZone *)zone
{
    NOZCompressEntry *entry = [[[self class] allocWithZone:zone] init];
    entry->_path = _path;
    entry->_name = _name;
    entry->_data = _data;
    return entry;
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@ %p", NSStringFromClass([self class]), self];
    if (_name) {
        [string appendFormat:@", name='%@'", _name];
    }
    if (_data) {
        [string appendFormat:@", data.length=%tu", _data.length];
    } else if (_path) {
        [string appendFormat:@", path='%@'", _path];
    }
    [string appendString:@">"];
    return string;
}

@end

static NSArray * NOZEntriesFromDirectory(NSString * directoryPath)
{
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:directoryPath];
    NSString *filePath = nil;
    while (nil != (filePath = enumerator.nextObject)) {
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:filePath];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) {
            NOZCompressEntry *entry = [[NOZCompressEntry alloc] initWithFilePath:fullPath name:filePath];
            [entries addObject:entry];
        }
    }
    return entries;
}
