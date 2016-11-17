//
//  NOZComparisonTest.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 11/16/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#import "NOZXAppleCompressionCoder.h"
#import "NOZXZStandardCompressionCoder.h"

@import XCTest;
@import ZipUtilities;

#define NOZCompressionMethodZStandard       (100)
#define NOZCompressionMethodZStandard_D128  (101)
#define NOZCompressionMethodZStandard_D256  (102)
#define NOZCompressionMethodZStandard_D512  (104)
#define NOZCompressionMethodZStandard_D1024 (108)
#define NOZCompressionMethodZStandard_DBOOK (190)

@interface NOZComparisonTest : XCTestCase
@end

@implementation NOZComparisonTest

+ (void)setUp
{
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

    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    // No dictionary coder

    [library setEncoder:[NOZXZStandardCompressionCoder encoder] forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:[NOZXZStandardCompressionCoder decoder] forMethod:NOZCompressionMethodZStandard];

    // Dictionary coders

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

    // No dictionary coder

    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard];

    // Dictionary coders

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

- (void)testCompressionSpeeds
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
        @[ @"zstd.2      ", @(NOZCompressionMethodZStandard),      @(NOZCompressionLevelMin) ],
        @[ @"zstd.book.2 ", @(NOZCompressionMethodZStandard_DBOOK),@(NOZCompressionLevelMin) ],
        @[ @"zstd.128.2  ", @(NOZCompressionMethodZStandard_D128), @(NOZCompressionLevelMin) ],
        @[ @"zstd.256.2  ", @(NOZCompressionMethodZStandard_D256), @(NOZCompressionLevelMin) ],
        @[ @"zstd.512.2  ", @(NOZCompressionMethodZStandard_D512), @(NOZCompressionLevelMin) ],
        @[ @"zstd.1024.2 ", @(NOZCompressionMethodZStandard_D1024),@(NOZCompressionLevelMin) ],
        @[ @"zstd.7      ", @(NOZCompressionMethodZStandard),      @(NOZCompressionLevelLow) ],
        @[ @"zstd.book.7 ", @(NOZCompressionMethodZStandard_DBOOK),@(NOZCompressionLevelLow) ],
        @[ @"zstd.128.7  ", @(NOZCompressionMethodZStandard_D128), @(NOZCompressionLevelLow) ],
        @[ @"zstd.256.7  ", @(NOZCompressionMethodZStandard_D256), @(NOZCompressionLevelLow) ],
        @[ @"zstd.512.7  ", @(NOZCompressionMethodZStandard_D512), @(NOZCompressionLevelLow) ],
        @[ @"zstd.1024.7 ", @(NOZCompressionMethodZStandard_D1024),@(NOZCompressionLevelLow) ],
        @[ @"zstd.15     ", @(NOZCompressionMethodZStandard),      @(NOZCompressionLevelMediumHigh) ],
        @[ @"zstd.book.15", @(NOZCompressionMethodZStandard_DBOOK),@(NOZCompressionLevelMediumHigh) ],
        @[ @"zstd.128.15 ", @(NOZCompressionMethodZStandard_D128), @(NOZCompressionLevelMediumHigh) ],
        @[ @"zstd.256.15 ", @(NOZCompressionMethodZStandard_D256), @(NOZCompressionLevelMediumHigh) ],
        @[ @"zstd.512.15 ", @(NOZCompressionMethodZStandard_D512), @(NOZCompressionLevelMediumHigh) ],
        @[ @"zstd.1024.15", @(NOZCompressionMethodZStandard_D1024),@(NOZCompressionLevelMediumHigh) ],
        @[ @"zstd.22     ", @(NOZCompressionMethodZStandard),      @(NOZCompressionLevelMax) ],
        @[ @"zstd.book.22", @(NOZCompressionMethodZStandard_DBOOK),@(NOZCompressionLevelMax) ],
        @[ @"zstd.128.22 ", @(NOZCompressionMethodZStandard_D128), @(NOZCompressionLevelMax) ],
        @[ @"zstd.256.22 ", @(NOZCompressionMethodZStandard_D256), @(NOZCompressionLevelMax) ],
        @[ @"zstd.512.22 ", @(NOZCompressionMethodZStandard_D512), @(NOZCompressionLevelMax) ],
        @[ @"zstd.1024.22", @(NOZCompressionMethodZStandard_D1024),@(NOZCompressionLevelMax) ],
        @[ @"lzma.6      ", @(NOZCompressionMethodLZMA),           @(NOZCompressionLevelMax) ],
        @[ @"lz4         ", @(COMPRESSION_LZ4),                    @(NOZCompressionLevelMax) ],
        @[ @"lzfse       ", @(COMPRESSION_LZFSE),                  @(NOZCompressionLevelMax) ],
        @[ @"deflate.1   ", @(NOZCompressionMethodDeflate),        @(NOZCompressionLevelMin) ],
        @[ @"deflate.6   ", @(NOZCompressionMethodDeflate),        @(NOZCompressionLevelMediumHigh) ],
        @[ @"deflate.9   ", @(NOZCompressionMethodDeflate),        @(NOZCompressionLevelMax) ],
                                     ];

    for (NSString *sourceFile in sources) {
        NSData *sourceData = [NSData dataWithContentsOfFile:sourceFile];
        printf("\n");
        printf("%s\n", sourceFile.lastPathComponent.UTF8String);
        printf("--------------------------------\n");

        for (NSArray *testCase in testCases) {
            [self runCategoryCodingTest:testCase[0] method:(NOZCompressionMethod)[testCase[1] intValue] level:(NOZCompressionLevel)[testCase[2] intValue] data:sourceData];
        }
    }

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

@end
