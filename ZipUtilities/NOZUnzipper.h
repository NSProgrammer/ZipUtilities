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

//! Callback when enumerating Central Directory Record.  Set _stop_ to `YES` to end the enumeration early.
typedef void(^NOZUnzipRecordEnumerationBlock)(NOZCentralDirectoryRecord * __nonnull record, NSUInteger index, BOOL * __nonnull stop);
//! Callback when enumerating bytes being decompressed for an entry.  Set _stop_ to `YES` to end the enumeration early.
typedef void(^NOZUnzipByteRangeEnumerationBlock)(const void * __nonnull bytes, NSRange byteRange, BOOL * __nonnull stop);

//! Values for options when saving a record to disk
typedef NS_OPTIONS(NSInteger, NOZUnzipperSaveRecordOptions)
{
    /** No options */
    NOZUnzipperSaveRecordOptionsNone = 0,
    /** If a file exists at the output path, overwrite it */
    NOZUnzipperSaveRecordOptionOverwriteExisting,
    /** If the output file would have intermediate directories, ignore them and write the file directly to the output directory. */
    NOZUnzipperSaveRecordOptionIgnoreIntermediatePath,
};

/**
 `NOZUnzipper` unzips an archive.

 Uses the globally registered compression encoders.  See `NOZDecoderForCompressionMethod` and `NOZUpdateCompressionMethodDecoder` in `NOZCompression.h`.

 ### Example

 Here's a completely contrived example for unzipping with the `NOZUnzipper`.
 Feel free to reference it for how to use `NOZUnzipper`, but don't treat it as an example of how to handle extracted data/files.

    - (BOOL)unzipThingsAndReturnError:(out NSError **)error
    {
        NSAssert(![NSThread isMainThread]); // do this work on a background thread
 
        NOZUnzipper *unzipper = [[NOZUnzipper alloc] initWithZipFile:zipFilePath];
        if (![unzipper openAndReturnError:error]) {
            return NO;
        }
 
        if (nil == [unzipper readCentralDirectoryAndReturnError:error]) {
            return NO;
        }
 
        __block NSError *enumError = nil;
        [unzipper enumerateManifestEntriesUsingBlock:^(NOZCentralDirectoryRecord * record, NSUInteger index, BOOL * stop) {
            NSString *extension = record.name.pathExtension;
            if ([extension isEqualToString:@"jpg"]) {
                *stop = ![self readImageFromUnzipper:unzipper withRecord:record error:&enumError];
            } else if ([extension isEqualToString:@"json"]) {
                *stop = ![self readJSONFromUnzipper:unzipper withRecord:record error:&enumError];
            } else {
                *stop = ![self extractFileFromUnzipper:unzipper withRecord:record error:&enumError];
            }
         }];
 
        if (enumError) {
            *error = enumError;
            return NO;
        }

        if (![unzipper closeAndReturnError:error]) {
            return NO;
        }

        return YES;
    }
 
    - (BOOL)readImageFromUnzipper:(NOZUnzipper *)unzipper withRecord:(NOZCentralDirectoryRecord *)record error:(out NSError **)error
    {
        CGImageSourceRef imageSource = CGImageSourceCreateIncremental(NULL);
        custom_defer(^{ // This is Obj-C equivalent to 'defer' in Swift.  See http://www.openradar.me/21684961 for more info.
            if (imageSource) {
                CFRelease(imageSource);
            }
        });

        NSMutableData *imageData = [NSMutableData dataWithCapacity:record.uncompressedSize];
        if (![unzipper enumerateByteRangesOfRecord:record
                                     progressBlock:NULL
                                        usingBlock:^(const void * bytes, NSRange byteRange, BOOL * stop) {
                                            [imageData appendBytes:bytes length:byteRange.length];
                                            CGImageSourceUpdate(imageSource, imageData, NO);
                                        }
                                             error:error]) {
            return NO;
        }

        CGImageSourceUpdate(imageSource, (__bridge CFDataRef)imageData, YES);
        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        if (!imageRef) {
            *error = ... some error ...;
            return NO;
        }

        custom_defer(^{
            CFRelease(imageRef);
        });
 
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        if (!image) {
            *error = ... some error ...;
            return NO;
        }

        self.image = image;
        return YES;
    }

    - (BOOL)readJSONFromUnzipper:(NOZUnzipper *)unzipper withRecord:(NOZCentralDirectoryRecord *)record error:(out NSError **)error
    {
        NSData *jsonData = [unzipper readDataFromRecord:record
                                          progressBlock:NULL
                                                  error:error];
        if (!jsonData) {
            return NO;
        }

        id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:0
                                                          error:error];
        if (!jsonObject) {
            return NO;
        }

        self.json = jsonObject;
        return YES;
    }

    - (BOOL)extractFileFromUnzipper:(NOZUnzipper *)unzipper withRecord:(NOZCentralDirectoryRecord *)record error:(out NSError **)error
    {
        if (record.isZeroLength || record.isMacOSXAttribute || record.isMacOSXDSStore) {
            return YES;
        }

        return [self saveRecord:record toDirectory:someDestinationRootDirectory options:NOZUnzipperSaveRecordOptionsNone progressBlock:NULL error:error];
    }

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
- (BOOL)enumerateByteRangesOfRecord:(nonnull NOZCentralDirectoryRecord *)record
                      progressBlock:(nullable NOZProgressBlock)progressBlock
                         usingBlock:(nonnull NOZUnzipByteRangeEnumerationBlock)block
                              error:(out NSError *__autoreleasing  __nullable * __nullable)error;

/**
 Save a record to disk.
 */
- (BOOL)saveRecord:(nonnull NOZCentralDirectoryRecord *)record
       toDirectory:(nonnull NSString *)destinationRootDirectory
           options:(NOZUnzipperSaveRecordOptions)options
     progressBlock:(nullable NOZProgressBlock)progressBlock
             error:(out NSError *__autoreleasing  __nullable * __nullable)error;

/**
 *DEPRECATED*: See `saveRecord:toDirectory:options:progressBlock:error:`
 */
- (BOOL)saveRecord:(nonnull NOZCentralDirectoryRecord *)record
       toDirectory:(nonnull NSString *)destinationRootDirectory
   shouldOverwrite:(BOOL)overwrite
     progressBlock:(nullable NOZProgressBlock)progressBlock
             error:(out NSError *__autoreleasing  __nullable * __nullable)error __attribute__((deprecated("Use saveRecord:toDirectory:options:progressBlock:error: instead!")));



@end

/**
 A central directory record is a zip entry populated with all the pertinent central directory info.
 */
@interface NOZCentralDirectoryRecord : NSObject <NOZZipEntry>
@property (nonatomic, readonly, nonnull) NSString *name;
@property (nonatomic, readonly, nullable) NSString *comment;
@property (nonatomic, readonly) NOZCompressionMethod compressionMethod;
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
/** A global comment for the entire archive */
@property (nonatomic, copy, readonly, nullable) NSString *globalComment;
/** The number of records in the archive */
@property (nonatomic, readonly) NSUInteger recordCount;
/** The total compressed size of the archive in bytes */
@property (nonatomic, readonly) SInt64 totalCompressedSize;
/** The total uncompressed size of all entries in bytes */
@property (nonatomic, readonly) SInt64 totalUncompressedSize;

/** Unavailable */
- (nullable instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (nullable instancetype)new NS_UNAVAILABLE;
@end

