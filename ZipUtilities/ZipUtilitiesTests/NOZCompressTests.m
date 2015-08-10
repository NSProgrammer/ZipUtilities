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

- (void)runCompressRequest:(NOZCompressRequest *)request withQueue:(NSOperationQueue *)queue expectedOutputZipName:(NSString *)zipName
{
    for (NOZCompressionLevel level = -1; level <= NOZCompressionLevelMax; level++) {
        request.compressionLevel = level;
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
        if (NOZCompressionLevelDefault == request.compressionLevel && zipName) {
            NSString *compZipPath = [[NSBundle bundleForClass:[self class]] pathForResource:zipName ofType:@"zip"];
            XCTAssertNotNil(compZipPath);
            NSData *compData = [NSData dataWithContentsOfFile:compZipPath];
            NSData *outputData = [NSData dataWithContentsOfFile:request.destinationPath];
            XCTAssertEqualObjects(compData, outputData);
        }
        [[NSFileManager defaultManager] removeItemAtPath:request.destinationPath error:NULL];
    }
}

- (void)runCompressRequest:(NOZCompressRequest *)request cancelling:(BOOL)yesBeforeEnqueueNoAfterEnqueue
{
    request.compressionLevel = NOZCompressionLevelMax;
    NOZCompressOperation *op = [[NOZCompressOperation alloc] initWithRequest:request delegate:self];
    if (yesBeforeEnqueueNoAfterEnqueue) {
        [op cancel];
    }
    [sQueue addOperation:op];
    if (!yesBeforeEnqueueNoAfterEnqueue) {
        [op cancel];
    }
    [op waitUntilFinished];

    XCTAssertTrue(op.isCancelled);
    XCTAssertNotNil(op.result);
    XCTAssertNotNil(op.result.operationError);
    XCTAssertFalse(op.result.didSucceed);
    XCTAssertEqualObjects(op.result.operationError.domain, NOZErrorDomain);
    XCTAssertEqual(op.result.operationError.code, NOZErrorCodeCompressCancelled);
}

- (void)runInvalidRequest:(NOZCompressRequest *)request
{
    NOZCompressOperation *op = [[NOZCompressOperation alloc] initWithRequest:request delegate:self];
    [sQueue addOperation:op];
    [op waitUntilFinished];

    NOZCompressResult *result = op.result;
    XCTAssertNotNil(result);
    XCTAssertNotNil(result.operationError);
    XCTAssertFalse(result.didSucceed);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:request.destinationPath]);
}

- (void)runGambitWithRequest:(NOZCompressRequest *)request expectedOutputZipName:(NSString *)zipName
{
    [self runCompressRequest:request withQueue:sQueue expectedOutputZipName:zipName];
    [self runCompressRequest:request withQueue:nil expectedOutputZipName:zipName];
    [self runCompressRequest:request cancelling:YES];
    [self runCompressRequest:request cancelling:NO];
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
    [request addEntriesInDirectory:sourceDirectoryPath];

    [self runGambitWithRequest:request expectedOutputZipName:nil];
}

- (void)testCompressionMixed
{
    NSString *sourceDirectoryPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSData *data = [NSData dataWithContentsOfFile:sourceDirectoryPath];
    sourceDirectoryPath = [[sourceDirectoryPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"maniac-mansion"];
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Mixed.zip"];

    NOZCompressRequest *request = [[NOZCompressRequest alloc] initWithDestinationPath:zipFilePath];
    [request addEntriesInDirectory:sourceDirectoryPath];
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
