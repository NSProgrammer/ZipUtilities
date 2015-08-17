//
//  NOZZipEntry.h
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

NS_ASSUME_NONNULL_BEGIN

/**
 `NOZAbstractZipEntry` is the base class for all entries
 */
@interface NOZAbstractZipEntry : NSObject <NSCopying>

/** The name of the entry.  Cannot be `nil`. */
@property (nonatomic, copy) NSString *name;
/** A comment associated with the entry. */
@property (nonatomic, copy, nullable) NSString *comment;
/** The `NOZCompressionLevel` to compress at.  Default is `NOZCompressionLevelDefault`. */
@property (nonatomic) NOZCompressionLevel compressionLevel;

- (instancetype)initWithName:(NSString *)name NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@protocol NOZZippableEntry <NSObject>

/** Timestamp for the entry. */
- (nullable NSDate *)timestamp;
/** The size in bytes of the entry. */
- (SInt64)sizeInBytes;
/** Is the entry valid for zipping. */
- (BOOL)canBeZipped;
/** Input Stream for reading the entry into the zip file. */
- (nullable NSInputStream *)inputStream;

@end

@interface NOZFileZipEntry : NOZAbstractZipEntry <NOZZippableEntry>

@property (nonatomic, copy, readonly, nonnull) NSString *filePath;

- (instancetype)initWithFilePath:(NSString *)filePath name:(NSString *)name NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFilePath:(NSString *)filePath;
- (instancetype)initWithName:(NSString *)name NS_UNAVAILABLE;

@end

@interface NOZDataZipEntry : NOZAbstractZipEntry <NOZZippableEntry>

@property (nonatomic, readonly, nonnull) NSData *data;

- (instancetype)initWithData:(NSData *)data name:(NSString *)name NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithName:(NSString *)name NS_UNAVAILABLE;

@end

// Doesn't support being zipped
@interface NOZManifestZipEntry : NOZAbstractZipEntry
@end

NS_ASSUME_NONNULL_END
