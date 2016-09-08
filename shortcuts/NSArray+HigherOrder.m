//
//  NSArray+HigherOrder.m
//  shortcuts
//
//  Created by Dmitry Rodionov on 21/08/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//


#import "NSArray+HigherOrder.h"

@implementation NSArray (HigherOrder)

- (NSArray *)rd_map: (nonnull id _Nonnull (^)(id _Nonnull obj))mapper
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: self.count];
	[self enumerateObjectsUsingBlock: ^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		[result addObject: mapper(obj)];
	}];
	return result;
}

- (nonnull NSArray *)rd_flatMap: (nonnull id _Nullable (^)(id _Nonnull obj))mapper
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity: self.count];
    [self enumerateObjectsUsingBlock: ^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id mapped = mapper(obj);
        if ([mapped isKindOfClass:[NSArray class]]) {
            [result addObjectsFromArray:mapped];
        } else if (mapped != nil) {
            [result addObject: mapped];
        }
    }];
    return result;
}

- (nonnull NSArray *)rd_filter: (nonnull BOOL (^)(id _Nonnull obj))block
{
    NSMutableArray *new = [NSMutableArray array];
    [self enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
        if (block(obj)) [new addObject: obj];
    }];
    return new;
}

@end
