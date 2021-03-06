//
//  NSManagedObjectContext+iOS10Additions.m
//  INSPersistentContainer
//
//  Created by Michal Zaborowski on 17.06.2016.
//  Copyright © 2016 Michal Zaborowski. All rights reserved.
//

#import "NSManagedObjectContext+iOS10Additions.h"
#import <objc/runtime.h>

@implementation NSManagedObjectContext (iOS10Additions)

#if NS_PERSISTENT_STORE_NOT_AVAILABLE_IN_SDK
- (BOOL)automaticallyMergesChangesFromParent {
    return self.ins_automaticallyMergesChangesFromParent;
}

- (void)setAutomaticallyMergesChangesFromParent:(BOOL)automaticallyMergesChangesFromParent {
    self.ins_automaticallyMergesChangesFromParent = automaticallyMergesChangesFromParent;
}
#endif

- (void)ins_dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextWillSaveNotification object:nil];
}

- (BOOL)ins_automaticallyObtainPermanentIDsForInsertedObjects {
    __block BOOL value = NO;
    [self performBlockAndWait:^{
        value = [objc_getAssociatedObject(self, @selector(ins_automaticallyObtainPermanentIDsForInsertedObjects)) boolValue];
    }];
    return value;
}

- (void)setIns_automaticallyObtainPermanentIDsForInsertedObjects:(BOOL)ins_automaticallyObtainPermanentIDsForInsertedObjects {
    [self performBlockAndWait:^{
        if (ins_automaticallyObtainPermanentIDsForInsertedObjects != self.ins_automaticallyObtainPermanentIDsForInsertedObjects) {
            objc_setAssociatedObject(self, @selector(ins_automaticallyObtainPermanentIDsForInsertedObjects), @(ins_automaticallyObtainPermanentIDsForInsertedObjects), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (ins_automaticallyObtainPermanentIDsForInsertedObjects) {
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ins_automaticallyObtainPermanentIDsForInsertedObjectsFromWillSaveNotification:) name:NSManagedObjectContextWillSaveNotification object:self];
            } else {
                [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextWillSaveNotification object:nil];
            }
        }
    }];
}

- (BOOL)ins_automaticallyMergesChangesFromParent {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    if (self.concurrencyType == NSConfinementConcurrencyType) {
#pragma GCC diagnostic pop
        return NO;
    }
    __block BOOL value = NO;
    [self performBlockAndWait:^{
        value = [objc_getAssociatedObject(self, @selector(ins_automaticallyMergesChangesFromParent)) boolValue];
    }];
    return value;
}

- (void)setIns_automaticallyMergesChangesFromParent:(BOOL)ins_automaticallyMergesChangesFromParent {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    if (self.concurrencyType == NSConfinementConcurrencyType) {
#pragma GCC diagnostic pop
        [[NSException exceptionWithName:NSInvalidArgumentException reason:@"Automatic merging is not supported by contexts using NSConfinementConcurrencyType" userInfo:0x0] raise];
    }
    if (self.parentContext == nil && self.persistentStoreCoordinator == nil) {
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot enable automatic merging for a context without a parent, set a parent context or persistent store coordinator first." userInfo:0x0] raise];
    }
    [self performBlockAndWait:^{
        if (ins_automaticallyMergesChangesFromParent != self.ins_automaticallyMergesChangesFromParent) {
            objc_setAssociatedObject(self, @selector(ins_automaticallyMergesChangesFromParent), @(ins_automaticallyMergesChangesFromParent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (ins_automaticallyMergesChangesFromParent) {
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ins_automaticallyMergeChangesFromContextDidSaveNotification:) name:NSManagedObjectContextDidSaveNotification object:self.parentContext];
            } else {
                [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
            }
        }
    }];
}

- (void)ins_automaticallyMergeChangesFromContextDidSaveNotification:(NSNotification *)notification {
    NSManagedObjectContext *context = (NSManagedObjectContext *)notification.object;
    if (context.persistentStoreCoordinator != self.persistentStoreCoordinator) {
        return;
    }
    BOOL isRootContext = context.parentContext == nil;
    BOOL isParentContext = self.parentContext == context;
    if (!(isRootContext || isParentContext) || context == self) {
        return;
    }
    
    [self performBlock:^{
        // WORKAROUND FOR: http://stackoverflow.com/questions/3923826/nsfetchedresultscontroller-with-predicate-ignores-changes-merged-from-different/3927811#3927811
        NSSet <NSManagedObject *> *updatedObjects = notification.userInfo[NSUpdatedObjectsKey];
        for (NSManagedObject *obj in updatedObjects) {
            [[self objectWithID:obj.objectID] willAccessValueForKey:nil]; // ensures that a fault has been fired
        }
        
        [self mergeChangesFromContextDidSaveNotification:notification];
    }];
}

- (void)ins_automaticallyObtainPermanentIDsForInsertedObjectsFromWillSaveNotification:(NSNotification *)notification {
    NSManagedObjectContext *context = notification.object;
    if (context.insertedObjects.count <= 0) {
        return;
    }
    [context obtainPermanentIDsForObjects:[context.insertedObjects allObjects] error:nil];
}

+ (void)load {
    
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max) {
        return;
    }
    
    Method automaticallyMergesChangesMethod = class_getInstanceMethod([self class], @selector(ins_automaticallyMergesChangesFromParent));
    class_addMethod([self class], @selector(automaticallyMergesChangesFromParent), method_getImplementation(automaticallyMergesChangesMethod), method_getTypeEncoding(automaticallyMergesChangesMethod));
    
    Method automaticallyMergesChangesSetMethod = class_getInstanceMethod([self class], @selector(setIns_automaticallyMergesChangesFromParent:));
    class_addMethod([self class], @selector(setAutomaticallyMergesChangesFromParent:), method_getImplementation(automaticallyMergesChangesSetMethod), method_getTypeEncoding(automaticallyMergesChangesSetMethod));
}

@end
