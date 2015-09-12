//
//  NOZXLMZACoderTests.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/11/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ZipUtilities.h"
#import "NOZXLZMACoders.h"

#if COMPRESSION_LIB_AVAILABLE

@interface NOZXLMZACoderTests : XCTestCase

@end

@implementation NOZXLMZACoderTests

+ (void)setUp
{
    if ([NOZXLZMAEncoder isSupported]) {
        NOZUpdateCompressionMethodEncoder(NOZCompressionMethodLZMA, [[NOZXLZMAEncoder alloc] init]);
    }
    if ([NOZXLZMADecoder isSupported]) {
        NOZUpdateCompressionMethodDecoder(NOZCompressionMethodLZMA, [[NOZXLZMADecoder alloc] init]);
    }
}

+ (void)tearDown
{
    NOZUpdateCompressionMethodEncoder(NOZCompressionMethodLZMA, nil);
    NOZUpdateCompressionMethodDecoder(NOZCompressionMethodLZMA, nil);
}

- (void)testLZMACoding
{
    if (![NOZXLZMAEncoder isSupported]) {
        return;
    }

    NSString *zipDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:zipDirectory withIntermediateDirectories:YES attributes:NULL error:NULL];
    NSString *sourceFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSData *sourceData = [NSData dataWithContentsOfFile:sourceFile];
    __block NSData *unzippedData = nil;

    // Zip

    NOZFileZipEntry *entry = [[NOZFileZipEntry alloc] initWithFilePath:sourceFile];
    entry.compressionMethod = NOZCompressionMethodLZMA;
    NOZZipper *zipper = [[NOZZipper alloc] initWithZipFile:[zipDirectory stringByAppendingPathComponent:@"Aesop.zip"]];
    XCTAssertTrue([zipper openWithMode:NOZZipperModeCreate error:NULL]);
    XCTAssertTrue([zipper addEntry:entry progressBlock:NULL error:NULL]);
    XCTAssertTrue([zipper closeAndReturnError:NULL]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:zipper.zipFilePath]);

    // Unzip

    NOZUnzipper *unzipper = [[NOZUnzipper alloc] initWithZipFile:zipper.zipFilePath];
    XCTAssertTrue([unzipper openAndReturnError:NULL]);
    XCTAssertTrue([unzipper readCentralDirectoryAndReturnError:NULL]);
    [unzipper enumerateManifestEntriesUsingBlock:^(NOZCentralDirectoryRecord *record, NSUInteger index, BOOL *stop) {
        XCTAssertTrue([unzipper saveRecord:record toDirectory:zipDirectory shouldOverwrite:YES progressBlock:NULL error:NULL]);
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

@end

#endif
