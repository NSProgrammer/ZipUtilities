//
//  NOZCLICompressMode.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIModeProtocol.h"

@interface NOZCLICompressModeInfo : NSObject <NOZCLIModeInfoProtocol>

@property (nonatomic, copy, readonly) NSString *method;
@property (nonatomic, readonly) NSInteger level;
@property (nonatomic, copy, readonly) NSString *inputFile;
@property (nonatomic, copy, readonly) NSString *outputFile;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface NOZCLICompressMode : NSObject <NOZCLIModeProtocol>
@end
