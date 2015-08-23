//
//  NOZUtils.m
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

#import "NOZUtils_Project.h"
#include "zlib.h"

void NOZFileEntryInit(NOZFileEntryT* entry)
{
    if (entry) {
        bzero(entry, sizeof(NOZFileEntryT));

        entry->centralDirectoryRecord.versionMadeBy = NOZVersionForCreation;
        entry->centralDirectoryRecord.fileHeader = &entry->fileHeader;

        entry->fileHeader.bitFlag = NOZFlagBitUseDescriptor;
        entry->fileHeader.compressionMethod = Z_DEFLATED;
        entry->fileHeader.versionForExtraction = NOZVersionForExtraction;
        entry->fileHeader.fileDescriptor = &entry->fileDescriptor;
    }
}

NOZFileEntryT* NOZFileEntryAllocInit(void)
{
    NOZFileEntryT *entry = (NOZFileEntryT *)malloc(sizeof(NOZFileEntryT));
    NOZFileEntryInit(entry);
    return entry;
}

void NOZFileEntryClean(NOZFileEntryT* entry)
{
    if (entry) {
        if (entry->name && entry->ownsName) {
            free((void*)entry->name);
            entry->name = NULL;
            entry->ownsName = NO;
        }
        if (entry->extraField && entry->ownsExtraField) {
            free((void*)entry->extraField);
            entry->extraField = NULL;
            entry->ownsExtraField = NO;
        }
        if (entry->comment && entry->ownsComment) {
            free((void*)entry->comment);
            entry->comment = NULL;
            entry->ownsComment = NO;
        }
    }
}

void NOZFileEntryCleanFree(NOZFileEntryT* entry)
{
    while (entry) {
        NOZFileEntryT* nextEntry = entry->nextEntry;

        NOZFileEntryClean(entry);

        free(entry);

        entry = nextEntry;
    }
}
