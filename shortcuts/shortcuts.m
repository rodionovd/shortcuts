//
//  shortcuts.c
//  shortcuts
//
//  Created by Dmitry Rodionov on 21/08/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

#import "shortcuts.h"
#import "InputMethodKit+Private.h"
#import "NSArray+HigherOrder.h"

static IMKTextReplacementEntryTransaction * _Nonnull transactionForNewEntry(IMKTextReplacementEntry * _Nonnull entry,
                                                                         BOOL * _Nullable overwritting);

int import(NSString * _Nonnull inputPropertyListPath, BOOL forceOverwrite)
{
    NSArray *array = [NSArray arrayWithContentsOfFile:inputPropertyListPath];
    NSCAssert(array != nil, @"Invalid input file");

    NSArray <IMKTextReplacementEntryTransaction *> *transactions = [array rd_flatMap:^id(NSDictionary *item) {
        IMKTextReplacementEntry *entry = [IMKTextReplacementEntry entryWithPhrase:item[@"phrase"]
                                                                         shortcut:item[@"shortcut"]
                                                                        timestamp:nil];
        NSCAssert(entry != nil, @"Could not create a text replacement entry from dictionary: %@", item);
        BOOL willOverwrite = NO;
        id result = transactionForNewEntry(entry, &willOverwrite);
        if (willOverwrite && !forceOverwrite) {
            return nil;
        }
        return result;
    }];

    IMKTextReplacementController *controller = [[IMKTextReplacementController alloc] init];
    [controller performTransactions:transactions withCompletionHandler:nil];

    return EXIT_SUCCESS;
}

int new(NSString * _Nonnull shortcut, NSString * _Nonnull phrase, BOOL forceOverwrite)
{
    NSCParameterAssert(shortcut != nil);
    NSCParameterAssert(phrase != nil);

    IMKTextReplacementEntry *newEntry = [IMKTextReplacementEntry entryWithPhrase:phrase
                                                                        shortcut:shortcut
                                                                       timestamp:nil];
    IMKTextReplacementController *controller = [[IMKTextReplacementController alloc] init];
    BOOL willOverwrite = NO;
    IMKTextReplacementEntryTransaction *_Nullable transaction = transactionForNewEntry(newEntry, &willOverwrite);
    // Check for undesired overrides
    if (willOverwrite && !forceOverwrite) {
        fprintf(stderr, "An entry with the same shortcut \"%s\" already exists. Use --force modifier or 'update' command to update existing text substitution entries.\n", shortcut.UTF8String);
        return EXIT_FAILURE;

    }
    // Nothing to do here (we're overriding an entry with the equal one)
    if (!transaction) {
        return EXIT_SUCCESS;
    }
    // XXX: we should probably wait here but I can't get the completion handler to be called so whatever
    [controller performTransactions:@[transaction] withCompletionHandler:nil];
    return EXIT_SUCCESS;
}

static IMKTextReplacementEntryTransaction * _Nullable transactionForNewEntry(IMKTextReplacementEntry *entry, BOOL *willOverwrite)
{
    IMKTextReplacementController *controller = [[IMKTextReplacementController alloc] init];
    // Maybe there's an entry for the same shortcut?
    NSUInteger idx = [controller.entries indexOfObjectPassingTest:
                      ^BOOL(IMKTextReplacementEntry *existing, NSUInteger idx, BOOL * stop)
    {
        return [existing.shortcut isEqualToString:entry.shortcut];
    }];
    IMKTextReplacementEntry *existingEntry = (idx != NSNotFound ? controller.entries[idx] : nil);
    if (willOverwrite) {
        *willOverwrite = (existingEntry != nil);
    }

    // Either update the existing entry or insert the new one
    IMKTextReplacementEntryTransaction *transaction = nil;
    if (existingEntry != nil) {
        transaction = [IMKTextReplacementEntryTransaction entryToUpdate:existingEntry withEntryToSet:entry];
    } else {
        transaction = [IMKTextReplacementEntryTransaction entryToInsert:entry];
    }
    return transaction;
}

int update(NSString * _Nonnull shortcut, NSString * _Nonnull phrase)
{
    return new(shortcut, phrase, /*force*/YES);
}

int list(NSString * _Nullable mode)
{
    IMKTextReplacementController *controller = [[IMKTextReplacementController alloc] init];
    NSArray *converted = [controller.entries rd_map:^NSDictionary *(IMKTextReplacementEntry *entry) {
        return @{@"phrase":entry.phrase, @"shortcut":entry.shortcut};
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
    IMKTextReplacementController *controller = [[IMKTextReplacementController alloc] init];
    NSUInteger idx = [controller.entries indexOfObjectPassingTest:
                      ^BOOL(IMKTextReplacementEntry *existing, NSUInteger idx, BOOL * stop)
    {
        return [existing.shortcut isEqualToString:shortcut];
    }];
    // Got nothing to delete
    if (idx == NSNotFound) {
        return EXIT_SUCCESS;
    }
    IMKTextReplacementEntry *existingEntry = controller.entries[idx];
    IMKTextReplacementEntryTransaction *transaction = [IMKTextReplacementEntryTransaction entryToDelete:existingEntry];
    NSCAssert(transaction != nil, @"This shouldn't happen actually. Please file an issue.");
    
    [controller performTransactions:@[transaction] withCompletionHandler:nil];
    return EXIT_SUCCESS;
}
