//
//  NOZUtils.h
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

/**
 The compression level to use.
 Lower levels execute faster, while higher levels will achieve a higher compression ratio.
 */
typedef NS_ENUM(NSInteger, NOZCompressionLevel)
{
    NOZCompressionLevelNone = 0,
    NOZCompressionLevelMin = 1,
    NOZCompressionLevelVeryLow = 2,
    NOZCompressionLevelLow = 3,
    NOZCompressionLevelMediumLow = 4,
    NOZCompressionLevelMedium = 5,
    NOZCompressionLevelMediumHigh = 6,
    NOZCompressionLevelHigh = 7,
    NOZCompressionLevelVeryHigh = 8,
    NOZCompressionLevelMax = 9,

    NOZCompressionLevelDefault = -1,
};

typedef void(^NOZProgressBlock)(int64_t totalBytes, int64_t bytesComplete, int64_t byteWrittenThisPass, BOOL *abort);

#if __LP64__
static const size_t NOZPointerByteSize = 8;
#else
static const size_t NOZPointerByteSize = 4;
#endif

static const size_t NOZPageSize = (NOZPointerByteSize * 1024);

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
