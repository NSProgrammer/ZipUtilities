# ZipUtilities
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/NSProgrammer/ZipUtilities/master/LICENSE.md) [![CocoaPods compatible](https://img.shields.io/cocoapods/v/ZipUtilities.svg?style=flat)](https://CocoaPods.org) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

![Targets](https://img.shields.io/badge/Targets-OSX.Framework_iOS.Framework_iOS.lib-lightgrey.svg)

[![Build Status](https://travis-ci.org/NSProgrammer/ZipUtilities.svg?branch=master)](https://travis-ci.org/NSProgrammer/ZipUtilities)

## Introduction

*ZipUtilities*, prefixed with `NOZ` for _Nolan O'Brien ZipUtilities_, is a library of zipping and unzipping utilities for iOS and Mac OS X.

## Background

The need can occasionally arise where easy compressing and decompressing of data is desired from a simple API.  There are many zipping/unzipping utilities out there but all of them can be found wanting in some way or another.

- too low level
- too complex
- poor code quality
- old coding practices/style (basically really old)
- lack a service oriented approach (request, operation and response pattern)

The goal is to provide an easy to use modern interface for archiving and unarchiving zip files. As a particular focus, providing a service oriented approach can provide powerful support for NSOperation composition.

## Install

The _ZipUtilities_ Xcode project has targets to build iOS and OSX dynamic frameworks. You can build these and add them to your project manually, or add a subproject in Xcode.

Alternatively you may use one of the following dependency managers:

#### CocoaPods

Add _ZipUtilities_ to your `Podfile`

```ruby
pod 'ZipUtilities', '~> 1.7.2'
```

#### Carthage

Add _ZipUtilities_ to your `Cartfile`

```ruby
github "NSProgrammer/ZipUtilities"
```

## Documentation

You can either build the documentation with appledoc locally or you can visit the documentation online at http://cocoadocs.org/docsets/ZipUtilities

## Overview

### Service Oriented Interfaces (NSOperations)

The primary value of _ZipUtilities_ is that it provides an easy to use interface for archiving data or files into a single zip archive and unarchiving a zip archive to the contained files.  The primary approach for _ZipUtilities_ is to provide a service oriented pattern for compressing and decompressing.

**`NOZCompress.h`**

`NOZCompress.h` contains the service oriented interfaces related to compressing into a zip archive.

- `NOZCompressRequest` is the object that encapsulates the _what_ and _how_ for the compression operation to act upon
- `NOZCompressOperation` is the `NSOperation` subclass object that performs the compression. By being an `NSOperation`, consumers can take advantage of cancelling, prioritization and dependencies.  Progress is also provided with the operation and can be observed via _KVO_ on the `progress` property or via the delegate callback.
- `NOZCompressDelegate` is the delegate for the `NOZCompressOperation`. It provides callbacks for progress and completion.
- `NOZCompressResult` is the object that encapsulates the result of a compress operation. It holds whether or not the operation succeed, the error if it didn't succeed, the path to the created zip archive and other informative metrics like duration and compression ratio.

*Example:*

```obj-c
- (NSOperation *)startCompression
{
	NOZCompressRequest *request = [[NOZCompressRequest alloc] initWithDestinationPath:self.zipFilePath];
    [request addEntriesInDirectory:self.sourceDirectoryPath 
                       filterBlock:^BOOL(NSString *filePath) {
        return [filePath.lastPathComponent hasPrefix:@"."];
    }
        compressionSelectionBlock:NULL];
    [request addDataEntry:self.data name:@"Aesop.txt"];
    for (id<NOZZippableEntry> entry in self.additionalEntries) {
        [request addEntry:entry];
    }

    NOZCompressionOperation *op = [[NOZCompressOperation alloc] initWithRequest:request delegate:self];
    [self.operationQueue addOperation:op];

    // return operation so that a handle can be maintained and cancelled if necessary
    return op;
}

- (void)compressOperation:(NOZCompressOperation *)op didCompleteWithResult:(NOZCompressResult *)result
{
    dispatch_async(dispatch_get_main_queue(), ^{
	    self.completionBlock(result.didSuccess, result.operationError);
    });
}

- (void)compressOperation:(NOZCompressOperation *)op didUpdateProgress:(float)progress
{
	dispatch_async(dispatch_get_main_queue(), ^{
	    self.progressBlock(progress);
	});
}
```

```swift
func startCompression() -> NSOperation
{
    let request = NOZCompressRequest.init(destinationPath: self.zipFilePath)
    request.addEntriesInDirectory(self.sourceDirectoryPath, filterBlock: { (filePath: String) -> Bool in
        return ((filePath as NSString).lastPathComponent as NSString).hasPrefix(".")
    }, compressionSelectionBlock: nil)
    request.addDataEntry(self.data name:"Aesop.txt")
    for entry in self.additionalEntries {
        request.addEntry(entry)
    }

    let operation = NOZCompressOperation.init(request: request, delegate: self)
    zipQueue?.addOperation(operation)
    
    // return operation so that a handle can be maintained and cancelled if necessary
    return operation
}

func compressOperation(op: NOZCompressOperation, didCompleteWithResult result: NOZCompressResult)
{
    dispatch_async(dispatch_get_main_queue(), {
        self.completionBlock(result.didSuccess, result.operationError);
    })
}

func compressOperation(op: NOZCompressOperation, didUpdateProgress progress: Float)
{
    dispatch_async(dispatch_get_main_queue(), {
        self.progressBlock(progress);
    })
}
```

**`NOZDecompress.h`**

`NOZDecompress.h` contains the service oriented interfaces related to decompressing from a zip archive.

- `NOZDecompressRequest` is the object that encapsulates the _what_ and _how_ for the decompression operation to act upon
- `NOZDecompressOperation` is the `NSOperation` subclass object that performs the compression. By being an `NSOperation`, consumers can take advantage of cancelling, prioritization and dependencies.  Progress is also provided with the operation and can be observed via _KVO_ on the `progress` property or via the delegate callback.
- `NOZDecompressDelegate` is the delegate for the `NOZDecompressOperation`. It provides callbacks for progress, overwriting output files and completion.
- `NOZDecompressResult` is the object that encapsulates the result of a compress operation. It holds whether or not the operation succeed, the error if it didn't succeed, the paths to the output unarchived files and other informative metrics like duration and compression ratio.

*Example:*

```obj-c
- (NSOperation *)startDecompression
{
    NOZDecompressRequest *request = [[NOZDecompressRequest alloc] initWithSourceFilePath:self.zipFilePath];

    NOZDecompressOperation *op = [[NOZDecompressOperation alloc] initWithRequest:request delegate:self];
    [self.operationQueue addOperation:op];

    // return operation so that a handle can be maintained and cancelled if necessary
    return op;
}

- (void)decompressOperation:(NOZDecompressOperation *)op didCompleteWithResult:(NOZDecompressResult *)result
{
    dispatch_async(dispatch_get_main_queue(), ^{
	    self.completionBlock(result.didSuccess, result.destinationFiles, result.operationError);
    });
}

- (void)decompressOperation:(NOZDecompressOperation *)op didUpdateProgress:(float)progress
{
	dispatch_async(dispatch_get_main_queue(), ^{
	    self.progressBlock(progress);
	});
}
```

```swift
func startDecompression() -> NSOperation
{
    let request = NOZDecompressRequest.init(sourceFilePath: self.zipFilePath)
    let operation = NOZDecompressOperation.init(request: request, delegate: self)
    zipQueue?.addOperation(operation)
    return operation
}

func decompressOperation(op: NOZDecompressOperation, didCompleteWithResult result: NOZDecompressResult)
{
    dispatch_async(dispatch_get_main_queue(), {
        self.completionBlock(result.didSuccess, result.destinationFiles, result.operationError);
    })
}

func decompressOperation(op: NOZDecompressOperation, didUpdateProgress progress: Float)
{
    dispatch_async(dispatch_get_main_queue(), {
        self.progressBlock(progress);
    })
}
```

### Manual Zipping and Unzipping

Additional, the underlying objects for zipping and unzipping are exposed for direct use if NSOperation support is not needed.

**`NOZZipper.h`**

`NOZZipper` is an object that encapsulates the work for zipping sources (NSData, streams and/or
files) into an on disk zip archive file.

*Example:*

```obj-c
- (BOOL)zipThingsUpAndReturnError:(out NSError **)error
{
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

```

**`NOZUnzipper.h`**

`NOZUnzipper` is an object that encapsulates the work for unzipping from a zip archive file on disk
into destinations (NSData, streams and/or files).

*Example:*

```obj-c
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
```

### Extensibility - Modular Compression Encoders/Decoders

**`NOZEncoder` and `NOZDecoder`**

_ZipUtilities_ provides a modular approach to compressing and decompressing individual entries of a zip archive.  The _Zip_ file format specifies what compression method is used for any given entry in an archive.  The two most common algorithms for zip archivers and unarchivers are *Deflate* and *Raw*.  Given those are the two most common, _ZipUtilities_ comes with those algorithms built in with *Deflate* being provided from the _zlib_ library present on iOS and OS X and *Raw* simply being unmodified bytes (no compression).  With the combination of `NOZCompressionLevel` and `NOZCompressionMethod` you can optimize the way you compress multiple entries in a file.  For example: you might have a text file, an image and a binary to archive.  You could add the text file with `NOZCompressionLevelDefault` and `NOZCompressionMethodDeflate`, the image with `NOZCompressionMethodNone` and the binary with `NOZCompressionLevelVeryLow` and `NOZCompressionMethodDeflate` (aka Fast).

Since _ZipUtilities_ takes a modular approach for compression methods, adding support for additional compression encoders and decoders is very straightforward.  You simply implement the `NOZEncoder` and `NOZDecoder` protocols and register them with the related `NOZCompressionMethod` with `NOZUpdateCompressionMethodEncoder(method,encoder)` and `NOZUpdateCompressionMethodDecoder(method,decoder)`.  For instance, you might want to add _BZIP2_ support: just implement `MyBZIP2Encoder<NOZEncoder>` and `MyBZIP2Decoder<NOZDecoder>` and update the know encoders and decoders for `NOZCompressionMethodBZip2` in _ZipUtilities_ before you start zipping or unzipping with `NOZUpdateCompressionMethodEncoder` and `NOZUpdateCompressionMethodDecoder`.

*Example:*

```objc
NOZUpdateCompressionMethodEncoder(NOZCompressionMethodBZip2, [[MyBZIP2Encoder alloc] init]);
NOZUpdateDecompressionMethodEncoder(NOZCompressionMethodBZip2, [[MyBZIP2Decoder alloc] init]);
```

*Apple compression library as an extra*

`NOZXAppleCompressionCoder` has been written as an example of how to construct your own coders.  Supports all algorithms provided by libcompression, including LZMA which is specified in as a known compression method in the ZIP archive format.

*Example of registering the Apple compression library coders:*

```objc
- (BOOL)updateRegisteredCodersWithAppleCompressionCoders
{
    if (![NOZXAppleCompressionCoder isSupported]) {
        // Apple's Compression Lib is only supported on iOS 9+ and Mac OS X 10.11+
        return NO;
    }

    // DEFLATE
    // Replace existing default DEFLATE coders with Apple Compression variant

    NOZUpdateCompressionMethodEncoder(NOZCompressionMethodDeflate,
                                      [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_ZLIB]);
    NOZUpdateCompressionMethodDecoder(NOZCompressionMethodDeflate,
                                      [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_ZLIB]);
    
    // LZMA

    NOZUpdateCompressionMethodEncoder(NOZCompressionMethodLZMA,
                                      [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZMA]);
    NOZUpdateCompressionMethodDecoder(NOZCompressionMethodLZMA,
                                      [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZMA]);

    // The following coders are not defined as known ZIP compression methods, 
    // however that doesn't mean we can't extend the enumeration of ZIP methods
    // to have custom compression methods.
    //
    // Since compression_algorithm enum values are all beyond the defined ZIP methods values
    // and are all within 16 bits, we can just use the values directly.
    // Puts the burden on the decoder to know that these non-ZIP compression methods
    // are for their respective algorithm.

    // LZ4

    NOZUpdateCompressionMethodEncoder((NOZCompressionMethod)COMPRESSION_LZ4,
                                      [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZ4]);
    NOZUpdateCompressionMethodDecoder((NOZCompressionMethod)COMPRESSION_LZ4,
                                      [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZ4]);

    // Apple LZFSE - the new hotness for compression from Apple

    NOZUpdateCompressionMethodEncoder((NOZCompressionMethod)COMPRESSION_LZFSE,
                                      [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZFSE]);
    NOZUpdateCompressionMethodDecoder((NOZCompressionMethod)COMPRESSION_LZFSE,
                                      [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZFSE]);

    return YES;
}
```

## TODO

### Eventually

- 64-bit file support (big file archiving)
- add password support
  - This is low priority as encrypting zip file content is not the appropriate way to secure data
- add support for per entry "extra info" in an archive
- expand on progress info
  - state transitions
  - what files are being zipped/unzipped
  - per file progress

## Dependencies

### Test files for zipping/unzipping
As a part of unit testing Aesop's Fables, the Star Wars Episode VII trailer and Maniac Mansion are used for unit testing.  Aesop's Fables and Maniac Mansion no longer hold a copyright anymore and can be freely be distributed including the unorthodox use as test files for unit testing zip archiving and unarchiving.  The Star Wars Episode VII Trailer is free for distribution and also provides a useful file for testing by being a large file.

![MANIAC.EXE](https://media.giphy.com/media/DPQ4G030oJdcc/giphy.gif)
