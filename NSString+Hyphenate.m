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
    HyphenDict* dict = NULL;
    NSString* localeIdentifier = nil;
    static NSBundle* bundle = nil;
    
    ////////////////////////////////////////////////////////////////////////////
    // Setup.
    //
    // Establish that we got all the information we need: the bundle with 
    // dictionaries, the locale and the loaded dictionary.  Cache dictionary and
    // save the language code used to retrieve it.
    //
    
    // Try to guess the locale from the string, if not given.
    CFStringRef language;
    if (locale == nil 
        && (language = CFStringTokenizerCopyBestStringLanguage(
            (CFStringRef)self, CFRangeMake(0, MIN(200, [self length])))))
    {
        locale = [[NSLocale alloc] 
                  initWithLocaleIdentifier:(__bridge NSString*)language];
        CFRelease(language);                
    }
    
    if (locale == nil) {
        return self;
    } // else
    
    if (![localeIdentifier isEqualToString:[locale localeIdentifier]] 
        && dict != NULL) 
    {
        hnj_hyphen_free(dict);
        dict = NULL;
    }
    
    if (bundle == nil) {
        NSString* bundlePath = [[[NSBundle mainBundle] resourcePath] 
                                stringByAppendingPathComponent:
                                @"Hyphenate.bundle"];
        bundle = [NSBundle bundleWithPath:bundlePath];
    }

    localeIdentifier = [locale localeIdentifier];
    
    NSArray * localeComponents = [localeIdentifier componentsSeparatedByString:@"_"];
    
    @synchronized (sharedDictionaries) {
        
        BOOL needToStore = NO;
        if (sharedDictionaries && [sharedDictionaries objectForKey:localeIdentifier]) {
            dict = [[sharedDictionaries objectForKey:localeIdentifier] pointerValue];
        }
        
        if (dict == NULL && localeComponents.count > 1) {
            dict = [[sharedDictionaries objectForKey:localeComponents[0]] pointerValue];
        }
        
        if (dict == NULL) {
            dict = hnj_hyphen_load([[bundle pathForResource:
                                     [NSString stringWithFormat:@"hyph_%@",
                                      localeIdentifier]
                                                     ofType:@"dic"]
                                    UTF8String]);
            
            needToStore = YES;
        }
        
        if (dict == NULL) {
            if (localeComponents.count > 1) {
                localeIdentifier = localeComponents[0];
                
                dict = hnj_hyphen_load([[bundle pathForResource:
                                         [NSString stringWithFormat:@"hyph_%@",
                                          localeComponents[0]]
                                                         ofType:@"dic"]
                                        UTF8String]);
                needToStore = YES;
            }
        }
        
        if (needToStore) {
            [sharedDictionaries setObject:[NSValue valueWithPointer:dict] forKey:localeIdentifier];
        }
    }
    
    if (dict == NULL) {
        return self;
    } // else

    ////////////////////////////////////////////////////////////////////////////
    // The works.
    //
    // No turning back now.  We traverse the string using a tokenizer and pass
    // every word we find into the hyphenation function.  Non-used tokens and
    // hyphenated words will be appended to the result string.
    //
    
    NSMutableString* result = [NSMutableString stringWithCapacity:
                               [self length] * 1.2];
    
    // Varibles used for tokenizing
    CFStringTokenizerRef tokenizer;
    CFStringTokenizerTokenType tokenType;
    CFRange tokenRange;
    NSString* token;
    
    // Varibles used for hyphenation
    char* hyphens;
    char** rep;
    int* pos;
    int* cut;
    int wordLength;
    int i;
    
    tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault,
                                        (CFStringRef)self, 
                                        CFRangeMake(0, [self length]), 
                                        kCFStringTokenizerUnitWordBoundary, 
                                        (CFLocaleRef)locale);
    
    BOOL skippingTag = NO;
    
    while ((tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)) 
           != kCFStringTokenizerTokenNone) 
    {
        tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
        token = [self substringWithRange:
                 NSMakeRange(tokenRange.location, tokenRange.length)];

        if ([token hasPrefix:@"<"]) {
            skippingTag = YES;
        }
        
        if ([token hasSuffix:@">"]) {
            skippingTag = NO;
        }
        
        
        if (tokenType & kCFStringTokenizerTokenHasNonLettersMask) {
            [result appendString:token];
        } else {
            char const* tokenChars = [token UTF8String];

            wordLength = (int)strlen(tokenChars);
            // This is the buffer size the algorithm needs.
            hyphens = (char*)malloc(wordLength + 5); // +5, see hypen.h 
            rep = NULL; // Will be allocated by the algorithm
            pos = NULL; // Idem
            cut = NULL; // Idem

            // rep, pos and cut are not currently used, but the simpler
            // hyphenation function is deprecated.
            hnj_hyphen_hyphenate2(dict, tokenChars, wordLength, hyphens, 
                                  NULL, &rep, &pos, &cut);
            
            NSUInteger loc = 0;
            NSUInteger len = 0;
            
            @autoreleasepool {
                
                for (i = 0; i < wordLength; i++) {
                    if (hyphens[i] & 1 && !skippingTag) {
                        
                        NSString *tokenized = [[NSString alloc] initWithBytesNoCopy:(void *)tokenChars + loc length:i - loc + 1 encoding:NSUTF8StringEncoding freeWhenDone:NO];
                        if (tokenized.length < 2) {
                            continue;
                        }
                        
                        len = i - loc + 1;
                        [result appendString:tokenized];
                        [result appendString:@"\u00AD"];
                        loc = loc + len;
                    }
                }
                if (loc < wordLength) {
                    
                    NSString * tokenized = [[NSString alloc] initWithBytesNoCopy:(void *)tokenChars + loc length:wordLength - loc encoding:NSUTF8StringEncoding freeWhenDone:NO];
                    [result appendString:tokenized];
                }
                
            }
            
            // Clean up
            free(hyphens);
            if (rep) {
                for (i = 0; i < wordLength; i++) {
                    if (rep[i]) free(rep[i]);
                }
                free(rep);
                free(pos);
                free(cut);
            }
        }
    }
    
    CFRelease(tokenizer);
    
    if (!sharedDictionaries) {
        hnj_hyphen_free(dict);
    }
    
    return result;
}

- (NSString*)stringByHyphenatingWithLocale:(NSLocale*)locale {
    return [self stringByHyphenatingWithLocale:locale usingSharedDictionaries:nil];
}

@end
