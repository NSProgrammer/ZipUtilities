//
//  NOZCLI.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLI.h"

#import "NOZCLICompressMode.h"
#import "NOZCLIDecompressMode.h"
#import "NOZCLIDumpMode.h"
#import "NOZCLIMethodMode.h"
#import "NOZCLIUnzipMode.h"
#import "NOZCLIZipMode.h"

#import "NOZXAppleCompressionCoder.h"
#import "NOZXBrotliCompressionCoder.h"
#import "NOZXZStandardCompressionCoder.h"

#define kMethodBrotli       (101)

@implementation MethodInfo

+ (instancetype)methodInfoWithName:(NSString *)name
                            method:(NOZCompressionMethod)method
                            levels:(NSUInteger)levels
                      defaultLevel:(NSUInteger)defaultLevel
                           encoder:(id<NOZEncoder>)encoder
                           decoder:(id<NOZDecoder>)decoder
                         isDefault:(BOOL)defaultEncoder
{
    return [[self alloc] initWithName:name
                               method:method
                               levels:levels
                         defaultLevel:defaultLevel
                              encoder:encoder
                              decoder:decoder
                            isDefault:defaultEncoder];
}

- (instancetype)initWithName:(NSString *)name
                      method:(NOZCompressionMethod)method
                      levels:(NSUInteger)levels
                defaultLevel:(NSUInteger)defaultLevel
                     encoder:(id<NOZEncoder>)encoder
                     decoder:(id<NOZDecoder>)decoder
                   isDefault:(BOOL)defaultEncoder
{
    if (self = [super init]) {
        _name = [name copy];
        _method = method;
        _levels = levels;
        _defaultLevel = defaultLevel;
        _defaultCodec = defaultEncoder;
        _encoder = encoder;
        _decoder = decoder;
    }
    return self;
}

- (NSString *)description
{
    NSString *codecInfo = nil;
    if (_method == NOZCompressionMethodNone) {
        codecInfo = @"Default";
    } else if (!_encoder || !_decoder) {
        codecInfo = @"Unsupported";
    } else if (_defaultCodec) {
        codecInfo = @"Default";
    } else {
        codecInfo = @"Extended";
    }

    return [NSString stringWithFormat:@"<%@: %p, name=\"%@\", methodEnum=%u, levels=%tu, codec=%@>", NSStringFromClass([self class]), self, _name, (unsigned int)_method, _levels, codecInfo];
}

@end

#define METHOD(theName, theMethod, theLevels, theDefaultLevel, theEncoder, theDecoder, theIsDefault) \
[MethodInfo methodInfoWithName:(theName) method:(theMethod) levels:(theLevels) defaultLevel:(theDefaultLevel) encoder:(theEncoder) decoder:(theDecoder) isDefault:(theIsDefault)]

#define ADD_METHOD(theArray, theName, theMethod, theIsDefault) \
do { \
    NOZCompressionMethod the_method = (theMethod); \
    id<NOZEncoder> the_encoder = [[NOZCompressionLibrary sharedInstance] encoderForMethod:the_method]; \
    id<NOZDecoder> the_decoder = [[NOZCompressionLibrary sharedInstance] decoderForMethod:the_method]; \
    if (!the_encoder || !the_decoder) { \
        the_encoder = nil; \
        the_decoder = nil; \
    } \
    NSUInteger the_levels = [the_encoder respondsToSelector:@selector(numberOfCompressionLevels)] ? [the_encoder numberOfCompressionLevels] : 0; \
    NSUInteger the_defaultLevel = [the_encoder respondsToSelector:@selector(defaultCompressionLevel)] ? [the_encoder defaultCompressionLevel] : 0; \
    [(theArray) addObject:METHOD((theName), the_method, the_levels, the_defaultLevel, the_encoder, the_decoder, (theIsDefault))]; \
} while (0)

#define UNS_ADD_METHOD(theArray, theName, theMethod) \
do { \
    NOZCompressionMethod the_method = (theMethod); \
    id<NOZEncoder> the_encoder = [[NOZCompressionLibrary sharedInstance] encoderForMethod:the_method]; \
    id<NOZDecoder> the_decoder = [[NOZCompressionLibrary sharedInstance] decoderForMethod:the_method]; \
    if (the_encoder && the_decoder) { \
        break; \
    } \
    [(theArray) addObject:METHOD((theName), the_method, 0, 0, nil, nil, NO)]; \
} while (0)

int NOZCLI_main(NSString *exe,
                NSString *exeDir,
                NSString *currentDir,
                NSArray<NSString *> *args)
{
    if (args.count == 0) {
        return -1;
    }

    NOZCLI_registerExtraEncoders();

    NSString *modeFlag = args[0];
    args = [args subarrayWithRange:NSMakeRange(1, args.count - 1)];

    NSArray<Class> *modes = NOZCLI_allModes();

    for (Class mode in modes) {
        if ([modeFlag isEqualToString:[mode modeFlag]]) {
            id<NOZCLIModeInfoProtocol> info = [mode infoFromArgs:args environmentPath:currentDir];
            return [mode run:info];
        }
    }

    return -1;
}

void NOZCLI_printUsage(NSString *exe, NSString *modeFlag)
{
    if (exe) {
        exe = @"noz";
    }

    printf("%s is the ZipUtilities CLI\n\n", exe.UTF8String);

    NSArray<Class> *modes = NOZCLI_allModes();

    if (modeFlag) {
        // if a mode was selected, just print how to use that mode
        for (Class mode in modes) {
            if ([[mode modeFlag] isEqualToString:modeFlag]) {
                modes = @[mode];
                break;
            }
        }
    }

    for (Class mode in modes) {
        NSString *modeDescription = [NSString stringWithFormat:@"%@ mode:\n\t%@ %@ %@", [mode modeName], exe, [mode modeFlag], [mode modeExecutionDescription]];
        printf("%s\n", modeDescription.UTF8String);
    }

    printf("%s", "\n");

    for (Class mode in modes) {
        NSUInteger count = [mode modeExtraArgumentsSectionCount];
        if (count > 0) {
            for (NSUInteger i = 0; i < count; i++) {
                NSString *name = [mode modeExtraArgumentsSectionName:i];
                NSArray<NSString *> *items = [mode modeExtraArgumentsSectionDescriptions:i];
                printf("%s:\n-------------------------------\n", name.UTF8String);
                for (NSString *item in items) {
                    printf("\t%s\n", item.UTF8String);
                }
                printf("%s", "\n");
            }
        }
    }
}

NSArray<Class> *NOZCLI_allModes()
{
    return @[
             [NOZCLIMethodMode class],
             [NOZCLIDumpMode class],
             [NOZCLICompressMode class],
             [NOZCLIDecompressMode class],
             [NOZCLIZipMode class],
             [NOZCLIUnzipMode class],
             ];
}

void NOZCLI_printError(NSError *error)
{
    NSString *errorString = [NSString stringWithFormat:@"ERROR: %@", error];
    printf("%s\n", errorString.UTF8String);
}

NSString *NOZCLI_normalizedPath(NSString *envPath, NSString *fileArg)
{
    if (fileArg) {
        if ([fileArg hasPrefix:@"/"]) {
            // leave as-is
        } else if ([fileArg hasPrefix:@"~"]) {
            fileArg = [fileArg stringByExpandingTildeInPath];
        } else {
            fileArg = [envPath stringByAppendingPathComponent:fileArg];
        }
    }

    return fileArg;
}

double NOZCLI_computeCompressionRatio(long long uncompressedBytes, long long compressedBytes)
{
    double ratio;
    if (uncompressedBytes > 0 && compressedBytes > 0) {
        ratio = ((double)uncompressedBytes / (double)compressedBytes);
    } else {
        ratio = NAN;
    }
    return ratio;
}

void NOZCLI_registerExtraEncoders(void)
{
    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    if ([NOZXAppleCompressionCoder isSupported]) {
        // Apple's Compression Lib is only supported on iOS 9+ and Mac OS X 10.11+

        // LZMA
        [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZMA]
                  forMethod:NOZCompressionMethodLZMA];
        [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZMA]
                  forMethod:NOZCompressionMethodLZMA];

        // LZ4
        [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZ4]
                  forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];
        [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZ4]
                  forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];

        // Apple LZFSE - the new hotness for compression from Apple
        [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZFSE]
                  forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
        [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZFSE]
                  forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
    }

    [library setEncoder:[NOZXBrotliCompressionCoder encoder]
              forMethod:kMethodBrotli];
    [library setDecoder:[NOZXBrotliCompressionCoder decoder]
              forMethod:kMethodBrotli];

    [library setEncoder:[NOZXZStandardCompressionCoder encoder]
              forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:[NOZXZStandardCompressionCoder decoder]
              forMethod:NOZCompressionMethodZStandard];
}

NSArray<MethodInfo *> *NOZCLI_allMethods()
{
    NSMutableArray<MethodInfo *> *methods = [[NSMutableArray alloc] init];
    [methods addObjectsFromArray:NOZCLI_allDefaultMethods()];
    [methods addObjectsFromArray:NOZCLI_allExtendedMethods()];
    [methods addObjectsFromArray:NOZCLI_allUnsupportedMethods()];
    return methods;
}

MethodInfo *NOZCLI_lookupMethod(NOZCompressionMethod method)
{
    for (MethodInfo *info in NOZCLI_allMethods()) {
        if (info.method == method) {
            return info;
        }
    }
    return nil;
}

MethodInfo *NOZCLI_lookupMethodByName(NSString *method)
{
    for (MethodInfo *info in NOZCLI_allMethods()) {
        if ([info.name isEqualToString:method]) {
            return info;
        }
    }
    return nil;
}

NSArray<MethodInfo *> *NOZCLI_allUnsupportedMethods()
{
    NSMutableArray<MethodInfo *> *methods = [[NSMutableArray alloc] init];

    UNS_ADD_METHOD(methods, @"Shrink", NOZCompressionMethodShrink);
    UNS_ADD_METHOD(methods, @"Reduce #1", NOZCompressionMethodReduce1);
    UNS_ADD_METHOD(methods, @"Reduce #2", NOZCompressionMethodReduce2);
    UNS_ADD_METHOD(methods, @"Reduce #3", NOZCompressionMethodReduce3);
    UNS_ADD_METHOD(methods, @"Reduce #4", NOZCompressionMethodReduce4);
    UNS_ADD_METHOD(methods, @"Implode", NOZCompressionMethodImplode);
    UNS_ADD_METHOD(methods, @"*PKWare Reserved*", NOZCompressionMethodReserved7);
    UNS_ADD_METHOD(methods, @"Deflate", NOZCompressionMethodDeflate);
    UNS_ADD_METHOD(methods, @"Deflate64", NOZCompressionMethodDeflate64);
    UNS_ADD_METHOD(methods, @"IBM TERSE (old)", NOZCompressionMethodIBMTERSEOld);
    UNS_ADD_METHOD(methods, @"*PKWare Reserved*", NOZCompressionMethodReserved11);
    UNS_ADD_METHOD(methods, @"BZip2", NOZCompressionMethodBZip2);
    UNS_ADD_METHOD(methods, @"*PKWare Reserved*", NOZCompressionMethodReserved13);
    UNS_ADD_METHOD(methods, @"LZMA", NOZCompressionMethodLZMA);
    UNS_ADD_METHOD(methods, @"*PKWare Reserved*", NOZCompressionMethodReserved15);
    UNS_ADD_METHOD(methods, @"*PKWare Reserved*", NOZCompressionMethodReserved16);
    UNS_ADD_METHOD(methods, @"*PKWare Reserved*", NOZCompressionMethodReserved17);
    UNS_ADD_METHOD(methods, @"IBM TERSE (new)", NOZCompressionMethodIBMTERSENew);
    UNS_ADD_METHOD(methods, @"LZ77", NOZCompressionMethodLZ77);
    UNS_ADD_METHOD(methods, @"*Deprecated*", NOZCompressionMethodDeprecated20);

    UNS_ADD_METHOD(methods, @"MP3", NOZCompressionMethodMP3);
    UNS_ADD_METHOD(methods, @"XZ", NOZCompressionMethodXZ);
    UNS_ADD_METHOD(methods, @"JPEG", NOZCompressionMethodJPEG);
    UNS_ADD_METHOD(methods, @"WAV Pack", NOZCompressionMethodWAVPack);
    UNS_ADD_METHOD(methods, @"PPM v1 rev1", NOZCompressionMethodPPMv1rev1);
    UNS_ADD_METHOD(methods, @"AE-x Encrypted", NOZCompressionMethodAEXEncryption);

    return methods;
}

NSArray<MethodInfo *> *NOZCLI_allDefaultMethods()
{
    NSMutableArray<MethodInfo *> *methods = [[NSMutableArray alloc] init];

    [methods addObject:METHOD(@"None", NOZCompressionMethodNone, 0, 0, nil, nil, YES)];
    ADD_METHOD(methods, @"Deflate", NOZCompressionMethodDeflate, YES);

    return methods;
}

NSArray<MethodInfo *> *NOZCLI_allExtendedMethods()
{
    NSMutableArray<MethodInfo *> *methods = [[NSMutableArray alloc] init];

    ADD_METHOD(methods, @"ZStandard", NOZCompressionMethodZStandard, NO);
    ADD_METHOD(methods, @"Brotli", kMethodBrotli, NO); /* TODO: Apple is adding Brotli to iOS 15 (COMPRESSION_BROTLI) */

    if ([NOZXAppleCompressionCoder isSupported]) {
        ADD_METHOD(methods, @"LZMA", NOZCompressionMethodLZMA, NO);
        ADD_METHOD(methods, @"LZ4", (NOZCompressionMethod)COMPRESSION_LZ4, NO);
        ADD_METHOD(methods, @"LZFSE", (NOZCompressionMethod)COMPRESSION_LZFSE, NO);
    }

    return methods;
}

BOOL NOZCLI_registerMethodToNumberMap(NSDictionary<NSString *, NSNumber *> * __nullable methodToNumberMap)
{
    NOZCompressionLibrary *lib = [NOZCompressionLibrary sharedInstance];
    NSMutableDictionary<NSNumber *, MethodInfo *> *methodMap = [[NSMutableDictionary alloc] init];
    for (NSString *methodName in methodToNumberMap.allKeys) {
        MethodInfo *methodInfo = NOZCLI_lookupMethodByName(methodName);
        if (!methodInfo) {
            printf("No such method name: %s\n", methodName.UTF8String);
            return NO;
        }
        NSNumber *methodNumber = methodToNumberMap[methodName];
        methodMap[methodNumber] = methodInfo;
    }
    for (NSNumber *methodNumber in methodMap.allKeys) {
        MethodInfo *methodInfo = methodMap[methodNumber];
        [lib setEncoder:methodInfo.encoder
              forMethod:methodNumber.unsignedShortValue];
        [lib setDecoder:methodInfo.decoder
              forMethod:methodNumber.unsignedShortValue];
    }
    return YES;
}
