//
//  NOZSwiftTests.swift
//  ZipUtilities
//
//  Created by Nolan O'Brien on 10/6/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

import Foundation
import XCTest
import ZipUtilities

var zipQueue : OperationQueue?

func RemoveTemporaryDirectoryContents()
{
    let fm = FileManager.default
    let tmpDir : NSString = NSTemporaryDirectory() as NSString
    let enumerator = fm.enumerator(atPath: tmpDir as String)
    enumerator?.skipDescendants();

    for object in enumerator! {
        let path = object as! String
        _ = try? fm.removeItem(atPath: tmpDir.appendingPathComponent(path))
    }
}

func SetUpZipQueue()
{
    let q : DispatchQueue = DispatchQueue(label: "zip.queue", attributes: [])
    let opQueue = OperationQueue()
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

    class func prepareFileForCompression(_ fileName: String) throws -> String
    {
        let tmpDir : NSString = NSTemporaryDirectory() as NSString
        let filePath = tmpDir.appendingPathComponent(fileName)
        let bundle = Bundle.init(for: self)
        let sourceFilePath = bundle.path(forResource: fileName, ofType: nil)!
        try FileManager.default.copyItem(atPath: sourceFilePath, toPath: filePath)
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
        XCTAssertTrue(op.isFinished)
        XCTAssertTrue(op.result.didSucceed)
    }

    func startCompression() -> NOZCompressOperation
    {
        let tmpDir : NSString = NSTemporaryDirectory() as NSString
        let zipFilePath = tmpDir.appendingPathComponent("Mixed.zip")

        let bundle = Bundle.init(for: type(of: self))
        let aesopFile : NSString = bundle.path(forResource: "Aesop", ofType: "txt")! as NSString
        let sourceDir : NSString = aesopFile.deletingLastPathComponent as NSString
        let maniacDir : NSString = sourceDir.appendingPathComponent("maniac-mansion") as NSString

        let request = NOZCompressRequest.init(destinationPath: zipFilePath)
        request.addEntries(inDirectory: maniacDir as String, filterBlock: { (filePath: String) -> Bool in
            return ((filePath as NSString).lastPathComponent as NSString).hasPrefix(".")
            }, compressionSelectionBlock: nil)
        request.addFileEntry(aesopFile as String)

        let operation = NOZCompressOperation.init(request: request, delegate: self)
        zipQueue?.addOperation(operation)
        return operation
    }

    func compressOperation(_ op: NOZCompressOperation, didCompleteWith result: NOZCompressResult)
    {
        XCTAssertTrue(result.didSucceed, "Failed to compress! \(String(describing: result.operationError))")
        if (result.didSucceed) {
            NSLog("Compression Ratio: \(result.compressionRatio())")
        }
    }

    func compressOperation(_ op: NOZCompressOperation, didUpdateProgress progress: Float)
    {
        DispatchQueue.main.async(execute: {
            // NSLog("Progress: \(progress)%")
        })
    }

    func testLargeZipCompress() {
        var result:NOZCompressResult? = nil
        let filePath = try! NOZSwiftCompressionTests.prepareFileForCompression("Star.Wars.7.Trailer.mp4") as NSString
        let expectation = self.expectation(description: "completion closure is called");
        let request = NOZCompressRequest(destinationPath: filePath.appendingPathExtension("zip")! as String)
        request.addFileEntry(filePath as String)
        let operation = NOZCompressOperation(request: request, completion: {
            (op, res) -> Void in
            result = res
            expectation.fulfill()
        })

        zipQueue?.addOperation(operation)
        waitForExpectations(timeout: 5.0 * 60.0, handler: nil)

        if let realResult = result
        {
            XCTAssert(realResult.didSucceed)
        }
    }

    func testLargeZipCompressWithAppleCoder() {
        if #available(iOS 9.0, OSX 10.11, *) {
            let library = NOZCompressionLibrary.sharedInstance()
            let oldEncoder = library.encoder(for: NOZCompressionMethod.deflate)
            let encoder = NOZXAppleCompressionCoder.encoder(with: COMPRESSION_ZLIB)
            library.setEncoder(encoder, for: NOZCompressionMethod.deflate)
            testLargeZipCompress()
            library.setEncoder(oldEncoder, for: NOZCompressionMethod.deflate)
        }
    }

}

@objc class NOZSwiftDecompressionTests: XCTestCase, NOZDecompressDelegate
{

    class func prepareZipFileForDecompression(_ fileName: String) throws -> String
    {
        let tmpDir = NSTemporaryDirectory()
        do {
            try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        let zipFilePath = (tmpDir as NSString).appendingPathComponent(fileName + ".zip")
        let bundle = Bundle.init(for: self)
        let sourceFilePath = bundle.path(forResource: fileName, ofType: "zip")!
        try FileManager.default.copyItem(atPath: sourceFilePath, toPath: zipFilePath)
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
        XCTAssertTrue(op.isFinished)
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

    func decompressOperation(_ op: NOZDecompressOperation, didCompleteWith result: NOZDecompressResult)
    {
        XCTAssertTrue(result.didSucceed, "Failed to decompress! \(String(describing: result.operationError))")
        if (result.didSucceed) {
            NSLog("Compression ratio: \(result.compressionRatio())")
        }
    }

    func decompressOperation(_ op: NOZDecompressOperation, didUpdateProgress progress: Float)
    {
        DispatchQueue.main.async(execute: {
            // NSLog("Progress: \(progress)%")
        })
    }

    func testLargeZipDecompress() {
        var result:NOZDecompressResult? = nil
        let zipFilePath = try! NOZSwiftDecompressionTests.prepareZipFileForDecompression("Star.Wars.7.Trailer.mp4")
        let expectation = self.expectation(description: "completion closure is called");
        let request = NOZDecompressRequest(sourceFilePath: zipFilePath)
        let operation = NOZDecompressOperation(request: request, completion: {
            (op, res) -> Void in
            result = res
            expectation.fulfill()
        })

        zipQueue?.addOperation(operation)
        waitForExpectations(timeout: 5.0 * 60.0, handler: nil)

        if let realResult = result
        {
            XCTAssert(realResult.didSucceed)
        }
    }

    func testLargeZipDecompressWithAppleCoder() {
        if #available(iOS 9.0, OSX 10.11, *) {
            let library = NOZCompressionLibrary.sharedInstance()
            let oldDecoder = library.decoder(for: NOZCompressionMethod.deflate)
            library.setDecoder(NOZXAppleCompressionCoder.decoder(with: COMPRESSION_ZLIB), for: NOZCompressionMethod.deflate)
            testLargeZipDecompress()
            library.setDecoder(oldDecoder, for: NOZCompressionMethod.deflate)
        }
    }

    func testValidateZip() {
        var unzipper: NOZUnzipper

        let goodFilePath = try! NOZSwiftDecompressionTests.prepareZipFileForDecompression("File")
        unzipper = NOZUnzipper.init(zipFile: goodFilePath)
        try! unzipper.open()
        try! unzipper.readCentralDirectory()
        unzipper.enumerateManifestEntries({ record, index, stop in
            var caughtError: NSError? = nil
            do {
                try unzipper.validate(record, progressBlock: nil)
            } catch let error as NSError {
                caughtError = error
            }
            XCTAssertNil(caughtError)
        })
        try! unzipper.close()

        let badFilePath = try! NOZSwiftDecompressionTests.prepareZipFileForDecompression("Bad_File")
        unzipper = NOZUnzipper.init(zipFile: badFilePath)
        try! unzipper.open()
        try! unzipper.readCentralDirectory()
        var didEncouterError: Bool = false
        unzipper.enumerateManifestEntries({ record, index, stop in
            do {
                try unzipper.validate(record, progressBlock: nil)
            } catch let error as NSError {
                XCTAssertEqual(NOZErrorCode.init(rawValue: error.code), NOZErrorCode.unzipChecksumMissmatch)
                didEncouterError = true
            }
        })
        XCTAssertTrue(didEncouterError)
        try! unzipper.close()
    }

}
