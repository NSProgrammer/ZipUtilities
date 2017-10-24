//
//  NOZCLIZipMode.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLI.h"
#import "NOZCLIZipMode.h"

@interface NOZCLIZipModeEntryInfo : NSObject

@property (nonatomic, copy, readonly) NSString *comment;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *level;
@property (nonatomic, copy, readonly) NSString *methodName;
@property (nonatomic, copy, readonly) NSString *entryPath;
@property (nonatomic, readonly) BOOL permitHiddenFiles;
@property (nonatomic, readonly) BOOL recurse;

+ (NSArray<NOZCLIZipModeEntryInfo *> *)entryInfosFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath;
+ (instancetype)entryFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath;
- (instancetype)initWithEntryPath:(NSString *)entryPath
                             name:(NSString *)name
                            level:(NSString *)level
                       methodName:(NSString *)methodName
                          comment:(NSString *)comment
                permitHiddenFiles:(BOOL)permitHiddenFiles
                          recurse:(BOOL)recurse;

@end

@interface NOZCLIZipModeInfo ()

@property (nonatomic, copy, readonly) NSString *globalComment;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSNumber *> *methodToNumberMap;
@property (nonatomic, copy, readonly) NSArray<NOZCLIZipModeEntryInfo *> *entryInfos;
@property (nonatomic, copy, readonly) NSString *outputFile;
@property (nonatomic, copy, readonly) NSString *envPath;

- (instancetype)initWithGlobalComment:(NSString *)globalComment
                    methodToNumberMap:(NSDictionary<NSString *, NSNumber *> *)methodToNumberMap
                           entryInfos:(NSArray<NOZCLIZipModeEntryInfo *> *)entryInfos
                           outputFile:(NSString *)outputFile
                      environmentPath:(NSString *)envPath;

@end

@implementation NOZCLIZipMode

+ (NSString *)modeFlag
{
    return @"-z";
}

+ (NSString *)modeName
{
    return @"Zip (NYI)";
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
                 @"-c COMMENT        provide an archive entry comment",
                 @"-n NAME           override the name",
                 @"-m METHOD         specify a compression method, default is \"deflate\" (see METHODS below)",
                 @"-l LEVEL          specify a compression level, levels are defined per METHOD each with their own default",
                 @"-h                permit hidden file(s)",
                 @"-f                don't recurse into the director if provided path was a directory (default is to recurse)",
                 ];
    }
    return @[
             @"-c COMMENT        provide an archive comment",
             @"-M METHOD NUMBER  map a METHOD to a different archive number... this impacts unzipping!",
             ];
}

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath
{
    NSString *globalComment = nil;
    NSMutableDictionary<NSString *, NSNumber *> *methodToNumberMap = [[NSMutableDictionary alloc] init];
    NSString *outputFile = nil;
    NSArray<NOZCLIZipModeEntryInfo *> *entryInfos = nil;

    for (NSUInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-c"]) {
            i++;
            if (i < args.count) {
                globalComment = args[i];
            } else {
                return nil;
            }
        } else if ([arg isEqualToString:@"-o"]) {
            i++;
            if (i < args.count) {
                outputFile = NOZCLI_normalizedPath(envPath, args[i]);
            } else {
                return nil;
            }
        } else if ([arg isEqualToString:@"-M"]) {
            i++;
            if (i < (args.count - 1)) {
                NSString *methodName = args[i];
                i++;
                NSString *methodNumberString = args[i];
                NSNumber *methodNumber = @(methodNumberString.integerValue);

                BOOL valid = YES;
                if (methodNumber.integerValue < 0) {
                    valid = NO;
                } else if (methodNumber.integerValue == 0 && ![methodNumberString isEqualToString:@"0"]) {
                    valid = NO;
                } else if (methodNumber.integerValue > UINT16_MAX) {
                    valid = NO;
                }

                if (!valid) {
                    printf("method map from '%s' to '%s' is invalid ('%s' is not a valid method archive number)\n", methodName.UTF8String, methodNumberString.UTF8String, methodNumberString.UTF8String);
                    return nil;
                }

                methodToNumberMap[methodName] = methodNumber;
            } else {
                return nil;
            }
        } else if ([arg isEqualToString:@"-i"]) {
            NSArray<NSString *> *subargs = [args subarrayWithRange:NSMakeRange(i, args.count - i)];
            entryInfos = [NOZCLIZipModeEntryInfo entryInfosFromArgs:subargs environmentPath:envPath];
            if (entryInfos.count == 0) {
                return nil;
            } else {
                break;
            }
        } else {
            return nil;
        }
    }


    return [[NOZCLIZipModeInfo alloc] initWithGlobalComment:globalComment
                                          methodToNumberMap:methodToNumberMap
                                                 entryInfos:entryInfos
                                                 outputFile:outputFile
                                            environmentPath:envPath];
}

+ (int)run:(NOZCLIZipModeInfo *)info
{
    printf("NYI!\n");
    return -1;
}

@end

@implementation NOZCLIZipModeEntryInfo

+ (NSArray<NOZCLIZipModeEntryInfo *> *)entryInfosFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath
{
    NSMutableArray<NOZCLIZipModeEntryInfo *> *entries = [[NSMutableArray alloc] init];
    NSMutableIndexSet *eIndexes = [[args indexesOfObjectsPassingTest:^BOOL(NSString *arg, NSUInteger idx, BOOL *stop) {
        return [arg isEqualToString:@"-i"];
    }] mutableCopy];

    NSMutableArray<NSArray<NSString *> *> *entryArgs = [[NSMutableArray alloc] init];
    if (eIndexes.count == 0) {
        return nil;
    }

    NSUInteger prevIndex = NSNotFound;
    do {
        const NSUInteger curIndex = eIndexes.firstIndex;
        [eIndexes removeIndex:curIndex];
        if (prevIndex != NSNotFound) {
            [entryArgs addObject:[args subarrayWithRange:NSMakeRange(prevIndex, curIndex - prevIndex)]];
            if (!eIndexes.count) {
                [entryArgs addObject:[args subarrayWithRange:NSMakeRange(curIndex, args.count - curIndex)]];
            }
        }
        prevIndex = curIndex;
    } while (eIndexes.count);

    if (entryArgs.count == 0) {
        return nil;
    }

    for (NSArray<NSString *> *argsForSingleEntry in entryArgs) {
        NOZCLIZipModeEntryInfo *entry = [NOZCLIZipModeEntryInfo entryFromArgs:argsForSingleEntry environmentPath:envPath];
        if (!entry) {
            printf("invalid arguments for zipping a specific file!\n");
            for (NSString *arg in argsForSingleEntry) {
                printf("%s ", arg.UTF8String);
            }
            printf("\n");
        }
        [entries addObject:entry];
    }

    return entries;
}

+ (instancetype)entryFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath
{
    NSString *comment = nil;
    NSString *name = nil;
    NSString *level = nil;
    NSString *methodName = nil;
    NSString *entryPath = nil;
    BOOL permitHiddenFiles = NO;
    BOOL recurse = YES;

    for (NSUInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if (!entryPath) {
            if (![arg isEqualToString:@"-i"]) {
                break;
            }
            i++;
            if (i >= args.count) {
                return nil;
            }
            entryPath = args[i];
            continue;
        }

        if ([arg isEqualToString:@"-c"]) {
            i++;
            if (i >= args.count) {
                return nil;
            }
            comment = args[i];
        } else if ([arg isEqualToString:@"-n"]) {
            i++;
            if (i >= args.count) {
                return nil;
            }
            name = args[i];
        } else if ([arg isEqualToString:@"-m"]) {
            i++;
            if (i >= args.count) {
                return nil;
            }
            methodName = args[i];
        } else if ([arg isEqualToString:@"-l"]) {
            i++;
            if (i >= args.count) {
                return nil;
            }
            level = args[i];
        } else if ([arg isEqualToString:@"-h"]) {
            permitHiddenFiles = YES;
        } else if ([arg isEqualToString:@"-f"]) {
            recurse = NO;
        } else {
            return nil;
        }
    }

    entryPath = NOZCLI_normalizedPath(envPath, envPath);
    if (!entryPath) {
        return nil;
    }

    return [[self alloc] initWithEntryPath:entryPath name:name level:level methodName:methodName comment:comment permitHiddenFiles:permitHiddenFiles recurse:recurse];
}

- (instancetype)initWithEntryPath:(NSString *)entryPath
                             name:(NSString *)name
                            level:(NSString *)level
                       methodName:(NSString *)methodName
                          comment:(NSString *)comment
                permitHiddenFiles:(BOOL)permitHiddenFiles
                          recurse:(BOOL)recurse
{
    if (self = [super init]) {
        _entryPath = [entryPath copy];
        _name = [name copy];
        _level = [level copy];
        _methodName = [methodName copy];
        _comment = [comment copy];
        _permitHiddenFiles = permitHiddenFiles;
        _recurse = recurse;
    }
    return self;
}

@end

@implementation NOZCLIZipModeInfo

- (instancetype)initWithGlobalComment:(NSString *)globalComment
                    methodToNumberMap:(NSDictionary<NSString *, NSNumber *> *)methodToNumberMap
                           entryInfos:(NSArray<NOZCLIZipModeEntryInfo *> *)entryInfos
                           outputFile:(NSString *)outputFile
                      environmentPath:(NSString *)envPath
{
    if (self = [super init]) {
        _globalComment = [globalComment copy];
        _methodToNumberMap = [methodToNumberMap copy];
        _entryInfos = [entryInfos copy];
        _outputFile = [outputFile copy];
        _envPath = [envPath copy];
    }
    return self;
}

@end
