//
//  shortcuts.c
//  shortcuts
//
//  Created by Dmitry Rodionov on 21/08/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

#import "shortcuts.h"
#import "KeyboardServices+Private.h"
#import "NSArray+HigherOrder.h"

#define kTimeoutSec (3)

#pragma mark Utilities

_KSTextReplacementEntry * _Nullable _existingEntryForShortcut(NSString * _Nonnull shortcut)
{
    // XXX: for some reason _KSTextReplacementClientStore returns an empty array for every (even
    // non-filtered) query so here's a workaround -- we'll look into global defaults to obtain
    // a list of existing shortcuts.
    // TODO: use -queryTextReplacementsWithPredicate:callback: here
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray <NSDictionary *> *rawEntries = [defaults arrayForKey:@"NSUserDictionaryReplacementItems"];
    return [[rawEntries rd_filter:^BOOL(NSDictionary *raw) {
        return [raw[@"replace"] isEqualToString:shortcut];
    }] rd_map:^id _Nonnull(NSDictionary *raw) {
        _KSTextReplacementEntry *entry = [_KSTextReplacementEntry new];
        entry.shortcut = raw[@"replace"];
        entry.phrase = raw[@"with"];
        return entry;
    }].firstObject;
}

int _submit(NSArray <_KSTextReplacementEntry *> * _Nullable toAdd, NSArray <_KSTextReplacementEntry *> * _Nullable toRemove)
{
    NSCAssert((toAdd != nil || toRemove != nil),
              @"At least one of the `toAdd` or `toRemove` arguments should be specified");

    _KSTextReplacementClientStore *store = [_KSTextReplacementClientStore new];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block int result = EXIT_FAILURE;
    [store addEntries:toAdd removeEntries:toRemove withCompletionHandler:^(NSError *error) {
        if (error && error.code != 0) {
            fprintf(stderr, "Error: %s\n", [_KSTextReplacementHelper errorStringForCode:error.code].UTF8String);
        } else {
            result = KERN_SUCCESS;
        }
        dispatch_semaphore_signal(sema);
    }];
    if (0 != dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kTimeoutSec * NSEC_PER_SEC)))) {
        fprintf(stderr, "Error: operation timed out\n");
        result = KERN_FAILURE;
    }
    return result;
}

int _update(_KSTextReplacementEntry * _Nonnull original, _KSTextReplacementEntry * _Nonnull replacement)
{
    NSCParameterAssert(original != nil);
    NSCParameterAssert(replacement != nil);

    _KSTextReplacementClientStore *store = [_KSTextReplacementClientStore new];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block int result = EXIT_FAILURE;
    [store modifyEntry:original toEntry:replacement withCompletionHandler:^(NSError *error) {
        if (error  && error.code != 0) {
            NSLog(@"%@", error);
            fprintf(stderr, "Error: %s\n", [_KSTextReplacementHelper errorStringForCode:error.code].UTF8String);
        } else {
            result = KERN_SUCCESS;
        }
        dispatch_semaphore_signal(sema);
    }];
    if (0 != dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kTimeoutSec * NSEC_PER_SEC)))) {
        fprintf(stderr, "Error: operation timed out\n");
        result = KERN_FAILURE;
    }
    return result;
}

#pragma mark API

int new(NSString * _Nonnull shortcut, NSString * _Nonnull phrase, BOOL forceOverwrite)
{
    NSCParameterAssert(shortcut != nil);
    NSCParameterAssert(phrase != nil);

    _KSTextReplacementEntry *existingEntry = _existingEntryForShortcut(shortcut);
    if (existingEntry && !forceOverwrite) {
        fprintf(stderr, "An entry with the same shortcut \"%s\" already exists."
                "Use --force modifier or 'update' command to update existing text"
                "substitution entries.\n", shortcut.UTF8String);
        return EXIT_FAILURE;
    }

    _KSTextReplacementEntry *newEntry = [_KSTextReplacementEntry new];
    newEntry.phrase = phrase;
    newEntry.shortcut = shortcut;

    NSCAssert([_KSTextReplacementHelper validateTextReplacement:newEntry] == 0,
              @"Could not create a text replacement entry from the given input: %@",
              [_KSTextReplacementHelper errorStringForCode:
               [_KSTextReplacementHelper validateTextReplacement:newEntry]]);

    if (existingEntry) {
        return _update(existingEntry, newEntry);
    } else {
        return _submit(@[newEntry], nil);
    }
}

int import(NSString * _Nonnull inputPropertyListPath, BOOL forceOverwrite)
{
    NSArray *array = [NSArray arrayWithContentsOfFile:inputPropertyListPath];
    NSCAssert(array != nil, @"Invalid input file");

    NSArray <_KSTextReplacementEntry *> *newEntries = [array rd_flatMap:^id _Nullable(NSDictionary *item) {
        _KSTextReplacementEntry *newEntry = [_KSTextReplacementEntry new];
        newEntry.phrase = item[@"phrase"];
        newEntry.shortcut = item[@"shortcut"];
        NSCAssert([_KSTextReplacementHelper validateTextReplacement:newEntry] == 0,
                  @"Could not create a text replacement entry from dictionary %@", item);
        // Check for overrides
        _KSTextReplacementEntry *existingEntry = _existingEntryForShortcut(item[@"shortcut"]);
        if (existingEntry && !forceOverwrite) {
            return nil;
        }
        // Update existing entries in-place
        if (existingEntry) {
            _update(existingEntry, newEntry);
            return nil;
        }
        return newEntry;
    }];

    return _submit(newEntries, nil);
}

int update(NSString * _Nonnull shortcut, NSString * _Nonnull phrase)
{
    return new(shortcut, phrase, /*force*/YES);
}

int list(NSString * _Nullable mode)
{
    // XXX: for some reason _KSTextReplacementClientStore returns an empty array for every single
    // query so here's a workaround -- we'll look into global defaults to obtain a list of existing shortcuts.
    // TODO: use -queryTextReplacementsWithCallback: here
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray <NSDictionary *> *rawEntries = [defaults arrayForKey:@"NSUserDictionaryReplacementItems"];
    NSArray *converted = [rawEntries rd_map:^id _Nonnull(NSDictionary *raw) {
        return @{@"phrase":raw[@"with"], @"shortcut":raw[@"replace"]};
    }];

    if ([mode isEqualToString:@"--as-plist"]) {
        NSError *error = nil;
        NSCParameterAssert([NSPropertyListSerialization propertyList:converted
                                                    isValidForFormat:NSPropertyListXMLFormat_v1_0]);
        NSData *raw = [NSPropertyListSerialization dataWithPropertyList:converted
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                                options:0 error:&error];
        NSCAssert(raw != nil, error.description);
        printf("%.*s", (int)raw.length, raw.bytes);
    } else if (mode == nil) {
        [converted enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
         printf("%ld: \"%s\" —> \"%s\"\n", idx, [entry[@"shortcut"] UTF8String],
                [entry[@"phrase"] UTF8String]);
         }];
    } else {
        fprintf(stderr, "Invalid format specifier: \"%s\"\n", mode.UTF8String);
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}

int delete(NSString * _Nonnull shortcut)
{
    _KSTextReplacementEntry *entryToDelete = _existingEntryForShortcut(shortcut);
    if (entryToDelete == nil) {
        return EXIT_SUCCESS;
    }
    return _submit(nil, @[entryToDelete]);
}
