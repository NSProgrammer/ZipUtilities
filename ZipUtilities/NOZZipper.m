//
//  NOZZipper.m
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
#import "NOZError.h"
#import "NOZUtils_Project.h"
#import "NOZZipper.h"

#ifndef NOZ_SINGLE_PASS_ZIP
#define NOZ_SINGLE_PASS_ZIP 1
#endif

static UInt8 noz_fwrite_value(UInt64 x, const UInt8 byteCount, FILE *file);
static UInt8 noz_store_value(UInt64 x, const UInt8 byteCount, Byte *buffer, const Byte *bufferEnd);

#define PRIVATE_WRITE(v) \
noz_fwrite_value((v), sizeof(v), _internal.file)

@interface NOZZipper (Private)

// Top level methods
- (BOOL)private_forciblyClose:(BOOL)forceClose error:(out NSError * __nullable * __nullable)error;

// Entry methods
- (BOOL)private_openEntry:(nonnull id<NOZZippableEntry>)entry
                    error:(out NSError * __nullable * __nullable)error;
- (BOOL)private_writeEntry:(nonnull id<NOZZippableEntry>)entry
             progressBlock:(nullable NOZProgressBlock)progressBlock
                     error:(out NSError * __nullable * __nullable)error
                  abortRef:(nonnull BOOL *)abort;
- (BOOL)private_closeCurrentOpenEntryAndReturnError:(out NSError * __nullable * __nullable)error;

// Helpers
- (BOOL)private_finishEncoding;
- (BOOL)private_flushWriteBuffer:(const Byte*)buffer length:(size_t)length;
- (void)private_freeLinkedList;

// Records
- (BOOL)private_populateRecordsForCurrentOpenEntryWithEntry:(nonnull id<NOZZippableEntry>)entry error:(out NSError * __nullable * __nullable)error;
- (BOOL)private_writeLocalFileHeaderForCurrentEntryAndReturnError:(out NSError * __nullable * __nullable)error;
- (BOOL)private_writeLocalFileHeaderForEntry:(NOZFileEntryT *)entry signature:(BOOL)writeSig;
- (BOOL)private_writeCurrentLocalFileDescriptor:(BOOL)writeSignature;
- (BOOL)private_writeLocalFileDescriptorForEntry:(NOZFileEntryT *)entry signature:(BOOL)writeSig;
- (BOOL)private_writeCentralDirectoryRecords;
- (BOOL)private_writeCentralDirectoryRecord:(NOZFileEntryT *)entry;
- (BOOL)private_writeEndOfCentralDirectoryRecord;

@end

@implementation NOZZipper
{
    NSString *_standardizedZipFilePath;
    id<NOZEncoder> _currentEncoder;
    id<NOZEncoderContext> _currentEncoderContext;

    struct {
        FILE *file;

        NOZFileEntryT *firstEntry;
        NOZFileEntryT *lastEntry;

        SInt64 beginBytePosition;
        SInt64 writingPositionOffset;

        NOZFileEntryT *currentEntry;
        NOZEndOfCentralDirectoryRecordT endOfCentralDirectoryRecord;
        Byte *comment;

        BOOL ownsComment:1;
    } _internal;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithZipFile:(nonnull NSString *)zipFilePath
{
    if (self = [super init]) {
        _zipFilePath = [zipFilePath copy];
        _standardizedZipFilePath = [_zipFilePath stringByStandardizingPath];

        _internal.beginBytePosition = 0;
        _internal.writingPositionOffset = 0;
        _internal.firstEntry = _internal.lastEntry = _internal.currentEntry = NULL;
    }
    return self;
}

- (void)dealloc
{
    [self forciblyCloseAndReturnError:NULL];
    [self private_freeLinkedList];
}

- (BOOL)openWithMode:(NOZZipperMode)mode error:(out NSError * __nullable * __nullable)error
{
    if (_internal.file) {
        return YES;
    }

    __block NSError *stackError = nil;
    noz_defer(^{
        if (stackError != nil && error) {
            *error = stackError;
        }
    });

    if (!_standardizedZipFilePath.UTF8String) {
        stackError = NOZError(NOZErrorCodeZipInvalidFilePath, _zipFilePath ? @{ @"zipFilePath" : _zipFilePath } : nil);
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm createDirectoryAtPath:[_standardizedZipFilePath stringByDeletingLastPathComponent]
       withIntermediateDirectories:YES
                        attributes:nil
                             error:&stackError]) {
        return NO;
    }

    const char *fopenMode = "w+";
    switch (mode) {
//        case NOZZipperModeOpenExistingOrCreate:
//            break;
//        case NOZZipperModeOpenExisting:
//        {
//            fopenMode = "r+";
//            if (![fm fileExistsAtPath:_standardizedZipFilePath]) {
//                stackError = NOZError(NOZErrorCodeZipCannotOpenExistingZip, @{ @"zipFilePath" : _zipFilePath });
//                return NO;
//            }
//            break;
//        }
        case NOZZipperModeCreate:
        default:
        {
            if ([fm fileExistsAtPath:_standardizedZipFilePath]) {
                stackError = NOZError(NOZErrorCodeZipCannotCreateZip, @{ @"zipFilePath" : _zipFilePath });
                return NO;
            }
            break;
        }
    }

    _internal.file = fopen(_standardizedZipFilePath.UTF8String, fopenMode);
    if (!_internal.file) {
        // stackError = NOZError((NOZZipperModeOpenExisting == mode) ? NOZErrorCodeZipCannotOpenExistingZip : NOZErrorCodeZipCannotCreateZip, @{ @"zipFilePath" : _zipFilePath });
        stackError = NOZError(NOZErrorCodeZipCannotCreateZip, @{ @"zipFilePath" : _zipFilePath });
        return NO;
    }
    noz_defer(^{
        if (stackError != nil) {
            fclose(_internal.file);
            _internal.file = NULL;
            if (NOZZipperModeCreate == mode) {
                [[NSFileManager defaultManager] removeItemAtPath:_standardizedZipFilePath error:NULL];
            }
        }
    });

    if (0 != fseeko(_internal.file, 0, SEEK_END)) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo: @{ @"zipFilePath" : _zipFilePath }];
        return NO;
    }

    _internal.beginBytePosition = ftello(_internal.file);
    if (_internal.beginBytePosition < 0) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{ @"zipFilePath" : _zipFilePath }];
        return NO;
    }
    return YES;
}

- (BOOL)closeAndReturnError:(out NSError * __nullable * __nullable)error
{
    return [self private_forciblyClose:NO error:error];
}

- (BOOL)forciblyCloseAndReturnError:(out NSError * __nullable * __nullable)error
{
    return [self private_forciblyClose:YES error:error];
}

- (BOOL)addEntry:(nonnull id<NOZZippableEntry>)entry
   progressBlock:(__attribute__((noescape)) NOZProgressBlock __nullable)progressBlock
           error:(out NSError * __nullable * __nullable)error
{
    if (![self private_openEntry:entry error:error]) {
        return NO;
    }

    BOOL writeSuccess = NO;
    BOOL shouldAbort = NO;

    if (!shouldAbort) {
        writeSuccess = [self private_writeEntry:entry progressBlock:progressBlock error:error abortRef:&shouldAbort];
    }

    if (![self private_closeCurrentOpenEntryAndReturnError:(writeSuccess) ? error : NULL] || !writeSuccess) {
        if (!writeSuccess && shouldAbort && error && !*error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ECANCELED userInfo:nil];
        }
        return NO;
    }

    return YES;
}

@end

@implementation NOZZipper (Private)

- (BOOL)private_forciblyClose:(BOOL)forceClose error:(out NSError * __nullable * __nullable)error
{
    if (!_internal.file) {
        return YES;
    }

    __block NSError *stackError = nil;
    noz_defer(^{ if (stackError != nil && error) { *error = stackError; } });

    if (forceClose && ![self private_closeCurrentOpenEntryAndReturnError:&stackError]) {
        [self private_freeLinkedList];
        return NO;
    } else if (!forceClose && NULL != _internal.currentEntry) {
        stackError = NOZError(NOZErrorCodeZipFailedToCloseCurrentEntry, nil);
        return NO;
    }

    NSUInteger globalCommentSize = [self.globalComment lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (globalCommentSize > UINT16_MAX) {
        globalCommentSize = 0;
    }
    if (globalCommentSize > 0) {
        _internal.endOfCentralDirectoryRecord.commentSize = (UInt16)globalCommentSize;
        _internal.comment = malloc(globalCommentSize);
        memcpy(_internal.comment, self.globalComment.UTF8String, globalCommentSize);
        _internal.ownsComment = YES;
    }

    noz_defer(^{
        fclose(_internal.file);
        _internal.file = NULL;
        [self private_freeLinkedList];
        if (_internal.ownsComment) {
            free(_internal.comment);
            _internal.comment = NULL;
        }
    });

    if (![self private_writeCentralDirectoryRecords]) {
        stackError = NOZError(NOZErrorCodeZipFailedToWriteZip, nil);
        return NO;
    }

    if (![self private_writeEndOfCentralDirectoryRecord]) {
        stackError = NOZError(NOZErrorCodeZipFailedToWriteZip, nil);
        return NO;
    }

    return YES;
}

- (BOOL)private_openEntry:(nonnull id<NOZZippableEntry>)entry
                    error:(out NSError * __nullable * __nullable)error
{
    __block BOOL errorEncountered = NO;
    noz_defer(^{ if (errorEncountered && error) { *error = NOZError(NOZErrorCodeZipCannotOpenNewEntry, nil); } });

    NSUInteger nameSize = [entry.name lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (nameSize > UINT16_MAX || nameSize == 0) {
        errorEncountered = YES;
        return NO;
    }

    if (!_internal.file) {
        errorEncountered = YES;
        return NO;
    }

    if (![self private_closeCurrentOpenEntryAndReturnError:error]) {
        return NO;
    }

    NOZFileEntryT *newEntry = NOZFileEntryAllocInit();
    if (!newEntry) {
        errorEncountered = YES;
        return NO;
    }

    if (_internal.lastEntry) {
        _internal.lastEntry->nextEntry = newEntry;
        _internal.lastEntry = newEntry;
    } else {
        _internal.firstEntry = _internal.lastEntry = newEntry;
    }
    _internal.currentEntry = newEntry;

    if (![self private_populateRecordsForCurrentOpenEntryWithEntry:entry error:error]) {
        _internal.currentEntry = NULL;
        return NO;
    }

    if (![self private_writeLocalFileHeaderForCurrentEntryAndReturnError:error]) {
        _internal.currentEntry = NULL;
        return NO;
    }

    __unsafe_unretained typeof(self) rawSelf = self;
    _currentEncoder = NOZEncoderForCompressionMethod(_internal.currentEntry->fileHeader.compressionMethod);
    _currentEncoderContext = [_currentEncoder createContextWithBitFlags:_internal.currentEntry->fileHeader.bitFlag
                                                       compressionLevel:entry.compressionLevel
                                                          flushCallback:^BOOL(id<NOZEncoder> encoder, id<NOZEncoderContext> context, const Byte* buffer, size_t length) {
        if (rawSelf->_currentEncoder != encoder) {
            return NO;
        }

        return [rawSelf private_flushWriteBuffer:buffer length:length];
    }];
    if (!_currentEncoder || !_currentEncoderContext) {
        if (error) {
            *error = NOZError(NOZErrorCodeZipDoesNotSupportCompressionMethod, @{ @"method" : @(_internal.currentEntry->fileHeader.compressionMethod) });
        }
        _currentEncoder = nil;
        _internal.currentEntry = NULL;
        return NO;
    }

    if (![_currentEncoder initializeEncoderContext:_currentEncoderContext]) {
        _currentEncoderContext = nil;
        _currentEncoder = nil;
        _internal.currentEntry = NULL;
        if (error) {
            *error = [NSError errorWithDomain:NOZErrorDomain
                                         code:NOZErrorCodeZipFailedToCompressEntry
                                     userInfo:nil];
        }
        return NO;
    }

    return YES;
}

- (BOOL)private_writeEntry:(nonnull id<NOZZippableEntry>)entry
             progressBlock:(nullable NOZProgressBlock)progressBlock
                     error:(out NSError * __nullable * __nullable)error
                  abortRef:(nonnull BOOL *)abort
{
    __block BOOL success = YES;
    noz_defer(^{
        if (error) {
            if ((*abort)) {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ECANCELED userInfo:nil];
            } else if (!success && !*error) {
                *error = NOZError(NOZErrorCodeZipFailedToWriteEntry, nil);
            }
        }
    });

    if (success && (!_internal.currentEntry || !entry.inputStream)) {
        success = NO;
        return NO;
    }

    const SInt64 totalBytes = entry.sizeInBytes;
    if (success) {
        NSInputStream *inputStream = entry.inputStream;
        [inputStream open];
        noz_defer(^{ [inputStream close]; });
        NSInteger bytesRead;
        const size_t pageSize = NSPageSize();
        Byte buffer[pageSize];

        do {
            bytesRead = [inputStream read:buffer maxLength:pageSize];

            if (bytesRead < 0) {
                success = NO;
                break;
            }

            if (bytesRead == 0) {
                break;
            }

            _internal.currentEntry->fileDescriptor.crc32 = (UInt32)crc32(_internal.currentEntry->fileDescriptor.crc32, buffer, (UInt32)bytesRead);

            success = [_currentEncoder encodeBytes:buffer length:(size_t)bytesRead context:_currentEncoderContext];
            if (!success) {
                if (error) {
                    *error = [NSError errorWithDomain:NOZErrorDomain
                                                 code:NOZErrorCodeZipFailedToCompressEntry
                                             userInfo:nil];
                }
                break;
            }

            if (bytesRead != 0) {
                _internal.currentEntry->fileDescriptor.uncompressedSize += (SInt64)bytesRead;
                if (progressBlock) {
                    progressBlock(totalBytes, _internal.currentEntry->fileDescriptor.uncompressedSize, bytesRead, abort);
                }
            }

        } while ((size_t)bytesRead == pageSize && !(*abort));
    }

    return success;
}

- (BOOL)private_closeCurrentOpenEntryAndReturnError:(out NSError * __nullable * __nullable)error
{
    if (!_internal.currentEntry) {
        return YES;
    }

    BOOL success = YES;

    if (success) {
        success = [self private_finishEncoding];
    }

#if NOZ_SINGLE_PASS_ZIP
    if (success) {
        success = [self private_writeCurrentLocalFileDescriptor:YES];
    }
#endif

    _internal.endOfCentralDirectoryRecord.totalRecordCount++;
    _internal.endOfCentralDirectoryRecord.recordCountForDisk++;
    _internal.currentEntry = NULL;

    if (!success && error) {
        *error = NOZError(NOZErrorCodeZipFailedToCloseCurrentEntry, nil);
    }
    
    return success;
}

- (void)private_freeLinkedList
{
    NOZFileEntryCleanFree(_internal.firstEntry);
    _internal.firstEntry = _internal.lastEntry = NULL;
}

- (BOOL)private_flushWriteBuffer:(const Byte*)buffer length:(size_t)length
{
    if (0 == length) {
        return YES;
    }

    BOOL success = YES;

    size_t bytesWritten = fwrite(buffer,
                                 1,
                                 length,
                                 _internal.file);
    if (bytesWritten != length) {
        success = NO;
    }

    _internal.currentEntry->fileDescriptor.compressedSize += bytesWritten;

    return success;
}

- (BOOL)private_populateRecordsForCurrentOpenEntryWithEntry:(nonnull id<NOZZippableEntry>)entry error:(out NSError * __nullable * __nullable)error
{
    NSUInteger nameSize = [entry.name lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (nameSize > UINT16_MAX) {
        nameSize = 0;
    }

    NSUInteger extraFieldSize = 0;
    if (extraFieldSize > UINT16_MAX) {
        extraFieldSize = 0;
    }

    NSUInteger commentSize = [entry.comment lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (commentSize > UINT16_MAX) {
        commentSize = 0;
    }

    if (0 == nameSize) {
        if (error) {
            *error = NOZError(NOZErrorCodeZipCannotOpenNewEntry, nil);
        }
        return NO;
    }

    if (entry.sizeInBytes > UINT32_MAX || (ftello(_internal.file) - _internal.beginBytePosition) > (UINT32_MAX - UINT8_MAX)) {
        if (error) {
            *error = NOZError(NOZErrorCodeZipDoesNotSupportZip64, nil);
        }
        return NO;
    }

    NOZCentralDirectoryFileRecordT *record = &_internal.currentEntry->centralDirectoryRecord;

    /* File Record info */
    {
        record->versionMadeBy = NOZVersionForCreation;

        /* File Header info */
        {
            record->fileHeader->versionForExtraction = NOZVersionForExtraction;

            /* Bit Flag */
            {
                record->fileHeader->bitFlag = 0;
                id<NOZEncoder> encoder = NOZEncoderForCompressionMethod(entry.compressionMethod);
                if (encoder) {
                    record->fileHeader->bitFlag |= [encoder bitFlagsForEntry:entry];
                }
#if NOZ_SINGLE_PASS_ZIP
                record->fileHeader->bitFlag |= NOZFlagBitUseDescriptor;
#endif
            }

            record->fileHeader->compressionMethod = entry.compressionMethod;
            noz_dos_date_from_NSDate(entry.timestamp ?: [NSDate date],
                                     &record->fileHeader->dosDate,
                                     &record->fileHeader->dosTime);

            /* File Descriptor info */
            {
                record->fileHeader->fileDescriptor->crc32 = 0;
                record->fileHeader->fileDescriptor->compressedSize = 0;
                record->fileHeader->fileDescriptor->uncompressedSize = 0;
            }

            record->fileHeader->nameSize = (UInt16)nameSize;
            record->fileHeader->extraFieldSize = (UInt16)extraFieldSize;
        }

        record->commentSize = (UInt16)commentSize;
        record->fileStartDiskNumber = 0;
        record->internalFileAttributes = 0;
        record->externalFileAttributes = 0;

        SInt64 offset = ((SInt64)ftello(_internal.file) - _internal.beginBytePosition);
        if (offset > UINT32_MAX) {
            offset = UINT32_MAX;
        }
        record->localFileHeaderOffsetFromStartOfDisk = (UInt32)offset;
    }

    if (nameSize > 0) {
        _internal.currentEntry->name = (const Byte*)malloc(nameSize);
        memcpy((void *)_internal.currentEntry->name, entry.name.UTF8String, nameSize);
        _internal.currentEntry->ownsName = YES;
    }
    _internal.currentEntry->extraField = NULL;
    _internal.currentEntry->ownsName = NO;
    if (commentSize > 0) {
        _internal.currentEntry->comment = (const Byte*)malloc(commentSize);
        memcpy((void *)_internal.currentEntry->comment, entry.comment.UTF8String, commentSize);
        _internal.currentEntry->ownsName = YES;
    }

    return YES;
}

- (BOOL)private_writeLocalFileHeaderForEntry:(NOZFileEntryT *)entry signature:(BOOL)writeSig
{
    NOZLocalFileHeaderT* header = &entry->fileHeader;
    SInt64 oldPosition = ftello(_internal.file);

    if (writeSig) {
        PRIVATE_WRITE(NOZMagicNumberLocalFileHeader);
    }
    PRIVATE_WRITE(header->versionForExtraction);
    PRIVATE_WRITE(header->bitFlag);
    PRIVATE_WRITE(header->compressionMethod);
    PRIVATE_WRITE(header->dosTime);
    PRIVATE_WRITE(header->dosDate);

    [self private_writeLocalFileDescriptorForEntry:entry signature:NO];

    PRIVATE_WRITE(header->nameSize);
    PRIVATE_WRITE(header->extraFieldSize);

    SInt64 diff = ftello(_internal.file) - oldPosition;
    SInt64 expectedBytesWritten = 30;
    return (diff == expectedBytesWritten);
}

- (BOOL)private_writeLocalFileHeaderForCurrentEntryAndReturnError:(out NSError * __nullable * __nullable)error
{
    BOOL success = YES;
    NOZFileEntryT *entry = _internal.currentEntry;

    success = [self private_writeLocalFileHeaderForEntry:entry signature:YES];

    if (success) {
        size_t bytesWritten = fwrite(entry->name, 1, (size_t)entry->fileHeader.nameSize, _internal.file);
        if (bytesWritten != (size_t)entry->fileHeader.nameSize) {
            success = NO;
        }
    }

    if (success && entry->fileHeader.extraFieldSize > 0) {
        size_t bytesWritten = fwrite(entry->extraField, 1, (size_t)entry->fileHeader.extraFieldSize, _internal.file);
        if (bytesWritten != (size_t)entry->fileHeader.extraFieldSize) {
            success = NO;
        }
    }

    if (!success && error) {
        *error = NOZError(NOZErrorCodeZipCannotOpenNewEntry, nil);
    }

    return success;
}

- (BOOL)private_finishEncoding
{
    if (!_currentEncoder) {
        return NO;
    }

    noz_defer(^{
        _currentEncoder = nil;
        _currentEncoderContext = nil;
    });

    BOOL success = [_currentEncoder finalizeEncoderContext:_currentEncoderContext];
    if (_currentEncoderContext.encodedDataWasText) {
        _internal.currentEntry->centralDirectoryRecord.internalFileAttributes |= (1 << 0) /* text */;
    }
    return success;
}

- (BOOL)private_writeLocalFileDescriptorForEntry:(NOZFileEntryT *)entry signature:(BOOL)writeSignature
{
    BOOL success = YES;

    NOZLocalFileDescriptorT *fileDescriptor = &entry->fileDescriptor;
    SInt64 oldPosition = ftello(_internal.file);

    if (writeSignature) {
        PRIVATE_WRITE(NOZMagicNumberDataDescriptor);
    }
    PRIVATE_WRITE(fileDescriptor->crc32);
    PRIVATE_WRITE(fileDescriptor->compressedSize);
    PRIVATE_WRITE(fileDescriptor->uncompressedSize);

    if ((ftello(_internal.file) - oldPosition) != (writeSignature ? 16 : 12)) {
        success = NO;
    }

    return success;
}

- (BOOL)private_writeCurrentLocalFileDescriptor:(BOOL)writeSignature
{
    return [self private_writeLocalFileDescriptorForEntry:_internal.currentEntry signature:writeSignature];
}

- (BOOL)private_writeCentralDirectoryRecords
{
    BOOL success = YES;

    NOZFileEntryT *entry = _internal.firstEntry;
    while (entry != NULL && success) {

        success = [self private_writeCentralDirectoryRecord:entry];

        entry = entry->nextEntry;
    }

    return success;
}

- (BOOL)private_writeCentralDirectoryRecord:(NOZFileEntryT *)entry
{
    if (0 == _internal.endOfCentralDirectoryRecord.archiveStartToCentralDirectoryStartOffset) {
        _internal.endOfCentralDirectoryRecord.archiveStartToCentralDirectoryStartOffset = (UInt32)(ftello(_internal.file) - _internal.beginBytePosition);
    }

    SInt64 oldPosition = ftello(_internal.file);
    SInt64 expectedBytesWritten = 46;
    NOZCentralDirectoryFileRecordT *record = &entry->centralDirectoryRecord;

    /* File Record info */
    {
        PRIVATE_WRITE(NOZMagicNumberCentralDirectoryFileRecord);
        PRIVATE_WRITE(record->versionMadeBy);

        [self private_writeLocalFileHeaderForEntry:entry signature:NO];

        PRIVATE_WRITE(record->commentSize);
        PRIVATE_WRITE(record->fileStartDiskNumber);
        PRIVATE_WRITE(record->internalFileAttributes);
        PRIVATE_WRITE(record->externalFileAttributes);
        PRIVATE_WRITE(record->localFileHeaderOffsetFromStartOfDisk);
    }

    if (entry->name) {
        expectedBytesWritten += record->fileHeader->nameSize;
        fwrite(entry->name, 1, (size_t)record->fileHeader->nameSize, _internal.file);
    }

    if (entry->extraField) {
        expectedBytesWritten += record->fileHeader->extraFieldSize;
        fwrite(entry->extraField, 1, (size_t)record->fileHeader->extraFieldSize, _internal.file);
    }

    if (entry->comment) {
        expectedBytesWritten += record->commentSize;
        fwrite(entry->comment, 1, (size_t)record->commentSize, _internal.file);
    }

    SInt64 bytesWritten = (ftello(_internal.file) - oldPosition);
    _internal.endOfCentralDirectoryRecord.centralDirectorySize += bytesWritten;
    if (bytesWritten != expectedBytesWritten) {
        return NO;
    }

#if !NOZ_SINGLE_PASS_ZIP
    if (0 == fseeko(_internal.file, _internal.beginBytePosition + record->localFileHeaderOffsetFromStartOfDisk + 14, SEEK_SET)) {
        [self private_writeLocalFileDescriptorForEntry:entry signature:NO];
    }
    fseeko(_internal.file, 0, SEEK_END);
#endif

    return YES;
}

- (BOOL)private_writeEndOfCentralDirectoryRecord
{
    SInt64 oldPosition = ftello(_internal.file);
    SInt64 expectedBytesWritten = 22;

    PRIVATE_WRITE(NOZMagicNumberEndOfCentralDirectoryRecord);
    PRIVATE_WRITE(_internal.endOfCentralDirectoryRecord.diskNumber);
    PRIVATE_WRITE(_internal.endOfCentralDirectoryRecord.startDiskNumber);
    PRIVATE_WRITE(_internal.endOfCentralDirectoryRecord.recordCountForDisk);
    PRIVATE_WRITE(_internal.endOfCentralDirectoryRecord.totalRecordCount);
    PRIVATE_WRITE(_internal.endOfCentralDirectoryRecord.centralDirectorySize);
    PRIVATE_WRITE(_internal.endOfCentralDirectoryRecord.archiveStartToCentralDirectoryStartOffset);
    PRIVATE_WRITE(_internal.endOfCentralDirectoryRecord.commentSize);

    if (_internal.comment) {
        expectedBytesWritten += _internal.endOfCentralDirectoryRecord.commentSize;
        fwrite(_internal.comment, 1, (size_t)_internal.endOfCentralDirectoryRecord.commentSize, _internal.file);
    }

    SInt64 bytesWritten = ftello(_internal.file) - oldPosition;
    return bytesWritten == expectedBytesWritten;
}

@end

static UInt8 noz_store_value(UInt64 x, const UInt8 byteCount, Byte *buffer, const Byte *bufferEnd)
{
    if (buffer + byteCount - 1 >= bufferEnd) {
        return false;
    }

    for (UInt8 n = 0; n < byteCount; n++) {
        buffer[n] = (Byte)(x & 0xff);
        x >>= 8;
    }

    if (x != 0) {
        // Handle overflow
        for (UInt8 n = 0; n < byteCount; n++) {
            buffer[n] = 0xff;
        }
        return 0;
    }

    return byteCount;
}

static UInt8 noz_fwrite_value(UInt64 x, const UInt8 byteCount, FILE *file)
{
    Byte buffer[8];

    UInt8 bytesWritten = noz_store_value(x, byteCount, buffer, buffer + 8);
    if (bytesWritten != byteCount) {
        return 0;
    }

    bytesWritten = (UInt8)fwrite((const char *)buffer, 1, (size_t)byteCount, file);
#if DEBUG
    fflush(file);
#endif
    return bytesWritten;
}
