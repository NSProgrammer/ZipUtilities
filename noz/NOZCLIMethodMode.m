//
//  NOZCLIMethodMode.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/8/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLI.h"
#import "NOZCLIMethodMode.h"

@implementation NOZCLIMethodModeInfo

- (instancetype)initInternal
{
    return [super init];
}

@end

@implementation NOZCLIMethodMode

+ (NSString *)modeFlag
{
    return @"-A";
}

+ (NSString *)modeName
{
    return @"All Methods";
}

+ (NSString *)modeExecutionDescription
{
    return @"";
}

+ (NSUInteger)modeExtraArgumentsSectionCount
{
    return 0;
}

+ (NSString *)modeExtraArgumentsSectionName:(NSUInteger)sectionIndex
{
    return nil;
}

+ (NSArray<NSString *> *)modeExtraArgumentsSectionDescriptions:(NSUInteger)sectionIndex
{
    return nil;
}

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath
{
    return [[NOZCLIMethodModeInfo alloc] initInternal];
}

+ (int)run:(NOZCLIMethodModeInfo *)unused
{
    for (MethodInfo *info in NOZCLI_allMethods()) {
        printf("(%u) \"%s\":\n", (unsigned int)info.method, info.name.UTF8String);
        if (info.levels > 0) {
            printf("\tLevels: 1-%tu, Default Level: %tu\n", info.levels, info.defaultLevel);
        }
        printf("\tSupport: ");
        if (info.method == NOZCompressionMethodNone) {
            printf("Default");
        } else if (!info.encoder || !info.decoder) {
            printf("Unsupported");
        } else if (info.isDefaultCodec) {
            printf("Default");
        } else {
            printf("Extended");
        }
        printf("\n");
    }
    return 1;
}

@end
