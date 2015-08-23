//
//  NOZZipEntry.m
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

#import "NOZZipEntry.h"

@interface NOZAbstractZipEntry ()
- (instancetype)initWithEntry:(nonnull NOZAbstractZipEntry *)entry;
@end

@implementation NOZAbstractZipEntry

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithName:(nonnull NSString *)name
{
    if (self = [super init]) {
        _name = [name copy];
        _compressionLevel = NOZCompressionLevelDefault;
        _compressionMethod = NOZCompressionMethodDeflate;
    }
    return self;
}

- (instancetype)initWithEntry:(nonnull NOZAbstractZipEntry *)entry
{
    return [self initWithName:entry.name];
}

- (id)copyWithZone:(NSZone *)zone
{
    NOZAbstractZipEntry *entry = [[[self class] allocWithZone:zone] initWithEntry:self];
    entry.comment = self.comment;
    entry.compressionLevel = self.compressionLevel;
    entry.compressionMethod = self.compressionMethod;
    return entry;
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@ %p", NSStringFromClass([self class]), self];
    if (_name) {
        [string appendFormat:@", name='%@'", _name];
    }
    if ([self respondsToSelector:@selector(sizeInBytes)]) {
        [string appendFormat:@", size=%lli", [(id<NOZZippableEntry>)self sizeInBytes]];
    }
    [string appendFormat:@", zipLevel=%hi", self.compressionLevel];
    [string appendFormat:@", zipMethod=%hi", self.compressionMethod];
    [string appendString:@">"];
    return string;
}

@end

@implementation NOZDataZipEntry

- (instancetype)initWithName:(nonnull NSString *)name
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithData:(nonnull NSData *)data name:(nonnull NSString *)name
{
    if (self = [super initWithName:name]) {
        _data = data;
    }
    return self;
}

- (instancetype)initWithEntry:(nonnull NOZDataZipEntry *)entry
{
    return [self initWithData:entry.data name:entry.name];
}

- (NSDate *)timestamp
{
    return nil;
}

- (SInt64)sizeInBytes
{
    return (SInt64)_data.length;
}

- (BOOL)canBeZipped
{
    return YES;
}

- (NSInputStream *)inputStream
{
    return [NSInputStream inputStreamWithData:_data];
}

@end

@implementation NOZFileZipEntry

- (instancetype)initWithName:(nonnull NSString *)name
{
    [self doesNotRecognizeSelector:_cmd];
    abort();
}

- (instancetype)initWithFilePath:(nonnull NSString *)filePath name:(nonnull NSString *)name
{
    if (self = [super initWithName:name]) {
        _filePath = [filePath copy];
    }
    return self;
}

- (instancetype)initWithFilePath:(nonnull NSString *)filePath
{
    return [self initWithFilePath:filePath name:filePath.lastPathComponent];
}

- (instancetype)initWithEntry:(nonnull NOZFileZipEntry *)entry
{
    return [self initWithFilePath:entry.filePath name:entry.name];
}

- (SInt64)sizeInBytes
{
    if (!_filePath) {
        return 0;
    }

    return (SInt64)[[[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:NULL] fileSize];
}

- (NSDate *)timestamp
{
    if (!_filePath) {
        return nil;
    }

    return [[[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:NULL] fileModificationDate];
}

- (BOOL)canBeZipped
{
    if (!_filePath) {
        return NO;
    }

    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:_filePath isDirectory:&isDir] && !isDir) {
        return YES;
    }

    return NO;
}

- (NSInputStream *)inputStream
{
    if (!_filePath) {
        return nil;
    }

    return [NSInputStream inputStreamWithFileAtPath:_filePath];
}

@end
