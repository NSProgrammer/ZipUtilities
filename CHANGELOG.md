# ZipUtilities Change Log

## History

### 1.10.0 (June 3, 2017) - Nolan O'Brien

- add convenience file-to-file compression/decompression functions in `NOZUtils.h`
- add CLI for ZipUtilities (called `noz`)
    - NOTE: Zip Mode is not yet implemented
- fix NOZUnzipper file size measurement bug

### 1.9.3 (Feb 20, 2017) - Nolan O'Brien

- add checksum error code and record validation method to unzipper

### 1.9.2 (Feb 19, 2017) - Nolan O'Brien

- updated zstd to v1.1.3

### 1.9.1 (Jan 31, 2017) - Nolan O'Brien

- Miscellaneous minor fixes

### 1.9.0 (Nov 22, 2016) - Nolan O'Brien

- Add Brotli support as an extra encoder/decoder
- Refactor compression level
  - decouples from ZLib levels (1-9) and moves to a float range (from 0.0 to 1.0)
  - can map to any encoder with multiple levels now
- Fix memory leak in Apple extra encoders/decoders
- Bump up buffer sizes from 4KB to 16KB
- Update unit tests
- Update test app
- rearrange some code paths for better 3rd party codec support
- improve memory management to reduce memory footprint when multiple encodes/decodes happen

### 1.8.1 (Nov 18, 2016) - Nolan O'Brien

- Fix up project

### 1.8.0  (Nov 17, 2016) - Nolan O'Brien

- Add ZStandard support as an extra encoder/decoder
- Clean up some files
- Fix an edge case in NSData+NOZAdditions category
- Clean up schemes
- Add codec comparison unit test
- Add ZipUtilitiesApp iOS app for testing codec perf on device

### 1.7.2  (Jan 11, 2016) - Nolan O'Brien

- Provide options when saving a record so that we can support writing an entry to disk without the interim path

### 1.7.1  (Dec 31, 2015) - Nolan O'Brien

- Add ability to filter files being added to an NOZCompressRequest when adding files via containing directory path

### 1.7.0  (Dec 15, 2015) - Nolan O'Brien

- Fix NOZErrorCodes (paging was off)
- Fix Decoding large files with Deflate
- Added unit tests

### 1.6.6  (Oct 6, 2015) - Nolan O'Brien

- Fix bug in Unzipper when "overwrite" is NO
- Add Swift unit tests
- Add Swift example code for operation based compression/decompression
- Fix compression ratio of NOZDecompressResult

### 1.6.5  (Oct 4, 2015) - Nolan O'Brien

- Fix bug in Apple Encoder/Decoder
- Add convenience NSInputStream for compressed streams (could be optimized further)

### 1.6.0  (Sep 26, 2015) - Nolan O'Brien

- Rename NOZCompressionEncoder/Decoder to NOZEncoder/Decoder
- Add category to NSData for easy compression/decompression of data

### 1.5.1  (Sep 13, 2015) - Nolan O'Brien

- Update docs
- Minor cleanup

### 1.5.0  (Sep 11, 2015) - Nolan O'Brien

- Simplify compression encoders/decoders to only return a BOOL and not an NSError
- Convert project to Xcode 7
- Use container generics throughout
- Add LZMA encoder/decoder to "extras"
  - Includes unit tests
  - iOS 9+ and OS X 10.11+ only
  - Not included in libs/frameworks, you can include these files to add LZMA support though

### 1.4.1  (Sep 6, 2015) - Nolan O'Brien

- Fix race condition with cancelling
- Change runStep: method to runStep:error: for better consistency and Swift compatibility

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
