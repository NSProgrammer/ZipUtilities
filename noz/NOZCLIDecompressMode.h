//
//  NOZCLIDecompressMode.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIModeProtocol.h"

// TODO: write unit tests

@interface NOZCLIDecompressModeInfo : NSObject <NOZCLIModeInfoProtocol>

@property (nonatomic, copy, readonly) NSString *method;
@property (nonatomic, copy, readonly) NSString *inputFile;
@property (nonatomic, copy, readonly) NSString *outputFile;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface NOZCLIDecompressMode : NSObject <NOZCLIModeProtocol>
@end
