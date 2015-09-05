//
//  NOZ_Project.m
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

#import "NOZ_Project.h"

/**
 https://msdn.microsoft.com/en-us/library/windows/desktop/ms724247(v=vs.85).aspx

 The MS-DOS date. The date is a packed value with the following format.
 Bits	Description
 0-4	Day of the month (1–31)
 5-8	Month (1 = January, 2 = February, and so on)
 9-15	Year offset from 1980 (add 1980 to get actual year)

 The MS-DOS time. The time is a packed value with the following format.
 Bits	Description
 0-4	Second divided by 2
 5-10	Minute (0–59)
 11-15	Hour (0–23 on a 24-hour clock)
 */

void noz_dos_date_from_NSDate(NSDate *__nullable dateObject, UInt16* dateOut, UInt16* timeOut)
{
    if (!dateObject) {
        *dateOut = 0;
        *timeOut = 0;
        return;
    }

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSCalendarUnit units =  NSCalendarUnitYear |
                            NSCalendarUnitMonth |
                            NSCalendarUnitDay |
                            NSCalendarUnitHour |
                            NSCalendarUnitMinute |
                            NSCalendarUnitSecond;
    NSDateComponents* components = [gregorianCalendar components:units
                                                        fromDate:dateObject];

    UInt16 date;
    UInt16 time;

    UInt16 years = (UInt16)components.year;
    if (years >= 1980) {
        years -= 1980;
    }
    if (years > 0b01111111) {
        years = 0b01111111;
    }
    UInt16 months = (UInt16)components.month;
    UInt16 days = (UInt16)components.day;
    date = (UInt16)((years << 9) | (months << 5) | (days << 0));

    UInt16 hours = (UInt16)components.hour;
    UInt16 mins = (UInt16)components.minute;
    UInt16 secs = (UInt16)components.second >> 1;  // cut seconds in half

    time = (UInt16)((hours <<  11) | (mins << 5) | (secs << 0));

    *dateOut = date;
    *timeOut = time;
}

NSDate *noz_NSDate_from_dos_date(UInt16 dosDate, UInt16 dosTime)
{
    if (!dosTime && !dosDate) {
        return nil;
    }

    UInt16 years, months, days;
    UInt16 hours, minutes, seconds;

    seconds = (UInt16)(((0b00011111) & dosTime) << 1);
    if (seconds > 59) {
        seconds = 59;
    }
    dosTime >>= 5;
    minutes = (UInt16)((0b00111111) & dosTime);
    if (minutes > 59) {
        minutes = 59;
    }
    dosTime >>= 6;
    hours = dosTime;
    if (hours > 23) {
        hours = 23;
    }

    days = (UInt16)((0b00011111) & dosDate);
    if (days > 31) {
        days = 31;
    } else if (days < 1) {
        days = 1;
    }
    dosDate >>= 5;
    months = (UInt16)((0b00001111) & dosDate);
    if (months > 12) {
        months = 12;
    } else if (months < 1) {
        months = 1;
    }
    dosDate >>= 4;
    years = dosDate + 1980;

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *date = [gregorianCalendar dateWithEra:1 year:years month:months day:days hour:hours minute:minutes second:seconds nanosecond:0];
    return date;
}
