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
@end
