//
//  NOZUtils.m
//  ZipUtilities
//
//  Copyright (c) 2015 Nolan O'Brien.
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
