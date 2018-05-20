//
//  NOZCLIUnzipMode.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLI.h"
#import "NOZCLIUnzipMode.h"

@interface NOZCLIUnzipDecompressDelegate : NSObject <NOZDecompressDelegate>
@end

@interface NOZCLIUnzipModeEntryInfo : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *methodName;
@property (nonatomic, copy, readonly, nullable) NSString *outputPath;
@property (nonatomic, copy, readonly, nonnull) NSString *entryName;

+ (NSArray<NOZCLIUnzipModeEntryInfo *> *)entryInfosFromArgs:(NSArray<NSString *> *)args basePath:(NSString *)basePath environmentPath:(NSString *)envPath;

@end

@interface NOZCLIUnzipModeInfo ()

@property (nonatomic, readonly, copy) NSString *inputFilePath;
@property (nonatomic, readonly) BOOL forceGuessUnknownMethod;
@property (nonatomic, readonly) BOOL forceFailUnknownMethod;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSNumber *> *methodToNumberMap;
@property (nonatomic, readonly, copy) NSString *baseOutputPath;
@property (nonatomic, readonly, copy) NSArray<NOZCLIUnzipModeEntryInfo *> *entryInfos;

- (instancetype)initWithInputFilePath:(NSString *)inputFilePath
              forceGuessUnknownMethod:(BOOL)guessUnknown
               forceFailUnknownMethod:(BOOL)failUnknown
                    methodToNumberMap:(NSDictionary<NSString *, NSNumber *> *)map
                       baseOutputPath:(NSString *)baseOutputPath
                           entryInfos:(NSArray<NOZCLIUnzipModeEntryInfo *> *)entryInfos;

@end

@implementation NOZCLIUnzipModeInfo

- (instancetype)initWithInputFilePath:(NSString *)inputFilePath
              forceGuessUnknownMethod:(BOOL)guessUnknown
               forceFailUnknownMethod:(BOOL)failUnknown
                    methodToNumberMap:(NSDictionary<NSString *,NSNumber *> *)map
                       baseOutputPath:(NSString *)baseOutputPath
                           entryInfos:(NSArray<NOZCLIUnzipModeEntryInfo *> *)entryInfos
{
    if (self = [super init]) {
        _inputFilePath = [inputFilePath copy];
        _forceGuessUnknownMethod = guessUnknown;
        _forceFailUnknownMethod = failUnknown;
        _methodToNumberMap = [map copy];
        _baseOutputPath = [baseOutputPath copy];
        _entryInfos = [entryInfos copy];
    }
    return self;
}

@end

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
             @"-b BASE_PATH      provide the base path output to.  Default is directory named after archive, './zip_file/'",
             ];
}

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args environmentPath:(NSString *)envPath
{
    BOOL forceGuessUnknownMethod = NO;
    BOOL forceFailUnknownMethod = NO;
    NSMutableDictionary<NSString *, NSNumber *> *methodToNumberMap = [[NSMutableDictionary alloc] init];
    NSString *baseOutputPath = nil;
    NSString *inputFilePath = nil;
    NSArray<NOZCLIUnzipModeEntryInfo *> *entryInfos = nil;

    for (NSUInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-f"]) {
            forceGuessUnknownMethod = YES;
        } else if ([arg isEqualToString:@"-F"]) {
            forceFailUnknownMethod = YES;
        } else if ([arg isEqualToString:@"-b"]) {
            i++;
            if (i < args.count) {
                baseOutputPath = NOZCLI_normalizedPath(envPath, args[i]);
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
        } else if ([arg isEqualToString:@"-e"]) {
            NSArray<NSString *> *subargs = [args subarrayWithRange:NSMakeRange(i, args.count - i)];
            entryInfos = [NOZCLIUnzipModeEntryInfo entryInfosFromArgs:subargs basePath:baseOutputPath environmentPath:envPath];
            if (entryInfos.count == 0) {
                return nil;
            } else {
                break;
            }
        } else if ([arg isEqualToString:@"-i"]) {
            i++;
            if (i < args.count) {
                inputFilePath = NOZCLI_normalizedPath(envPath, args[i]);
            } else {
                return nil;
            }
        } else {
            return nil;
        }
    }

    if (!baseOutputPath) {
        baseOutputPath = [[envPath stringByAppendingPathComponent:inputFilePath.lastPathComponent] stringByDeletingPathExtension];
    }

    return [[NOZCLIUnzipModeInfo alloc] initWithInputFilePath:inputFilePath
                                      forceGuessUnknownMethod:forceGuessUnknownMethod
                                       forceFailUnknownMethod:forceFailUnknownMethod
                                            methodToNumberMap:methodToNumberMap
                                               baseOutputPath:baseOutputPath
                                                   entryInfos:entryInfos];
}

+ (int)run:(NOZCLIUnzipModeInfo *)info
{
    if (!NOZCLI_registerMethodToNumberMap(info.methodToNumberMap)) {
        return -1;
    }

    if (0 == info.entryInfos.count) {
        id<NOZDecompressDelegate> decompressDelegate = [[NOZCLIUnzipDecompressDelegate alloc] init];
        NOZDecompressRequest *request = [[NOZDecompressRequest alloc] initWithSourceFilePath:info.inputFilePath destinationDirectoryPath:info.baseOutputPath];
        NOZDecompressOperation *op = [[NOZDecompressOperation alloc] initWithRequest:request delegate:decompressDelegate];
        [op start]; // will run synchronously
        NOZDecompressResult *result = op.result;
        if (result.operationError) {
            printf("\n");
            NOZCLI_printError(result.operationError);
            return -2;
        }

        if (!result.didSucceed) {
            printf("\n");
            printf("FAILED!\n");
            return -2;
        }

        fprintf(stdout, "\r");
        fflush(stdout);
        printf("compression ratio: %f\n", result.compressionRatio);
        return 0;
    }

    NOZUnzipper *unzipper = [[NOZUnzipper alloc] initWithZipFile:info.inputFilePath];

    NSError *error = nil;
    if (![unzipper openAndReturnError:&error]) {
        NOZCLI_printError(error);
        return -2;
    }

    if (![unzipper readCentralDirectoryAndReturnError:&error]) {
        NOZCLI_printError(error);
        return -2;
    }

    NOZProgressBlock progressBlock = ^(int64_t totalBytes, int64_t bytesComplete, int64_t bytesCompletedThisPass, BOOL *abort) {
        const double progress = (double)bytesComplete / (double)totalBytes;
        fprintf(stdout, "\r%li%%", (long)progress);
        fflush(stdout);
    };
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    for (NOZCLIUnzipModeEntryInfo *entry in info.entryInfos) {
        NSUInteger index = [unzipper indexForRecordWithName:entry.entryName];
        if (NSNotFound == index) {
            [fm removeItemAtPath:tmpDir error:NULL];
            printf("no such Zip record named '%s'\n", entry.entryName.UTF8String);
            return -2;
        }
        NOZCentralDirectoryRecord *record = [unzipper readRecordAtIndex:index error:&error];
        if (!record) {
            [fm removeItemAtPath:tmpDir error:NULL];
            NOZCLI_printError(error);
            return -2;
        }

        printf("%s\n", record.name.UTF8String);

        if (![unzipper saveRecord:record toDirectory:tmpDir options:NOZUnzipperSaveRecordOptionIgnoreIntermediatePath progressBlock:progressBlock error:&error]) {
            [fm removeItemAtPath:tmpDir error:NULL];
            printf("\n");
            NOZCLI_printError(error);
            return -2;
        }
        fprintf(stdout, "\r");
        fflush(stdout);

        NSString *tmpPath = [tmpDir stringByAppendingPathComponent:record.name.lastPathComponent];
        NSString *dstPath = entry.outputPath ?: [info.baseOutputPath stringByAppendingPathComponent:entry.entryName];

        [fm createDirectoryAtPath:[dstPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];

        if (![fm moveItemAtPath:tmpPath toPath:dstPath error:&error]) {
            [fm removeItemAtPath:tmpDir error:NULL];
            NOZCLI_printError(error);
            return -2;
        }
    }
    [fm removeItemAtPath:tmpDir error:NULL];

    [unzipper closeAndReturnError:NULL];

    return 0;
}

@end

@implementation NOZCLIUnzipModeEntryInfo

+ (NSArray<NOZCLIUnzipModeEntryInfo *> *)entryInfosFromArgs:(NSArray<NSString *> *)args basePath:(NSString *)basePath environmentPath:(NSString *)envPath
{
    NSMutableArray<NOZCLIUnzipModeEntryInfo *> *entries = [[NSMutableArray alloc] init];
    NSMutableIndexSet *eIndexes = [[args indexesOfObjectsPassingTest:^BOOL(NSString *arg, NSUInteger idx, BOOL *stop) {
        return [arg isEqualToString:@"-e"];
    }] mutableCopy];

    NSMutableArray<NSArray<NSString *> *> *entryArgs = [[NSMutableArray alloc] init];
    if (eIndexes.count == 0) {
        return nil;
    }

    NSUInteger prevIndex = 0;
    do {
        const NSUInteger curIndex = eIndexes.firstIndex;
        [eIndexes removeIndex:curIndex];
        if (prevIndex != NSNotFound) {
            if (prevIndex != curIndex) {
                [entryArgs addObject:[args subarrayWithRange:NSMakeRange(prevIndex, curIndex - prevIndex)]];
            }
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
        NOZCLIUnzipModeEntryInfo *entry = [NOZCLIUnzipModeEntryInfo entryFromArgs:argsForSingleEntry basePath:basePath environmentPath:envPath];
        if (!entry) {
            printf("invalid arguments for unzipping a specific entry!\n");
            for (NSString *arg in argsForSingleEntry) {
                printf("%s ", arg.UTF8String);
            }
            printf("\n");
        }
        [entries addObject:entry];
    }

    return entries;
}

+ (instancetype)entryFromArgs:(NSArray<NSString *> *)args basePath:(NSString *)basePath environmentPath:(NSString *)environmentPath
{
    NSString *name = nil;
    NSString *outputPath = nil;
    NSString *methodName = nil;
    BOOL leadsWithCorrectFlag = NO;

    for (NSUInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if (!leadsWithCorrectFlag) {
            leadsWithCorrectFlag = [arg isEqualToString:@"-e"];
            if (!leadsWithCorrectFlag) {
                break;
            }
            continue;
        }

        if ([arg isEqualToString:@"-o"]) {
            i++;
            if (i >= args.count) {
                return nil;
            }
            outputPath = args[i];
        } else if ([arg isEqualToString:@"-m"]) {
            i++;
            if (i >= args.count) {
                return nil;
            }
            methodName = args[i];
        } else {
            if (name) {
                return nil;
            }
            name = arg;
        }
    }

    if (!name) {
        return nil;
    }

    if (!leadsWithCorrectFlag) {
        return nil;
    }

    outputPath = NOZCLI_normalizedPath(basePath ?: environmentPath, outputPath);

    return [[self alloc] initWithName:name method:methodName outputPath:outputPath];
}

- (instancetype)initWithName:(NSString *)name method:(NSString *)methodName outputPath:(NSString *)outputPath
{
    if (self = [super init]) {
        _entryName = [name copy];
        _methodName = [methodName copy];
        _outputPath = [outputPath copy];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p, name=%@, method=%@, output=%@>", NSStringFromClass([self class]), self, _entryName, _methodName, _outputPath];
}

@end

@implementation NOZCLIUnzipDecompressDelegate
{
    long _lastProgress;
}

- (void)decompressOperation:(NOZDecompressOperation *)op didCompleteWithResult:(NOZDecompressResult *)result
{
}

- (void)decompressOperation:(NOZDecompressOperation *)op didUpdateProgress:(float)progress
{
    const long progressInt = (long)(progress * 100.f);
    if (progressInt == _lastProgress) {
        return;
    }
    _lastProgress = progressInt;
    fprintf(stdout, "\r%li%%", progressInt);
    fflush(stdout);
}

- (BOOL)shouldDecompressOperation:(NOZDecompressOperation *)op overwriteFileAtPath:(NSString *)path
{
    return NO;
}

@end
