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

#import "NOZZipEntry.h"

@class NOZEncrytion;

typedef NS_ENUM(NSInteger, NOZZipperMode)
{
    NOZZipperModeCreate,
// TODO: add support for adding to an existing file
//    NOZZipperModeOpenExisting,
//    NOZZipperModeOpenExistingOrCreate,
};

/**
 `NOZZipper` encapsulates zipping sources into a zip archive.
 
 Uses **zlib** to compress with **deflate** encoding.
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
