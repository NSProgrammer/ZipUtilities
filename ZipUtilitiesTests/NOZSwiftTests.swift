//
//  NOZSwiftTests.swift
//  ZipUtilities
//
//  Created by Nolan O'Brien on 10/6/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

import XCTest

var zipQueue : NSOperationQueue? = nil;

func RemoveTemporaryDirectoryContents()
{
    let fm = NSFileManager.defaultManager()
    let tmpDir : NSString = NSTemporaryDirectory()
    let enumerator = fm.enumeratorAtPath(tmpDir as String)
    enumerator?.skipDescendants();

    for object in enumerator! {
        let path = object as! String
        _ = try? fm.removeItemAtPath(tmpDir.stringByAppendingPathComponent(path))
    }
}

func SetUpZipQueue()
{
    let q : dispatch_queue_t = dispatch_queue_create("zip.queue", DISPATCH_QUEUE_SERIAL)
    let opQueue = NSOperationQueue()
    opQueue.underlyingQueue = q
    opQueue.name = "Zip.Swift.Queue"
    opQueue.maxConcurrentOperationCount = 1
    zipQueue = opQueue
}

func TearDownZipQueue()
{
    zipQueue = nil;
}

@objc class NOZSwiftCompressionTests: XCTestCase, NOZCompressDelegate
{

    class func prepareFileForCompression(fileName: String) throws -> String
    {
        let tmpDir : NSString = NSTemporaryDirectory()
        let filePath = tmpDir.stringByAppendingPathComponent(fileName)
        let bundle = NSBundle.init(forClass: self)
        let sourceFilePath = bundle.pathForResource(fileName, ofType: nil)!
        try NSFileManager.defaultManager().copyItemAtPath(sourceFilePath, toPath: filePath)
        return filePath
    }

    override class func setUp()
    {
        SetUpZipQueue()
        RemoveTemporaryDirectoryContents()
    }

    override class func tearDown()
    {
        TearDownZipQueue()
        RemoveTemporaryDirectoryContents()
    }

    override func tearDown()
    {
        RemoveTemporaryDirectoryContents()
        super.tearDown()
    }

    func testCompressionOperation()
    {
        let op = startCompression()
        op.waitUntilFinished()
        XCTAssertTrue(op.finished)
        XCTAssertTrue(op.result.didSucceed)
    }

    func startCompression() -> NOZCompressOperation
    {
        let tmpDir : NSString = NSTemporaryDirectory()
        let zipFilePath = tmpDir.stringByAppendingPathComponent("Mixed.zip")

        let bundle = NSBundle.init(forClass: self.dynamicType)
        let aesopFile : NSString = bundle.pathForResource("Aesop", ofType: "txt")!
        let sourceDir : NSString = aesopFile.stringByDeletingLastPathComponent
        let maniacDir : NSString = sourceDir.stringByAppendingPathComponent("maniac-mansion")

        let request = NOZCompressRequest.init(destinationPath: zipFilePath)
        request.addEntriesInDirectory(maniacDir as String, compressionSelectionBlock: nil)
        request.addFileEntry(aesopFile as String)

        let operation = NOZCompressOperation.init(request: request, delegate: self)
        zipQueue?.addOperation(operation)
        return operation
    }

    func compressOperation(op: NOZCompressOperation, didCompleteWithResult result: NOZCompressResult)
    {
        XCTAssertTrue(result.didSucceed, "Failed to compress! \(result.operationError)")
        if (result.didSucceed) {
            NSLog("Compression Ratio: \(result.compressionRatio())")
        }
    }

    func compressOperation(op: NOZCompressOperation, didUpdateProgress progress: Float)
    {
        dispatch_async(dispatch_get_main_queue(), {
            // NSLog("Progress: \(progress)%")
        })
    }

    func testLargeZipCompress() {
        var result:NOZCompressResult? = nil
        let filePath = try! NOZSwiftCompressionTests.prepareFileForCompression("Star.Wars.7.Trailer.mp4") as NSString
        let expectation = expectationWithDescription("completion closure is called");
        let request = NOZCompressRequest(destinationPath: filePath.stringByAppendingPathExtension("zip")! as String)
        request.addFileEntry(filePath as String)
        let operation = NOZCompressOperation(request: request, completion: {
            (op, res) -> Void in
            result = res
            expectation.fulfill()
        })

        zipQueue?.addOperation(operation)
        waitForExpectationsWithTimeout(5.0 * 60.0, handler: nil)

        if let realResult = result
        {
            XCTAssert(realResult.didSucceed)
        }
    }

    func testLargeZipCompressWithAppleCoder() {
        if #available(iOS 9.0, *) {
            let oldEncoder = NOZEncoderForCompressionMethod(NOZCompressionMethod.Deflate)
            NOZUpdateCompressionMethodEncoder(NOZCompressionMethod.Deflate, NOZXAppleCompressionCoder.encoderWithAlgorithm(COMPRESSION_ZLIB))
            testLargeZipCompress()
            NOZUpdateCompressionMethodEncoder(NOZCompressionMethod.Deflate, oldEncoder)
        }
    }

}

@objc class NOZSwiftDecompressionTests: XCTestCase, NOZDecompressDelegate
{

    class func prepareZipFileForDecompression(fileName: String) throws -> String
    {
        let tmpDir : NSString = NSTemporaryDirectory()
        let zipFilePath = tmpDir.stringByAppendingPathComponent(fileName + ".zip")
        let bundle = NSBundle.init(forClass: self)
        let sourceFilePath = bundle.pathForResource(fileName, ofType: "zip")!
        try NSFileManager.defaultManager().copyItemAtPath(sourceFilePath, toPath: zipFilePath)
        return zipFilePath
    }

    override class func setUp()
    {
        SetUpZipQueue()
        RemoveTemporaryDirectoryContents()
    }

    override class func tearDown()
    {
        TearDownZipQueue()
        RemoveTemporaryDirectoryContents()
    }

    override func tearDown()
    {
        RemoveTemporaryDirectoryContents()
        super.tearDown()
    }

    func testDecompressionOperation()
    {
        let op = startDecompression()
        op.waitUntilFinished()
        XCTAssertTrue(op.finished)
        XCTAssertTrue(op.result.didSucceed)
    }

    func startDecompression() -> NOZDecompressOperation
    {
        let zipFilePath = try! NOZSwiftDecompressionTests.prepareZipFileForDecompression("Mixed")
        let request = NOZDecompressRequest.init(sourceFilePath: zipFilePath)
        let operation = NOZDecompressOperation.init(request: request, delegate: self)
        zipQueue?.addOperation(operation)
        return operation
    }

    func decompressOperation(op: NOZDecompressOperation, didCompleteWithResult result: NOZDecompressResult)
    {
        XCTAssertTrue(result.didSucceed, "Failed to decompress! \(result.operationError)")
        if (result.didSucceed) {
            NSLog("Compression ratio: \(result.compressionRatio())")
        }
    }

    func decompressOperation(op: NOZDecompressOperation, didUpdateProgress progress: Float)
    {
        dispatch_async(dispatch_get_main_queue(), {
            // NSLog("Progress: \(progress)%")
        })
    }

    func testLargeZipDecompress() {
        var result:NOZDecompressResult? = nil
        let zipFilePath = try! NOZSwiftDecompressionTests.prepareZipFileForDecompression("Star.Wars.7.Trailer.mp4")
        let expectation = expectationWithDescription("completion closure is called");
        let request = NOZDecompressRequest(sourceFilePath: zipFilePath)
        let operation = NOZDecompressOperation(request: request, completion: {
            (op, res) -> Void in
            result = res
            expectation.fulfill()
        })

        zipQueue?.addOperation(operation)
        waitForExpectationsWithTimeout(5.0 * 60.0, handler: nil)

        if let realResult = result
        {
            XCTAssert(realResult.didSucceed)
        }
    }

    func testLargeZipDecompressWithAppleCoder() {
        if #available(iOS 9.0, *) {
            let oldDecoder = NOZDecoderForCompressionMethod(NOZCompressionMethod.Deflate)
            NOZUpdateCompressionMethodDecoder(NOZCompressionMethod.Deflate, NOZXAppleCompressionCoder.decoderWithAlgorithm(COMPRESSION_ZLIB))
            testLargeZipDecompress()
            NOZUpdateCompressionMethodDecoder(NOZCompressionMethod.Deflate, oldDecoder)
        }
    }

}
