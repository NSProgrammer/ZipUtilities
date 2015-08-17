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

@interface NOZZipper : NSObject

@property (nonatomic, readonly, nonnull) NSString *zipFilePath;

@property (nonatomic, copy, nullable) NSString *globalComment; // set "before" closing the Zipper

// Constructor
- (nonnull instancetype)initWithZipFile:(nonnull NSString *)zipFilePath NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)init NS_UNAVAILABLE;
+ (nullable instancetype)new NS_UNAVAILABLE;

// Open/close the zipped file
- (BOOL)openWithMode:(NOZZipperMode)mode error:(out NSError * __nullable * __nullable)error;
- (BOOL)closeAndReturnError:(out NSError * __nullable * __nullable)error;
- (BOOL)forciblyCloseAndReturnError:(out NSError * __nullable * __nullable)error;

// Add entries
- (BOOL)addEntry:(nonnull NOZAbstractZipEntry<NOZZippableEntry> *)entry
   progressBlock:(__attribute__((noescape)) NOZProgressBlock __nullable)progressBlock
           error:(out NSError * __nullable * __nullable)error;

@end
