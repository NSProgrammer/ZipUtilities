//
//  NOZZipper.h
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

@class NOZEncrytion;

/**
 Enum of possible modes to open an `NOZZipper` with.  Currently only creating a new archive is supported.
 */
typedef NS_ENUM(NSInteger, NOZZipperMode)
{
    /** Creat a new zip archive */
    NOZZipperModeCreate,
// TODO: add support for adding to an existing file
//    NOZZipperModeOpenExisting,
//    NOZZipperModeOpenExistingOrCreate,
};

/**
 `NOZZipper` encapsulates zipping sources into a zip archive.
 
 Uses the globally registered compression encoders.  See `NOZEncoderForCompressionMethod` and `NOZUpdateCompressionMethodEncoder` in `NOZCompression.h`.
 
 By default, `NOZZipper` is optimized to compress in a single pass.
 If you need `NOZZipper` to output without this optimization, define `NOZ_SINGLE_PASS_ZIP` as `0`
 in your build settings.
 
 ### Example

    - (BOOL)zipThingsUpAndReturnError:(out NSError **)error
    {
        NSAssert(![NSThread isMainThread]); // do this work on a background thread

        NOZZipper *zipper = [[NOZZipper alloc] initWithZipFile:pathToCreateZipFile];
        if (![zipper openWithMode:NOZZipperModeCreate error:error]) {
            return NO;
        }

        __block int64_t totalBytesCompressed = 0;

        NOZFileZipEntry *textFileZipEntry = [[NOZFileZipEntry alloc] initWithFilePath:textFilePath];
        textFileZipEntry.comment = @"This is a heavily compressed text file.";
        textFileZipEntry.compressionLevel = NOZCompressionLevelMax;

        NSData *jpegData = UIImageJPEGRepresentation(someImage, 0.8f);
        NOZDataZipEntry *jpegEntry = [[NOZDataZipEntry alloc] initWithData:jpegData name:@"image.jpg"];
        jpegEntry.comment = @"This is a JPEG so it doesn't need more compression.";
        jpegEntry.compressionMode = NOZCompressionModeNone;

        if (![zipper addEntry:textFileZipEntry
                progressBlock:^(int64_t totalBytes, int64_t bytesComplete, int64_t bytesCompletedThisPass, BOOL *abort) {
                 totalBytesCompressed = bytesCompletedThisPass;
             }
                        error:error]) {
            return NO;
        }

        if (![zipper addEntry:jpegEntry
                progressBlock:^(int64_t totalBytes, int64_t bytesComplete, int64_t bytesCompletedThisPass, BOOL *abort) {
                 totalBytesCompressed = bytesCompletedThisPass;
             }
                        error:error]) {
            return NO;
        }

        zipper.globalComment = @"This is a global comment for the entire archive.";
        if (![zipper closeAndReturnError:error]) {
            return NO;
        }

        int64_t archiveSize = (int64_t)[[[NSFileManager defaultFileManager] attributesOfItemAtPath:zipper.zipFilePath] fileSize];
        NSLog(@"Compressed to %@ with compression ratio of %.4f:1", zipper.zipFilePath, (double)totalBytesCompressed / (double)archiveSize);
        return YES;
    }
 */
@interface NOZZipper : NSObject

/** The path to the zip file */
@property (nonatomic, readonly, nonnull) NSString *zipFilePath;

/** An optional global comment for the zip archive.  Must be set _before_ closing the Zipper. */
@property (nonatomic, copy, nullable) NSString *globalComment;

/** Designated initializer */
- (nonnull instancetype)initWithZipFile:(nonnull NSString *)zipFilePath NS_DESIGNATED_INITIALIZER;

/** Unavailable */
- (nullable instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (nullable instancetype)new NS_UNAVAILABLE;

/** 
 Open the Zipper.
 This is the first step before any other method can be called.
 Should be balanced with a call to `closeAndReturnError:`.
 */
- (BOOL)openWithMode:(NOZZipperMode)mode error:(out NSError * __nullable * __nullable)error;

/** Close the Zipper. */
- (BOOL)closeAndReturnError:(out NSError * __nullable * __nullable)error;

/** Close the Zipper, but more aggressively. */
- (BOOL)forciblyCloseAndReturnError:(out NSError * __nullable * __nullable)error;

/**
 Add an entry to the Zipper.
 @param entry The entry to zip.
 @param progressBlock The optional block for observing progress.
 @param error The error will be set if an error is encountered.  Pass `NULL` if you don't care.
 @return `YES` on success, `NO` on failure.
 */
- (BOOL)addEntry:(nonnull id<NOZZippableEntry>)entry
   progressBlock:(__attribute__((noescape)) NOZProgressBlock __nullable)progressBlock
           error:(out NSError * __nullable * __nullable)error;

@end
