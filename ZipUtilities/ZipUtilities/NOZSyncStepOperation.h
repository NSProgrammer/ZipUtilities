//
//  NOZSyncStepOperation.h
//  ZipUtilities
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Nolan O'Brien
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NOZSyncStepOperation : NSOperation

@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly, nullable) NSError *operationError;

@end

@interface NOZSyncStepOperation (Protected)

// MUST Override methods

- (NSUInteger)numberOfSteps;
- (int64_t)weightForStep:(NSUInteger)stepIndex;
- (nullable NSError *)runStep:(NSUInteger)stepIndex;
+ (nonnull NSError *)operationCancelledError;

// Override methods

- (void)handleProgressUpdated:(float)progress;
- (void)handleFinishing;

// Callable methods - Do Not Override

- (void)updateProgress:(float)progress forStep:(NSUInteger)stepIndex NS_REQUIRES_SUPER;

@end

@interface NOZSyncStepOperation (DoNotOverride)

// Do not add custom behavior to these methods.
// Only ever override them for passive observation AND call super if you do.

- (void)main NS_REQUIRES_SUPER;
- (void)start NS_REQUIRES_SUPER;
- (BOOL)isConcurrent NS_REQUIRES_SUPER; // returns NO
- (BOOL)isAsynchronous NS_REQUIRES_SUPER; // returns NO
- (BOOL)isCancelled NS_REQUIRES_SUPER;
- (BOOL)isFinished NS_REQUIRES_SUPER;
- (BOOL)isExecuting NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
