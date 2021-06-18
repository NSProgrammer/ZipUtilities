//
//  NOZUtils_Project.h
//  ZipUtilities
//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Nolan O'Brien
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

#import <ZipUtilities/NOZUtils.h>

#if __LP64__
static const size_t NOZPointerByteSize = 8;
#else
static const size_t NOZPointerByteSize = 4;
#endif

static const UInt32 NOZMagicNumberLocalFileHeader               = 0x04034b50;
static const UInt32 NOZMagicNumberDataDescriptor                = 0x08074b50;
static const UInt32 NOZMagicNumberCentralDirectoryFileRecord    = 0x02014b50;
static const UInt32 NOZMagicNumberEndOfCentralDirectoryRecord   = 0x06054b50;

static const UInt32 NOZVersionForCreation   = 20; // Zip 2.0
static const UInt32 NOZVersionForExtraction = 20; // Zip 2.0

typedef NS_OPTIONS(UInt16, NOZFlagBits)
{
    NOZFlagBitsEncrypted = 0b1 << 0, // Unsupported w/ NOZ
    NOZFlagBitsCompressionInfoMask = (0b1 << 1) | (0b1 << 2), // flags specifically for compression methods (differs by method) -- see `NOZDeflateFlagBits`
    NOZFlagBitsFileMetadataInDescriptor = 0b1 << 3, // CRC32, Compressed size and uncompressed size are not set in the record, instead they are in the data descriptor (follows the compressed data)
    NOZFlagBitsDeflateMethodIsEnhanced = 0b1 << 4, // for DEFLATE compression method, uses enhanced deflating
    NOZFlagBitsPatchData = 0b1 << 5, // effectively reserved for PKZIP
    NOZFlagBitsStronglyEncrypted = 0b1 << 6, // when `NOZFlagBitesEncrypted` (bit zero) is set, Strong Encryption is used.  MUST have a version of at least 50 as well.
    NOZFlagBitsReserved7 = 0b1 << 7,
    NOZFlagBitsReserved8 = 0b1 << 8,
    NOZFlagBitsReserved9 = 0b1 << 9,
    NOZFlagBitsReserved10 = 0b1 << 10,
    NOZFlagBitsUTF8EncodedStrings = 0b1 << 11, // For filename and comment strings: unset means DOS Latin US (Code Page 437) encoded, set means UTF-8 encoded.
    NOZFlagBitsPKWAREEnhancedCompression = 0b1 << 12, // effectively reserved by PKWARE
    NOZFlagBitsStronglyEncryptedMaskingRecords = 0b1 << 13, // used with `NOZFlagBitsStronglyEncrypted` (bit 6) to indicate that records should themselves be encrypted as well
    NOZFlagBitsPKWAREAlternateStreams = 0b1 << 14, // effectively reserved by PKWARE
    NOZFlagBitsPKWAREReserved15 = 0b1 << 15,
};

typedef NS_OPTIONS(UInt8, NOZDeflateFlagBits)
{
    NOZDeflateFlagBitsNormal = 0b00,
    NOZDeflateFlagBitsMax = 0b01,
    NOZDeflateFlagBitsFast = 0b10,
    NOZDeflateFlagBitsSuperFast = 0b11,
};

NS_INLINE NOZDeflateFlagBits NOZExtractDeflateFlagBits(NOZFlagBits bits)
{
    return (NOZDeflateFlagBits)((bits & 0b0110) >> 1);
}

NS_INLINE NOZFlagBits NOZEmplaceDeflateFlagBits(NOZDeflateFlagBits deflateBits)
{
    return (NOZFlagBits)((deflateBits & 0b11) << 1);
}

typedef struct _NOZLocalFileDescriptorT
{
    // Optionally starts with NOZMagicNumberDataDescriptor

    UInt32 crc32;
    UInt32 compressedSize;
    UInt32 uncompressedSize;
} NOZLocalFileDescriptorT;

typedef struct _NOZLocalFileHeaderT
{
    // starts with NOZMagicNumberLocalFileHeader

    UInt16 versionForExtraction;
    UInt16 bitFlag;
    UInt16 compressionMethod;
    UInt16 dosTime;
    UInt16 dosDate;
    NOZLocalFileDescriptorT *fileDescriptor;
    UInt16 nameSize;
    UInt16 extraFieldSize;

    // ends with:
    // const Byte* name;
    // const Byte* extraField;
} NOZLocalFileHeaderT;

typedef struct _NOZCentralDirectoryFileRecordT
{
    // Starts with NOZMagicNumberCentralDirectoryFileRecord

    UInt16 versionMadeBy;
    NOZLocalFileHeaderT *fileHeader;
    UInt16 commentSize;
    UInt16 fileStartDiskNumber;
    UInt16 internalFileAttributes;
    UInt32 externalFileAttributes;
    UInt32 localFileHeaderOffsetFromStartOfDisk;

    // ends with:
    // const Byte* name;
    // const Byte* extraField;
    // const Byte* fileComment;
} NOZCentralDirectoryFileRecordT;

typedef struct _NOZEndOfCentralDirectoryRecordT
{
    // starts with NOZMagicNumberEndOfCentralDirectoryRecord

    UInt16 diskNumber;
    UInt16 startDiskNumber;
    UInt16 recordCountForDisk;
    UInt16 totalRecordCount;
    UInt32 centralDirectorySize;
    UInt32 archiveStartToCentralDirectoryStartOffset;
    UInt16 commentSize;

    // ends with:
    // const Byte* comment
} NOZEndOfCentralDirectoryRecordT;

typedef struct _NOZFileEntryT
{
    NOZLocalFileDescriptorT fileDescriptor;
    NOZLocalFileHeaderT fileHeader;
    NOZCentralDirectoryFileRecordT centralDirectoryRecord;
    const Byte* name;
    const Byte* extraField;
    const Byte* comment;

    struct _NOZFileEntryT *nextEntry;

    BOOL ownsName:1;
    BOOL ownsExtraField:1;
    BOOL ownsComment:1;
} NOZFileEntryT;

FOUNDATION_EXTERN NOZFileEntryT* NOZFileEntryAllocInit(void);
FOUNDATION_EXTERN void NOZFileEntryInit(NOZFileEntryT* entry);

FOUNDATION_EXTERN void NOZFileEntryCleanFree(NOZFileEntryT* entry);
FOUNDATION_EXTERN void NOZFileEntryClean(NOZFileEntryT* entry);

#import "NOZDecoder.h"
#import "NOZEncoder.h"

@interface NOZDeflateEncoder : NSObject <NOZEncoder>
@end

@interface NOZDeflateDecoder : NSObject <NOZDecoder>
@end

@interface NOZRawEncoder : NSObject <NOZEncoder>
@end

@interface NOZRawDecoder : NSObject <NOZDecoder>
@end
