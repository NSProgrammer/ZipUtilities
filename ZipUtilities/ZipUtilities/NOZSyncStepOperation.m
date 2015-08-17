//
//  NOZSyncStepOperation.m
//  ZipUtilities
//
//  Copyright (c) 2015 Nolan O'Brien.
//

#import "NOZ_Project.h"
#import "NOZSyncStepOperation.h"

@interface NOZSyncStepOperation ()
@property (nonatomic) float progress;
@end

@implementation NOZSyncStepOperation
{
    NSUInteger _stepCount;
    SInt64 *_stepWeights;
    float *_currentStepProgress;
    SInt64 _totalWeight;
}

- (void)dealloc
{
    free(_stepWeights);
    free(_currentStepProgress);
}

- (void)main
{
    _stepCount = [self numberOfSteps];

    if (_stepCount > 0) {
        _stepWeights = (SInt64 *)malloc(sizeof(SInt64) * _stepCount);
        _currentStepProgress = (float *)malloc(sizeof(float) * _stepCount);
    }

    for (NSUInteger step = 0; step < _stepCount; step++) {
        SInt64 weight = [self weightForStep:step];
        _stepWeights[step] = weight;
        _currentStepProgress[step] = 0.f;
        _totalWeight += weight;
    };

    for (NSUInteger step = 0; step < _stepCount; step++) {
        if (self.isCancelled) {
            _operationError = [[self class] operationCancelledError];
        } else {
            _operationError = [self runStep:step];
        }
        if (_operationError) {
            break;
        }
    };

    [self handleFinishing];
}

- (void)start
{
    if (self.isCancelled) {
        _operationError = [[self class] operationCancelledError];
        [self handleFinishing];
    }
    [super start];
}

- (BOOL)isConcurrent
{
    return NO;
}

- (BOOL)isAsynchronous
{
    return NO;
}

@end

@implementation NOZSyncStepOperation (Protected)

#pragma mark MUST Override methods

- (NSUInteger)numberOfSteps
{
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

- (SInt64)weightForStep:(NSUInteger)stepIndex
{
    if (!_stepCount) {
        return 0ll;
    }
    return 1000ll / _stepCount;
}

- (nullable NSError *)runStep:(NSUInteger)stepIndex
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (nonnull NSError *)operationCancelledError
{
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"does not recognize selector!"
                                 userInfo:@{ @"Class" : NSStringFromClass(self), @"selector" : NSStringFromSelector(_cmd) }];
}

#pragma mark Override methods

- (void)handleProgressUpdated:(float)progress
{

}

- (void)handleFinishing
{

}

#pragma mark Callable Methods

- (void)updateProgress:(float)progress forStep:(NSUInteger)step
{
    if (step >= _stepCount) {
        return;
    }

    const float oldProgress = self.progress;
    const BOOL wasIndeterminate = oldProgress < 0.f;
    BOOL isIndeeterminate = progress < 0.f;

    if (wasIndeterminate && isIndeeterminate) {
        return;
    }

    _currentStepProgress[step] = MIN(progress, 1.f);

    SInt64 currentWeight = 0;
    for (NSUInteger iStep = 0; iStep < _stepCount; iStep++) {
        currentWeight += _currentStepProgress[iStep] * _stepWeights[iStep];
        if (_currentStepProgress[iStep] < 0.f) {
            isIndeeterminate = YES;
        }
    }

    progress = (isIndeeterminate) ? -1.f : (float)((double)currentWeight / (double)_totalWeight);
    self.progress = progress;
    [self handleProgressUpdated:progress];
}

@end
