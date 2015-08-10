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

 ## History

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

 - modernize minizip 1.1 into minizip 1.2
 - add Mac OS X target and support
 - add iOS dynamic framework target
 - add generic utilies like compressing/decompressing from NSData to NSData
 
 ### Eventually
 
 - add password support
 - add support for the global commment on an archive
 - add support for per entry comments in an archive
 - add support for per entry "extra info" in an archive
 - expand on progress info
   - state transitions
   - what files are being zipped/unzipped
   - per file progress

## Dependencies

### Test files for zipping/unzipping
As a part of unit testing, Aesop's Fables and Maniac Mansion are both used for unit testing.  Neither has a copyright anymore and can be freely be distributed including the unorthodox use as test files for unit testing zip archiving and unarchiving.

### MiniZip
MiniZip 1.1 is a dependency of ZipUtilities.  However, given that the latest version of MiniZip was from 2010, ZipUtilities will modify MiniZip to version 1.2 in order to address 2 concerns:

1. compiler and static analysis warnings
2. dated coding style and syntax


