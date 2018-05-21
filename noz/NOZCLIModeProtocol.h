//
//  NOZCLIModeProtocol.h
//  ZipUtilities
//
//  Created by Nolan O'Brien on 5/8/17.
//  Copyright © 2017 NSProgrammer. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NOZCLIModeInfoProtocol <NSObject>
@end

@protocol NOZCLIModeProtocol <NSObject>

+ (NSString *)modeFlag;
+ (NSString *)modeName;
+ (NSString *)modeExecutionDescription;

+ (NSUInteger)modeExtraArgumentsSectionCount;
+ (NSString *)modeExtraArgumentsSectionName:(NSUInteger)sectionIndex;
+ (NSArray<NSString *> *)modeExtraArgumentsSectionDescriptions:(NSUInteger)sectionIndex;

+ (id<NOZCLIModeInfoProtocol>)infoFromArgs:(NSArray<NSString *> *)args
                           environmentPath:(NSString *)envPath;
+ (int)run:(id<NOZCLIModeInfoProtocol>)info;

@end
