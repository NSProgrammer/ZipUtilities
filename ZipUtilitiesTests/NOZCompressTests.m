//
//  NOZCompressTests.m
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

@import Foundation;
@import XCTest;

#import "NOZCompress.h"

//#define TESTLOG(...) NSLog(__VA_ARGS__)
#define TESTLOG(...) ((void)0)

static NSOperationQueue *sQueue = nil;

@interface NOZCompressRequest (TestExposure)
- (nonnull NSMutableArray *)mutableEntries;
@end

@interface NOZCompressTests : XCTestCase <NOZCompressDelegate>
@end

@implementation NOZCompressTests

+ (void)setUp
{
    dispatch_queue_t q = dispatch_queue_create("Zip.GCD.Queue", DISPATCH_QUEUE_SERIAL);
    sQueue = [[NSOperationQueue alloc] init];
    sQueue.name = @"Zip.Queue";
    sQueue.maxConcurrentOperationCount = 1;
    sQueue.underlyingQueue = q;

    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"maniac-mansion.zip"] error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"Aesop.zip"] error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"Mixed.zip"] error:NULL];
}

+ (void)tearDown
{
    sQueue = nil;
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"maniac-mansion.zip"] error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"Aesop.zip"] error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"Mixed.zip"] error:NULL];

    [super tearDown];
}

+ (void)forceCompressionLevel:(NOZCompressionLevel)level forAllEntriesOnRequest:(NOZCompressRequest *)request
{
    static NSSet *sAlreadyCompressedExtensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sAlreadyCompressedExtensions = [NSSet setWithArray:@[
                                                             @"lfl",
                                                             @"zip",
                                                             @"jpg",
                                                             @"jpeg",
                                                             @"j2k",
                                                             @"j2000",
                                                             @"gif",
                                                             @"png",
                                                             @"webp",
                                                             @"mov",
                                                             @"mp4",
                                                             @"mp3",
                                                             @"aac",
                                                             @"mkv",
                                                             @"rar",
                                                             @"ipa",
                                                             @"pkg",
                                                             @"jar",
                                                             @"cab",
                                                             @"iwa",
                                                             @"webarchive",
                                                             @"tgz",
                                                             @"htmlz",
                                                             @"gz",
                                                             @"lz",
                                                             @"bz2"
                                                             ]];
    });

    for (NOZAbstractZipEntry *entry in request.mutableEntries) {
        if ([entry isKindOfClass:[NOZFileZipEntry class]]) {
            NSString *extension = [[(NOZFileZipEntry *)entry filePath].pathExtension lowercaseString];
            if ([sAlreadyCompressedExtensions containsObject:extension]) {
                entry.compressionLevel = NOZCompressionLevelNone;
            }
        }
        entry.compressionLevel = level;
    }
}

- (void)runValidCompressRequest:(NOZCompressRequest *)request withQueue:(NSOperationQueue *)queue
{
    NOZCompressOperation *op = [[NOZCompressOperation alloc] initWithRequest:request delegate:self];
    if (queue) {
        [queue addOperation:op];
    } else {
        [op start];
    }
    [op waitUntilFinished];

    NOZCompressResult *result = op.result;
    TESTLOG(@"Compression finished\n%@", @{ @"level" : @(level), @"duration" : @(result.duration), @"ratio" : @(result.compressionRatio) });

    XCTAssertNotNil(result);
    XCTAssertNil(result.operationError);
    XCTAssertTrue(result.didSucceed);
    XCTAssertEqualObjects(result.destinationPath, request.destinationPath);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:request.destinationPath]);
}

- (void)runCompressRequest:(NOZCompressRequest *)request withQueue:(NSOperationQueue *)queue expectedOutputZipName:(NSString *)zipName
{
    for (NOZCompressionLevel level = -1; level <= NOZCompressionLevelMax; level++) {
        [[self class] forceCompressionLevel:level forAllEntriesOnRequest:request];

        [self runValidCompressRequest:request withQueue:queue];

        if (NOZCompressionLevelDefault == level && zipName) {
            NSString *compZipPath = [[NSBundle bundleForClass:[self class]] pathForResource:zipName ofType:@"zip"];
            XCTAssertNotNil(compZipPath);
            NSData *compData = [NSData dataWithContentsOfFile:compZipPath];
            NSData *outputData = [NSData dataWithContentsOfFile:request.destinationPath];
            XCTAssertEqualObjects(compData, outputData);
        }
        [[NSFileManager defaultManager] removeItemAtPath:request.destinationPath error:NULL];
    }
}

- (void)runAllCompressionMethodsWithRequest:(NOZCompressRequest *)request
{
    [[self class] forceCompressionLevel:NOZCompressionLevelDefault forAllEntriesOnRequest:request];
    for (NOZCompressionMethod method = NOZCompressionMethodNone; method <= NOZCompressionMethodLZ77; method++) {
        for (NOZAbstractZipEntry *entry in request.mutableEntries) {
            entry.compressionMethod = method;
        }

        if (NOZEncoderForCompressionMethod(method) != nil) {
            [self runValidCompressRequest:request withQueue:sQueue];
            [[NSFileManager defaultManager] removeItemAtPath:request.destinationPath error:NULL];
        } else {
            NSError *error = [self runInvalidRequest:request];
            XCTAssertEqualObjects(error.domain, NOZErrorDomain);
            XCTAssertEqual(error.code, NOZErrorCodeCompressFailedToAppendEntryToZip);
            error = error.userInfo[NSUnderlyingErrorKey];
            XCTAssertEqualObjects(error.domain, NOZErrorDomain);
            XCTAssertEqual(error.code, NOZErrorCodeZipDoesNotSupportCompressionMethod);
        }
    }
}

- (void)runCompressRequest:(NOZCompressRequest *)request cancelling:(BOOL)yesBeforeEnqueueNoAfterEnqueue
{
    [[self class] forceCompressionLevel:NOZCompressionLevelMax forAllEntriesOnRequest:request];
    NOZCompressOperation *op = [[NOZCompressOperation alloc] initWithRequest:request delegate:self];
    if (yesBeforeEnqueueNoAfterEnqueue) {
        [op cancel];
    }
    [sQueue addOperation:op];
    if (!yesBeforeEnqueueNoAfterEnqueue) {
        [op cancel];
    }
    [op waitUntilFinished];

    NSString * const cancellingStr = yesBeforeEnqueueNoAfterEnqueue ? @"Cancel before enqueue" : @"Cancel after enqueue";

    XCTAssertTrue(op.isCancelled, @"%@", cancellingStr);
    XCTAssertTrue(op.isFinished, @"%@", cancellingStr);
    XCTAssertNotNil(op.result, @"%@", cancellingStr);
    XCTAssertNotNil(op.result.operationError, @"%@", cancellingStr);
    XCTAssertFalse(op.result.didSucceed, @"%@", cancellingStr);
    XCTAssertEqualObjects(op.result.operationError.domain, NOZErrorDomain, @"%@", cancellingStr);
    XCTAssertEqual(op.result.operationError.code, NOZErrorCodeCompressCancelled, @"%@", cancellingStr);
}

- (NSError *)runInvalidRequest:(NOZCompressRequest *)request
{
    NOZCompressOperation *op = [[NOZCompressOperation alloc] initWithRequest:request delegate:self];
    [sQueue addOperation:op];
    [op waitUntilFinished];

    NOZCompressResult *result = op.result;
    XCTAssertNotNil(result);
    XCTAssertNotNil(result.operationError);
    XCTAssertFalse(result.didSucceed);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:request.destinationPath]);
    return result.operationError;
}

- (void)runGambitWithRequest:(NOZCompressRequest *)request expectedOutputZipName:(NSString *)zipName
{
    request.comment = @"This is a comment on the ZIP archive.  Nothing special...just some extra text.";
    NOZAbstractZipEntry *lastEntry = [[request mutableEntries] lastObject];
    lastEntry.comment = @"This is a comment on a specific entry in a ZIP archive.";
    [self runCompressRequest:request withQueue:sQueue expectedOutputZipName:zipName];
    [self runCompressRequest:request withQueue:nil expectedOutputZipName:zipName];
    [self runCompressRequest:request cancelling:YES];
    [self runCompressRequest:request cancelling:NO];
    [self runAllCompressionMethodsWithRequest:request];
}

- (void)testCompressSingleFile
{
    NSString *sourceFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Aesop.zip"];

    NOZCompressRequest *request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addFileEntry:sourceFilePath];

    [self runGambitWithRequest:request expectedOutputZipName:nil];
}

- (void)testCompressionSingleData
{
    NSData *data = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"]];
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Aesop.zip"];

    NOZCompressRequest *request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addDataEntry:data name:@"Aesop.txt"];

    [self runGambitWithRequest:request expectedOutputZipName:nil];
}

- (void)testCompressionDirectory
{
    NSString *sourceDirectoryPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    sourceDirectoryPath = [[sourceDirectoryPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"maniac-mansion"];
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"maniac-mansion.zip"];

    NOZCompressRequest *request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addEntriesInDirectory:sourceDirectoryPath compressionSelectionBlock:NULL];

    [self runGambitWithRequest:request expectedOutputZipName:nil];
}

- (void)testCompressionMixed
{
    NSString *sourceDirectoryPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSData *data = [NSData dataWithContentsOfFile:sourceDirectoryPath];
    sourceDirectoryPath = [[sourceDirectoryPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"maniac-mansion"];
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Mixed.zip"];

    NOZCompressRequest *request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addEntriesInDirectory:sourceDirectoryPath compressionSelectionBlock:NULL];
    [request addDataEntry:data name:@"Aesop.txt"];

    [self runGambitWithRequest:request expectedOutputZipName:nil];
}

- (void)testCompressionInvalid
{
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Aesop.zip"];
    NOZCompressRequest *request = nil;

    [self runInvalidRequest:request];

    request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [self runInvalidRequest:request];

    request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addDataEntry:(NSData * __nonnull)nil name:(NSString * __nonnull)nil];
    [self runInvalidRequest:request];

    request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addDataEntry:[@"data" dataUsingEncoding:NSUTF8StringEncoding] name:(NSString * __nonnull)nil];
    [self runInvalidRequest:request];

    request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addDataEntry:(NSData * __nonnull)nil name:@"data"];
    [self runInvalidRequest:request];
}

#pragma mark Compress Delegate

- (dispatch_queue_t)completionQueue
{
    return sQueue.underlyingQueue;
}

- (void)compressOperation:(NOZCompressOperation * __nonnull)op didUpdateProgress:(float)progress
{
    TESTLOG(@"%%%tu", (NSUInteger)(progress * 100.0f));
}

- (void)compressOperation:(NOZCompressOperation * __nonnull)op didCompleteWithResult:(NOZCompressResult * __nonnull)result
{
    TESTLOG(@"Done!");
}

@end
