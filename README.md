# ZipUtilities
![MIT License](https://img.shields.io/github/license/NSProgrammer/ZipUtilities.svg?style=flat) [![CocoaPods compatible](https://img.shields.io/cocoapods/v/ZipUtilities.svg?style=flat)](https://CocoaPods.org) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

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
pod 'ZipUtilities', '~> 1.4.0'
```

#### Carthage

Add _ZipUtilities_ to your `Cartfile`

```ruby
github "NSProgrammer/ZipUtilities"
```


## Overview

### Service Oriented Interfaces (NSOperations)

The primary value of _ZipUtilities_ is that it provides an easy to use interface for archiving data or files into a single zip archive and unarchiving a zip archive to the contained files.  The primary approach for _ZipUtilities_ is to provide a service oriented pattern for compressing and decompressing.

**`NOZCompress.h`**

`NOZCompress.h` contains the service oriented interfaces related to compressing into a zip archive.

- `NOZCompressRequest` is the object that encapsulates the _what_ and _how_ for the compression operation to act upon
- `NOZCompressOperation` is the `NSOperation` subclass object that performs the compression. By being an `NSOperation`, consumers can take advantage of cancelling, prioritization and dependencies.  Progress is also provided with the operation and can be observed via _KVO_ on the `progress` property or via the delegate callback.
- `NOZCompressDelegate` is the delegate for the `NOZCompressOperation`.  It provides callbacks for progress and completion.
- `NOZCompressResult` is the object taht encapsulates the result of a compress operation. It holds whether or not the operation succeed, the error if it didn't succeed, the path to the created zip archive and other informative metrics like duration and compression ratio.

**`NOZDecompress.h`**

`NOZDecompress.h` contains the service oriented interfaces related to decompressing from a zip archive.

- `NOZDecompressRequest` is the object that encapsulates the _what_ and _how_ for the decompression operation to act upon
- `NOZDecompressOperation` is the `NSOperation` subclass object that performs the compression. By being an `NSOperation`, consumers can take advantage of cancelling, prioritization and dependencies.  Progress is also provided with the operation and can be observed via _KVO_ on the `progress` property or via the delegate callback.
- `NOZDecompressDelegate` is the delegate for the `NOZDecompressOperation`.  It provides callbacks for progress, overwriting output files and completion.
- `NOZDecompressResult` is the object taht encapsulates the result of a compress operation. It holds whether or not the operation succeed, the error if it didn't succeed, the paths to the output unarchived files and other informative metrics like duration and compression ratio.

### Manual Zipping and Unzipping

Additional, the underlying objects for zipping and unzipping are exposed for direct use if NSOperation support is not needed.

**`NOZZipper.h`**

`NOZZipper` is an object that encapsulates the work for zipping sources (NSData, streams and/or
files) into an on disk zip archive file.

**`NOZUnzipper.h`**

`NOZUnzipper` is an object that encapsulates the work for unzipping from a zip archive file on disk
into destinations (NSData, streams and/or files).

### Extensibility - Modular Compression Encoders/Decoders

**`NOZCompression.h`**

_ZipUtilities_ provides a modular approach to compressing and decompressing individual entries of a zip archive.  The _Zip_ file format specifies what compression method is used for any given entry in an archive.  The two most common algorithms for zip archivers and unarchivers are *Deflate* and *Raw*.  Given those are the two most common, _ZipUtilities_ comes with those algorithms built in with *Deflate* being provided from the _zlib_ library present on iOS and OS X and *Raw* simply being unmodified bytes (no compression).  With the combination of `NOZCompressionLevel` and `NOZCompressionMethod` you can optimize the way you compress multiple entries in a file.  For example: you might have a text file, an image and a binary to archive.  You could add the text file with `NOZCompressionLevelDefault` and `NOZCompressionMethodDeflate`, the image with `NOZCompressionMethodNone` and the binary with `NOZCompressionLevelVeryLow` and `NOZCompressionMethodDeflate` (aka Fast).

Since _ZipUtilities_ takes a modular approach for compression methods, adding support for additional compression encoders and decoders is very straightforward.  You simply implement the `NOZCompressionEncoder` and `NOZCompressionDecoder` protocols and register them with the related `NOZCompressionMethod` with `NOZUpdateCompressionMethodEncoder(method,encoder)` and `NOZUpdateCompressionMethodDecoder(method,decoder)`.  For instance, you might want to add _BZIP2_ support: just implement `MyBZIP2Encoder<NOZCompressionEncoder>` and `MyBZIP2Decoder<NOZCompressionDecoder>` and update the know encoders and decoders for `NOZCompressionMethodBZip2` in _ZipUtilities_ before you start zipping or unzipping with `NOZUpdateCompressionMethodEncoder` and `NOZUpdateCompressionMethodDecoder`.

## History

### 1.4.0  (Sep 5, 2015) - Ashton Williams

- Mac OS X target and support
- iOS dynamic framework target

### 1.3.2  (Aug 23, 2015) - Nolan O'Brien

- Optimize zipping to be done in a single write pass
  - Can be disabled with NOZ_SINGLE_PASS_ZIP being set to 0

### 1.3.1  (Aug 23, 2015) - Nolan O'Brien

- Finish modularization of compression with decoders being implemented

### 1.3.0  (Aug 22, 2015) - Nolan O'Brien

- Modularize compression encoding and decoding with protocols in `NOZCompression.h`
- Add _Deflate_ encoder/decoder
- Add _Raw_ encoder/decoder (for no compression support)
- TODO: currently, only encoders are supported and implemented. Still need to implement and use decoders.

### 1.2.0  (Aug 21, 2015) - Nolan O'Brien

- Implement NOZUnzipper
- Use NOZUnzipper for decompression
- Remove minizip dependency

### 1.1.0  (Aug 15, 2015) - Nolan O'Brien

- Introduce NOZZipper for compression
- Remove minizip dependency for compression
- TODO: implement NOZUnzipper and remove minizip dependency completely
- NOTE: loses support for password encryption and ZIP64 support

### 1.0.1b (Aug 11, 2015) - Nolan O'Brien

- Straighten out some minizip code

### 1.0.1 (Aug 10, 2015) - Nolan O'Brien

- Added comments/documentation throughout headers
- Added more places to detect cancellation to NOZDecompressOperation

### 1.0.0 (Aug 9, 2015) - Nolan O'Brien

- Refactored code
- fixed compilation and static analysis warnings in minizip 1.1
- pushed to github ( https://github.com/NSProgrammer/ZipUtilities )

### 0.9.0 (Aug 4, 2015) - Nolan O'Brien

- Initial Project built, structured and unit tested

## TODO

### Near term

- add generic utilies like compressing/decompressing from NSData to NSData

### Eventually

- add password support
  - This is low priority as encrypting zip file content is not the appropriate way to secure data
- add support for per entry "extra info" in an archive
- expand on progress info
  - state transitions
  - what files are being zipped/unzipped
  - per file progress

## Dependencies

### Test files for zipping/unzipping
As a part of unit testing, Aesop's Fables and Maniac Mansion are both used for unit testing.  Neither has a copyright anymore and can be freely be distributed including the unorthodox use as test files for unit testing zip archiving and unarchiving.
