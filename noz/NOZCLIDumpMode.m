//
//  NOZCLIDumpMode.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import <ZipUtilities/ZipUtilities.h>

#import "NOZCLI.h"
#import "NOZCLIDumpMode.h"

@implementation NOZCLIDumpModeInfo

- (instancetype)initWithFilePath:(NSString *)filePath
                            list:(BOOL)list
                         verbose:(BOOL)verbose
              silenceArchiveInfo:(BOOL)silence
{
    if (self = [super init]) {
        _filePath = [filePath copy];
        _list = list;
        _silenceArchiveInfo = silence;
        _verbose = verbose;
    }
    return self;
}

@end

@implementation NOZCLIDumpMode

+ (NSString *)modeFlag
{
    return @"-D";
}

+ (NSString *)modeName
{
    return @"Dump";
}

+ (NSString *)modeExecutionDescription
{
    return @"[dump_options] -i zip_file";
}

+ (NSUInteger)modeExtraArgumentsSectionCount
{
    return 1;
}

+ (NSString *)modeExtraArgumentsSectionName:(NSUInteger)sectionIndex
{
    return @"dump_options";
}

+ (NSArray<NSString *> *)modeExtraArgumentsSectionDescriptions:(NSUInteger)sectionIndex
{
    return @[
             @"-L                list all entries",
             @"-v                verbose info",
             @"-s                silence the archive info (the default info that is output)"
             ];
}

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args
                           environmentPath:(NSString *)envPath
{
    BOOL list = NO;
    BOOL verbose = NO;
    BOOL silenceArchiveInfo = NO;
    NSString *file = nil;

    for (NSInteger i = 0; i < ((NSInteger)args.count - 1); i++) {
        NSString *arg = args[(NSUInteger)i];
        if ([arg isEqualToString:@"-L"]) {
            list = YES;
        } else if ([arg isEqualToString:@"-v"]) {
            verbose = YES;
        } else if ([arg isEqualToString:@"-s"]) {
            silenceArchiveInfo = YES;
        } else if ([arg isEqualToString:@"-i"]) {
            i++;
            file = args[(NSUInteger)i];
        } else  {
            return nil;
        }
    }

    file = NOZCLI_normalizedPath(envPath, file);

    BOOL isDir = NO;
    if (!file || ![[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDir] || isDir) {
        return nil;
    }

    return [[NOZCLIDumpModeInfo alloc] initWithFilePath:file
                                                   list:list
                                                verbose:verbose
                                     silenceArchiveInfo:silenceArchiveInfo];
}

+ (int)run:(NOZCLIDumpModeInfo *)info
{
    if (!info) {
        return -1;
    }

    NSError *error = nil;
    NOZUnzipper *unzipper = [[NOZUnzipper alloc] initWithZipFile:info.filePath];
    if (![unzipper openAndReturnError:&error]) {
        NOZCLI_printError(error);
        return -2;
    }

    NOZCentralDirectory *centralDirectory = [unzipper readCentralDirectoryAndReturnError:&error];
    if (!centralDirectory) {
        NOZCLI_printError(error);
        return -2;
    }

    if (!info.silenceArchiveInfo) {
        [self dumpCentralDirectory:centralDirectory info:info];
    }

    if (info.list) {
        [unzipper enumerateManifestEntriesUsingBlock:^(NOZCentralDirectoryRecord *record, NSUInteger index, BOOL *stop) {
            [self dumpRecord:record info:info];
        }];
    }

    return 0;
}

+ (void)dumpCentralDirectory:(NOZCentralDirectory *)centralDirectory
                        info:(NOZCLIDumpModeInfo *)info
{
    NSString *compressedSize = [NSByteCountFormatter stringFromByteCount:centralDirectory.totalCompressedSize
                                                              countStyle:NSByteCountFormatterCountStyleBinary];
    NSString *uncompressedSize = [NSByteCountFormatter stringFromByteCount:centralDirectory.totalUncompressedSize
                                                                countStyle:NSByteCountFormatterCountStyleBinary];
    double ratio = NOZCLI_computeCompressionRatio(centralDirectory.totalUncompressedSize, centralDirectory.totalCompressedSize);

    printf("uncompressed: %s", uncompressedSize.UTF8String);
    if (info.verbose) {
        printf(" (%lli bytes)", centralDirectory.totalUncompressedSize);
    }
    printf("\n");

    printf("compressed: %s", compressedSize.UTF8String);
    if (info.verbose) {
        printf(" (%lli bytes)", centralDirectory.totalCompressedSize);
    }
    printf("\n");

    if (info.verbose) {
        printf("compression ratio: %f\n", ratio);
        printf("record count: %tu\n", centralDirectory.recordCount);
        if (centralDirectory.globalComment) {
            printf("comment: \"%s\"\n", centralDirectory.globalComment.UTF8String);
        }
        printf("path: %s\n", info.filePath.UTF8String);
    }
}

+ (void)dumpRecord:(NOZCentralDirectoryRecord *)record info:(NOZCLIDumpModeInfo *)info
{
    printf("%s\n", record.name.UTF8String);
    if (info.verbose) {
        NSString *compressedSize = [NSByteCountFormatter stringFromByteCount:record.compressedSize
                                                                  countStyle:NSByteCountFormatterCountStyleBinary];
        NSString *uncompressedSize = [NSByteCountFormatter stringFromByteCount:record.uncompressedSize
                                                                    countStyle:NSByteCountFormatterCountStyleBinary];
        double ratio = NOZCLI_computeCompressionRatio(record.uncompressedSize, record.compressedSize);

        printf("\tuncompressed: %s, (%lli bytes)\n", uncompressedSize.UTF8String, record.uncompressedSize);
        printf("\tcompressed: %s, (%lli bytes)\n", compressedSize.UTF8String, record.compressedSize);
        printf("\tcompression ratio: %f\n", ratio);

        MethodInfo *methodInfo = NOZCLI_lookupMethod(record.compressionMethod);
        NSUInteger methodLevel = 0;
        if (methodInfo && methodInfo.levels > 0) {
            methodLevel = NOZCompressionLevelToCustomEncoderLevel(record.compressionLevel, 1, methodInfo.levels, methodInfo.defaultLevel);
        }

        printf("\tcompression method: %s (%u)\n", (info) ? methodInfo.name.UTF8String : "unknown", (unsigned int)record.compressionMethod);
        printf("\tcompression level: %f", record.compressionLevel);
        if (methodLevel > 0) {
            printf(" (%tu of %tu)", methodLevel, methodInfo.levels);
        }
        printf("\n");

        if (record.comment) {
            printf("\tcomment: \"%s\"\n", record.comment.UTF8String);
        }
    }
}

@end
