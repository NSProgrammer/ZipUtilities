//
//  ViewController.m
//  ZipUtilitiesApp
//
//  Created by Nolan O'Brien on 11/16/16.
//  Copyright © 2016 NSProgrammer. All rights reserved.
//

#import "NOZXAppleCompressionCoder.h"
#import "NOZXBrotliCompressionCoder.h"
#import "NOZXZStandardCompressionCoder.h"
#import "ViewController.h"

@import ZipUtilities;

// NOZCompressionMethodZStandard is now part of the ZIP spec, method #93
#define NOZCompressionMethodZStandard_D128  (101)
#define NOZCompressionMethodZStandard_D256  (102)
#define NOZCompressionMethodZStandard_D512  (104)
#define NOZCompressionMethodZStandard_D1024 (108)
#define NOZCompressionMethodZStandard_DBOOK (190)

#define NOZCompressionMethodBrotli          (200)

#define kRUN_COUNT (20)

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
    { "deflate.6", NOZCompressionMethodDeflate, ((6.f - 1.f) / (9.f - 1.f)) },
    { "lzma.6", NOZCompressionMethodLZMA, NOZCompressionLevelMax },
    { "lz4", (NOZCompressionMethod)COMPRESSION_LZ4, NOZCompressionLevelMax },
    { "lzfse", (NOZCompressionMethod)COMPRESSION_LZFSE, NOZCompressionLevelMax },
    { "brotli.5", NOZCompressionMethodBrotli, ((5.f - 0.f) / (11.f - 0.f)) },
    { "brotli.6", NOZCompressionMethodBrotli, ((6.f - 0.f) / (11.f - 0.f)) },
    { "brotli.7", NOZCompressionMethodBrotli, ((7.f - 0.f) / (11.f - 0.f)) },
    { "brotli.8", NOZCompressionMethodBrotli, ((8.f - 0.f) / (11.f - 0.f)) },
    { "zstd.7", NOZCompressionMethodZStandard, ((7.f - 1.f) / (22.f - 1.f)) },
    { "zstd.book.7", NOZCompressionMethodZStandard_DBOOK, ((7.f - 1.f) / (22.f - 1.f)) },
    { "zstd.128.7", NOZCompressionMethodZStandard_D128, ((7.f - 1.f) / (22.f - 1.f)) },
    { "zstd.256.7", NOZCompressionMethodZStandard_D256, ((7.f - 1.f) / (22.f - 1.f)) },
    { "zstd.512.7", NOZCompressionMethodZStandard_D512, ((7.f - 1.f) / (22.f - 1.f)) },
    { "zstd.1024.7", NOZCompressionMethodZStandard_D1024, ((7.f - 1.f) / (22.f - 1.f)) },
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

    [library setEncoder:[NOZXBrotliCompressionCoder encoder] forMethod:NOZCompressionMethodBrotli];
    [library setDecoder:[NOZXBrotliCompressionCoder decoder] forMethod:NOZCompressionMethodBrotli];

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

- (RunResult)_runEncoder:(id<NOZEncoder>)encoder decoder:(id<NOZDecoder>)decoder level:(NOZCompressionLevel)level
{
    NSTimeInterval totalCompressDuration = 0, totalDecompressDuration = 0;
    double totalCompressRatio = 0;
    const NSUInteger count = kRUN_COUNT;
    for (NSUInteger i = 0; i < count; i++) {
        @autoreleasepool {
            CFTimeInterval start = CFAbsoluteTimeGetCurrent();
            NSData *data = [sSourceData noz_dataByCompressing:encoder compressionLevel:level];
            totalCompressDuration += CFAbsoluteTimeGetCurrent() - start;
            totalCompressRatio += (double)sSourceData.length / (double)data.length;
            start = CFAbsoluteTimeGetCurrent();
            data = [data noz_dataByDecompressing:decoder];
            totalDecompressDuration += CFAbsoluteTimeGetCurrent() - start;
            NSAssert(data.length == sSourceData.length, @"decompress wasn't accurate! %@ %@ %tu", encoder, decoder, level);
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
