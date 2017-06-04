//
//  NOZCLIDumpMode.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIModeProtocol.h"

@interface NOZCLIDumpModeInfo : NSObject <NOZCLIModeInfoProtocol>

@property (nonatomic, readonly) BOOL list;
@property (nonatomic, readonly) BOOL silenceArchiveInfo;
@property (nonatomic, readonly) BOOL verbose;
@property (nonatomic, copy, readonly) NSString *filePath;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface NOZCLIDumpMode : NSObject <NOZCLIModeProtocol>
@end
