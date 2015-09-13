//
//  NOZDecompressTests.m
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

#import "NOZDecompress.h"

//#define TESTLOG(...) NSLog(__VA_ARGS__)
#define TESTLOG(...) ((void)0)

static NSArray<NSString *> *sFileNames = nil;
static NSOperationQueue *sQueue = nil;

@interface NOZDecompressTests : XCTestCase <NOZDecompressDelegate>
@end

@implementation NOZDecompressTests

+ (void)setUp
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    sFileNames = @[
                   @"Directory",
                   @"File",
                   @"Mixed"
                   ];

    for (NSString *fileName in sFileNames) {
        NSString *zipFile = [bundle pathForResource:fileName ofType:@"zip"];
        NSString *dstZipFile = [NSTemporaryDirectory() stringByAppendingPathComponent:zipFile.lastPathComponent];
        [fm removeItemAtPath:dstZipFile error:NULL];
        [fm copyItemAtPath:zipFile toPath:dstZipFile error:NULL];
    }

    dispatch_queue_t q = dispatch_queue_create("Unzip.GCD.Queue", DISPATCH_QUEUE_SERIAL);
    sQueue = [[NSOperationQueue alloc] init];
    sQueue.name = @"Unzip.Queue";
    sQueue.maxConcurrentOperationCount = 1;
    sQueue.underlyingQueue = q;
}

+ (void)tearDown
{
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *fileName in sFileNames) {
        NSString *dstZipFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:@"zip"]];
        [fm removeItemAtPath:dstZipFile error:NULL];
    }

    sFileNames = nil;
    sQueue = nil;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)runDecompressRequest:(NOZDecompressRequest *)request withOperationQueue:(NSOperationQueue *)queue removingUnzippedFiles:(BOOL)removeUnzippedFiles expectedOutputFiles:(NSSet *)expectedOutputFiles
{
    NOZDecompressOperation *op = [[NOZDecompressOperation alloc] initWithRequest:request delegate:self];
    if (queue) {
        [queue addOperation:op];
    } else {
        [op start];
    }
    [op waitUntilFinished];
    NOZDecompressResult *result = op.result;
    XCTAssertNotNil(result);
    XCTAssertNil(result.operationError);
    XCTAssertTrue(result.didSucceed);

    TESTLOG(@"%@", result);

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    for (NSString *file in result.destinationFiles) {
        NSString *compFilePath = [bundle pathForResource:file ofType:nil];
        if (!compFilePath) {
            compFilePath = [bundle pathForResource:[@"maniac-mansion" stringByAppendingPathComponent:file] ofType:nil];
        }
        NSString *unzipFilePath = [[result.destinationDirectoryPath stringByStandardizingPath] stringByAppendingPathComponent:file];
        XCTAssertNotNil(compFilePath);
        if (compFilePath) {
            NSData *compData = [NSData dataWithContentsOfFile:compFilePath];
            NSData *unzipData = [NSData dataWithContentsOfFile:unzipFilePath];
            XCTAssertEqualObjects(compData, unzipData, @"%@ not equal to %@", compFilePath, unzipFilePath);
        }
    }

    NSSet *actualFiles = [NSSet setWithArray:result.destinationFiles];
    XCTAssertEqualObjects(actualFiles, expectedOutputFiles);

    if (removeUnzippedFiles) {
        XCTAssertNotEqualObjects(NSTemporaryDirectory(), result.destinationDirectoryPath);
        if (![NSTemporaryDirectory() isEqualToString:result.destinationDirectoryPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:result.destinationDirectoryPath error:NULL];
        }
    }
}

- (void)runDecompressRequest:(NOZDecompressRequest *)request cancelling:(BOOL)yesBeforeEnqueueNoAfterEnqueue
{
    NSString * const cancellingStr = yesBeforeEnqueueNoAfterEnqueue ? @"Cancel before enqueue" : @"Cancel after enqueue";

    // Enqueue a blocking op
    __block NSBlockOperation *blockingOp = nil;
    blockingOp = [NSBlockOperation blockOperationWithBlock:^{
        while (!blockingOp.isCancelled) {
            usleep(10000);
        }
        blockingOp = nil;
    }];
    [sQueue addOperation:blockingOp];

    // Create zip op
    NOZDecompressOperation *op = [[NOZDecompressOperation alloc] initWithRequest:request delegate:self];
    [op addDependency:blockingOp];

    // Cancel and Enqueue
    if (yesBeforeEnqueueNoAfterEnqueue) {
        [op cancel];
    }
    [sQueue addOperation:op];
    if (!yesBeforeEnqueueNoAfterEnqueue) {
        [op cancel];
    }

    // Async cancel blocking op
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [blockingOp cancel];
    });

    // Wait for zip op
    [op waitUntilFinished];

    XCTAssertTrue(op.isCancelled, @"%@", cancellingStr);
    XCTAssertTrue(op.isFinished, @"%@", cancellingStr);
    XCTAssertNotNil(op.result, @"%@", cancellingStr);
    XCTAssertNotNil(op.result.operationError, @"%@", cancellingStr);
    XCTAssertFalse(op.result.didSucceed, @"%@", cancellingStr);
    XCTAssertEqualObjects(op.result.operationError.domain, NOZErrorDomain, @"%@", cancellingStr);
    XCTAssertEqual(op.result.operationError.code, NOZErrorCodeDecompressCancelled, @"%@", cancellingStr);
}

- (void)runInvalidRequest:(NOZDecompressRequest *)request
{
    NOZDecompressOperation *op = [[NOZDecompressOperation alloc] initWithRequest:request delegate:self];
    [sQueue addOperation:op];
    [op waitUntilFinished];
    NOZDecompressResult *result = op.result;
    XCTAssertNotNil(result);
    XCTAssertNotNil(result.operationError);
    XCTAssertFalse(result.didSucceed);
}

- (void)runGambitWithRequest:(NOZDecompressRequest *)request expectedOutputFiles:(NSSet *)expectedOutputFiles
{
    [self runDecompressRequest:request withOperationQueue:sQueue removingUnzippedFiles:NO expectedOutputFiles:expectedOutputFiles];
    [self runDecompressRequest:request withOperationQueue:nil removingUnzippedFiles:YES expectedOutputFiles:expectedOutputFiles];
    [self runDecompressRequest:request cancelling:YES];
    [self runDecompressRequest:request cancelling:NO];
}

- (void)testDecompressFile
{
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"File.zip"];
    NOZDecompressRequest *request = [[NOZDecompressRequest alloc] initWithSourceFilePath:zipFilePath];

    [self runGambitWithRequest:request expectedOutputFiles:[NSSet setWithArray:@[@"Aesop.txt"]]];
}

- (void)testDecompressDirectory
{
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Directory.zip"];
    NOZDecompressRequest *request = [[NOZDecompressRequest alloc] initWithSourceFilePath:zipFilePath];

    [self runGambitWithRequest:request expectedOutputFiles:[NSSet setWithArray:@[
                                                                                 @"Walkthrough/walkthrough.txt",
                                                                                 @"ca1.jpeg",
                                                                                 @"Game/MANIAC.EXE",
                                                                                 @"Game/00.LFL",
                                                                                 @"Game/01.LFL",
                                                                                 @"Game/02.LFL",
                                                                                 @"Game/03.LFL",
                                                                                 @"Game/04.LFL",
                                                                                 @"Game/05.LFL",
                                                                                 @"Game/06.LFL",
                                                                                 @"Game/07.LFL",
                                                                                 @"Game/08.LFL",
                                                                                 @"Game/09.LFL",
                                                                                 @"Game/10.LFL",
                                                                                 @"Game/11.LFL",
                                                                                 @"Game/12.LFL",
                                                                                 @"Game/13.LFL",
                                                                                 @"Game/14.LFL",
                                                                                 @"Game/15.LFL",
                                                                                 @"Game/16.LFL",
                                                                                 @"Game/17.LFL",
                                                                                 @"Game/18.LFL",
                                                                                 @"Game/19.LFL",
                                                                                 @"Game/20.LFL",
                                                                                 @"Game/21.LFL",
                                                                                 @"Game/22.LFL",
                                                                                 @"Game/23.LFL",
                                                                                 @"Game/24.LFL",
                                                                                 @"Game/25.LFL",
                                                                                 @"Game/26.LFL",
                                                                                 @"Game/27.LFL",
                                                                                 @"Game/28.LFL",
                                                                                 @"Game/29.LFL",
                                                                                 @"Game/30.LFL",
                                                                                 @"Game/31.LFL",
                                                                                 @"Game/32.LFL",
                                                                                 @"Game/33.LFL",
                                                                                 @"Game/34.LFL",
                                                                                 @"Game/35.LFL",
                                                                                 @"Game/36.LFL",
                                                                                 @"Game/37.LFL",
                                                                                 @"Game/38.LFL",
                                                                                 @"Game/39.LFL",
                                                                                 @"Game/40.LFL",
                                                                                 @"Game/41.LFL",
                                                                                 @"Game/42.LFL",
                                                                                 @"Game/43.LFL",
                                                                                 @"Game/44.LFL",
                                                                                 @"Game/45.LFL",
                                                                                 @"Game/46.LFL",
                                                                                 @"Game/47.LFL",
                                                                                 @"Game/48.LFL",
                                                                                 @"Game/49.LFL",
                                                                                 @"Game/50.LFL",
                                                                                 @"Game/51.LFL",
                                                                                 @"Game/52.LFL",
                                                                                 ]]];
}

- (void)testDecompressMixed
{
    NSString *zipFilePath = [NSTemporaryDirectory() stringByAppendingString:@"Mixed.zip"];
    NOZDecompressRequest *request = [[NOZDecompressRequest alloc] initWithSourceFilePath:zipFilePath];

    [self runGambitWithRequest:request expectedOutputFiles:[NSSet setWithArray:@[
                                                                                 @"Aesop.txt",
                                                                                 @"Walkthrough/walkthrough.txt",
                                                                                 @"ca1.jpeg",
                                                                                 @"Game/MANIAC.EXE",
                                                                                 @"Game/00.LFL",
                                                                                 @"Game/01.LFL",
                                                                                 @"Game/02.LFL",
                                                                                 @"Game/03.LFL",
                                                                                 @"Game/04.LFL",
                                                                                 @"Game/05.LFL",
                                                                                 @"Game/06.LFL",
                                                                                 @"Game/07.LFL",
                                                                                 @"Game/08.LFL",
                                                                                 @"Game/09.LFL",
                                                                                 @"Game/10.LFL",
                                                                                 @"Game/11.LFL",
                                                                                 @"Game/12.LFL",
                                                                                 @"Game/13.LFL",
                                                                                 @"Game/14.LFL",
                                                                                 @"Game/15.LFL",
                                                                                 @"Game/16.LFL",
                                                                                 @"Game/17.LFL",
                                                                                 @"Game/18.LFL",
                                                                                 @"Game/19.LFL",
                                                                                 @"Game/20.LFL",
                                                                                 @"Game/21.LFL",
                                                                                 @"Game/22.LFL",
                                                                                 @"Game/23.LFL",
                                                                                 @"Game/24.LFL",
                                                                                 @"Game/25.LFL",
                                                                                 @"Game/26.LFL",
                                                                                 @"Game/27.LFL",
                                                                                 @"Game/28.LFL",
                                                                                 @"Game/29.LFL",
                                                                                 @"Game/30.LFL",
                                                                                 @"Game/31.LFL",
                                                                                 @"Game/32.LFL",
                                                                                 @"Game/33.LFL",
                                                                                 @"Game/34.LFL",
                                                                                 @"Game/35.LFL",
                                                                                 @"Game/36.LFL",
                                                                                 @"Game/37.LFL",
                                                                                 @"Game/38.LFL",
                                                                                 @"Game/39.LFL",
                                                                                 @"Game/40.LFL",
                                                                                 @"Game/41.LFL",
                                                                                 @"Game/42.LFL",
                                                                                 @"Game/43.LFL",
                                                                                 @"Game/44.LFL",
                                                                                 @"Game/45.LFL",
                                                                                 @"Game/46.LFL",
                                                                                 @"Game/47.LFL",
                                                                                 @"Game/48.LFL",
                                                                                 @"Game/49.LFL",
                                                                                 @"Game/50.LFL",
                                                                                 @"Game/51.LFL",
                                                                                 @"Game/52.LFL",
                                                                                 ]]];
}

- (void)testDecompressInvalid
{
    NSString *zipFilePath = nil;
    NOZDecompressRequest *request = nil;

    zipFilePath = nil;
    request = [[NOZDecompressRequest alloc] initWithSourceFilePath:zipFilePath];
    [self runInvalidRequest:request];

    zipFilePath = NSTemporaryDirectory();
    request = [[NOZDecompressRequest alloc] initWithSourceFilePath:zipFilePath];
    [self runInvalidRequest:request];

    zipFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    request = [[NOZDecompressRequest alloc] initWithSourceFilePath:zipFilePath destinationDirectoryPath:NSTemporaryDirectory()];
    [self runInvalidRequest:request];

    zipFilePath = nil;
    request = nil;
    [self runInvalidRequest:request];
}

#pragma mark Decompress Delegate

- (dispatch_queue_t)completionQueue
{
    return sQueue.underlyingQueue;
}

- (BOOL)shouldDecompressOperation:(NOZDecompressOperation *)op overwriteFileAtPath:(NSString *)path
{
    TESTLOG(@"Overwriting %@", path);
    return YES;
}

- (void)decompressOperation:(NOZDecompressOperation *)op didUpdateProgress:(float)progress
{
    TESTLOG(@"%%%tu", (NSUInteger)(progress * 100.0f));
}

- (void)decompressOperation:(NOZDecompressOperation *)op didCompleteWithResult:(NOZDecompressResult *)result
{
    TESTLOG(@"Done!");
}

@end
