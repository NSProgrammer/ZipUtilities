//
//  main.m
//  noz
//
//  Created by Nolan O'Brien on 5/6/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLI.h"

static NSArray<NSString *> *parseArgs(int argc, const char * argv[]);

int main(int argc, const char * argv[])
{
    int retVal = -1;
    @autoreleasepool {
        NSString *exe = nil;
        NSArray<NSString *> *args = parseArgs(argc, argv);
        if (args.count > 0) {
            NSString *path = args[0];
            exe = [path lastPathComponent];
            path = [path stringByDeletingLastPathComponent];
            args = [args subarrayWithRange:NSMakeRange(1, args.count - 1)];
            NSString *currentDir = @(getenv("PWD"));

            retVal = NOZCLI_main(exe, path, currentDir, args);
        }

        if (retVal != 0) {
            if (retVal != -1) {
                printf("\n\n----------------------------------------\n\n");
            }
            NOZCLI_printUsage(exe, args.firstObject);
        }
    }

    return retVal;
}

static NSArray<NSString *> *parseArgs(int argc, const char * argv[])
{
    NSMutableArray<NSString *> *args = [[NSMutableArray alloc] init];
    for (int c = 0; c < argc; c++) {
        [args addObject:@(argv[c])];
    }
    return [args copy];
}
