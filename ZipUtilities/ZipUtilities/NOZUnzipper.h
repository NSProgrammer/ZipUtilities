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

#import "NOZZipEntry.h"

@class NOZGlobalInfo;
@class NOZManifest;

typedef NS_OPTIONS(NSInteger, NOZUnzipManifestReadOptions)
{
#define NOZUnzipManifestReadOptionReserved(bit) \
NOZUnzipManifestReadOptionReserved##bit = 1 << bit

    NOZUnzipManifestReadOptionsNone = 0,

    // Global
    NOZUnzipManifestReadOptionLoadGlobalInfo = 1 << 0,
    NOZUnzipManifestReadOptionLoadGlobalComment = 1 << 1,
    NOZUnzipManifestReadOptionReserved(2),
    NOZUnzipManifestReadOptionReserved(3),
    NOZUnzipManifestReadOptionReserved(4),
    NOZUnzipManifestReadOptionReserved(5),
    NOZUnzipManifestReadOptionReserved(6),
    NOZUnzipManifestReadOptionReserved(7),

    // Entries
    NOZUnzipManifestReadOptionLoadEntries = 1 << 8,
    NOZUnzipManifestReadOptionLoadCommentsOnEntries = 1 << 9,
    NOZUnzipManifestReadOptionLoadExtraInfoOnEntries = 1 << 10,
    NOZUnzipManifestReadOptionReserved(11),
    NOZUnzipManifestReadOptionReserved(12),
    NOZUnzipManifestReadOptionReserved(13),
    NOZUnzipManifestReadOptionReserved(14),
    NOZUnzipManifestReadOptionReserved(15),

#undef NOZUnzipManifestReadOptionReserved
};

typedef void(^NOZUnzipEntryEnumerationBlock)(NOZManifestZipEntry * __nonnull entry, NSUInteger index, BOOL * __nonnull stop);
typedef void(^NOZUnzipByteRangeEnumerationBlock)(const void * __nonnull bytes, NSRange byteRange, BOOL * __nonnull stop);

/**
 NOT THREAD SAFE
 */
@interface NOZUnzipper : NSObject <NSFastEnumeration>

@property (nonatomic, readonly, nonnull) NSString *zipFilePath;
@property (nonatomic, readonly, nullable) NOZManifestZipEntry *manifestEntry;

// Constructor
- (nonnull instancetype)initWithZipFile:(nonnull NSString *)zipFilePath;
- (nullable instancetype)init NS_UNAVAILABLE;
+ (nullable instancetype)new NS_UNAVAILABLE;

// Open/close the zipped file
- (BOOL)openAndReturnError:(out NSError * __nullable * __nullable)error;
- (BOOL)closeAndReturnError:(out NSError * __nullable * __nullable)error;
- (BOOL)forciblyCloseAndReturnError:(out NSError * __nullable * __nullable)error;

// Read manifest
- (nullable NOZManifest *)readManifest:(NOZUnzipManifestReadOptions)options
                                 error:(out NSError * __nullable * __nullable)error;

// Read entry
- (nullable NOZManifestZipEntry *)readManifestEntryAtIndex:(NSUInteger)entryIndex
                                                options:(NOZUnzipManifestReadOptions)options
                                                  error:(out NSError * __nullable * __nullable)error;

// Index of entry with name
- (NSUInteger)indexForManfiestEntryWithName:(nonnull NSString *)name;

// Enumerate all entries
- (void)enumerateManifestEntriesWithOptions:(NOZUnzipManifestReadOptions)options usingBlock:(nonnull NOZUnzipEntryEnumerationBlock)block;

// Open/close an entry
- (BOOL)openManifestEntry:(nonnull NOZManifestZipEntry *)entry
                    error:(out NSError * __nullable * __nullable)error;
- (BOOL)closeCurrentlyOpenManifestEntryAndReturnError:(out NSError *__autoreleasing  __nullable * __nullable)error;

// Read the entry

// Load to NSData
- (nullable NSData *)readDataFromCurrentlyOpenManifestEntry:(nullable NOZProgressBlock)progressBlock
                                                      error:(out NSError *__autoreleasing  __nullable * __nullable)error;
// Stream the bytes
- (nullable NSError *)enumerateByteRanges:(nullable NOZProgressBlock)progressBlock
                               usingBlock:(nonnull NOZUnzipByteRangeEnumerationBlock)block;
// Save to disk
- (BOOL)saveCurrentlyOpenManifestEntryToDirectory:(nonnull NSString *)destinationRootDirectory
                                  shouldOverwrite:(BOOL)overwrite
                                    progressBlock:(nullable NOZProgressBlock)progressBlock
                                            error:(out NSError *__autoreleasing  __nullable * __nullable)error;



@end
