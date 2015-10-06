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
    }

    func startCompression() -> NSOperation
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

}

@objc class NOZSwiftDecompressionTests: XCTestCase, NOZDecompressDelegate
{
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
    }

    func startDecompression() -> NSOperation
    {
        let tmpDir : NSString = NSTemporaryDirectory()
        let zipFilePath = tmpDir.stringByAppendingPathComponent("Mixed.zip")
        let bundle = NSBundle.init(forClass: self.dynamicType)
        let sourceFilePath = bundle.pathForResource("Mixed", ofType: "zip")!
        try! NSFileManager.defaultManager().copyItemAtPath(sourceFilePath, toPath: zipFilePath)

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
}
