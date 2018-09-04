//
//  NOZComparisonTest.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 11/16/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#import "NOZXAppleCompressionCoder.h"
#import "NOZXBrotliCompressionCoder.h"
#import "NOZXZStandardCompressionCoder.h"

#import "ZipUtilities.h"

@import XCTest;

#define NOZCompressionMethodZStandard       (100)
#define NOZCompressionMethodZStandard_D128  (101)
#define NOZCompressionMethodZStandard_D256  (102)
#define NOZCompressionMethodZStandard_D512  (104)
#define NOZCompressionMethodZStandard_D1024 (108)
#define NOZCompressionMethodZStandard_DBOOK (190)

#define NOZCompressionMethodBrotli          (200)

#define ZSTD_LEVEL(level)       NOZCompressionLevelFromCustomEncoderLevel(1, 22, (level))
#define BROTLI_LEVEL(level)     NOZCompressionLevelFromCustomEncoderLevel(0, 11, (level))
#define DEFLATE_LEVEL(level)    NOZCompressionLevelFromCustomEncoderLevel(1, 9, (level))

@interface NOZComparisonTest : XCTestCase
@end

@implementation NOZComparisonTest

+ (void)setUp
{
    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    // ZSTD

    NSString *dbookFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"book" ofType:@"zstd_dict"];
    NSData *dbookData = [NSData dataWithContentsOfFile:dbookFile];
    NSString *d128File = [[NSBundle bundleForClass:[self class]] pathForResource:@"htl.128" ofType:@"zstd_dict"];
    NSData *d128Data = [NSData dataWithContentsOfFile:d128File];
    NSString *d256File = [[NSBundle bundleForClass:[self class]] pathForResource:@"htl.256" ofType:@"zstd_dict"];
    NSData *d256Data = [NSData dataWithContentsOfFile:d256File];
    NSString *d512File = [[NSBundle bundleForClass:[self class]] pathForResource:@"htl.512" ofType:@"zstd_dict"];
    NSData *d512Data = [NSData dataWithContentsOfFile:d512File];
    NSString *d1024File = [[NSBundle bundleForClass:[self class]] pathForResource:@"htl.1024" ofType:@"zstd_dict"];
    NSData *d1024Data = [NSData dataWithContentsOfFile:d1024File];

    // ZSTD - No dictionary coder

    [library setEncoder:[NOZXZStandardCompressionCoder encoder] forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:[NOZXZStandardCompressionCoder decoder] forMethod:NOZCompressionMethodZStandard];

    // ZSTD - Dictionary coders

    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:dbookData] forMethod:NOZCompressionMethodZStandard_DBOOK];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:dbookData] forMethod:NOZCompressionMethodZStandard_DBOOK];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d128Data] forMethod:NOZCompressionMethodZStandard_D128];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d128Data] forMethod:NOZCompressionMethodZStandard_D128];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d256Data] forMethod:NOZCompressionMethodZStandard_D256];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d256Data] forMethod:NOZCompressionMethodZStandard_D256];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d512Data] forMethod:NOZCompressionMethodZStandard_D512];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d512Data] forMethod:NOZCompressionMethodZStandard_D512];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d1024Data] forMethod:NOZCompressionMethodZStandard_D1024];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d1024Data] forMethod:NOZCompressionMethodZStandard_D1024];

    // Brotli

    [library setEncoder:[NOZXBrotliCompressionCoder encoder] forMethod:NOZCompressionMethodBrotli];
    [library setDecoder:[NOZXBrotliCompressionCoder decoder] forMethod:NOZCompressionMethodBrotli];

    if ([NOZXAppleCompressionCoder isSupported]) {

        // LZMA

        [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZMA] forMethod:NOZCompressionMethodLZMA];
        [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZMA] forMethod:NOZCompressionMethodLZMA];

        // LZ4

        [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZ4] forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];
        [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZ4] forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];

        // Apple LZFSE

        [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZFSE] forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
        [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZFSE] forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
        
    }
}

+ (void)tearDown
{
    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    // ZSTD - No dictionary coder

    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard];

    // ZSTD - Dictionary coders

    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard_DBOOK];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard_DBOOK];
    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard_D128];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard_D128];
    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard_D256];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard_D256];
    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard_D512];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard_D512];
    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard_D1024];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard_D1024];

    // Brotli

    [library setEncoder:nil forMethod:NOZCompressionMethodBrotli];
    [library setDecoder:nil forMethod:NOZCompressionMethodBrotli];

    if ([NOZXAppleCompressionCoder isSupported]) {

        // LZMA

        [library setEncoder:nil forMethod:NOZCompressionMethodLZMA];
        [library setDecoder:nil forMethod:NOZCompressionMethodLZMA];

        // LZ4

        [library setEncoder:nil forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];
        [library setDecoder:nil forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];

        // Apple LZFSE

        [library setEncoder:nil forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
        [library setDecoder:nil forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
        
    }
}

+ (BOOL)canTestWithMethod:(NOZCompressionMethod)method
{
    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    id<NOZEncoder> checkEncoder = [library encoderForMethod:method];
    id<NOZDecoder> checkDecoder = [library decoderForMethod:method];

    if (!checkEncoder || !checkDecoder) {
        return NO;
    }
    
    return YES;
}

- (void)runCategoryCodingTest:(NSString *)methodName method:(NOZCompressionMethod)method level:(NOZCompressionLevel)level data:(NSData *)sourceData
{
    if (![[self class] canTestWithMethod:method]) {
        return;
    }

    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    NSData *compressedData;
    NSData *decompressedData;
    id<NOZEncoder> encoder = [library encoderForMethod:method];
    id<NOZDecoder> decoder = [library decoderForMethod:method];
    NSTimeInterval compressionInterval, decompressionInterval;
    double compressionRatio;

    CFAbsoluteTime startCompress = CFAbsoluteTimeGetCurrent();
    compressedData = [sourceData noz_dataByCompressing:encoder compressionLevel:level];
    compressionInterval = CFAbsoluteTimeGetCurrent() - startCompress;
    compressionRatio = (double)sourceData.length / (double)compressedData.length;

    CFAbsoluteTime startDecompress = CFAbsoluteTimeGetCurrent();
    decompressedData = [compressedData noz_dataByDecompressing:decoder];
    decompressionInterval = CFAbsoluteTimeGetCurrent() - startDecompress;

    printf("%s: c=%.5fs, d=%.5fs, r=%.3f\n", methodName.UTF8String, compressionInterval, decompressionInterval, compressionRatio);

    XCTAssertEqualObjects(decompressedData, sourceData);
}

- (void)runCodingWithMethod:(NOZCompressionMethod)method
{
    if (![[self class] canTestWithMethod:method]) {
        return;
    }

    id<NOZEncoder> encoder = [[NOZCompressionLibrary sharedInstance] encoderForMethod:method];
    const NSUInteger compressionLevels = NOZCompressionLevelsForEncoder(encoder);

#define FORMAT @"Method=%tu, Level=%tu, error=%@", (NSUInteger)method, (NSUInteger)cLevel, error

    for (NSUInteger cLevel = 0; cLevel < compressionLevels; cLevel++) {
        NOZCompressionLevel level = (compressionLevels > 1) ? (float)(cLevel) / (float)(compressionLevels - 1) : NOZCompressionLevelMax;
        @autoreleasepool {
            NSString *zipDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
            [[NSFileManager defaultManager] createDirectoryAtPath:zipDirectory withIntermediateDirectories:YES attributes:NULL error:NULL];
            NSString *sourceFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
            NSData *sourceData = [NSData dataWithContentsOfFile:sourceFile];
            __block NSData *unzippedData = nil;
            __block NSError *error = nil;

            // Zip

            NOZFileZipEntry *entry = [[NOZFileZipEntry alloc] initWithFilePath:sourceFile];
            entry.compressionMethod = method;
            entry.compressionLevel = level;
            NSString *zipFileName = [NSString stringWithFormat:@"Aesop.%u.zip", method];
            NOZZipper *zipper = [[NOZZipper alloc] initWithZipFile:[zipDirectory stringByAppendingPathComponent:zipFileName]];
            XCTAssertTrue([zipper openWithMode:NOZZipperModeCreate error:&error], FORMAT);
            XCTAssertTrue([zipper addEntry:entry progressBlock:NULL error:&error], FORMAT);
            XCTAssertTrue([zipper closeAndReturnError:&error], FORMAT);
            XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:zipper.zipFilePath], FORMAT);

            // Unzip

            NOZUnzipper *unzipper = [[NOZUnzipper alloc] initWithZipFile:zipper.zipFilePath];
            XCTAssertTrue([unzipper openAndReturnError:&error], FORMAT);
            XCTAssertTrue([unzipper readCentralDirectoryAndReturnError:&error], FORMAT);
            [unzipper enumerateManifestEntriesUsingBlock:^(NOZCentralDirectoryRecord *record, NSUInteger index, BOOL *stop) {
                XCTAssertTrue([unzipper saveRecord:record
                                       toDirectory:zipDirectory
                                           options:NOZUnzipperSaveRecordOptionOverwriteExisting
                                     progressBlock:NULL
                                             error:&error], FORMAT);
                NSString *unzippedFilePath = [zipDirectory stringByAppendingPathComponent:record.name];
                XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:unzippedFilePath], FORMAT);
                if ([record.name isEqualToString:sourceFile.lastPathComponent]) {
                    unzippedData = [NSData dataWithContentsOfFile:unzippedFilePath];
                }
            }];
            XCTAssertTrue([unzipper closeAndReturnError:&error], FORMAT);
            XCTAssertTrue([unzippedData isEqualToData:sourceData], @"data don't equate.  d1.length=%tu, d2.length=%tu, Method=%tu, Level=%tu", unzippedData.length, sourceData.length, (NSUInteger)method, (NSUInteger)level);
            
            // Cleanup
            
            [[NSFileManager defaultManager] removeItemAtPath:zipDirectory error:NULL];
        }
    }

#undef FORMAT
}

- (void)runCategoryCodingTest:(NOZCompressionMethod)method
{
    if (![[self class] canTestWithMethod:method]) {
        return;
    }

    NSString *sourceFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSData *sourceData = [NSData dataWithContentsOfFile:sourceFile];
    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    NSData *compressedData;
    NSData *decompressedData;
    id<NOZEncoder> encoder = [library encoderForMethod:method];
    id<NOZDecoder> decoder = [library decoderForMethod:method];
    const BOOL isRaw = NOZCompressionMethodNone == method;
    const NSUInteger compressionLevels = NOZCompressionLevelsForEncoder(encoder);

#define FORMAT @"Method=%tu, Level=%tu, i=%tu", (NSUInteger)method, (NSUInteger)cLevel, (NSUInteger)i

    for (NSUInteger cLevel = 0; cLevel < compressionLevels; cLevel++) {
        NOZCompressionLevel level = (compressionLevels > 1) ? (float)(cLevel) / (float)(compressionLevels - 1) : NOZCompressionLevelMax;
        @autoreleasepool {
            for (NSUInteger i = 0; i < 2; i++) {
                if (i == 0) {
                    compressedData = [sourceData noz_dataByCompressing:encoder
                                                      compressionLevel:level];
                } else {
                    continue;
                    NSInputStream *sourceStream = (i == 1) ? [NSInputStream inputStreamWithFileAtPath:sourceFile] : [NSInputStream inputStreamWithData:sourceData];
                    sourceStream = [NSInputStream noz_compressedInputStream:sourceStream
                                                                withEncoder:encoder
                                                           compressionLevel:level];

                    const size_t bufferSize = 4 * NSPageSize();
                    Byte buffer[bufferSize];
                    NSMutableData *compressedDataM = [NSMutableData data];

                    [sourceStream open];
                    NSInteger bytesRead = 1;
                    while (sourceStream.hasBytesAvailable && bytesRead > 0) {
                        bytesRead = [sourceStream read:buffer maxLength:bufferSize];
                        if (bytesRead > 0) {
                            [compressedDataM appendBytes:buffer length:(NSUInteger)bytesRead];
                        }
                    }
                    [sourceStream close];

                    XCTAssertFalse(sourceStream.hasBytesAvailable, FORMAT);
                    XCTAssertGreaterThan(compressedDataM.length, (NSUInteger)0, FORMAT);
                    compressedData = (!sourceStream.hasBytesAvailable && compressedDataM.length > 0) ? [compressedDataM copy] : nil;
                }

                if (encoder) {
                    XCTAssertNotNil(compressedData, FORMAT);
                    if (!isRaw) {
                        XCTAssertLessThan(compressedData.length, sourceData.length, FORMAT);
                        XCTAssertFalse([compressedData isEqualToData:sourceData], FORMAT);
                    } else {
                        XCTAssertEqual(compressedData.length, sourceData.length, FORMAT);
                        XCTAssertTrue([compressedData isEqualToData:sourceData], FORMAT);
                    }

                    decompressedData = [compressedData noz_dataByDecompressing:decoder];

                    if (decoder) {
                        XCTAssertNotNil(decompressedData, FORMAT);
                        XCTAssertEqual(decompressedData.length, sourceData.length, FORMAT);
                        XCTAssertTrue([decompressedData isEqualToData:sourceData], FORMAT);
                    } else {
                        XCTAssertNil(decompressedData, FORMAT);
                    }
                } else {
                    XCTAssertNil(compressedData, FORMAT);
                }

                compressedData = nil;
                decompressedData = nil;
            }
        }
    }

#undef FORMAT
}

#pragma mark Individual Codecs

- (void)testDeflate_DefaultDefault
{
    [self runCodingWithMethod:NOZCompressionMethodDeflate];
    [self runCategoryCodingTest:NOZCompressionMethodDeflate];
}

- (void)testDeflate_CustomCustom
{
    if (![NOZXAppleCompressionCoder isSupported]) {
        return;
    }

    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    id<NOZEncoder> originalEncoder = [library encoderForMethod:NOZCompressionMethodDeflate];
    id<NOZDecoder> originalDecoder = [library decoderForMethod:NOZCompressionMethodDeflate];

    [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_ZLIB] forMethod:NOZCompressionMethodDeflate];
    [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_ZLIB] forMethod:NOZCompressionMethodDeflate];

    [self runCodingWithMethod:NOZCompressionMethodDeflate];
    [self runCategoryCodingTest:NOZCompressionMethodDeflate];

    // Return to original

    [library setEncoder:originalEncoder forMethod:NOZCompressionMethodDeflate];
    [library setDecoder:originalDecoder forMethod:NOZCompressionMethodDeflate];
}

- (void)testDeflate_DefaultCustom
{
    if (![NOZXAppleCompressionCoder isSupported]) {
        return;
    }

    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    id<NOZDecoder> originalDecoder = [library decoderForMethod:NOZCompressionMethodDeflate];

    // Original Encoder / Custom Decoder

    [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_ZLIB] forMethod:NOZCompressionMethodDeflate];

    [self runCodingWithMethod:NOZCompressionMethodDeflate];
    [self runCategoryCodingTest:NOZCompressionMethodDeflate];

    // Reset to original

    [library setDecoder:originalDecoder forMethod:NOZCompressionMethodDeflate];
}

- (void)testDeflate_CustomDefault
{
    if (![NOZXAppleCompressionCoder isSupported]) {
        return;
    }

    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    id<NOZEncoder> originalEncoder = [library encoderForMethod:NOZCompressionMethodDeflate];

    // Custom Encoder / Original Decoder

    [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_ZLIB] forMethod:NOZCompressionMethodDeflate];

    [self runCodingWithMethod:NOZCompressionMethodDeflate];
    [self runCategoryCodingTest:NOZCompressionMethodDeflate];

    // Reset encoder

    [library setEncoder:originalEncoder forMethod:NOZCompressionMethodDeflate];
}

- (void)testLZMACoding
{
    [self runCodingWithMethod:NOZCompressionMethodLZMA];
    [self runCategoryCodingTest:NOZCompressionMethodLZMA];
}

- (void)testLZ4Coding
{
    [self runCodingWithMethod:(NOZCompressionMethod)COMPRESSION_LZ4];
    [self runCategoryCodingTest:(NOZCompressionMethod)COMPRESSION_LZ4];
}

- (void)testLZFSECoding
{
    [self runCodingWithMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
    [self runCategoryCodingTest:(NOZCompressionMethod)COMPRESSION_LZFSE];
}

- (void)testRawCoding
{
    [self runCodingWithMethod:NOZCompressionMethodNone];
    [self runCategoryCodingTest:NOZCompressionMethodNone];
}

- (void)testZSTD
{
    [self runCodingWithMethod:NOZCompressionMethodZStandard];
    [self runCategoryCodingTest:NOZCompressionMethodZStandard];
}

//- (void)testZSTD_128KB_HTL_JSON_DICT
//{
//    [self runCodingWithMethod:NOZCompressionMethodZStandard_D128];
//    [self runCategoryCodingTest:NOZCompressionMethodZStandard_D128];
//}

- (void)testZSTD_256KB_HTL_JSON_DICT
{
    [self runCodingWithMethod:NOZCompressionMethodZStandard_D256];
    [self runCategoryCodingTest:NOZCompressionMethodZStandard_D256];
}

//- (void)testZSTD_512KB_HTL_JSON_DICT
//{
//    [self runCodingWithMethod:NOZCompressionMethodZStandard_D512];
//    [self runCategoryCodingTest:NOZCompressionMethodZStandard_D512];
//}

//- (void)testZSTD_1024KB_HTL_JSON_DICT
//{
//    [self runCodingWithMethod:NOZCompressionMethodZStandard_D1024];
//    [self runCategoryCodingTest:NOZCompressionMethodZStandard_D1024];
//}

- (void)testZSTD_BOOK_DICT
{
    [self runCodingWithMethod:NOZCompressionMethodZStandard_DBOOK];
    [self runCategoryCodingTest:NOZCompressionMethodZStandard_DBOOK];
}

- (void)testBrotli
{
    [self runCodingWithMethod:NOZCompressionMethodBrotli];
    [self runCategoryCodingTest:NOZCompressionMethodBrotli];
}

#pragma mark Comparison Tests

- (void)test_CompressionSpeeds
{
    NSString *htlFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"timeline" ofType:@"json"];
    NSString *aesopFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSString *ca1File = [[NSBundle bundleForClass:[self class]] pathForResource:@"maniac-mansion/ca1" ofType:@"jpeg"];

    NSArray<NSString *> *sources = @[
                                     htlFile,
                                     aesopFile,
                                     ca1File,
                                     ];

    NSArray<NSArray *> *testCases = @[
                                      @[ @"zstd.1      ", @(NOZCompressionMethodZStandard),      @(NOZCompressionLevelMin) ],
                                      @[ @"zstd.book.1 ", @(NOZCompressionMethodZStandard_DBOOK),@(NOZCompressionLevelMin) ],
                                      // @[ @"zstd.128.1  ", @(NOZCompressionMethodZStandard_D128), @(NOZCompressionLevelMin) ],
                                      @[ @"zstd.256.1  ", @(NOZCompressionMethodZStandard_D256), @(NOZCompressionLevelMin) ],
                                      // @[ @"zstd.512.1  ", @(NOZCompressionMethodZStandard_D512), @(NOZCompressionLevelMin) ],
                                      // @[ @"zstd.1024.1 ", @(NOZCompressionMethodZStandard_D1024),@(NOZCompressionLevelMin) ],
                                      @[ @"zstd.7      ", @(NOZCompressionMethodZStandard),      @(ZSTD_LEVEL(7)) ],
                                      @[ @"zstd.book.7 ", @(NOZCompressionMethodZStandard_DBOOK),@(ZSTD_LEVEL(7)) ],
                                      // @[ @"zstd.128.7  ", @(NOZCompressionMethodZStandard_D128), @(ZSTD_LEVEL(7)) ],
                                      @[ @"zstd.256.7  ", @(NOZCompressionMethodZStandard_D256), @(ZSTD_LEVEL(7)) ],
                                      // @[ @"zstd.512.7  ", @(NOZCompressionMethodZStandard_D512), @(ZSTD_LEVEL(7)) ],
                                      // @[ @"zstd.1024.7 ", @(NOZCompressionMethodZStandard_D1024),@(ZSTD_LEVEL(7)) ],
                                      @[ @"zstd.14     ", @(NOZCompressionMethodZStandard),      @(ZSTD_LEVEL(14)) ],
                                      @[ @"zstd.book.14", @(NOZCompressionMethodZStandard_DBOOK),@(ZSTD_LEVEL(14)) ],
                                      // @[ @"zstd.128.14 ", @(NOZCompressionMethodZStandard_D128), @(ZSTD_LEVEL(14)) ],
                                      @[ @"zstd.256.14 ", @(NOZCompressionMethodZStandard_D256), @(ZSTD_LEVEL(14)) ],
                                      // @[ @"zstd.512.14 ", @(NOZCompressionMethodZStandard_D512), @(ZSTD_LEVEL(14)) ],
                                      // @[ @"zstd.1024.14", @(NOZCompressionMethodZStandard_D1024),@(ZSTD_LEVEL(14)) ],
                                      @[ @"zstd.22     ", @(NOZCompressionMethodZStandard),      @(NOZCompressionLevelMax) ],
                                      @[ @"zstd.book.22", @(NOZCompressionMethodZStandard_DBOOK),@(NOZCompressionLevelMax) ],
                                      // @[ @"zstd.128.22 ", @(NOZCompressionMethodZStandard_D128), @(NOZCompressionLevelMax) ],
                                      @[ @"zstd.256.22 ", @(NOZCompressionMethodZStandard_D256), @(NOZCompressionLevelMax) ],
                                      // @[ @"zstd.512.22 ", @(NOZCompressionMethodZStandard_D512), @(NOZCompressionLevelMax) ],
                                      // @[ @"zstd.1024.22", @(NOZCompressionMethodZStandard_D1024),@(NOZCompressionLevelMax) ],
                                      @[ @"bro.1       ", @(NOZCompressionMethodBrotli), @(NOZCompressionLevelMin) ],
                                      @[ @"bro.7       ", @(NOZCompressionMethodBrotli), @(ZSTD_LEVEL(7)) ],
                                      @[ @"bro.11      ", @(NOZCompressionMethodBrotli), @(NOZCompressionLevelMax) ],
                                      @[ @"lzma.6      ", @(NOZCompressionMethodLZMA),           @(NOZCompressionLevelMax) ],
                                      @[ @"lz4         ", @(COMPRESSION_LZ4),                    @(NOZCompressionLevelMax) ],
                                      @[ @"lzfse       ", @(COMPRESSION_LZFSE),                  @(NOZCompressionLevelMax) ],
                                      @[ @"deflate.1   ", @(NOZCompressionMethodDeflate),        @(NOZCompressionLevelMin) ],
                                      @[ @"deflate.6   ", @(NOZCompressionMethodDeflate),        @(ZSTD_LEVEL(6)) ],
                                      @[ @"deflate.9   ", @(NOZCompressionMethodDeflate),        @(NOZCompressionLevelMax) ],
                                      ];
    
    for (NSString *sourceFile in sources) {
        NSData *sourceData = [NSData dataWithContentsOfFile:sourceFile];
        printf("\n");
        printf("%s\n", sourceFile.lastPathComponent.UTF8String);
        printf("--------------------------------\n");
        
        for (NSArray *testCase in testCases) {
            [self runCategoryCodingTest:testCase[0] method:(NOZCompressionMethod)[testCase[1] intValue] level:(NOZCompressionLevel)[testCase[2] floatValue] data:sourceData];
        }
    }
    
}

@end
