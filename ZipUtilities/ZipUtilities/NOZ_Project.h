//
//  NOZ_Project.h
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

#pragma mark Utils

/**
 `noz_macro_concat`
 Macro for combining 2 names into a single name.
 Offers the ability to expand any initial macros passed in.
 
 *Example:*

     // writing this:
     int noz_macro_concat(hidden_int_, __FILE__) = __FILE__;
     // will be preprocessed as this:
     int hidden_int_38 = 38;

 */
#define _noz_macro_concat(a, b) a##b
#define noz_macro_concat(a, b) _noz_macro_concat(a, b)

#pragma mark Defer Support

/**
 `noz_defer`
 Macro for support code deferral.
 Offers the same behavior as `defer` in Swift.
 Effectively, the block provided to `noz_defer` will execute on scope exit.
 Offers a safe way to perform cleanup on scope exit, no matter the mechanism.
 Scope exits include: break, continue, return, @throw/throw and leaving the scope of an if/else/while/for
 
 *Example:*

     FILE *file
 */
#define noz_defer(deferBlock) \
__strong noz_defer_block_t noz_macro_concat(__noz_stack_defer_block_, __LINE__) __attribute__((cleanup(noz_deferFunc), unused)) = deferBlock

typedef void(^noz_defer_block_t)();
NS_INLINE void noz_deferFunc(__strong noz_defer_block_t __nonnull * __nonnull blockRef)
{
    noz_defer_block_t actualBlock = *blockRef;
    actualBlock();
}

#pragma mark Error

#import "NOZError.h"

NS_INLINE NSError * __nonnull NOZError(NOZErrorCode code, NSDictionary * __nullable ui)
{
    return [NSError errorWithDomain:NOZErrorDomain code:code userInfo:ui];
}

#pragma mark DOS Time

FOUNDATION_EXTERN void noz_dos_date_from_NSDate(NSDate *__nullable dateObject, UInt16*__nonnull dateOut, UInt16*__nonnull timeOut);
FOUNDATION_EXTERN NSDate * __nullable noz_NSDate_from_dos_date(UInt16 dosDate, UInt16 dosTime);

#pragma mark CRC32 exposed

NS_ASSUME_NONNULL_BEGIN

extern unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);

NS_ASSUME_NONNULL_END
