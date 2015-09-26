//
//  NOZUtils_Project.h
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

#import "NOZUtils.h"

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

static const UInt16 NOZFlagBitsNormalDeflate    = 0b000000;
static const UInt16 NOZFlagBitsMaxDeflate       = 0b000010;
static const UInt16 NOZFlagBitsFastDeflate      = 0b000100;
static const UInt16 NOZFlagBitsSuperFastDeflate = 0b000110;
static const UInt16 NOZFlagBitUseDescriptor     = 0b001000;

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
