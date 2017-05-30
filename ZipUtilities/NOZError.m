//
//  NOZError.m
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

#import "NOZError.h"

NSString * const NOZErrorDomain = @"NOZErrorDomain";

NSString *NOZErrorCodeToString(NOZErrorCode code)
{

#define SWITCH_CASE(caseCode) \
    case caseCode : \
        return @"" #caseCode ;

    switch (code) {
            SWITCH_CASE(NOZErrorCodeCompressUnknown);
            SWITCH_CASE(NOZErrorCodeCompressFailedToOpenNewZipFile);
            SWITCH_CASE(NOZErrorCodeCompressNoEntriesToCompress);
            SWITCH_CASE(NOZErrorCodeCompressMissingEntryName);
            SWITCH_CASE(NOZErrorCodeCompressEntryCannotBeZipped);
            SWITCH_CASE(NOZErrorCodeCompressFailedToAppendEntryToZip);
            SWITCH_CASE(NOZErrorCodeCompressFailedToFinalizeNewZipFile);
            SWITCH_CASE(NOZErrorCodeCompressCancelled);

            SWITCH_CASE(NOZErrorCodeDecompressUnknown);
            SWITCH_CASE(NOZErrorCodeDecompressFailedToOpenZipArchive);
            SWITCH_CASE(NOZErrorCodeDecompressFailedToCreateDestinationDirectory);
            SWITCH_CASE(NOZErrorCodeDecompressFailedToReadArchiveEntry);
            SWITCH_CASE(NOZErrorCodeDecompressFailedToCreateUnarchivedFile);
            SWITCH_CASE(NOZErrorCodeDecompressCannotOverwriteExistingFile);
            SWITCH_CASE(NOZErrorCodeDecompressCancelled);

            SWITCH_CASE(NOZErrorCodeZipUnknown);
            SWITCH_CASE(NOZErrorCodeZipInvalidFilePath);
            SWITCH_CASE(NOZErrorCodeZipCannotOpenExistingZip);
            SWITCH_CASE(NOZErrorCodeZipCannotCreateZip);
            SWITCH_CASE(NOZErrorCodeZipFailedToCloseCurrentEntry);
            SWITCH_CASE(NOZErrorCodeZipFailedToWriteZip);
            SWITCH_CASE(NOZErrorCodeZipCannotOpenNewEntry);
            SWITCH_CASE(NOZErrorCodeZipDoesNotSupportZip64);
            SWITCH_CASE(NOZErrorCodeZipDoesNotSupportCompressionMethod);
            SWITCH_CASE(NOZErrorCodeZipFailedToWriteEntry);
            SWITCH_CASE(NOZErrorCodeZipFailedToCompressEntry);

            SWITCH_CASE(NOZErrorCodeUnzipUnknown);
            SWITCH_CASE(NOZErrorCodeUnzipCannotOpenZip);
            SWITCH_CASE(NOZErrorCodeUnzipInvalidZipFile);
            SWITCH_CASE(NOZErrorCodeUnzipMustOpenUnzipperBeforeManipulating);
            SWITCH_CASE(NOZErrorCodeUnzipCannotReadCentralDirectory);
            SWITCH_CASE(NOZErrorCodeUnzipCentralDirectoryRecordCountsDoNotAlign);
            SWITCH_CASE(NOZErrorCodeUnzipCentralDirectoryRecordsDoNotCompleteWithEOCDRecord);
            SWITCH_CASE(NOZErrorCodeUnzipMultipleDiskZipArchivesNotSupported);
            SWITCH_CASE(NOZErrorCodeUnzipCouldNotReadCentralDirectoryRecord);
            SWITCH_CASE(NOZErrorCodeUnzipUnsupportedRecordVersion);
            SWITCH_CASE(NOZErrorCodeUnzipDecompressionMethodNotSupported);
            SWITCH_CASE(NOZErrorCodeUnzipDecompressionEncryptionNotSupported);
            SWITCH_CASE(NOZErrorCodeUnzipIndexOutOfBounds);
            SWITCH_CASE(NOZErrorCodeUnzipCannotReadFileEntry);
            SWITCH_CASE(NOZErrorCodeUnzipCannotDecompressFileEntry);
            SWITCH_CASE(NOZErrorCodeUnzipChecksumMissmatch);
            SWITCH_CASE(NOZErrorCodeUnzipFailedToDecompressEntry);
    }

#undef SWITCH_CASE

    return @"Unknown";
}

NSError *NOZErrorCreate(NOZErrorCode code, NSDictionary *ui)
{
    NSMutableDictionary *mUserInfo = [NSMutableDictionary dictionaryWithDictionary:ui];
    mUserInfo[@"errorCodeString"] = NOZErrorCodeToString(code);
    return [NSError errorWithDomain:NOZErrorDomain code:code userInfo:mUserInfo];
}
