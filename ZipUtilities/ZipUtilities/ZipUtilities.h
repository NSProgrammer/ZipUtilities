//
//  ZipUtilities.h
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

#pragma mark Compress/Decompress Operations

#import "NOZCompress.h"
#import "NOZDecompress.h"

#pragma mark Zip/Unzip Objects

#import "NOZUnzipper.h"
#import "NOZZipper.h"

#pragma mark Errors

#import "NOZError.h"

#pragma mark Utilities

#import "NOZUtils.h"


#warning TODO \
Support single pass zipping (0x08 bitFlag) \
Handle zero length entries as no-ops \
Handle zero compression methods as copies


/**
 # ZipUtilities
 
 ## Introduction
 
 *ZipUtilities*, prefixed with `NOZ` for _Nolan O'Brien ZipUtilities_, is a library of zipping and
 unzipping utilities for iOS (and Mac OS X soon).
 
 ## Background
 
 The need can occasionally arise where easy compressing and decompressing of data is desired from a
 simple API.  There are many zipping/unzipping utilities out there but all of them can be found
 wanting in some way or another.
 
   - too low/level
   - too complex
   - poor code quality
   - old coding practices/style (basically really old)
   - lack a service oriented approach (request, operation and response pattern)
 
 ## Overview
 
 The primary value of *ZipUtilities* is that it provides an easy to use interface for archiving data
 or files into a single zip archive and unarchiving a zip archive to the contained files.  The
 primary approach for *ZipUtilities* is to provide a service oriented pattern for compressing and
 decompressing.
 
 ### `NOZCompress.h`
 
 `NOZCompress.h` contains the service oriented interfaces related to compressing into a zip archive.
 
   - `NOZCompressRequest` is the object that encapsulates the _what_ and _how_ for the compression
 operation to act upon
   - `NOZCompressOperation` is the `NSOperation` subclass object that performs the compression.
 By being an `NSOperation`, consumers can take advantage of cancelling, prioritization and
 dependencies.  Progress is also provided with the operation and can be observed via _KVO_ on the
 `progress` property or via the delegate callback.
   - `NOZCompressDelegate` is the delegate for the `NOZCompressOperation`.  It provides callbacks
 for progress and completion.
   - `NOZCompressResult` is the object taht encapsulates the result of a compress operation. It
 holds whether or not the operation succeed, the error if it didn't succeed, the path to the created
 zip archive and other informative metrics like duration and compression ratio.
 
 ### `NOZDecompress.h`

 `NOZDecompress.h` contains the service oriented interfaces related to decompressing from a zip
 archive.

 - `NOZDecompressRequest` is the object that encapsulates the _what_ and _how_ for the decompression
 operation to act upon
 - `NOZDecompressOperation` is the `NSOperation` subclass object that performs the compression.
 By being an `NSOperation`, consumers can take advantage of cancelling, prioritization and
 dependencies.  Progress is also provided with the operation and can be observed via _KVO_ on the
 `progress` property or via the delegate callback.
 - `NOZDecompressDelegate` is the delegate for the `NOZDecompressOperation`.  It provides callbacks
 for progress, overwriting output files and completion.
 - `NOZDecompressResult` is the object taht encapsulates the result of a compress operation. It
 holds whether or not the operation succeed, the error if it didn't succeed, the paths to the output
 unarchived files and other informative metrics like duration and compression ratio.

 ### `NOZZipper.h`

 `NOZZipper` is an object that encapsulates the work for zipping sources (NSData, streams and/or
 files) into an on disk zip archive file.

 ### `NOZUnzipper.h`

 `NOZUnzipper` is an object that encapsulates the work for unzipping from a zip archive file on disk
 into destinations (NSData, streams and/or files).

 ## History

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

 - add Mac OS X target and support
 - add iOS dynamic framework target
 - add generic utilies like compressing/decompressing from NSData to NSData
 
 ### Eventually
 
 - add password support
 - add support for per entry "extra info" in an archive
 - expand on progress info
   - state transitions
   - what files are being zipped/unzipped
   - per file progress

 */
#if APPLEDOC
@interface ZipUtilities
@end
#endif