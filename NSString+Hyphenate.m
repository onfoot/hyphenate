//
//  NSString+Hyphenate.m
//
//  Created by Eelco Lempsink on 09-06-10.
//  Copyright 2010 Tupil. All rights reserved.
//

#import "NSString+Hyphenate.h"

#include "hyphen.h"

@implementation NSString (Hyphenate)

- (NSString*)stringByHyphenatingWithLocale:(NSLocale*)locale usingSharedDictionaries:(id)sharedDictionaries
{
    if (self.length == 0) {
        return self;
    }
    
    
    CFStringRef cfString = (__bridge CFStringRef)self;
    
    CFIndex stringLength = CFStringGetLength(cfString);
    
    NSMutableArray <NSNumber *> * hyphenLocations = [NSMutableArray array];
    CFRange fullRange = CFRangeMake(0, CFStringGetLength(cfString));
    
    CFIndex previousLocation = kCFNotFound;
    BOOL isSkippingTag = NO;
    
    CFIndex currentIndex = stringLength - 1;
    while (currentIndex > 0) {
        if(CFStringGetCharacterAtIndex(cfString, currentIndex) == '>' && !isSkippingTag) {
            isSkippingTag = YES;
            currentIndex -= 1;
            continue;
        }
        
        if (CFStringGetCharacterAtIndex(cfString, currentIndex) == '<' && isSkippingTag) {
            isSkippingTag = NO;
            currentIndex -= 1;
            continue;
        }
        
        CFIndex nextLocation = CFStringGetHyphenationLocationBeforeIndex(
                                                                         cfString,
                                                                         currentIndex,
                                                                         fullRange,
                                                                         0,
                                                                         (CFLocaleRef)locale,
                                                                         NULL
                                                                         );
        
        if (nextLocation != kCFNotFound && nextLocation != previousLocation) {
            [hyphenLocations addObject:[NSNumber numberWithLong:nextLocation]];
            previousLocation = nextLocation;
            currentIndex = nextLocation;
        } else {
            break;
        }
        
        
    }
    
    if (hyphenLocations.count == 0) {
        return self;
    }
    
    NSMutableString *result = [NSMutableString stringWithString:self];
    NSEnumerator * enumerator = [hyphenLocations reverseObjectEnumerator];
    while (true) {
        NSNumber * location = [enumerator nextObject];
        if (location == NULL) break;
        [result insertString:@"\u00AD" atIndex:[location longValue]];
    }
    
    return result;
}


- (NSString*)stringByHyphenatingWithLocale:(NSLocale*)locale {
    return [self stringByHyphenatingWithLocale:locale usingSharedDictionaries:nil];
}

@end
