//
//  NOZCLIUnzipMode.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIUnzipMode.h"

@implementation NOZCLIUnzipMode

+ (NSString *)modeFlag
{
    return @"-u";
}

+ (NSString *)modeName
{
    return @"Unzip";
}

+ (NSString *)modeExecutionDescription
{
    return @"[unzip_options] -i zip_file [-e [entry_options] entry1 [... [-e [entry_options] entryN]]]";
}

+ (NSUInteger)modeExtraArgumentsSectionCount
{
    return 2;
}

+ (NSString *)modeExtraArgumentsSectionName:(NSUInteger)sectionIndex
{
    if (1 == sectionIndex) {
        return @"unzip entry_options";
    }
    return @"unzip_options";
}

+ (NSArray<NSString *> *)modeExtraArgumentsSectionDescriptions:(NSUInteger)sectionIndex
{
    if (1 == sectionIndex) {
        return @[
                 @"-o OUTPUT_FILE    provide the specific output file",
                 @"-m METHOD         override the method to unzip the entry with",
                 ];
    }
    return @[
             @"-f                forcibly guess METHOD when unzipping an unknown METHOD",
             @"-F                forcibly fail when unzipping an unknown METHOD",
             @"-M METHOD NUMBER  map a METHOD to a different archive number... this impacts unzipping!",
             @"-b BASE_PATH      provide the base patht output to - default is directory named after archive, './zip_file/'",
             ];
}

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath
{
    return nil;
}

+ (int)run:(NOZCLIUnzipModeInfo *)info
{
    printf("NYI!\n");
    return -1;
}

@end
