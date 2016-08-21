//
//  NSArray+HigherOrder.h
//  shortcuts
//
//  Created by Dmitry Rodionov on 21/08/16.
//  Copyright © 2016 Internals Exposed. All rights reserved.
//

@import Foundation;

@interface NSArray (HigherOrder)

- (nonnull NSArray *)rd_map: (nonnull id _Nonnull (^)(id _Nonnull obj))mapper;

- (nonnull NSArray *)rd_flatMap: (nonnull id _Nullable (^)(id _Nonnull obj))mapper;

- (nonnull NSArray *)rd_filter: (nonnull BOOL (^)(id _Nonnull obj))block;

@end
