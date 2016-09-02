//
//  SubRipParser.m
//  Spuul
//
//  Created by honcheng on 16/10/12.
//  Copyright (c) 2012 honcheng@gmail.com. All rights reserved.
//

#import "SubRipParser.h"

@implementation SubRipItem

+ (SubRipItem*)subRipItem
{
    return [[SubRipItem alloc] init];
}

- (NSString*)description
{
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%f-->%f : %@", self.startTime, self.endTime, self.text];
    return text;
}

@end

@implementation SubRipItems

- (NSString*)description
{
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"SubRipItems: number of items %lu, ", (unsigned long)[self.items count]];
    
    SubRipItem *lastItem = [self.items lastObject];
    NSTimeInterval timeInterval = lastItem.endTime;
    int minute = timeInterval/60;
    [text appendFormat:@"%i minutes", minute];
    
    return text;
}

@end

@interface SubRipParser()
- (SubRipItem*)parseSubRipItem:(NSString*)text;
- (NSTimeInterval)timeIntervalFromSubRipTimeString:(NSString*)text;
@end

@implementation SubRipParser

- (id)initWithSubRipContent:(NSString*)subripContent
{
    self = [super init];
    if (self)
    {
        _subripContent = subripContent;
    }
    return self;
}

- (void)parseWithBlock:(void (^)(BOOL, SubRipItems *))block
{
    dispatch_async(dispatch_queue_create("parse subrip file", 0), ^{
       
        if([self.subripContent hasPrefix:@"WEBVTT"]) {
            NSRange range = [self.subripContent rangeOfString:@"00:"];
            self.subripContent = [self.subripContent substringFromIndex:range.location];
        }
        
        self.subripContent = [self.subripContent stringByReplacingOccurrencesOfString:@"\n\r\n" withString:@"\n\n"];
        self.subripContent = [self.subripContent stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
        NSArray *textBlocks = [self.subripContent componentsSeparatedByString:@"\n\n"];
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *text in textBlocks)
        {
            SubRipItem *subRipItem = [self parseSubRipItem:text];
            if (subRipItem)
            {
                [items addObject:subRipItem];
            }
        }
        
        SubRipItems *subRipItems = [[SubRipItems alloc] init];
        [subRipItems setItems:items];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(YES, subRipItems);
        });
    });
}

- (SubRipItem*)parseSubRipItem:(NSString*)text {
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    SubRipItem *subRipItem = [SubRipItem subRipItem];
    
    if ([lines count] >= 3) {
        // SubRipt format requires at least 3 lines
        // srt parsing
        subRipItem.subtitleNumber = [lines[0] intValue];
        if([self createSubripItem:subRipItem lines:[lines subarrayWithRange:NSMakeRange(1, lines.count - 1)]]) {
            return subRipItem;
        }
    } else if ([lines count] == 2) {
        // webvtt parsing
        subRipItem.subtitleNumber = 0; // not defined in webvtt
        if([self createSubripItem:subRipItem lines:lines]) {
            return subRipItem;
        }
    }
    return nil;
}

- (BOOL) createSubripItem:(SubRipItem *)subRipItem lines:(NSArray *)lines {
    NSArray *timeRange = [lines[0] componentsSeparatedByString:@"-->"];
    // there will always be 2 items in time range
    if ([timeRange count]==2) {
        NSString *startTimeString = [self parseTimeString:timeRange[0]];
        NSString *endTimeString = [self parseTimeString:timeRange[1]];
        
        if(startTimeString && endTimeString) {
            subRipItem.startTime = [self timeIntervalFromSubRipTimeString:startTimeString] + self.timeOffset;
            subRipItem.endTime = [self timeIntervalFromSubRipTimeString:endTimeString] + self.timeOffset;
        } else {
            return false;
        }
    } else {
        return false;
    }
    
    subRipItem.text = [self parseText:[lines subarrayWithRange:NSMakeRange(1, lines.count - 1)]];
    return true;
}

- (NSString *) parseTimeString:(NSString *)timeString {
    if(!timeString) {
        return nil;
    }
    timeString = [timeString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(timeString && timeString.length >= 12) {
        // Make sure that we're getting exact amount of string to parse the time e.g 00:01:17.220
        // especially for end time string there can be some CSS styling at the end of time string so
        // we need to substring
        timeString = [timeString substringWithRange:NSMakeRange(0, 12)];
        return timeString;
    }
    return nil;
}

- (NSString *) parseText:(NSArray *)lines {
    NSMutableString *text = [NSMutableString string];
    for (int i=0; i<[lines count]; i++) {
        [text appendFormat:@"%@\n", lines[i]];
    }
    return text;
}

- (NSTimeInterval)timeIntervalFromSubRipTimeString:(NSString*)text
{
    NSArray *components = [text componentsSeparatedByString:@","];
    int miliseconds = 0;
    if ([components count]==2) miliseconds = [components[1] intValue];
    
    // crashlylitics crash check
    int hour = 0;
    int minute = 0;
    int second = 0;
    NSArray *hourMinSec = [components.firstObject componentsSeparatedByString:@":"];
    if (hourMinSec.count > 0) {
        hour = [hourMinSec[0] intValue];
    }
    if (hourMinSec.count > 1) {
        minute = [hourMinSec[1] intValue];
    }
    if (hourMinSec.count > 2) {
        second = [hourMinSec[2] intValue];
    }
    
    NSTimeInterval timeInterval = hour*60*60 + minute*60 + second + miliseconds/1000.0;
    return timeInterval;
}

@end
