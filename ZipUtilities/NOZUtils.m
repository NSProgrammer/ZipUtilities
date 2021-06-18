//
//  NOZUtils.m
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
#import "NOZUtils_Project.h"
#include "zlib.h"

static BOOL _NOZOpenInputOutputFiles(NSString * __nonnull sourceFilePath,
                                     FILE * __nullable * __nonnull sourceFile,
                                     NSString * __nonnull destinationFilePath,
                                     FILE * __nonnull * __nullable destinationFile,
                                     NSError * __autoreleasing __nullable * __nullable error);

void NOZFileEntryInit(NOZFileEntryT* entry)
{
    if (entry) {
        bzero(entry, sizeof(NOZFileEntryT));

        entry->centralDirectoryRecord.versionMadeBy = NOZVersionForCreation;
        entry->centralDirectoryRecord.fileHeader = &entry->fileHeader;

        entry->fileHeader.bitFlag = NOZFlagBitsFileMetadataInDescriptor;
        entry->fileHeader.compressionMethod = Z_DEFLATED;
        entry->fileHeader.versionForExtraction = NOZVersionForExtraction;
        entry->fileHeader.fileDescriptor = &entry->fileDescriptor;
    }
}

NOZFileEntryT* NOZFileEntryAllocInit(void)
{
    NOZFileEntryT *entry = (NOZFileEntryT *)malloc(sizeof(NOZFileEntryT));
    NOZFileEntryInit(entry);
    return entry;
}

void NOZFileEntryClean(NOZFileEntryT* entry)
{
    if (entry) {
        if (entry->name && entry->ownsName) {
            free((void*)entry->name);
            entry->name = NULL;
            entry->ownsName = NO;
        }
        if (entry->extraField && entry->ownsExtraField) {
            free((void*)entry->extraField);
            entry->extraField = NULL;
            entry->ownsExtraField = NO;
        }
        if (entry->comment && entry->ownsComment) {
            free((void*)entry->comment);
            entry->comment = NULL;
            entry->ownsComment = NO;
        }
    }
}

void NOZFileEntryCleanFree(NOZFileEntryT* entry)
{
    while (entry) {
        NOZFileEntryT* nextEntry = entry->nextEntry;

        NOZFileEntryClean(entry);

        free(entry);

        entry = nextEntry;
    }
}

static BOOL _NOZOpenInputOutputFiles(NSString * __nonnull sourceFilePath,
                                     FILE * __nullable * __nonnull sourceFile,
                                     NSString * __nonnull destinationFilePath,
                                     FILE * __nonnull * __nullable destinationFile,
                                     NSError * __autoreleasing __nullable * __nullable error)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    __block FILE *inFile = NULL;
    __block FILE *outFile = NULL;
    __block NSError *stackError = nil;
    noz_defer(^{
        if (stackError) {
            if (error) {
                *error = stackError;
            }
            if (inFile) {
                fclose(inFile);
            }
            if (outFile) {
                fclose(outFile);
                [fm removeItemAtPath:destinationFilePath error:NULL];
            }
        } else {
            if (inFile) {
                *sourceFile = inFile;
            }
            if (outFile) {
                *destinationFile = outFile;
            }
        }
    });

    inFile = fopen(sourceFilePath.UTF8String, "r");
    if (!inFile) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:errno
                                     userInfo:@{ @"sourceFile" : sourceFilePath ?: [NSNull null] }];
        return NO;
    }

    const BOOL didCreateDir = [fm createDirectoryAtPath:[destinationFilePath stringByDeletingLastPathComponent]
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&stackError];
    if (!didCreateDir) {
        return NO;
    }

    if ([fm fileExistsAtPath:destinationFilePath]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EEXIST
                                     userInfo:@{ @"destinationFile" : destinationFilePath }];
        return NO;
    }

    outFile = fopen(destinationFilePath.UTF8String, "w");
    if (!outFile) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:errno
                                     userInfo:@{ @"destinationFile" : destinationFilePath }];
        return NO;
    }

    return YES;
}

BOOL NOZEncodeFile(NSString *sourceFile,
                   NSString *destinationFile,
                   id<NOZEncoder> encoder,
                   NOZCompressionLevel level,
                   NSError * __autoreleasing * error)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    __block FILE *uncompressedFile = NULL;
    __block FILE *compressedFile = NULL;
    __block NSError *stackError = nil;
    noz_defer(^{
        if (stackError) {
            if (error) {
                *error = stackError;
            }
        }
        if (uncompressedFile) {
            fclose(uncompressedFile);
        }
        if (compressedFile) {
            fclose(compressedFile);
            if (stackError) {
                [fm removeItemAtPath:destinationFile error:NULL];
            }
        }
    });

    if (!encoder) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EINVAL
                                     userInfo:NULL];
        return NO;
    }

    const BOOL didOpenFiles = _NOZOpenInputOutputFiles(sourceFile,
                                                       &uncompressedFile,
                                                       destinationFile,
                                                       &compressedFile,
                                                       &stackError);
    if (!didOpenFiles) {
        return NO;
    }

    id<NOZEncoderContext> context;
    context = [encoder createContextWithBitFlags:0
                                compressionLevel:level
                                   flushCallback:^BOOL(id<NOZEncoder> theEncoder,
                                                       id<NOZEncoderContext> theContext,
                                                       const Byte *bufferToFlush,
                                                       size_t length) {
        if (length != fwrite(bufferToFlush, 1, length, compressedFile)) {
            return NO;
        }
        return YES;
    }];

    if (![encoder initializeEncoderContext:context]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EIO
                                     userInfo:nil];
        return NO;
    }

    do {
        const size_t bufferSize = 1024 * 1024;
        Byte *buffer = malloc(bufferSize * sizeof(Byte));
        noz_defer(^{
            free(buffer);
        });
        while (!feof(uncompressedFile)) {

            const size_t bytesRead = fread(buffer, 1, bufferSize, uncompressedFile);
            if (bytesRead < bufferSize && ferror(uncompressedFile)) {
                stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                 code:EIO
                                             userInfo:nil];
                return NO;
            }

            const BOOL didEncode = [encoder encodeBytes:buffer
                                                 length:bytesRead
                                                context:context];
            if (!didEncode) {
                stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                 code:EIO
                                             userInfo:nil];
                return NO;
            }

        }
    } while (0);

    if (![encoder finalizeEncoderContext:context]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EIO
                                     userInfo:nil];
        return NO;
    }

    fflush(compressedFile);

    return YES;
}

BOOL NOZDecodeFile(NSString *sourceFile,
                   NSString *destinationFile,
                   id<NOZDecoder> decoder,
                   NSError * __autoreleasing * error)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    __block FILE *uncompressedFile = NULL;
    __block FILE *compressedFile = NULL;
    __block NSError *stackError = nil;
    noz_defer(^{
        if (stackError) {
            if (error) {
                *error = stackError;
            }
        }
        if (uncompressedFile) {
            fclose(uncompressedFile);
        }
        if (compressedFile) {
            fclose(compressedFile);
            if (stackError) {
                [fm removeItemAtPath:destinationFile error:NULL];
            }
        }
    });

    if (!decoder) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EINVAL
                                     userInfo:NULL];
        return NO;
    }

    const BOOL didOpenFiles = _NOZOpenInputOutputFiles(sourceFile,
                                                       &compressedFile,
                                                       destinationFile,
                                                       &uncompressedFile,
                                                       &stackError);
    if (!didOpenFiles) {
        return NO;
    }

    id<NOZDecoderContext> context;
    context = [decoder createContextForDecodingWithBitFlags:0
                                              flushCallback:^BOOL(id<NOZDecoder> theDecoder,
                                                                  id<NOZDecoderContext> theContext,
                                                                  const Byte *bufferToFlush,
                                                                  size_t length) {
        if (length != fwrite(bufferToFlush, 1, length, uncompressedFile)) {
            return NO;
        }
        return YES;
    }];

    if (![decoder initializeDecoderContext:context]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EIO
                                     userInfo:nil];
        return NO;
    }

    do {
        const size_t bufferSize = 1024 * 1024;
        Byte *buffer = malloc(bufferSize * sizeof(Byte));
        noz_defer(^{
            free(buffer);
        });
        while (!context.hasFinished) {
            const size_t bytesRead = fread(buffer, 1, bufferSize, compressedFile);
            if (ferror(compressedFile)) {
                stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                 code:EIO
                                             userInfo:nil];
                return NO;
            }
            if (![decoder decodeBytes:buffer length:bytesRead context:context]) {
                stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                 code:EIO
                                             userInfo:nil];
                return NO;
            }
        }
    } while (0);

    if (![decoder finalizeDecoderContext:context]) {
        stackError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EIO
                                     userInfo:nil];
        return NO;
    }

    fflush(uncompressedFile);

    return YES;
}
