//
//  NOZError.h
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

NS_ASSUME_NONNULL_BEGIN

//! Error domain for _ZipUtilities_
FOUNDATION_EXTERN NSString * const NOZErrorDomain;

/**
 `NOZErrorCode` values are broken into pages (`NOZErrorPage`) for each are of *ZipUtilities* that can produce an error.
 
    static const NSInteger NOZErrorPageSize = 100;
 */
typedef NS_ENUM(NSInteger, NOZErrorPage)
{
    /** None */
    NOZErrorPageNone = 0,
    /** For `NOZCompressOperation` errors */
    NOZErrorPageCompress,
    /** For `NOZDecompressOperation` errors */
    NOZErrorPageDecompress,
    /** For `NOZZipper` errors */
    NOZErrorPageZip,
    /** For `NOZUnzipper` errors */
    NOZErrorPageUnzip,
};

static const NSInteger NOZErrorPageSize = 100;

/**
 `NOZErrorCode` values for *ZipUtilities* related errors in the `NOZErrorDomain` domain.

     FOUNDATION_EXTERN NSString * const NOZErrorDomain;

 ## Error Utilities

     BOOL NOZErrorCodeIsInErrorPage(NOZErrorCode code, NOZErrorPage page);
     BOOL NOZErrorCodeIsCompressError(NOZErrorCode code);
     BOOL NOZErrorCodeIsDecompressError(NOZErrorCode code);
     BOOL NOZErrorCodeIsZipError(NOZErrorCode code);
     BOOL NOZErrorCodeIsUnzipError(NOZErrorCode code);
     NSError *NOZErrorCreate(NOZErrorCode code, NSDictionary *userInfo);

 */
typedef NS_ENUM(NSInteger, NOZErrorCode)
{
    /** Unknown Compress Error */
    NOZErrorCodeCompressUnknown = NOZErrorPageCompress * NOZErrorPageSize,
    /** Compress did fail to open new zip file */
    NOZErrorCodeCompressFailedToOpenNewZipFile,
    /** Compress had no entries to compress */
    NOZErrorCodeCompressNoEntriesToCompress,
    /** Compress was missing a name for an entry */
    NOZErrorCodeCompressMissingEntryName,
    /** Compress entry couldn't be zipped */
    NOZErrorCodeCompressEntryCannotBeZipped,
    /** Compress did fail to append an entry to the zip */
    NOZErrorCodeCompressFailedToAppendEntryToZip,
    /** Compress did fail to finalize the new zip file */
    NOZErrorCodeCompressFailedToFinalizeNewZipFile,
    /** Compress was cancelled */
    NOZErrorCodeCompressCancelled = NOZErrorCodeCompressUnknown + NOZErrorPageSize - 1,

    /** Unknown decompress error */
    NOZErrorCodeDecompressUnknown = NOZErrorPageDecompress * NOZErrorPageSize,
    /** Decompress did fail to open the zip archive */
    NOZErrorCodeDecompressFailedToOpenZipArchive,
    /** Decompress did fail to create the destination directory */
    NOZErrorCodeDecompressFailedToCreateDestinationDirectory,
    /** Decompress did fail to read an archive entry */
    NOZErrorCodeDecompressFailedToReadArchiveEntry,
    /** Decompress did fail to create an unarchived file */
    NOZErrorCodeDecompressFailedToCreateUnarchivedFile,
    /** Decompress counldn't overwrite an existing file */
    NOZErrorCodeDecompressCannotOverwriteExistingFile,
    /** Decompress was cancelled */
    NOZErrorCodeDecompressCancelled = NOZErrorCodeDecompressUnknown + NOZErrorPageSize - 1,

    /** Unknown zip error */
    NOZErrorCodeZipUnknown = NOZErrorPageZip * NOZErrorPageSize,
    /** Zipper used with invalid file path */
    NOZErrorCodeZipInvalidFilePath,
    /** Zipper couldn't open an existing zip */
    NOZErrorCodeZipCannotOpenExistingZip,
    /** Zipper couldn't create a zip */
    NOZErrorCodeZipCannotCreateZip,
    /** Zipper did fail to close the current entry */
    NOZErrorCodeZipFailedToCloseCurrentEntry,
    /** Zipper did fail to write to zip */
    NOZErrorCodeZipFailedToWriteZip,
    /** Zipper couldn't open a new entry */
    NOZErrorCodeZipCannotOpenNewEntry,
    /** Zipper doesn't support 64-bit file sizes */
    NOZErrorCodeZipDoesNotSupportZip64,
    /** Zipper doesn't support a particular compression method */
    NOZErrorCodeZipDoesNotSupportCompressionMethod,
    /** Zipper did fail to write an entry */
    NOZErrorCodeZipFailedToWriteEntry,
    /** An entry failed to be compressed */
    NOZErrorCodeZipFailedToCompressEntry,

    /** Unknown unzip error */
    NOZErrorCodeUnzipUnknown = NOZErrorPageUnzip * NOZErrorPageSize,
    /** Unzipper couldn't open a zip */
    NOZErrorCodeUnzipCannotOpenZip,
    /** Unzipper used with an invalid file path */
    NOZErrorCodeUnzipInvalidZipFile,
    /** Unzipper was manipulated before being opened */
    NOZErrorCodeUnzipMustOpenUnzipperBeforeManipulating,
    /** Unzipper couldn't read the Central Directory */
    NOZErrorCodeUnzipCannotReadCentralDirectory,
    /** Unzipper found that the count of Central Directory Records doesn't match the number of Central Directories Records found */
    NOZErrorCodeUnzipCentralDirectoryRecordCountsDoNotAlign,
    /** Unzipper did not find expected End of Central Directory (EOCD) marker */
    NOZErrorCodeUnzipCentralDirectoryRecordsDoNotCompleteWithEOCDRecord,
    /** Unzipper does not support multiple disk zip archives */
    NOZErrorCodeUnzipMultipleDiskZipArchivesNotSupported,
    /** Unzipper couldn't read the Central Directory Record */
    NOZErrorCodeUnzipCouldNotReadCentralDirectoryRecord,
    /** Unzipper doesn't support the version on the record */
    NOZErrorCodeUnzipUnsupportedRecordVersion,
    /** Unzipper doesn't support decompressing with the method or a record */
    NOZErrorCodeUnzipDecompressionMethodNotSupported,
    /** Unzipper doesn't support decrypting an encrypted record */
    NOZErrorCodeUnzipDecompressionEncryptionNotSupported,
    /** Unzipper was queried for a Central Directory Record that is out of bounds */
    NOZErrorCodeUnzipIndexOutOfBounds,
    /** Unzipper couldn't read a file entry */
    NOZErrorCodeUnzipCannotReadFileEntry,
    /** Unzipper couldn't decompress a file entry */
    NOZErrorCodeUnzipCannotDecompressFileEntry,
    /** An entry failed to be decompressed */
    NOZErrorCodeUnzipFailedToDecompressEntry,
};

//! Is the given _code_ within the specified _page_
NS_INLINE BOOL NOZErrorCodeIsInErrorPage(NOZErrorCode code, NOZErrorPage page)
{
    return page == ((code - (code % NOZErrorPageSize)) / NOZErrorPageSize);
}

//! Is the given _code_ a Compress Error
#define NOZErrorCodeIsCompressError(code)   NOZErrorCodeIsInErrorPage(code, NOZErrorPageCompress)
//! Is the given _code_ a Decompress Error
#define NOZErrorCodeIsDecompressError(code) NOZErrorCodeIsInErrorPage(code, NOZErrorPageDecompress)
//! Is the given _code_ a Zip Error
#define NOZErrorCodeIsZipError(code)        NOZErrorCodeIsInErrorPage(code, NOZErrorPageZip)
//! Is the given _code_ an Unzip Error
#define NOZErrorCodeIsUnzipError(code)      NOZErrorCodeIsInErrorPage(code, NOZErrorPageUnzip)

//! Convenience macro for creating an `NOZErrorDomain` `NSError`
#define NOZErrorCreate(errCode, ui) [NSError errorWithDomain:NOZErrorDomain code:(errCode) userInfo:(ui)]

NS_ASSUME_NONNULL_END
