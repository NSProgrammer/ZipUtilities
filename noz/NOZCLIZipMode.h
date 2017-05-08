//
//  NOZCLIZipMode.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIModeProtocol.h"

// TODO: write unit tests

@interface NOZCLIZipModeInfo : NSObject <NOZCLIModeInfoProtocol>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface NOZCLIZipMode : NSObject <NOZCLIModeProtocol>

//Zip mode:         %1$@ -z [zip_options] -o output_file -i [file_options] input_file1 [... [-i [file_options] intpu_fileN]]\n"
/*
"zip_options:\n"
"-------------------------------\n"
"\t-c COMMENT        provide an archive comment\n"
"\t-M METHOD NUMBER  map a METHOD to a different archive number... this impacts unzipping!\n"
"\n"
"zip file_options:\n"
"-------------------------------\n"
"\t-c COMMENT        provide an archive comment\n"
"\t-n NAME           override the name\n"
"\t-m METHOD         specify a compression method, default is \"deflate\" (see METHODS below)\n"
"\t-l LEVEL          specify a compression level, levels are defined per METHOD each with their own default\n"
"\t-h                permit hidden file(s)\n"
"\t-f                don't recurse into the director if provided path was a directory (default is to recurse)\n"
"\n"
*/

// TODO

@end
