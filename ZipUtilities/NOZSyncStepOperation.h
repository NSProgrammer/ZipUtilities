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

/**
 `NOZSyncStepOperation` is an `NSOperation` subclass for dealing with a lot of boiler plate code
 associated with creating a synchronous operation that performs multiple synchronous steps
 in sequential order.
 
 Both `NOZCompressOperation` and `NOZDecompressOperation` subclass `NOZSyncStepOperation`
 */
@interface NOZSyncStepOperation : NSOperation

/**
 Indicates how much progress has passed.
 Supports KVO.
 */
@property (nonatomic, readonly) float progress;
/**
 Stores any `NSError` encountered while running.
 Useful for subclasses to examine during `handleFinishing`.
 */
@property (atomic, readonly, nullable) NSError *operationError;

@end

/**
 Methods for subclasses to override or call.
 */
@interface NOZSyncStepOperation (Protected)

// MUST/SHOULD Override methods

/**
 Number of steps in the operation.
 MUST override in subclass.
 When other methods are called with an `NSUInteger` _step_, the _step_ is `0`-based (like an index).
 */
- (NSUInteger)numberOfSteps;

/**
 Return the weight of a given _step_.
 This can make it so that you can specify the amount of progress attributed to a particular step.
 For example: reading the header of a JPEG is light weight while decoding the image is heavy.
   You could have header reading be `500LL` and decoding be `9500LL` so that 95% goes to decoding.
 SHOULD override in subclass.
 Default distributes weight equally amoung all steps.
 */
- (SInt64)weightForStep:(NSUInteger)step;

/**
 Run the specified _step_.
 MUST override in subclass.
 Return `NO` and set the output _error_ if an error was encountered, otherwise return `nil`.
 Implementers should check `[self isCancelled]` for any indication that the operation was cancelled
 and return `[[self class] operationCancelledError]`.
 */
- (BOOL)runStep:(NSUInteger)step error:(out NSError * __nullable * __nullable)error;

/**
 Return the `NSError` that represents when this operation was cancelled.
 MUST override in subclass.
 */
+ (nonnull NSError *)operationCancelledError;

// OPTIONAL Override methods

/** Subclasses can override this method to handle when `progress` was updated. */
- (void)handleProgressUpdated:(float)progress;

/**
 Subclasses can override this method to handle when the operation is finishing.
 Useful for aggregating results.
 */
- (void)handleFinishing;

// Callable methods - DO NOT Override

/**
 Subclasses SHOULD call this method with the progress of a given step.
 Simplest option is to just to call this method when a step completes with `1.f` for the _progress_.
 DO NOT Override.
 */
- (void)updateProgress:(float)progress forStep:(NSUInteger)step NS_REQUIRES_SUPER;

@end

@interface NOZSyncStepOperation (DoNotOverride)

// Do not add custom behavior to these methods.
// Only ever override them for passive observation AND call super if you do.

/** DO NOT OVERRIDE.  If you need to add passive code, be sure to call `super`.  Never override with new behavior. */
- (void)main NS_REQUIRES_SUPER;
/** DO NOT OVERRIDE.  If you need to add passive code, be sure to call `super`.  Never override with new behavior. */
- (void)start NS_REQUIRES_SUPER;
/** DO NOT OVERRIDE.  If you need to add passive code, be sure to call `super`.  Never override with new behavior. */
- (BOOL)isConcurrent NS_REQUIRES_SUPER;
/** DO NOT OVERRIDE.  If you need to add passive code, be sure to call `super`.  Never override with new behavior. */
- (BOOL)isAsynchronous NS_REQUIRES_SUPER;
/** DO NOT OVERRIDE.  If you need to add passive code, be sure to call `super`.  Never override with new behavior. */
- (BOOL)isCancelled NS_REQUIRES_SUPER;
/** DO NOT OVERRIDE.  If you need to add passive code, be sure to call `super`.  Never override with new behavior. */
- (BOOL)isFinished NS_REQUIRES_SUPER;
/** DO NOT OVERRIDE.  If you need to add passive code, be sure to call `super`.  Never override with new behavior. */
- (BOOL)isExecuting NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
