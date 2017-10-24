//
//  NOZCLIUnzipMode.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/7/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIModeProtocol.h"

@interface NOZCLIUnzipModeInfo : NSObject <NOZCLIModeInfoProtocol>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface NOZCLIUnzipMode : NSObject <NOZCLIModeProtocol>
@end
