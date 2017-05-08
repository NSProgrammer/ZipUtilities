//
//  NOZCLI.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ZipUtilities/ZipUtilities.h>

// TODO: write unit tests

@class MethodInfo;

FOUNDATION_EXTERN int NOZCLI_main(NSString *exe, NSString *exeDir, NSString *currentDir, NSArray<NSString *> *args);
FOUNDATION_EXTERN void NOZCLI_printUsage(NSString *exe);

FOUNDATION_EXTERN void NOZCLI_registerExtraEncoders(void);

FOUNDATION_EXTERN void NOZCLI_printError(NSError *error);
FOUNDATION_EXTERN NSString *NOZCLI_normalizedPath(NSString *envPath, NSString *fileArg);
FOUNDATION_EXTERN double NOZCLI_computeCompressionRatio(long long uncompressedBytes, long long compressedBytes);

FOUNDATION_EXTERN MethodInfo *NOZCLI_lookupMethod(NOZCompressionMethod method);
FOUNDATION_EXTERN MethodInfo *NOZCLI_lookupMethodByName(NSString *method);

FOUNDATION_EXTERN NSArray<MethodInfo *> *NOZCLI_allMethods(void);
FOUNDATION_EXTERN NSArray<MethodInfo *> *NOZCLI_allUnsupportedMethods(void);
FOUNDATION_EXTERN NSArray<MethodInfo *> *NOZCLI_allDefaultMethods(void);
FOUNDATION_EXTERN NSArray<MethodInfo *> *NOZCLI_allExtendedMethods(void);

FOUNDATION_EXTERN NSArray<Class> *NOZCLI_allModes(void);

@interface MethodInfo : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, readonly) NOZCompressionMethod method;
@property (nonatomic, readonly) NSUInteger levels;
@property (nonatomic, readonly) NSUInteger defaultLevel;

@property (nonatomic, readonly) id<NOZEncoder> encoder;
@property (nonatomic, readonly) id<NOZDecoder> decoder;
@property (nonatomic, readonly, getter=isDefaultCodec) BOOL defaultCodec;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
