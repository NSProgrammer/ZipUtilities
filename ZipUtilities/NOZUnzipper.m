//
//  NOZUnzipper.m
//  ZipUtilities
//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Nolan O'Brien
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
#import "NOZCompressionLibrary.h"
#import "NOZError.h"
#import "NOZUnzipper.h"
#import "NOZUtils_Project.h"

static BOOL noz_fread_value(FILE *file, Byte* value, const UInt8 byteCount);

#define PRIVATE_READ(file, value) noz_fread_value(file, (Byte *)&value, sizeof(value))

NOZ_OBJC_DIRECT_MEMBERS
@interface NOZCentralDirectoryRecord (/* direct declarations */)
- (NOZFileEntryT *)private_internalEntry;
- (NOZErrorCode)private_validate;
- (BOOL)private_isOwnedByCentralDirectory:(NOZCentralDirectory *)cd;
- (NSString *)private_nameNoCopy;
@end

NOZ_OBJC_DIRECT_MEMBERS
@interface NOZCentralDirectory (/* direct declarations */)
- (NSArray<NOZCentralDirectoryRecord *> *)private_internalRecords;
- (BOOL)private_readEndOfCentralDirectoryRecordAtPosition:(off_t)eocdPos inFile:(FILE*)file;
- (BOOL)private_readCentralDirectoryEntriesWithFile:(FILE*)file;
- (NOZCentralDirectoryRecord *)private_readCentralDirectoryEntryAtCurrentPositionWithFile:(FILE*)file;
- (BOOL)private_validateCentralDirectoryAndReturnError:(NSError **)error;
- (NOZCentralDirectoryRecord *)private_recordAtIndex:(NSUInteger)index;
- (NSUInteger)private_indexForRecordWithName:(NSString *)name;
@end

NOZ_OBJC_DIRECT_MEMBERS
@implementation NOZUnzipper
{
    NSString *_standardizedFilePath;
    id<NOZDecoder> _currentDecoder;
    id<NOZDecoderContext> _currentDecoderContext;

    struct {
        FILE* file;

        off_t endOfCentralDirectorySignaturePosition;
        off_t endOfFilePosition;
    } _internal;

    struct {
        off_t offsetToFirstByte;
        UInt32 crc32;
        size_t bytesDecompressed;

        NOZFileEntryT *entry;

        BOOL isUnzipping:YES;
    } _currentUnzipping;
}

-(void)dealloc
{
    [self closeAndReturnError:NULL];
}

- (instancetype)initWithZipFile:(NSString *)zipFilePath
{
    if (self = [super init]) {
        _zipFilePath = [zipFilePath copy];
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (BOOL)openAndReturnError:(out NSError **)error
{
    NSError *stackError = NOZErrorCreate(NOZErrorCodeUnzipCannotOpenZip, @{ @"zipFilePath" : [self zipFilePath] ?: [NSNull null] });
    _standardizedFilePath = [self.zipFilePath stringByStandardizingPath];
    if (_standardizedFilePath.UTF8String) {
        _internal.file = fopen(_standardizedFilePath.UTF8String, "r");
        if (_internal.file) {
            if (0 == fseeko(_internal.file, 0, SEEK_END)) {
                _internal.endOfFilePosition = ftello(_internal.file);
            } else {
                _internal.endOfFilePosition = (off_t)[[[NSFileManager defaultManager] attributesOfItemAtPath:_standardizedFilePath error:nil] fileSize];
            }
            _internal.endOfCentralDirectorySignaturePosition = [self private_locateSignature:NOZMagicNumberEndOfCentralDirectoryRecord];
            if (_internal.endOfCentralDirectorySignaturePosition) {
                return YES;
            } else {
                [self closeAndReturnError:NULL];
                stackError = NOZErrorCreate(NOZErrorCodeUnzipInvalidZipFile, @{ @"zipFilePath" : self.zipFilePath });
            }
        }
    }

    if (error) {
        *error = stackError;
    }
    return NO;
}

- (BOOL)closeAndReturnError:(out NSError **)error
{
    _centralDirectory = nil;
    if (_internal.file) {
        fclose(_internal.file);
        _internal.file = NULL;
    }
    return YES;
}

- (NOZCentralDirectory *)readCentralDirectoryAndReturnError:(out NSError * __autoreleasing * )error
{
    __block NSError *stackError = nil;
    noz_defer(^{
        if (stackError && error) {
            *error = stackError;
        }
    });

    if (!_internal.file || !_internal.endOfCentralDirectorySignaturePosition) {
        stackError = NOZErrorCreate(NOZErrorCodeUnzipMustOpenUnzipperBeforeManipulating, nil);
        return nil;
    }

    NOZCentralDirectory *cd = [[NOZCentralDirectory alloc] initWithKnownFileSize:_internal.endOfFilePosition];

    @autoreleasepool {
        if (![cd private_readEndOfCentralDirectoryRecordAtPosition:_internal.endOfCentralDirectorySignaturePosition inFile:_internal.file]) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipCannotReadCentralDirectory, nil);
            return nil;
        }

        if (![cd private_readCentralDirectoryEntriesWithFile:_internal.file]) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipCannotReadCentralDirectory, nil);
            return nil;
        }

        if (![cd private_validateCentralDirectoryAndReturnError:&stackError]) {
            return nil;
        }
    }

    _centralDirectory = cd;
    return cd;
}

- (NOZCentralDirectoryRecord *)readRecordAtIndex:(NSUInteger)index error:(out NSError **)error
{
    if (index >= _centralDirectory.recordCount) {
        if (error) {
            *error = NOZErrorCreate(NOZErrorCodeUnzipIndexOutOfBounds, nil);
        }
        return nil;
    }
    return [_centralDirectory private_recordAtIndex:index];
}

- (NSUInteger)indexForRecordWithName:(NSString *)name
{
    return (_centralDirectory) ? [_centralDirectory private_indexForRecordWithName:name] : NSNotFound;
}

- (void)enumerateManifestEntriesUsingBlock:(NOZUnzipRecordEnumerationBlock NS_NOESCAPE)block
{
    [[_centralDirectory private_internalRecords] enumerateObjectsUsingBlock:block];
}

- (BOOL)enumerateByteRangesOfRecord:(NOZCentralDirectoryRecord *)record
                      progressBlock:(NOZProgressBlock)progressBlock
                         usingBlock:(NOZUnzipByteRangeEnumerationBlock)block
                              error:(out NSError * __autoreleasing *)error
{
    __block NSError *stackError = nil;
    noz_defer(^{
        if (error && stackError) {
            *error = stackError;
        }
    });

    @autoreleasepool {
        if (!_internal.file) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipMustOpenUnzipperBeforeManipulating, nil);
            return NO;
        }

        if (![record private_isOwnedByCentralDirectory:_centralDirectory]) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipCannotReadFileEntry, nil);
            return NO;
        }

        if (![self private_locateCompressedDataOfRecord:record]) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipCannotReadFileEntry, nil);
            return NO;
        }

        do {
            NOZErrorCode code = [record private_validate];
            if (0 != code) {
                stackError = NOZErrorCreate(code, nil);
                return NO;
            }
        } while (0);

        _currentUnzipping.isUnzipping = YES;
        noz_defer(^{ self->_currentUnzipping.isUnzipping = NO; });

        _currentUnzipping.offsetToFirstByte = ftello(_internal.file);
        if (_currentUnzipping.offsetToFirstByte == -1) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipCannotReadFileEntry, nil);
            return NO;
        }

        _currentUnzipping.crc32 = 0;

        __unsafe_unretained typeof(self) rawSelf = self;
        NOZFlushCallback flushCallback = ^BOOL(id coder,
                                               id context,
                                               const Byte* bufferToFlush,
                                               size_t length) {
            if (rawSelf->_currentDecoder != coder) {
                return NO;
            }

            return [rawSelf private_flushDecompressedBytes:bufferToFlush
                                                    length:length
                                                     block:block];
        };
        _currentDecoder = [[NOZCompressionLibrary sharedInstance] decoderForMethod:[record private_internalEntry]->fileHeader.compressionMethod];
        _currentDecoderContext = [_currentDecoder createContextForDecodingWithBitFlags:[record private_internalEntry]->fileHeader.bitFlag
                                                                         flushCallback:flushCallback];

        noz_defer(^{
            self->_currentDecoder = nil;
            self->_currentDecoderContext = nil;
        });

        if (!_currentDecoder || !_currentDecoderContext) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipDecompressionMethodNotSupported, nil);
            return NO;
        }
        
        if (![_currentDecoder initializeDecoderContext:_currentDecoderContext]) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipFailedToDecompressEntry, nil);
            return NO;
        }
        
        _currentUnzipping.entry = record.private_internalEntry;
        noz_defer(^{ self->_currentUnzipping.entry = NULL; });
        
        if (![self private_deflateWithProgressBlock:progressBlock usingBlock:block error:&stackError]) {
            return NO;
        }
        
        if (![_currentDecoder finalizeDecoderContext:_currentDecoderContext]) {
            stackError = NOZErrorCreate(NOZErrorCodeUnzipFailedToDecompressEntry, nil);
            return NO;
        }
    }

    return YES;
}

- (NSData *)readDataFromRecord:(NOZCentralDirectoryRecord *)record
                 progressBlock:(NOZProgressBlock)progressBlock
                         error:(out NSError **)error
{
    __block NSMutableData *data = nil;
    if (![self enumerateByteRangesOfRecord:record
                             progressBlock:progressBlock
                                usingBlock:^(const void * __nonnull bytes,
                                             NSRange byteRange,
                                             BOOL * __nonnull stop) {
                                    if (!data) {
                                        data = [NSMutableData dataWithCapacity:byteRange.length];
                                    }
                                    [data appendBytes:bytes length:byteRange.length];
                                }
                                     error:error]) {
        data = nil;
    }

    return data;
}

- (BOOL)saveRecord:(NOZCentralDirectoryRecord *)record
       toDirectory:(NSString *)destinationRootDirectory
   shouldOverwrite:(BOOL)overwrite
     progressBlock:(NOZProgressBlock)progressBlock
             error:(out NSError **)error
{
    return [self saveRecord:record
                toDirectory:destinationRootDirectory
                    options:NOZUnzipperSaveRecordOptionOverwriteExisting
              progressBlock:progressBlock
                      error:error];
}

- (BOOL)saveRecord:(NOZCentralDirectoryRecord *)record
       toDirectory:(NSString *)destinationRootDirectory
           options:(NOZUnzipperSaveRecordOptions)options
     progressBlock:(NOZProgressBlock)progressBlock
             error:(out NSError * __autoreleasing *)error
{
    __block NSError *stackError = nil;
    noz_defer(^{
        if (stackError && error) {
            *error = stackError;
        }
    });

    destinationRootDirectory = [destinationRootDirectory stringByStandardizingPath];
    const BOOL overwrite = (options & NOZUnzipperSaveRecordOptionOverwriteExisting) != 0;
    const BOOL followIntermediatePaths = !(options & NOZUnzipperSaveRecordOptionIgnoreIntermediatePath);

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *destinationFile = nil;
    if (followIntermediatePaths) {
        destinationFile = [[destinationRootDirectory stringByAppendingPathComponent:[record private_nameNoCopy]] stringByStandardizingPath];
    } else {
        destinationFile = [[destinationRootDirectory stringByAppendingPathComponent:[record private_nameNoCopy].lastPathComponent] stringByStandardizingPath];
    }

    if (![destinationFile hasPrefix:destinationRootDirectory]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EBADF userInfo:nil];
        return NO;
    }

    if (![fm createDirectoryAtPath:[destinationFile stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:error]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EACCES userInfo:nil];
        return NO;
    }

    if (!overwrite && [fm fileExistsAtPath:destinationFile]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EEXIST userInfo:nil];
        return NO;
    }

    FILE *file = fopen(destinationFile.UTF8String, "w+");
    if (!file) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return NO;
    }

    NSDate *fileDate = noz_NSDate_from_dos_date(record.private_internalEntry->fileHeader.dosDate,
                                                record.private_internalEntry->fileHeader.dosTime);

    noz_defer(^{
        off_t offset = ftello(file);
        fclose(file);
        if (offset == 0) {
            [[NSFileManager defaultManager] removeItemAtPath:destinationFile error:NULL];
        } else if (fileDate) {
            [[NSFileManager defaultManager] setAttributes:@{ NSFileModificationDate : fileDate }
                                             ofItemAtPath:destinationFile
                                                    error:NULL];
        }
    });

    if (![self enumerateByteRangesOfRecord:record
                             progressBlock:progressBlock
                                usingBlock:^(const void * __nonnull bytes,
                                             NSRange byteRange,
                                             BOOL * __nonnull stop) {
                                    if (fwrite(bytes, 1, byteRange.length, file) != byteRange.length) {
                                        *stop = YES;
                                    } else {
#if DEBUG
                                        if ((byteRange.length + byteRange.location) == self->_currentUnzipping.entry->fileDescriptor.uncompressedSize) {
                                            fflush(file);
                                        }
#endif
                                    }
                                }
                                     error:error]) {
        return NO;
    }

    return YES;
}

- (BOOL)validateRecord:(NOZCentralDirectoryRecord *)record
         progressBlock:(NOZProgressBlock)progressBlock
                 error:(out NSError **)error
{
    return [self enumerateByteRangesOfRecord:record
                               progressBlock:progressBlock
                                  usingBlock:^(const void * __nonnull bytes,
                                               NSRange byteRange,
                                               BOOL * __nonnull stop) {
                                      (void)bytes;
                                  }
                                       error:error];
}

- (BOOL)private_flushDecompressedBytes:(const Byte *)buffer
                                length:(size_t)length
                                 block:(NOZUnzipByteRangeEnumerationBlock)block
{
    _currentUnzipping.crc32 = (UInt32)crc32(_currentUnzipping.crc32, buffer, (UInt32)length);
    _currentUnzipping.bytesDecompressed += length;

    BOOL abort = NO;
    block(buffer, NSMakeRange((NSUInteger)(_currentUnzipping.bytesDecompressed - length), (NSUInteger)length), &abort);

    return !abort;
}

- (off_t)private_locateSignature:(UInt32)signature
{
    Byte sig[4];

#if __BIG_ENDIAN__
    sig[0] = ((Byte*)(&signature))[3];
    sig[1] = ((Byte*)(&signature))[2];
    sig[2] = ((Byte*)(&signature))[1];
    sig[3] = ((Byte*)(&signature))[0];
#else
    sig[0] = ((Byte*)(&signature))[0];
    sig[1] = ((Byte*)(&signature))[1];
    sig[2] = ((Byte*)(&signature))[2];
    sig[3] = ((Byte*)(&signature))[3];
#endif

    const size_t pageSize = NOZBufferSize();
    Byte buffer[pageSize];
    size_t bytesRead = 0;
    size_t maxBytes = UINT16_MAX /* max global comment size */ + 22 /* End of Central Directory Record size */;

    if (0 != fseeko(_internal.file, 0, SEEK_END)) {
        return 0;
    }

    size_t fileSize = (size_t)ftello(_internal.file);
    if (maxBytes > fileSize) {
        maxBytes = fileSize;
    }

    while (bytesRead < maxBytes) {
        size_t sizeToRead = sizeof(buffer);
        if (sizeToRead > (maxBytes - bytesRead)) {
            sizeToRead = maxBytes - bytesRead;
        }
        if (sizeToRead < 4) {
            return 0;
        }

        off_t position = (off_t)fileSize - (off_t)bytesRead - (off_t)sizeToRead;
        if (0 != fseeko(_internal.file, position, SEEK_SET)) {
            return 0;
        }

        if (sizeToRead != fread(buffer, 1, sizeToRead, _internal.file)) {
            return 0;
        }

        const size_t bytesToRead = sizeToRead - 3;
        for (off_t i = (off_t)(bytesToRead - 1); i >= 0; i--) {
            if (buffer[i + 3] == sig[3]) {
                if (buffer[i + 2] == sig[2]) {
                    if (buffer[i + 1] == sig[1]) {
                        if (buffer[i + 0] == sig[0]) {
                            return (off_t)(position + i);
                        }
                    }
                }
            }
        }

        bytesRead += bytesToRead;
    }

    return 0;
}

- (BOOL)private_locateCompressedDataOfRecord:(NOZCentralDirectoryRecord *)record
{
    NOZFileEntryT *entry = record.private_internalEntry;
    if (!entry) {
        return NO;
    }

    if (0 != fseeko(_internal.file, entry->centralDirectoryRecord.localFileHeaderOffsetFromStartOfDisk, SEEK_SET)) {
        return NO;
    }

    UInt32 signature = 0;
    if (!PRIVATE_READ(_internal.file, signature) || signature != NOZMagicNumberLocalFileHeader) {
        return NO;
    }

    UInt16 nameSize, extraFieldSize;

    off_t seek =    2 + // versionForExtraction
                    2 + // bitFlag
                    2 + // compressionMethod
                    2 + // dosTime
                    2 + // dosDate
                    4 + // crc32
                    4 + // compressed size
                    4 + // decompressed size
                    0;

    if (0 != fseeko(_internal.file, seek, SEEK_CUR)) {
        return NO;
    }

    if (!PRIVATE_READ(_internal.file, nameSize) ||
        !PRIVATE_READ(_internal.file, extraFieldSize)) {
        return NO;
    }

    if (entry->fileHeader.nameSize != nameSize) {
        return NO;
    }

    seek = extraFieldSize + nameSize;
    if (0 != fseeko(_internal.file, seek, SEEK_CUR)) {
        return NO;
    }

    return YES;
}

- (BOOL)private_deflateWithProgressBlock:(NOZProgressBlock)progressBlock
                              usingBlock:(NOZUnzipByteRangeEnumerationBlock)block
                                   error:(out NSError * __autoreleasing *)error
{
    __block BOOL success = YES;
    noz_defer(^{
        if (!success && error && !*error) {
            *error = NOZErrorCreate(NOZErrorCodeUnzipCannotDecompressFileEntry, nil);
        }
    });

    const size_t pageSize = NOZBufferSize();
    Byte compressedBuffer[pageSize];
    size_t compressedBufferSize = sizeof(compressedBuffer);

    BOOL stop = NO;
    const SInt64 compressedBytesTotal = _currentUnzipping.entry->fileDescriptor.compressedSize;
    SInt64 compressedBytesLeft = compressedBytesTotal;

    while (!stop && !_currentDecoderContext.hasFinished) {

        if ((size_t)compressedBytesLeft < compressedBufferSize) {
            compressedBufferSize = (size_t)compressedBytesLeft;
        }

        if (compressedBufferSize != fread(compressedBuffer, 1, compressedBufferSize, _internal.file)) {
            success = NO;
            return NO;
        }
        compressedBytesLeft -= compressedBufferSize;

        const BOOL decoded = [_currentDecoder decodeBytes:compressedBuffer
                                                   length:compressedBufferSize
                                                  context:_currentDecoderContext];
        if (!decoded) {
            success = NO;
            return NO;
        }

        if (progressBlock) {
            BOOL progressStop = NO;
            progressBlock(compressedBytesTotal,
                          compressedBytesTotal - compressedBytesLeft,
                          (SInt64)compressedBufferSize,
                          &progressStop);
            if (progressStop) {
                stop = YES;
            }
        }

    } // while (...)

    if (stop) {
        success = NO;
        return NO;
    }

    if (_currentUnzipping.crc32 != _currentUnzipping.entry->fileDescriptor.crc32) {
        success = NO;
        if (error) {
            *error = NOZErrorCreate(NOZErrorCodeUnzipChecksumMissmatch, nil);
        }

        return NO;
    }

    return YES;
}

@end

NOZ_OBJC_DIRECT_MEMBERS
@implementation NOZCentralDirectory
{
    off_t _endOfCentralDirectoryRecordPosition;
    NOZEndOfCentralDirectoryRecordT _endOfCentralDirectoryRecord;

    NSArray<NOZCentralDirectoryRecord *> *_records;
    off_t _lastCentralDirectoryRecordEndPosition; // exclusive
}

- (void)dealloc
{
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithKnownFileSize:(SInt64)fileSize
{
    if (self = [super init]) {
        _totalCompressedSize = fileSize;
    }
    return self;
}

- (NSUInteger)recordCount
{
    return _records.count;
}

- (BOOL)private_readEndOfCentralDirectoryRecordAtPosition:(off_t)eocdPos inFile:(FILE*)file
{
    if (!file) {
        return NO;
    }

    if (fseeko(file, eocdPos, SEEK_SET) != 0) {
        return NO;
    }

    UInt32 signature = 0;
    if (!PRIVATE_READ(file, signature) || NOZMagicNumberEndOfCentralDirectoryRecord != signature) {
        return NO;
    }

    if (!PRIVATE_READ(file, _endOfCentralDirectoryRecord.diskNumber) ||
        !PRIVATE_READ(file, _endOfCentralDirectoryRecord.startDiskNumber) ||
        !PRIVATE_READ(file, _endOfCentralDirectoryRecord.recordCountForDisk) ||
        !PRIVATE_READ(file, _endOfCentralDirectoryRecord.totalRecordCount) ||
        !PRIVATE_READ(file, _endOfCentralDirectoryRecord.centralDirectorySize) ||
        !PRIVATE_READ(file, _endOfCentralDirectoryRecord.archiveStartToCentralDirectoryStartOffset) ||
        !PRIVATE_READ(file, _endOfCentralDirectoryRecord.commentSize)) {
        return NO;
    }

    if (_endOfCentralDirectoryRecord.commentSize) {
        unsigned char* commentBuffer = malloc(_endOfCentralDirectoryRecord.commentSize + 1);
        if (_endOfCentralDirectoryRecord.commentSize == fread(commentBuffer, 1, _endOfCentralDirectoryRecord.commentSize, file)) {
            commentBuffer[_endOfCentralDirectoryRecord.commentSize] = '\0';
            _globalComment = [[NSString alloc] initWithUTF8String:(const char *)commentBuffer];
        }
        free(commentBuffer);
    }

    _endOfCentralDirectoryRecordPosition = eocdPos;
    return YES;
}

- (BOOL)private_readCentralDirectoryEntriesWithFile:(FILE *)file
{
    if (!file || !_endOfCentralDirectoryRecordPosition) {
        return NO;
    }

    if (0 != fseeko(file, _endOfCentralDirectoryRecord.archiveStartToCentralDirectoryStartOffset, SEEK_SET)) {
        return NO;
    }

    NSMutableArray<NOZCentralDirectoryRecord *> *records = [NSMutableArray arrayWithCapacity:_endOfCentralDirectoryRecord.totalRecordCount];
    while (_endOfCentralDirectoryRecordPosition > ftello(file)) {
        NOZCentralDirectoryRecord *record = [self private_readCentralDirectoryEntryAtCurrentPositionWithFile:file];
        if (record) {
            [records addObject:record];
        } else {
            break;
        }
    }

    _records = [records copy];
    return YES;
}

- (NOZCentralDirectoryRecord *)private_readCentralDirectoryEntryAtCurrentPositionWithFile:(FILE *)file
{
    UInt32 signature = 0;
    if (!PRIVATE_READ(file, signature) || signature != NOZMagicNumberCentralDirectoryFileRecord) {
        return nil;
    }

    NOZCentralDirectoryRecord *record = [[NOZCentralDirectoryRecord alloc] initWithOwner:self];
    NOZFileEntryT* entry = record.private_internalEntry;

    if (!PRIVATE_READ(file, entry->centralDirectoryRecord.versionMadeBy) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->versionForExtraction) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->bitFlag) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->compressionMethod) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->dosTime) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->dosDate) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->fileDescriptor->crc32) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->fileDescriptor->compressedSize) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->fileDescriptor->uncompressedSize) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->nameSize) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileHeader->extraFieldSize) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.commentSize) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.fileStartDiskNumber) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.internalFileAttributes) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.externalFileAttributes) ||
        !PRIVATE_READ(file, entry->centralDirectoryRecord.localFileHeaderOffsetFromStartOfDisk) ||
        entry->centralDirectoryRecord.fileHeader->nameSize == 0) {
        return nil;
    }

    entry->name = malloc(entry->centralDirectoryRecord.fileHeader->nameSize + 1);
    ((Byte*)entry->name)[entry->centralDirectoryRecord.fileHeader->nameSize] = '\0';
    entry->ownsName = YES;
    if (entry->centralDirectoryRecord.fileHeader->nameSize != fread((Byte*)entry->name, 1, entry->centralDirectoryRecord.fileHeader->nameSize, file)) {
        return nil;
    }

    if (entry->centralDirectoryRecord.fileHeader->extraFieldSize > 0) {
        if (0 != fseeko(file, entry->centralDirectoryRecord.fileHeader->extraFieldSize, SEEK_CUR)) {
            return nil;
        }
    }

    if (entry->centralDirectoryRecord.commentSize > 0) {
        entry->comment = malloc(entry->centralDirectoryRecord.commentSize + 1);
        ((Byte*)entry->comment)[entry->centralDirectoryRecord.commentSize] = '\0';
        entry->ownsComment = YES;
        if (entry->centralDirectoryRecord.commentSize != fread((Byte*)entry->comment, 1, entry->centralDirectoryRecord.commentSize, file)) {
            return nil;
        }
    }

    _totalUncompressedSize += record.uncompressedSize;
    _lastCentralDirectoryRecordEndPosition = ftello(file);
    return record;
}

- (NOZCentralDirectoryRecord *)private_recordAtIndex:(NSUInteger)index
{
    return [_records objectAtIndex:index];
}

- (NSUInteger)private_indexForRecordWithName:(NSString *)name
{
    __block NSUInteger index = NSNotFound;
    [_records enumerateObjectsUsingBlock:^(NOZCentralDirectoryRecord *record, NSUInteger idx, BOOL *stop) {
        if ([name isEqualToString:[record private_nameNoCopy]]) {
            index = idx;
            *stop = YES;
        }
    }];
    return index;
}

- (NSArray<NOZCentralDirectoryRecord *> *)private_internalRecords
{
    return _records;
}

- (BOOL)private_validateCentralDirectoryAndReturnError:(NSError * __autoreleasing *)error
{
    __block NOZErrorCode code = 0;
    __block NSDictionary *userInfo = nil;
    noz_defer(^{
        if (code && error) {
            *error = NOZErrorCreate(code, userInfo);
        }
    });

    if (_endOfCentralDirectoryRecord.diskNumber != 0) {
        code = NOZErrorCodeUnzipMultipleDiskZipArchivesNotSupported;
        return NO;
    }

    if (0 == _records.count) {
        code = NOZErrorCodeUnzipCouldNotReadCentralDirectoryRecord;
        return NO;
    }

    if (_records.count != _endOfCentralDirectoryRecord.totalRecordCount) {
        code = NOZErrorCodeUnzipCentralDirectoryRecordCountsDoNotAlign;
        userInfo = @{ @"expectedCount" : @(_endOfCentralDirectoryRecord.totalRecordCount), @"actualCount" : @(_records.count) };
        return NO;
    }

    if (_endOfCentralDirectoryRecordPosition != _lastCentralDirectoryRecordEndPosition) {
        code = NOZErrorCodeUnzipCentralDirectoryRecordsDoNotCompleteWithEOCDRecord;
        return NO;
    }

    return YES;
}

@end

NOZ_OBJC_DIRECT_MEMBERS
@implementation NOZCentralDirectoryRecord
{
    NOZFileEntryT _entry;
    __unsafe_unretained NOZCentralDirectory *_owner;
}

- (void)dealloc
{
    NOZFileEntryClean(&_entry);
}

- (instancetype)initWithOwner:(NOZCentralDirectory *)cd
{
    if (self = [super init]) {
        NOZFileEntryInit(&_entry);
        _owner = cd;
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (NSString *)private_nameNoCopy
{
    return [[NSString alloc] initWithBytesNoCopy:(void *)_entry.name
                                          length:_entry.fileHeader.nameSize
                                        encoding:NSUTF8StringEncoding
                                    freeWhenDone:NO];
}

- (NSString *)name
{
    return [[NSString alloc] initWithBytes:_entry.name
                                    length:_entry.fileHeader.nameSize
                                  encoding:NSUTF8StringEncoding];
}

- (NSString *)comment
{
    if (!_entry.comment) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:_entry.comment
                                    length:_entry.centralDirectoryRecord.commentSize
                                  encoding:NSUTF8StringEncoding];
}

- (NOZCompressionLevel)compressionLevel
{
    UInt16 bitFlag = _entry.fileHeader.bitFlag;
    if (bitFlag & NOZFlagBitsSuperFastDeflate) {
        return NOZCompressionLevelMin;
    } else if (bitFlag & NOZFlagBitsFastDeflate) {
        return (2.f / 9.f);
    } else if (bitFlag & NOZFlagBitsMaxDeflate) {
        return NOZCompressionLevelMax;
    }
    return NOZCompressionLevelDefault;
}

- (NOZCompressionMethod)compressionMethod
{
    return _entry.fileHeader.compressionMethod;
}

- (SInt64)compressedSize
{
    return _entry.fileDescriptor.compressedSize;
}

- (SInt64)uncompressedSize
{
    return _entry.fileDescriptor.uncompressedSize;
}

- (id)copyWithZone:(NSZone *)zone
{
    NOZCentralDirectoryRecord *record = [[[self class] allocWithZone:zone] init];
    record->_entry.fileDescriptor = _entry.fileDescriptor;
    record->_entry.fileHeader = _entry.fileHeader;
    record->_entry.centralDirectoryRecord = _entry.centralDirectoryRecord;

    if (_entry.name) {
        record->_entry.name = malloc(_entry.fileHeader.nameSize + 1);
        memcpy((Byte *)record->_entry.name, _entry.name, _entry.fileHeader.nameSize + 1);
        record->_entry.ownsName = YES;
    }

    if (_entry.extraField) {
        record->_entry.extraField = malloc(_entry.fileHeader.extraFieldSize + 1);
        memcpy((Byte *)record->_entry.extraField, _entry.extraField, _entry.fileHeader.extraFieldSize + 1);
        record->_entry.ownsExtraField = YES;
    }

    if (_entry.comment) {
        record->_entry.comment = malloc(_entry.centralDirectoryRecord.commentSize + 1);
        memcpy((Byte *)record->_entry.comment, _entry.comment, _entry.centralDirectoryRecord.commentSize + 1);
        record->_entry.ownsComment = YES;
    }

    return record;
}

#pragma mark Internal

- (BOOL)private_isOwnedByCentralDirectory:(NOZCentralDirectory *)cd
{
    return (cd != nil) && (cd == _owner);
}

- (NOZFileEntryT *)private_internalEntry
{
    return &_entry;
}

- (NOZErrorCode)private_validate
{
    if (self.isZeroLength || self.isMacOSXAttribute || self.isMacOSXDSStore) {
        return 0;
    }

    if ((_entry.centralDirectoryRecord.fileHeader->versionForExtraction & 0x00ff) > (NOZVersionForExtraction & 0x00ff)) {
        return NOZErrorCodeUnzipUnsupportedRecordVersion;
    }
    if ((_entry.centralDirectoryRecord.fileHeader->bitFlag & 0b01)) {
        return NOZErrorCodeUnzipDecompressionEncryptionNotSupported;
    }

    return 0;
}

@end

@implementation NOZCentralDirectoryRecord (Attributes)

- (BOOL)isZeroLength
{
    return (_entry.centralDirectoryRecord.fileHeader->fileDescriptor->compressedSize == 0);
}

- (BOOL)isMacOSXAttribute
{
    NSArray<NSString *> *components = [[self private_nameNoCopy] pathComponents];
    if ([components containsObject:@"__MACOSX"]) {
        return YES;
    }
    return NO;
}

- (BOOL)isMacOSXDSStore
{
    if ([[self private_nameNoCopy].lastPathComponent isEqualToString:@".DS_Store"]) {
        return YES;
    }
    return NO;
}

@end

static BOOL noz_fread_value(FILE *file, Byte* value, const UInt8 byteCount)
{
    for (size_t i = 0; i < byteCount; i++) {

#if __BIG_ENDIAN__
        size_t bytesRead = fread(value + (byteCount - 1 - i), 1, 1, file);
#else
        size_t bytesRead = fread(value + i, 1, 1, file);
#endif
        if (bytesRead != 1) {
            return NO;
        }
    }
    return YES;
}
