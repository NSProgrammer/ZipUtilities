//
//  NOZCLIMethodMode.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/8/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import "NOZCLIModeProtocol.h"

@interface NOZCLIMethodModeInfo : NSObject <NOZCLIModeInfoProtocol>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface NOZCLIMethodMode : NSObject <NOZCLIModeProtocol>
@end
