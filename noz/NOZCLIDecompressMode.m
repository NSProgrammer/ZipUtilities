//
//  NOZCLIDecompressMode.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLI.h"
#import "NOZCLIDecompressMode.h"

@interface NOZCLIDecompressModeInfo ()
@property (nonatomic, readonly) MethodInfo *methodInfo;
@end

@implementation NOZCLIDecompressModeInfo

- (instancetype)initWithMethodInfo:(MethodInfo *)methodInfo
                         inputFile:(NSString *)inputFile
                        outputFile:(NSString *)outputFile
{
    if (self = [super init]) {
        _methodInfo = methodInfo;
        _method = [methodInfo.name copy];
        _inputFile = [inputFile copy];
        _outputFile = [outputFile copy];
    }
    return self;
}

@end

@implementation NOZCLIDecompressMode

+ (NSString *)modeFlag
{
    return @"-d";
}

+ (NSString *)modeName
{
    return @"Decompress";
}

+ (NSString *)modeExecutionDescription
{
    return @"-m METHOD -i in_file -o out_file";
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

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args
                           environmentPath:(NSString *)envPath
{
    NSString *inputFile = nil;
    NSString *outputFile = nil;
    NSString *method = nil;

    for (NSUInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-m"]) {
            i++;
            if (i < args.count) {
                method = args[i];
            }
        } else if ([arg isEqualToString:@"-i"]) {
            i++;
            if (i < args.count) {
                inputFile = args[i];
            }
        } else if ([arg isEqualToString:@"-o"]) {
            i++;
            if (i < args.count) {
                outputFile = args[i];
            }
        } else {
            return nil;
        }
    }

    if (!method) {
        return nil;
    }

    BOOL isDir = NO;
    MethodInfo *methodInfo = NOZCLI_lookupMethodByName(method);
    inputFile = NOZCLI_normalizedPath(envPath, inputFile);
    outputFile = NOZCLI_normalizedPath(envPath, outputFile);

    if (!methodInfo) {
        printf("no such compression method \"%s\"!\n", method.UTF8String);
        return nil;
    }

    if (!methodInfo.encoder || !methodInfo.decoder) {
        printf("unsupported method  \"%s\"!\n", method.UTF8String);
        return nil;
    }

    if (!inputFile || ![[NSFileManager defaultManager] fileExistsAtPath:inputFile isDirectory:&isDir] || isDir) {
        return nil;
    }

    if (!outputFile) {
        return nil;
    }

    return [[NOZCLIDecompressModeInfo alloc] initWithMethodInfo:methodInfo
                                                      inputFile:inputFile
                                                     outputFile:outputFile];
}

+ (int)run:(NOZCLIDecompressModeInfo *)info
{
    if (!info) {
        return -1;
    }

    id<NOZDecoder> decoder = info.methodInfo.decoder;
    if (!decoder) {
        return -1;
    }

    NSError *error = nil;
    if (!NOZDecodeFile(info.inputFile, info.outputFile, decoder, &error)) {
        NOZCLI_printError(error);
        return -2;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    long long inSize = (long long)[[fm attributesOfItemAtPath:info.inputFile error:NULL] fileSize];
    long long outSize = (long long)[[fm attributesOfItemAtPath:info.outputFile error:NULL] fileSize];
    double ratio = NOZCLI_computeCompressionRatio(outSize, inSize);
    NSString *printMessage = [NSString stringWithFormat:@"input  size: %@\noutput size: %@\ncompression ratio: %f\n",
                              [NSByteCountFormatter stringFromByteCount:inSize countStyle:NSByteCountFormatterCountStyleBinary],
                              [NSByteCountFormatter stringFromByteCount:outSize countStyle:NSByteCountFormatterCountStyleBinary],
                              ratio];
    printf("%s", printMessage.UTF8String);

    return 1;
}

@end

