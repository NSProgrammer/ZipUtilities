//
//  NOZXZStandardCoderTests.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 11/16/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#import "NOZXZStandardCompressionCoder.h"

@import XCTest;
@import ZipUtilities;

#define NOZCompressionMethodZStandard               (100)
#define NOZCompressionMethodZStandardWithDictionary (200)

@interface NOZXZStandardCoderTests : XCTestCase
@end

@implementation NOZXZStandardCoderTests

+ (void)setUp
{
    NSString *dictionaryDataFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"book" ofType:@"zstd_dict"];
    NSData *dictionaryData = [NSData dataWithContentsOfFile:dictionaryDataFile];

    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    // No dictionary coder

    [library setEncoder:[NOZXZStandardCompressionCoder encoder] forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:[NOZXZStandardCompressionCoder decoder] forMethod:NOZCompressionMethodZStandard];

    // Dictionary coder

    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:dictionaryData] forMethod:NOZCompressionMethodZStandardWithDictionary];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:dictionaryData] forMethod:NOZCompressionMethodZStandardWithDictionary];
}

+ (void)tearDown
{
    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    // No dictionary coder

    [library setEncoder:nil forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandard];

    // Dictionary coder

    [library setEncoder:nil forMethod:NOZCompressionMethodZStandardWithDictionary];
    [library setDecoder:nil forMethod:NOZCompressionMethodZStandardWithDictionary];
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

- (void)runCodingWithMethod:(NOZCompressionMethod)method level:(NOZCompressionLevel)level
{
    if (![[self class] canTestWithMethod:method]) {
        return;
    }

    NSString *zipDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:zipDirectory withIntermediateDirectories:YES attributes:NULL error:NULL];
    NSString *sourceFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSData *sourceData = [NSData dataWithContentsOfFile:sourceFile];
    __block NSData *unzippedData = nil;

    // Zip

    NOZFileZipEntry *entry = [[NOZFileZipEntry alloc] initWithFilePath:sourceFile];
    entry.compressionMethod = method;
    entry.compressionLevel = level;
    NSString *zipFileName = [NSString stringWithFormat:@"Aesop.%u.zip", method];
    NOZZipper *zipper = [[NOZZipper alloc] initWithZipFile:[zipDirectory stringByAppendingPathComponent:zipFileName]];
    XCTAssertTrue([zipper openWithMode:NOZZipperModeCreate error:NULL]);
    XCTAssertTrue([zipper addEntry:entry progressBlock:NULL error:NULL]);
    XCTAssertTrue([zipper closeAndReturnError:NULL]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:zipper.zipFilePath]);

    // Unzip

    NOZUnzipper *unzipper = [[NOZUnzipper alloc] initWithZipFile:zipper.zipFilePath];
    XCTAssertTrue([unzipper openAndReturnError:NULL]);
    XCTAssertTrue([unzipper readCentralDirectoryAndReturnError:NULL]);
    [unzipper enumerateManifestEntriesUsingBlock:^(NOZCentralDirectoryRecord *record, NSUInteger index, BOOL *stop) {
        XCTAssertTrue([unzipper saveRecord:record toDirectory:zipDirectory options:NOZUnzipperSaveRecordOptionOverwriteExisting progressBlock:NULL error:NULL]);
        NSString *unzippedFilePath = [zipDirectory stringByAppendingPathComponent:record.name];
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:unzippedFilePath]);
        if ([record.name isEqualToString:sourceFile.lastPathComponent]) {
            unzippedData = [NSData dataWithContentsOfFile:unzippedFilePath];
        }
    }];
    XCTAssertTrue([unzipper closeAndReturnError:NULL]);
    XCTAssertEqualObjects(unzippedData, sourceData);

    // Cleanup

    [[NSFileManager defaultManager] removeItemAtPath:zipDirectory error:NULL];
}

- (void)runCategoryCodingTest:(NOZCompressionMethod)method level:(NOZCompressionLevel)level
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
    BOOL isRaw = NOZCompressionMethodNone == method;
    NSTimeInterval compressionInterval, decompressionInterval;
    double compressionRatio;

    for (NSUInteger i = 0; i < 2; i++) {
        if (i == 0) {
            CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
            compressedData = [sourceData noz_dataByCompressing:encoder
                                              compressionLevel:level];
            compressionInterval = CFAbsoluteTimeGetCurrent() - start;
            compressionRatio = (double)sourceData.length / (double)compressedData.length;
        } else {

            NSInputStream *sourceStream = (i == 1) ? [NSInputStream inputStreamWithFileAtPath:sourceFile] : [NSInputStream inputStreamWithData:sourceData];
            sourceStream = [NSInputStream noz_compressedInputStream:sourceStream withEncoder:encoder compressionLevel:level];

            const size_t bufferSize = NSPageSize();
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

            XCTAssertFalse(sourceStream.hasBytesAvailable);
            XCTAssertGreaterThan(compressedDataM.length, (NSUInteger)0);
            compressedData = (!sourceStream.hasBytesAvailable && compressedDataM.length > 0) ? [compressedDataM copy] : nil;
        }

        if (encoder) {
            XCTAssertNotNil(compressedData);
            if (!isRaw) {
                XCTAssertLessThan(compressedData.length, sourceData.length);
                XCTAssertNotEqualObjects(compressedData, sourceData);
            } else {
                XCTAssertEqual(compressedData.length, sourceData.length);
                XCTAssertEqualObjects(compressedData, sourceData);
            }

            CFAbsoluteTime startDecompress = CFAbsoluteTimeGetCurrent();
            decompressedData = [compressedData noz_dataByDecompressing:decoder];
            decompressionInterval = CFAbsoluteTimeGetCurrent() - startDecompress;

            if (decoder) {
                XCTAssertNotNil(decompressedData);
                XCTAssertEqual(decompressedData.length, sourceData.length);
                XCTAssertEqualObjects(decompressedData, sourceData);
            } else {
                XCTAssertNil(decompressedData);
            }
        } else {
            XCTAssertNil(compressedData);
        }

        NSLog(@"%u @ %2i: c=%.3fs, d=%.3fs, r=%.3f", method, level, compressionInterval, decompressionInterval, compressionRatio);
    }
}

- (void)testZStandard
{
    for (NOZCompressionLevel level = -1 /*default*/; level <= NOZCompressionLevelMax; level++) {
        [self runCodingWithMethod:NOZCompressionMethodZStandard level:level];
        [self runCategoryCodingTest:NOZCompressionMethodZStandard level:level];
    }

    for (NOZCompressionLevel level = -1 /*default*/; level <= NOZCompressionLevelMax; level++) {
        [self runCodingWithMethod:NOZCompressionMethodZStandardWithDictionary level:level];
        [self runCategoryCodingTest:NOZCompressionMethodZStandardWithDictionary level:level];
    }
}

@end
