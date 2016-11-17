//
//  ViewController.m
//  ZipUtilitiesApp
//
//  Created by Nolan O'Brien on 11/16/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#import "NOZXAppleCompressionCoder.h"
#import "NOZXZStandardCompressionCoder.h"
#import "ViewController.h"

@import ZipUtilities;

@interface FastZSTDDecoder : NSObject <NOZDecoder>
@property (nonatomic, nullable, readonly) NSData *dictionaryData;
- (instancetype)initWithDictionaryData:(NSData *)dictionaryData;
- (instancetype)init NS_UNAVAILABLE;
@end

#define NOZCompressionMethodZStandard       (100)
#define NOZCompressionMethodZStandard_D128  (101)
#define NOZCompressionMethodZStandard_D256  (102)
#define NOZCompressionMethodZStandard_D512  (104)
#define NOZCompressionMethodZStandard_D1024 (108)
#define NOZCompressionMethodZStandard_DBOOK (190)

typedef struct _Coder {
    const char *name;
    NOZCompressionMethod method;
    NOZCompressionLevel level;
} Coder;

typedef struct _RunResult {
    NSTimeInterval compressDuration;
    NSTimeInterval decompressDuration;
    double compressionRatio;
} RunResult;

@protocol CoderWithDictionary <NSObject>
- (NSData *)dictionaryData;
@end

static const Coder kMethods[] = {
    { "deflate.6", NOZCompressionMethodDeflate, 6 },
    { "lzma.6", NOZCompressionMethodLZMA, 9 },
    { "lz4", (NOZCompressionMethod)COMPRESSION_LZ4, 9 },
    { "lzfse", (NOZCompressionMethod)COMPRESSION_LZFSE, 9 },
    { "zstd.7", NOZCompressionMethodZStandard, 3 },
    { "zstd.book.7", NOZCompressionMethodZStandard_DBOOK, 3 },
    { "zstd.128.7", NOZCompressionMethodZStandard_D128, 3 },
    { "zstd.256.7", NOZCompressionMethodZStandard_D256, 3 },
    { "zstd.512.7", NOZCompressionMethodZStandard_D512, 3 },
    { "zstd.1024.7", NOZCompressionMethodZStandard_D1024, 3 },
};

static NSData *sSourceData = nil;

@interface ViewController ()
{
    UITextView *_textView;
    dispatch_queue_t _queue;
}

@end

@implementation ViewController

+ (void)initialize
{
    NOZCompressionLibrary *library = [NOZCompressionLibrary sharedInstance];

    [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZMA] forMethod:NOZCompressionMethodLZMA];
    [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZMA] forMethod:NOZCompressionMethodLZMA];

    [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZ4] forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];
    [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZ4] forMethod:(NOZCompressionMethod)COMPRESSION_LZ4];

    [library setEncoder:[NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZFSE] forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
    [library setDecoder:[NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZFSE] forMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];

    NSBundle *bundle = [NSBundle mainBundle];

    NSString *dbookFile = [bundle pathForResource:@"book" ofType:@"zstd_dict"];
    NSData *dbookData = [NSData dataWithContentsOfFile:dbookFile];
    NSString *d128File = [bundle pathForResource:@"htl.128" ofType:@"zstd_dict"];
    NSData *d128Data = [NSData dataWithContentsOfFile:d128File];
    NSString *d256File = [bundle pathForResource:@"htl.256" ofType:@"zstd_dict"];
    NSData *d256Data = [NSData dataWithContentsOfFile:d256File];
    NSString *d512File = [bundle pathForResource:@"htl.512" ofType:@"zstd_dict"];
    NSData *d512Data = [NSData dataWithContentsOfFile:d512File];
    NSString *d1024File = [bundle pathForResource:@"htl.1024" ofType:@"zstd_dict"];
    NSData *d1024Data = [NSData dataWithContentsOfFile:d1024File];

    // No dictionary coder

    [library setEncoder:[NOZXZStandardCompressionCoder encoder] forMethod:NOZCompressionMethodZStandard];
    [library setDecoder:[NOZXZStandardCompressionCoder decoder] forMethod:NOZCompressionMethodZStandard];

    // Dictionary coders

    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:dbookData] forMethod:NOZCompressionMethodZStandard_DBOOK];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:dbookData] forMethod:NOZCompressionMethodZStandard_DBOOK];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d128Data] forMethod:NOZCompressionMethodZStandard_D128];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d128Data] forMethod:NOZCompressionMethodZStandard_D128];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d256Data] forMethod:NOZCompressionMethodZStandard_D256];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d256Data] forMethod:NOZCompressionMethodZStandard_D256];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d512Data] forMethod:NOZCompressionMethodZStandard_D512];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d512Data] forMethod:NOZCompressionMethodZStandard_D512];
    [library setEncoder:[NOZXZStandardCompressionCoder encoderWithDictionaryData:d1024Data] forMethod:NOZCompressionMethodZStandard_D1024];
    [library setDecoder:[NOZXZStandardCompressionCoder decoderWithDictionaryData:d1024Data] forMethod:NOZCompressionMethodZStandard_D1024];

    NSString *sourceFile = [bundle pathForResource:@"timeline" ofType:@"json"];
    sSourceData = [NSData dataWithContentsOfFile:sourceFile];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.navigationItem.title = @"Zip Utilities";
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(start:)];
        _queue = dispatch_queue_create("Zip.Queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UITextView *textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    textView.editable = NO;
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.backgroundColor = [UIColor blackColor];
    textView.textColor = [UIColor whiteColor];
    textView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    textView.alwaysBounceVertical = YES;
    textView.text = @"Press \"Play\" to start...";
    textView.font = [UIFont fontWithName:@"Menlo" size:11.5];
    [self.view addSubview:textView];
    _textView = textView;
}

- (void)start:(id)sender
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self _runAllCoders];
}

- (void)_runAllCoders
{
    dispatch_async(_queue, ^{

        NSMutableString *string = [[NSMutableString alloc] init];
        [string appendString:@"Running codecs...\n"];

        [self _updateText:string];

        for (size_t i = 0; i < sizeof(kMethods) / sizeof(kMethods[0]); i++) {
            Coder coder = kMethods[i];
            [string appendFormat:@"%12s: ", coder.name];
            RunResult result = [self _runCoder:coder];
            [string appendFormat:@"c=%.4fs, d=%.4fs, r=%02.2f\n", result.compressDuration, result.decompressDuration, result.compressionRatio];
            [self _updateText:string];
        }

        [string appendFormat:@"Custom ZStandard:\n"];
        for (size_t i = 0; i < sizeof(kMethods) / sizeof(kMethods[0]); i++) {
            Coder coder = kMethods[i];
            if ((int)coder.method >= 100 && (int)coder.method < 200) {
                [string appendFormat:@"%12s: ", coder.name];
                RunResult result = [self _runCustomCoder:coder];
                [string appendFormat:@"c=%.4fs, d=%.4fs, r=%02.2f\n", result.compressDuration, result.decompressDuration, result.compressionRatio];
                [self _updateText:string];
            }
        }

        [string appendString:@"Done!"];
        [self _updateText:string];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.navigationItem.rightBarButtonItem.enabled = YES;
        });
    });
}

- (RunResult)_runCoder:(Coder)coder
{
    id<NOZEncoder> encoder = [[NOZCompressionLibrary sharedInstance] encoderForMethod:coder.method];
    id<NOZDecoder> decoder = [[NOZCompressionLibrary sharedInstance] decoderForMethod:coder.method];
    return [self _runEncoder:encoder decoder:decoder level:coder.level];
}

- (RunResult)_runCustomCoder:(Coder)coder
{
    id<NOZEncoder, CoderWithDictionary> encoder = (id)[[NOZCompressionLibrary sharedInstance] encoderForMethod:coder.method];
    NSData *dictionaryData = [encoder dictionaryData];
    id<NOZDecoder> decoder = [[FastZSTDDecoder alloc] initWithDictionaryData:dictionaryData];
    return [self _runEncoder:encoder decoder:decoder level:coder.level];
}

- (RunResult)_runEncoder:(id<NOZEncoder>)encoder decoder:(id<NOZDecoder>)decoder level:(NOZCompressionLevel)level
{
    NSTimeInterval totalCompressDuration = 0, totalDecompressDuration = 0;
    double totalCompressRatio = 0;
    const NSUInteger count = 20;
    for (NSUInteger i = 0; i < count; i++) {
        @autoreleasepool {
            CFTimeInterval start = CFAbsoluteTimeGetCurrent();
            NSData *data = [sSourceData noz_dataByCompressing:encoder compressionLevel:level];
            totalCompressDuration += CFAbsoluteTimeGetCurrent() - start;
            totalCompressRatio += (double)sSourceData.length / (double)data.length;
            start = CFAbsoluteTimeGetCurrent();
            data = [data noz_dataByDecompressing:decoder];
            totalDecompressDuration += CFAbsoluteTimeGetCurrent() - start;
            NSAssert(data.length == sSourceData.length, @"decompress wasn't accurate!");
        }
    }
    return (RunResult){ totalCompressDuration / (double)count, totalDecompressDuration / (double)count, totalCompressRatio / (double)count };
}

- (void)_updateText:(NSMutableString *)string
{
    NSString *str = [string copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_textView.text = str;
    });
}

@end

@interface FastZSTDDecoderContext : NSObject <NOZDecoderContext>
@property (nonatomic, readonly, unsafe_unretained) id<NOZDecoder> decoder;
@property (nonatomic, readonly, nullable) NSData *dictionaryData;
@property (nonatomic, copy, readonly) NOZFlushCallback flushCallback;
@property (nonatomic, readonly) BOOL hasFinished;
- (instancetype)initWithDecoder:(id<NOZDecoder>)decoder dictionaryData:(NSData *)dictionaryData flushCallback:(NOZFlushCallback)flushCallback;
- (BOOL)initialize;
- (BOOL)decodeBytes:(const Byte *)bytes length:(size_t)length;
- (BOOL)finalize;
@end

@implementation FastZSTDDecoder

- (instancetype)initWithDictionaryData:(NSData *)dictionaryData
{
    if (self = [super init]) {
        _dictionaryData = dictionaryData;
    }
    return self;
}

- (id<NOZDecoderContext>)createContextForDecodingWithBitFlags:(UInt16)flags flushCallback:(NOZFlushCallback)callback
{
    return [[FastZSTDDecoderContext alloc] initWithDecoder:self dictionaryData:_dictionaryData flushCallback:callback];
}

- (BOOL)initializeDecoderContext:(id<NOZDecoderContext>)context
{
    return [(FastZSTDDecoderContext *)context initialize];
}

- (BOOL)decodeBytes:(const Byte *)bytes length:(size_t)length context:(id<NOZDecoderContext>)context
{
    return [(FastZSTDDecoderContext *)context decodeBytes:bytes length:length];
}

- (BOOL)finalizeDecoderContext:(id<NOZDecoderContext>)context
{
    return [(FastZSTDDecoderContext *)context finalize];
}

@end

#include "zstd.h"

@implementation FastZSTDDecoderContext
{
    NSMutableData *_buffer;
}

- (instancetype)initWithDecoder:(id<NOZDecoder>)decoder dictionaryData:(NSData *)dictionaryData flushCallback:(NOZFlushCallback)flushCallback
{
    if (self = [super init]) {
        _decoder = decoder;
        _dictionaryData = dictionaryData;
        _flushCallback = [flushCallback copy];
    }
    return self;
}

- (BOOL)initialize
{
    _buffer = [NSMutableData data];
    return YES;
}

- (BOOL)decodeBytes:(const Byte *)bytes length:(size_t)length
{
    if (!_buffer || _hasFinished) {
        return NO;
    }

    if (length) {
        [_buffer appendBytes:bytes length:length];
    } else {
        _hasFinished = YES;
    }

    return YES;
}

- (BOOL)finalize
{
    if (!_buffer) {
        return NO;
    }

    const size_t decompressSize = sSourceData.length*2;
    Byte *decompressBuffer = malloc(decompressSize);
    size_t decompressReturnValue;
    if (_dictionaryData) {
        ZSTD_DCtx *context = ZSTD_createDCtx();
        decompressReturnValue = ZSTD_decompress_usingDict(context, decompressBuffer, decompressSize, _buffer.bytes, _buffer.length, _dictionaryData.bytes, _dictionaryData.length);
        ZSTD_freeDCtx(context);
    } else {
        decompressReturnValue = ZSTD_decompress(decompressBuffer, decompressSize, _buffer.bytes, _buffer.length);
    }

    BOOL success = !ZSTD_isError(decompressReturnValue);
    if (success) {
        success = _flushCallback(_decoder, self, decompressBuffer, decompressReturnValue);
    }

    free(decompressBuffer);

    return success;
}

@end
