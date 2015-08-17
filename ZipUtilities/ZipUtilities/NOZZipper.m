//
//  NOZZipper.m
//  ZipUtilities
//
//  Copyright (c) 2015 Nolan O'Brien.
//

#import "NOZ_Project.h"
#import "NOZError.h"
#import "NOZZipper.h"

#include "zlib.h"

static UInt8 noz_fwrite_value(UInt64 x, const UInt8 byteCount, FILE *file);
static UInt8 noz_store_value(UInt64 x, const UInt8 byteCount, Byte *buffer, const Byte *bufferEnd);

#define PRIVATE_WRITE(v) \
noz_fwrite_value((v), sizeof(v), _internal.file)

static void noz_dos_date_from_NSDate(NSDate *__nonnull dateObj, UInt16* __nonnull dateOut, UInt16* __nonnull timeOut);

static const UInt32 NOZMagicNumberLocalFileHeader               = 0x04034b50;
static const UInt32 NOZMagicNumberDataDescriptor                = 0x08074b50;
static const UInt32 NOZMagicNumberCentralDirectoryFileRecord    = 0x02014b50;
static const UInt32 NOZMagicNumberEndOfCentralDirectoryRecord   = 0x06054b50;

static const UInt32 NOZVersionForCreation   = 20; // Zip 2.0
static const UInt32 NOZVersionForExtraction = 20; // Zip 2.0

static const UInt16 NOZFlagBitsNormalDeflate    = 0b000000;
static const UInt16 NOZFlagBitsMaxDeflate       = 0b000010;
static const UInt16 NOZFlagBitsFastDeflate      = 0b000100;
static const UInt16 NOZFlagBitsSuperFastDeflate = 0b000110;
static const UInt16 NOZFlagBitUseDescriptor     = 0b001000;

typedef struct _NOZLocalFileDescriptorT
{
    // Optionally starts with NOZMagicNumberDataDescriptor

    UInt32 crc32;
    UInt32 compressedSize;
    UInt32 uncompressedSize;
} NOZLocalFileDescriptorT;

typedef struct _NOZLocalFileHeaderT
{
    // starts with NOZMagicNumberLocalFileHeader

    UInt16 versionForExtraction;
    UInt16 bitFlag;
    UInt16 compressionMethod;
    UInt16 dosTime;
    UInt16 dosDate;
    NOZLocalFileDescriptorT *fileDescriptor;
    UInt16 nameSize;
    UInt16 extraFieldSize;

    // ends with:
    // const Byte* name;
    // const Byte* extraField;
} NOZLocalFileHeaderT;

typedef struct _NOZCentralDirectoryFileRecordT
{
    // Starts with NOZMagicNumberCentralDirectoryFileRecord

    UInt16 versionMadeBy;
    NOZLocalFileHeaderT *fileHeader;
    UInt16 commentSize;
    UInt16 fileStartDiskNumber;
    UInt16 internalFileAttributes;
    UInt32 externalFileAttributes;
    UInt32 localFileHeaderOffsetFromStartOfDisk;

    // ends with:
    // const Byte* name;
    // const Byte* extraField;
    // const Byte* fileComment;
} NOZCentralDirectoryFileRecordT;

typedef struct _NOZEndOfCentralDirectoryRecordT
{
    // starts with NOZMagicNumberEndOfCentralDirectoryRecord

    UInt16 diskNumber;
    UInt16 startDiskNumber;
    UInt16 recordCountForDisk;
    UInt16 totalRecordCount;
    UInt32 centralDirectorySize;
    UInt32 archiveStartToCentralDirectoryStartOffset;
    UInt16 commentSize;

    // ends with:
    // const Byte* comment
} NOZEndOfCentralDirectoryRecordT;

typedef struct _NOZFileEntryT
{
    NOZLocalFileDescriptorT fileDescriptor;
    NOZLocalFileHeaderT fileHeader;
    NOZCentralDirectoryFileRecordT centralDirectoryRecord;
    const Byte* name;
    const Byte* extraField;
    const Byte* comment;

    struct _NOZFileEntryT *nextEntry;

    BOOL ownsName:1;
    BOOL ownsExtraField:1;
    BOOL ownsComment:1;
} NOZFileEntryT;

static NOZFileEntryT* NOZFileEntryAlloc();
static void NOZFileEntryFree(NOZFileEntryT* entry);

typedef struct _NOZCurrentEntryInfoT
{
    // structure of current entry
    NOZFileEntryT *entry;

    // zlib
    z_stream zStream;
    Byte compressedDataBuffer[NOZPageSize];
    UInt32 compressedDataBufferPosition;

    // Encryption
    uLong keys[3];
    const uLong* crc32Table;
    UInt32 cryptHeaderSize;

    // Flags
    BOOL isOpen:1;
    BOOL isZStreamOpen:1;

} NOZCurrentEntryInfoT;

NS_INLINE NSError * __nonnull NOZZipError(NOZErrorCode code, NSDictionary * __nullable ui)
{
    return [NSError errorWithDomain:NOZErrorDomain code:code userInfo:ui];
}

@interface NOZZipper (Private)

// Top level methods
- (BOOL)private_forciblyClose:(BOOL)forceClose error:(out NSError * __nullable * __nullable)error;

// Entry methods
- (BOOL)private_openEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry
                    error:(out NSError * __nullable * __nullable)error;
- (BOOL)private_writeEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry
             progressBlock:(nullable NOZProgressBlock)progressBlock
                     error:(out NSError * __nullable * __nullable)error
                  abortRef:(nonnull BOOL *)abort;
- (BOOL)private_closeCurrentOpenEntryAndReturnError:(out NSError * __nullable * __nullable)error;

// Helpers
- (BOOL)private_prepareCurrentEntryZStream:(NOZCompressionLevel)compressionLevel;
- (BOOL)private_finishDeflate;
- (BOOL)private_flushWriteBuffer;
- (void)private_freeLinkedList;

// Records
- (BOOL)private_populateRecordsForCurrentOpenEntryWithEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry error:(out NSError * __nullable * __nullable)error;
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

    struct {
        FILE *file;

        NOZFileEntryT *firstEntry;
        NOZFileEntryT *lastEntry;

        SInt64 beginBytePosition;
        SInt64 writingPositionOffset;

        NOZCurrentEntryInfoT currentEntryInfo;
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

        bzero(&_internal.currentEntryInfo, sizeof(NOZCurrentEntryInfoT));
        _internal.beginBytePosition = 0;
        _internal.writingPositionOffset = 0;
        _internal.firstEntry = _internal.lastEntry = NULL;
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
        stackError = NOZZipError(NOZErrorCodeZipInvalidFilePath, _zipFilePath ? @{ @"zipFilePath" : _zipFilePath } : nil);
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
//                stackError = NOZZipError(NOZErrorCodeZipCannotOpenExistingZip, @{ @"zipFilePath" : _zipFilePath });
//                return NO;
//            }
//            break;
//        }
        case NOZZipperModeCreate:
        default:
        {
            if ([fm fileExistsAtPath:_standardizedZipFilePath]) {
                stackError = NOZZipError(NOZErrorCodeZipCannotCreateZip, @{ @"zipFilePath" : _zipFilePath });
                return NO;
            }
            break;
        }
    }

    _internal.file = fopen(_standardizedZipFilePath.UTF8String, fopenMode);
    if (!_internal.file) {
        // stackError = NOZZipError((NOZZipperModeOpenExisting == mode) ? NOZErrorCodeZipCannotOpenExistingZip : NOZErrorCodeZipCannotCreateZip, @{ @"zipFilePath" : _zipFilePath });
        stackError = NOZZipError(NOZErrorCodeZipCannotCreateZip, @{ @"zipFilePath" : _zipFilePath });
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

- (BOOL)addEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry
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
    } else if (!forceClose && _internal.currentEntryInfo.isOpen) {
        stackError = NOZZipError(NOZErrorCodeZipFailedToCloseCurrentEntry, nil);
        return NO;
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
        stackError = NOZZipError(NOZErrorCodeZipFailedToWriteZip, nil);
        return NO;
    }

    if (![self private_writeEndOfCentralDirectoryRecord]) {
        stackError = NOZZipError(NOZErrorCodeZipFailedToWriteZip, nil);
        return NO;
    }

    return YES;
}

- (BOOL)private_openEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry
                    error:(out NSError * __nullable * __nullable)error
{
    __block BOOL errorEncountered = NO;
    noz_defer(^{ if (errorEncountered && error) { *error = NOZZipError(NOZErrorCodeZipCannotOpenNewEntry, nil); } });

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

    NOZFileEntryT *newEntry = NOZFileEntryAlloc();
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
    _internal.currentEntryInfo.entry = newEntry;

    if (![self private_populateRecordsForCurrentOpenEntryWithEntry:entry error:error]) {
        return NO;
    }

    if (![self private_writeLocalFileHeaderForCurrentEntryAndReturnError:error]) {
        return NO;
    }

    if (![self private_prepareCurrentEntryZStream:entry.compressionLevel]) {
        errorEncountered = YES;
        return NO;
    }

    _internal.currentEntryInfo.isOpen = YES;
    return YES;
}

- (BOOL)private_writeEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry
             progressBlock:(nullable NOZProgressBlock)progressBlock
                     error:(out NSError * __nullable * __nullable)error
                  abortRef:(nonnull BOOL *)abort
{
    __block BOOL success = YES;
    noz_defer(^{
        if (error) {
            if ((*abort)) {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ECANCELED userInfo:nil];
            } else if (!success) {
                *error = NOZZipError(NOZErrorCodeZipFailedToWriteEntry, nil);
            }
        }
    });

    if (success && (!_internal.currentEntryInfo.isOpen || !entry.inputStream)) {
        success = NO;
        return NO;
    }

    const SInt64 totalBytes = entry.sizeInBytes;
    SInt64 totalBytesRead = 0;
    if (success) {
        NSInputStream *inputStream = entry.inputStream;
        [inputStream open];
        noz_defer(^{ [inputStream close]; });
        NSInteger bytesRead;
        Byte buffer[NOZPageSize];

        do {
            bytesRead = [inputStream read:buffer maxLength:NOZPageSize];

            if (bytesRead < 0) {
                success = NO;
                break;
            }

            _internal.currentEntryInfo.entry->fileDescriptor.crc32 = (UInt32)crc32(_internal.currentEntryInfo.entry->fileDescriptor.crc32, buffer, (UInt32)bytesRead);

            _internal.currentEntryInfo.zStream.next_in = buffer;
            _internal.currentEntryInfo.zStream.avail_in = (UInt32)bytesRead;

            while (success && _internal.currentEntryInfo.zStream.avail_in > 0 && !(*abort)) {
                if (_internal.currentEntryInfo.zStream.avail_out == 0) {
                    if (![self private_flushWriteBuffer]) {
                        success = NO;
                    }
                    _internal.currentEntryInfo.zStream.avail_out = NOZPageSize;
                    _internal.currentEntryInfo.zStream.next_out = _internal.currentEntryInfo.compressedDataBuffer;
                }

                if (!success) {
                    break;
                }

                uLong previousTotalIn = _internal.currentEntryInfo.zStream.total_in;
                uLong previousTotalOut = _internal.currentEntryInfo.zStream.total_out;
                success = deflate(&_internal.currentEntryInfo.zStream, Z_NO_FLUSH) == Z_OK;
                if (previousTotalOut > _internal.currentEntryInfo.zStream.total_out) {
                    success = NO;
                } else {
                    _internal.currentEntryInfo.compressedDataBufferPosition += (UInt32)(_internal.currentEntryInfo.zStream.total_out - previousTotalOut);
                }
                uLong additionalBytesRead = _internal.currentEntryInfo.zStream.total_in - previousTotalIn;
                if (additionalBytesRead != 0) {
                    totalBytesRead += additionalBytesRead;
                    if (progressBlock) {
                        progressBlock(totalBytes, totalBytesRead, (SInt64)additionalBytesRead, abort);
                    }
                }
            } // endwhile
        } while (bytesRead == NOZPageSize && !(*abort));
    }

    return success;
}

- (BOOL)private_closeCurrentOpenEntryAndReturnError:(out NSError * __nullable * __nullable)error
{
    if (!_internal.currentEntryInfo.isOpen) {
        return YES;
    }

    BOOL success = YES;

    if (success) {
        success = [self private_finishDeflate];
    }

#if 0
    if (success) {
        success = [self private_writeCurrentLocalFileDescriptor:YES];
    }
#endif

    _internal.endOfCentralDirectoryRecord.totalRecordCount++;
    _internal.endOfCentralDirectoryRecord.recordCountForDisk++;
    _internal.currentEntryInfo.isOpen = NO;
    _internal.currentEntryInfo.entry = NULL;

    if (!success && error) {
        *error = NOZZipError(NOZErrorCodeZipFailedToCloseCurrentEntry, nil);
    }
    
    return success;
}

- (void)private_freeLinkedList
{
    NOZFileEntryFree(_internal.firstEntry);
    _internal.firstEntry = _internal.lastEntry = NULL;
}

- (BOOL)private_flushWriteBuffer
{
    if (0 == _internal.currentEntryInfo.compressedDataBufferPosition) {
        return YES;
    }

    BOOL success = YES;

    size_t bytesWritten = fwrite(_internal.currentEntryInfo.compressedDataBuffer,
                                 1,
                                 _internal.currentEntryInfo.compressedDataBufferPosition,
                                 _internal.file);
    if (bytesWritten != _internal.currentEntryInfo.compressedDataBufferPosition) {
        success = NO;
    }

    _internal.currentEntryInfo.entry->fileDescriptor.compressedSize += bytesWritten;
    _internal.currentEntryInfo.entry->fileDescriptor.uncompressedSize += _internal.currentEntryInfo.zStream.total_in;
    _internal.currentEntryInfo.zStream.total_in = 0;

    _internal.currentEntryInfo.compressedDataBufferPosition = 0;
    
    return success;
}

- (BOOL)private_populateRecordsForCurrentOpenEntryWithEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry error:(out NSError * __nullable * __nullable)error
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
            *error = NOZZipError(NOZErrorCodeZipCannotOpenNewEntry, nil);
        }
        return NO;
    }

    if (entry.sizeInBytes > UINT32_MAX || (ftello(_internal.file) - _internal.beginBytePosition) > (UINT32_MAX - UINT8_MAX)) {
        if (error) {
            *error = NOZZipError(NOZErrorCodeZipDoesNotSupportZip64, nil);
        }
        return NO;
    }

    NOZCentralDirectoryFileRecordT *record = &_internal.currentEntryInfo.entry->centralDirectoryRecord;

    /* File Record info */
    {
        record->versionMadeBy = NOZVersionForCreation;

        /* File Header info */
        {
            record->fileHeader->versionForExtraction = NOZVersionForExtraction;

            /* Bit Flag */
            {
                record->fileHeader->bitFlag = 0;
                switch (entry.compressionLevel) {
                    case 9:
                    case 8:
                        record->fileHeader->bitFlag |= NOZFlagBitsMaxDeflate;
                        break;
                    case 2:
                        record->fileHeader->bitFlag |= NOZFlagBitsFastDeflate;
                        break;
                    case 1:
                        record->fileHeader->bitFlag |= NOZFlagBitsSuperFastDeflate;
                        break;
                    default:
                        record->fileHeader->bitFlag |= NOZFlagBitsNormalDeflate;
                        break;
                }
            }

            record->fileHeader->compressionMethod = Z_DEFLATED;
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
        _internal.currentEntryInfo.entry->name = (const Byte*)malloc(nameSize);
        memcpy((void *)_internal.currentEntryInfo.entry->name, entry.name.UTF8String, nameSize);
        _internal.currentEntryInfo.entry->ownsName = YES;
    }
    _internal.currentEntryInfo.entry->extraField = NULL;
    _internal.currentEntryInfo.entry->ownsName = NO;
    if (commentSize > 0) {
        _internal.currentEntryInfo.entry->comment = (const Byte*)malloc(commentSize);
        memcpy((void *)_internal.currentEntryInfo.entry->comment, entry.comment.UTF8String, commentSize);
        _internal.currentEntryInfo.entry->ownsName = YES;
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
    NOZFileEntryT *entry = _internal.currentEntryInfo.entry;

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
        *error = NOZZipError(NOZErrorCodeZipCannotOpenNewEntry, nil);
    }

    return success;
}

- (BOOL)private_prepareCurrentEntryZStream:(NOZCompressionLevel)compressionLevel
{
    _internal.currentEntryInfo.zStream.avail_in = 0;
    _internal.currentEntryInfo.zStream.avail_out = NOZPageSize;
    _internal.currentEntryInfo.zStream.next_out = _internal.currentEntryInfo.compressedDataBuffer;
    _internal.currentEntryInfo.zStream.total_in = 0;
    _internal.currentEntryInfo.zStream.total_out = 0;
    _internal.currentEntryInfo.zStream.data_type = Z_BINARY;
    _internal.currentEntryInfo.zStream.zalloc = NULL;
    _internal.currentEntryInfo.zStream.zfree = NULL;
    _internal.currentEntryInfo.zStream.opaque = NULL;

    if (Z_OK != deflateInit2(&(_internal.currentEntryInfo.zStream),
                             compressionLevel,
                             Z_DEFLATED,
                             -MAX_WBITS,
                             8 /* default memory level */,
                             Z_DEFAULT_STRATEGY)) {
        return NO;
    }

    _internal.currentEntryInfo.isZStreamOpen = 1;
    return YES;
}

- (BOOL)private_finishDeflate
{
    if (!_internal.currentEntryInfo.isZStreamOpen) {
        return NO;
    }

    BOOL success = YES;
    BOOL finishedDeflate = NO;
    _internal.currentEntryInfo.zStream.avail_in = 0;
    while (success && !finishedDeflate) {
        uLong previousTotalOut;
        if (_internal.currentEntryInfo.zStream.avail_out == 0) {
            if (![self private_flushWriteBuffer]) {
                success = NO;
            }
            _internal.currentEntryInfo.zStream.avail_out = NOZPageSize;
            _internal.currentEntryInfo.zStream.next_out = _internal.currentEntryInfo.compressedDataBuffer;
        }

        previousTotalOut = _internal.currentEntryInfo.zStream.total_out;
        if (success) {
            int err = deflate(&_internal.currentEntryInfo.zStream, Z_FINISH);
            if (err != Z_OK) {
                if (err == Z_STREAM_END) {
                    finishedDeflate = YES;
                } else {
                    success = NO;
                }
            }
        }
        _internal.currentEntryInfo.compressedDataBufferPosition += _internal.currentEntryInfo.zStream.total_out - previousTotalOut;
    }

    if (success && _internal.currentEntryInfo.compressedDataBufferPosition > 0) {
        success = [self private_flushWriteBuffer];
    }

    do {
        if (_internal.currentEntryInfo.zStream.data_type == Z_ASCII) {
            _internal.currentEntryInfo.entry->centralDirectoryRecord.internalFileAttributes = Z_ASCII;
        }
        int err = deflateEnd(&_internal.currentEntryInfo.zStream);
        if (success) {
            success = (err == Z_OK);
        }
        _internal.currentEntryInfo.isZStreamOpen = NO;
    } while (0);

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
    return [self private_writeLocalFileDescriptorForEntry:_internal.currentEntryInfo.entry signature:writeSignature];
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

    if (0 == fseeko(_internal.file, _internal.beginBytePosition + record->localFileHeaderOffsetFromStartOfDisk + 14, SEEK_SET)) {
        [self private_writeLocalFileDescriptorForEntry:entry signature:NO];
    }
    fseeko(_internal.file, 0, SEEK_END);

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

static void noz_dos_date_from_NSDate(NSDate *__nullable dateObject, UInt16* dateOut, UInt16* timeOut)
{
    if (!dateObject) {
        *dateOut = 0;
        *timeOut = 0;
        return;
    }

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents* components = [gregorianCalendar components:   NSCalendarUnitYear |
                                                                    NSCalendarUnitMonth |
                                                                    NSCalendarUnitDay |
                                                                    NSCalendarUnitHour |
                                                                    NSCalendarUnitMinute |
                                                                    NSCalendarUnitSecond
                                                        fromDate:dateObject];

    UInt16 date;
    UInt16 time;

    UInt16 years = (UInt16)components.year;
    if (years >= 1980) {
        years -= 1980;
    }
    if (years > 0b01111111) {
        years = 0b01111111;
    }
    UInt16 months = (UInt16)components.month;
    UInt16 days = (UInt16)components.day;
    date = (UInt16)((years << 9) | (months << 5) | (days << 0));

    UInt16 hours = (UInt16)components.hour;
    UInt16 mins = (UInt16)components.minute;
    UInt16 secs = (UInt16)components.second >> 2;  // cut seconds in half

    time = (UInt16)((hours <<  11) | (mins << 5) | (secs << 0));

    *dateOut = date;
    *timeOut = time;
}

static NOZFileEntryT* NOZFileEntryAlloc()
{
    NOZFileEntryT *entry = (NOZFileEntryT *)malloc(sizeof(NOZFileEntryT));
    if (entry) {
        bzero(entry, sizeof(NOZFileEntryT));

        entry->centralDirectoryRecord.versionMadeBy = NOZVersionForCreation;
        entry->centralDirectoryRecord.fileHeader = &entry->fileHeader;

        entry->fileHeader.bitFlag = NOZFlagBitUseDescriptor;
        entry->fileHeader.compressionMethod = Z_DEFLATED;
        entry->fileHeader.versionForExtraction = NOZVersionForExtraction;
        entry->fileHeader.fileDescriptor = &entry->fileDescriptor;
    }
    return entry;
}

static void NOZFileEntryFree(NOZFileEntryT* entry)
{
    while (entry) {
        NOZFileEntryT* nextEntry = entry->nextEntry;

        if (entry->ownsName) {
            free((void*)entry->name);
        }
        if (entry->ownsExtraField) {
            free((void*)entry->extraField);
        }
        if (entry->ownsComment) {
            free((void*)entry->comment);
        }

        free(entry);

        entry = nextEntry;
    }
}
