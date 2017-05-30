//
//  NOZCLIZipMode.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIZipMode.h"

@implementation NOZCLIZipMode

+ (NSString *)modeFlag
{
    return @"-z";
}

+ (NSString *)modeName
{
    return @"Zip";
}

+ (NSString *)modeExecutionDescription
{
    return @"[zip_options] -o output_file -i [file_options] input_file1 [... [-i [file_options] intpu_fileN]]";
}

+ (NSUInteger)modeExtraArgumentsSectionCount
{
    return 2;
}

+ (NSString *)modeExtraArgumentsSectionName:(NSUInteger)sectionIndex
{
    if (1 == sectionIndex) {
        return @"zip file_options";
    }
    return @"zip_options";
}

+ (NSArray<NSString *> *)modeExtraArgumentsSectionDescriptions:(NSUInteger)sectionIndex
{
    if (1 == sectionIndex) {
        return @[
                 @"-c COMMENT        provide an archive comment",
                 @"-n NAME           override the name",
                 @"-m METHOD         specify a compression method, default is \"deflate\" (see METHODS below)",
                 @"-l LEVEL          specify a compression level, levels are defined per METHOD each with their own default",
                 @"-h                permit hidden file(s)",
                 @"-f                don't recurse into the director if provided path was a directory (default is to recurse)",
                 ];
    }
    return @[
             @"-c COMMENT        provide an archive entry comment",
             @"-M METHOD NUMBER  map a METHOD to a different archive number... this impacts unzipping!",
             ];
}

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath
{
    return nil;
}

+ (int)run:(NOZCLIZipModeInfo *)info
{
    printf("NYI!\n");
    return -1;
}

@end
