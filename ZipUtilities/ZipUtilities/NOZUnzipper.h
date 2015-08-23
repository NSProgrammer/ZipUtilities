//
//  NOZUnzipper.h
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

#import "NOZUtils.h"
#import "NOZZipEntry.h"

@class NOZGlobalInfo;
@class NOZCentralDirectory;
@class NOZCentralDirectoryRecord;

typedef void(^NOZUnzipRecordEnumerationBlock)(NOZCentralDirectoryRecord * __nonnull record, NSUInteger index, BOOL * __nonnull stop);
typedef void(^NOZUnzipByteRangeEnumerationBlock)(const void * __nonnull bytes, NSRange byteRange, BOOL * __nonnull stop);

/**
 `NOZUnzipper` unzips an archive.

  Uses **zlib** to decompress and therefore only supports **deflate** compressed entries/record.
 */
@interface NOZUnzipper : NSObject

/** The path to the zip archive */
@property (nonatomic, readonly, nonnull) NSString *zipFilePath;
/** The central directory object.  `nil` if it hasn't been parsed (or failed to be read). */
@property (nonatomic, readonly, nullable) NOZCentralDirectory *centralDirectory;

/** Designated initializer */
- (nonnull instancetype)initWithZipFile:(nonnull NSString *)zipFilePath;

/** Unavailable */
- (nullable instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (nullable instancetype)new NS_UNAVAILABLE;

/**
 Open the zip archive.
 Must open before performing another action.
 Should be balanced with a `closeAndReturnError:` call
 */
- (BOOL)openAndReturnError:(out NSError * __nullable * __nullable)error;

/**
 Close the open archive.
 Harmless to call redundantly.
 */
- (BOOL)closeAndReturnError:(out NSError * __nullable * __nullable)error;

/**
 Read the central directory.
 Must read the central directory before doing anything with specific entries.
 If successful, `[NOZUnzipper centralDirectory]` will be populated (and no longer `nil`).
 */
- (nullable NOZCentralDirectory *)readCentralDirectoryAndReturnError:(out NSError * __nullable * __nullable)error;

/**
 Read a central directory record at a specific _index_.
 */
- (nullable NOZCentralDirectoryRecord *)readRecordAtIndex:(NSUInteger)index
                                                    error:(out NSError * __nullable * __nullable)error;

/**
 Find the index for a record matching the _name_ provided.  `NSNotFound` if no match was found.
 */
- (NSUInteger)indexForRecordWithName:(nonnull NSString *)name;

/**
 Enumerate all the records.
 */
- (void)enumerateManifestEntriesUsingBlock:(__attribute__((noescape)) NOZUnzipRecordEnumerationBlock __nonnull)block;


/**
 Read a record as NSData.
 */
- (nullable NSData *)readDataFromRecord:(nonnull NOZCentralDirectoryRecord *)record
                          progressBlock:(nullable NOZProgressBlock)progressBlock
                                  error:(out NSError *__autoreleasing  __nullable * __nullable)error;

/**
 Stream a record's data to _block_.
 */
- (nullable NSError *)enumerateByteRangesOfRecord:(nonnull NOZCentralDirectoryRecord *)record
                                    progressBlock:(nullable NOZProgressBlock)progressBlock
                                       usingBlock:(nonnull NOZUnzipByteRangeEnumerationBlock)block;

/**
 Save a record to disk.
 */
- (BOOL)saveRecord:(nonnull NOZCentralDirectoryRecord *)record
       toDirectory:(nonnull NSString *)destinationRootDirectory
   shouldOverwrite:(BOOL)overwrite
     progressBlock:(nullable NOZProgressBlock)progressBlock
             error:(out NSError *__autoreleasing  __nullable * __nullable)error;



@end

/**
 A central directory record is a zip entry populated with all the pertinent central directory info.
 */
@interface NOZCentralDirectoryRecord : NSObject <NOZZipEntry>
@property (nonatomic, readonly, nonnull) NSString *name;
@property (nonatomic, readonly, nullable) NSString *comment;
@property (nonatomic, readonly) NOZCompressionLevel compressionLevel; // a best guess
@property (nonatomic, readonly) SInt64 compressedSize;
@property (nonatomic, readonly) SInt64 uncompressedSize;

/** Unavailable */
- (nullable instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (nullable instancetype)new NS_UNAVAILABLE;
@end

/**
 `NOZCentralDirectoryRecord(Attributes)` has methods to identify if a record has any specific attributes.
 */
@interface NOZCentralDirectoryRecord (Attributes)
/** Record is empty */
- (BOOL)isZeroLength;
/** Record is a Mac OS X attribute entry.  `"__MACOSX/"` entries are not automatically supported by **ZipUtilities**. */
- (BOOL)isMacOSXAttribute;
/** Record is a `".DS_Store"` file for Mac OS X. */
- (BOOL)isMacOSXDSStore;
@end

/**
 The central directory houses all the records for entries in the zip as well as global info.
 */
@interface NOZCentralDirectory : NSObject
@property (nonatomic, copy, readonly, nullable) NSString *globalComment;
@property (nonatomic, readonly) NSUInteger recordCount;
@property (nonatomic, readonly) SInt64 totalCompressedSize;
@property (nonatomic, readonly) SInt64 totalUncompressedSize;

/** Unavailable */
- (nullable instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (nullable instancetype)new NS_UNAVAILABLE;
@end

