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

#import "NOZCompression.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol for a Zip Entry
 */
@protocol NOZZipEntry <NSObject, NSCopying>

/** Name of entry */
- (NSString *)name;
/** Optional comment for entry */
- (nullable NSString *)comment;
/** Compression level for entry */
- (NOZCompressionLevel)compressionLevel;
/** Compression Method for entry */
- (NOZCompressionMethod)compressionMethod;
/** Copiable */
- (id)copy;

@end

/**
 Protocol for a Zip Entry that can be Zipped
 */
@protocol NOZZippableEntry <NOZZipEntry>

/** Timestamp for the entry. */
- (nullable NSDate *)timestamp;
/** The size in bytes of the entry. */
- (SInt64)sizeInBytes;
/** Is the entry valid for zipping. */
- (BOOL)canBeZipped;
/** Input Stream for reading the entry into the zip file. */
- (NSInputStream *)inputStream;

@end

/**
 `NOZAbstractZipEntry` is the base class for all entries
 */
@interface NOZAbstractZipEntry : NSObject <NOZZipEntry>

/** The name of the entry.  Cannot be `nil`. */
@property (nonatomic, copy) NSString *name;
/** A comment associated with the entry. */
@property (nonatomic, copy, nullable) NSString *comment;
/** The `NOZCompressionLevel` to compress at.  Default is `NOZCompressionLevelDefault`. */
@property (nonatomic) NOZCompressionLevel compressionLevel;
/** The `NOZCompressionMethod` to compress with.  Default is `NOZCompressionMethodDeflate`. */
@property (nonatomic) NOZCompressionMethod compressionMethod;

/** Designated initializer */
- (instancetype)initWithName:(NSString *)name NS_DESIGNATED_INITIALIZER;

/** Unavailable */
- (instancetype)init NS_UNAVAILABLE;
/** Unavailable */
+ (instancetype)new NS_UNAVAILABLE;

@end

/**
    Zippable entry from a file
 */
@interface NOZFileZipEntry : NOZAbstractZipEntry <NOZZippableEntry>

/** Path to file to zip */
@property (nonatomic, copy, readonly) NSString *filePath;

/** Designated initializer */
- (instancetype)initWithFilePath:(NSString *)filePath name:(NSString *)name NS_DESIGNATED_INITIALIZER;

/** Uses `filePath.lastPathComponent` for the _name_ */
- (instancetype)initWithFilePath:(NSString *)filePath;

/** Unavailable */
- (instancetype)initWithName:(NSString *)name NS_UNAVAILABLE;

@end

/**
    Zippable entry from NSData
 */
@interface NOZDataZipEntry : NOZAbstractZipEntry <NOZZippableEntry>

/** The data to zip */
@property (nonatomic, readonly) NSData *data;

/** Designated initializer */
- (instancetype)initWithData:(NSData *)data name:(NSString *)name NS_DESIGNATED_INITIALIZER;

/** Unavailable */
- (instancetype)initWithName:(NSString *)name NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
