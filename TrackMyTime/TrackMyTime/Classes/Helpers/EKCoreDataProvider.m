//
//  EKCoreDataProvider.m
//  TrackMyTime
//
//  Created by Evgeny Karkan on 11.12.13.
//  Copyright (c) 2013 EvgenyKarkan. All rights reserved.
//

#import "EKCoreDataProvider.h"
#import "Record.h"
#import "Date.h"

static NSString * const kEKRecord = @"Record";
static NSString * const kEKDate   = @"Date";

@interface EKCoreDataProvider ()

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end


@implementation EKCoreDataProvider;

#pragma mark Singleton stuff

static id _sharedInstance;

+ (EKCoreDataProvider *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    _sharedInstance = [[EKCoreDataProvider alloc] init];
	});
	return _sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    _sharedInstance = nil;
	    _sharedInstance = [super allocWithZone:zone];
	});
	return _sharedInstance;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

+ (id)new
{
	NSException *exception = [[NSException alloc] initWithName:kEKException
	                                                    reason:kEKExceptionReason
	                                                  userInfo:nil];
	[exception raise];
    
	return nil;
}

#pragma mark - Core Data stack

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"TrackMyTime" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"TrackMyTime.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
             NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark - Public API

- (void)saveRecord:(EKRecordModel *)recordModel withCompletionBlock:(void (^)(NSString *status))block
{
	NSAssert(recordModel != nil, @"Error with nil recordModel as parameter");
    NSParameterAssert(block != nil);
    
	Date *date = nil;
    
	if ([[self fetchedEntitiesForEntityName:kEKDate] count] == 0) {
		date = [NSEntityDescription insertNewObjectForEntityForName:kEKDate inManagedObjectContext:[self managedObjectContext]];
		date.dateOfRecord = [NSDate dateWithoutTime:[NSDate date]];
	}
	else {
        NSDate *dateOfLastSavedDateEntity = ((Date *)[[self fetchedEntitiesForEntityName:kEKDate] lastObject]).dateOfRecord;
        
        if ([NSDate comparisonResultOfTodayWithDate:dateOfLastSavedDateEntity] == NSOrderedDescending) {
			NSLog(@"Desc");
			date = [NSEntityDescription insertNewObjectForEntityForName:kEKDate inManagedObjectContext:[self managedObjectContext]];
			date.dateOfRecord = [NSDate dateWithoutTime:[NSDate date]];
		}
		else {
			NSLog(@"Same ");
			date = [[self fetchedEntitiesForEntityName:kEKDate] lastObject];
		}
	}
	Record *newRecord = [NSEntityDescription insertNewObjectForEntityForName:kEKRecord inManagedObjectContext:self.managedObjectContext];
    
	if (newRecord != nil) {
		[[self fetchedEntitiesForEntityName:kEKDate] count] > 0 ? [self mapRecordModel:recordModel toCoreDataRecordModel:newRecord] : nil;
		NSError *errorOnAdd = nil;
		[date addToRecordObject:newRecord];
		[self.managedObjectContext save:&errorOnAdd];
        
		NSAssert(errorOnAdd == nil, @"Error occurs during saving to context %@", [errorOnAdd localizedDescription]);
		block(kEKSavedWithSuccess);
	}
	else {
		block(kEKErrorOnSaving);
	}
}

- (NSArray *)allRecordModels
{
    NSMutableArray *bufferArray = [@[] mutableCopy];
    
	for (NSUInteger i = 0; i < [[self fetchedEntitiesForEntityName:kEKRecord] count]; i++) {
		EKRecordModel *recordModel = [[EKRecordModel alloc] init];
		[self mapCoreDataRecord:[self fetchedEntitiesForEntityName:kEKRecord][i] toRecordModel:recordModel];
		[bufferArray addObject:recordModel];
	}
	NSAssert(bufferArray != nil, @"Buffer array should be not nil");
    
	return [bufferArray copy];
}

- (NSArray *)allDateModels
{
	NSMutableArray *bufferArray = [@[] mutableCopy];
    
	for (NSUInteger i = 0; i < [[self fetchedEntitiesForEntityName:kEKDate] count]; i++) {
		EKDateModel *dateModel = [[EKDateModel alloc] init];
        [self mapCoreDataDate:[self fetchedEntitiesForEntityName:kEKDate][i] toDateModel:dateModel];
		[bufferArray addObject:dateModel];
	}
	NSAssert(bufferArray != nil, @"Buffer array should be not nil");
    
	return [bufferArray copy];
}


    //
- (NSArray *)fetchedDatesWithCalendarRange:(DSLCalendarRange *)rangeForFetch
{
    NSDate *foo = [NSDate date];
    
    NSLog(@"DATE & TIME NOW %@", foo);
    
	rangeForFetch.startDay.calendar = [NSCalendar currentCalendar];
	rangeForFetch.endDay.calendar = [NSCalendar currentCalendar];
    
	NSDate *startDate = [rangeForFetch.startDay date];
	NSDate *endDate = [rangeForFetch.endDay date];

	NSLog(@"Start %@ end %@", startDate, endDate);
    
    NSPredicate *pre = [NSPredicate predicateWithFormat:@"(dateOfRecord >= %@) AND (dateOfRecord <= %@)", startDate, endDate];
    NSLog(@"Models count %@", @([[self allDateModels] count]));
    
    NSDate *bar = ((EKDateModel *)[self allDateModels][0]).dateOfRecord;
    NSDate *wt = [NSDate dateWithoutTime:bar];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy/mm/dd hh:mm:ss"];

    NSString *dateString = [NSDateFormatter localizedStringFromDate:wt
                                                          dateStyle:NSDateFormatterShortStyle
                                                          timeStyle:NSDateFormatterFullStyle];
    
    NSString * foooo = [NSString stringWithFormat:@" %lu", (unsigned long)[[[self allDateModels] filteredArrayUsingPredicate:pre] count] ];
    
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:foooo
                                                      message:dateString
                                                     delegate:nil
                                            cancelButtonTitle:@"Button 1"
                                            otherButtonTitles:@"Button 2", @"Button 3", nil];
        //[message show];
    
    NSLog(@"After filtering %@", @([[[self allDateModels] filteredArrayUsingPredicate:pre] count]));
    
    return [[self allDateModels] filteredArrayUsingPredicate:pre];
}

#pragma mark - Private API
#pragma mark - Models mapping

- (void)mapRecordModel:(EKRecordModel *)recordModel toCoreDataRecordModel:(Record *)record
{
	if ((recordModel != nil) && (record != nil)) {
        record.activity = recordModel.activity;
        record.duration = recordModel.duration;
        record.toDate = recordModel.toDate;
	}
	else {
		NSAssert(recordModel != nil, @"Record model should be not nil");
		NSAssert(record != nil, @"Core Data record model should be not nil");
	}
}

- (void)mapCoreDataRecord:(Record *)record toRecordModel:(EKRecordModel *)recordModel
{
	if ((recordModel != nil) && (record != nil)) {
		recordModel.activity = record.activity;
		recordModel.duration = record.duration;
        recordModel.toDate = record.toDate;
	}
	else {
		NSAssert(recordModel != nil, @"Record model should be not nil");
		NSAssert(record != nil, @"Core Data record model should be not nil");
	}
}

- (void)mapCoreDataDate:(Date *)date toDateModel:(EKDateModel *)dateModel
{
	if ((dateModel != nil) && (date != nil)) {
		dateModel.dateOfRecord = date.dateOfRecord;
        dateModel.toRecord = date.toRecord;
	}
	else {
		NSAssert(dateModel != nil, @"Date model should be not nil");
		NSAssert(date != nil, @"Core Data date model should be not nil");
	}
}

#pragma mark - Fetch stuff 

- (NSArray *)fetchedEntitiesForEntityName:(NSString *)name
{
    NSParameterAssert(name != nil);
    
	NSError *error = nil;
	NSArray *entities = [self.managedObjectContext executeFetchRequest:[self requestWithEntityName:name]
	                                                             error:&error];
	NSAssert(entities != nil, @"Fetched array should not be nil");
    
	return entities;
}

- (NSFetchRequest *)requestWithEntityName:(NSString *)entityName
{
    NSParameterAssert(entityName != nil);
    
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName
	                                                     inManagedObjectContext:self.managedObjectContext];
	if (entityDescription != nil) {
		[fetchRequest setEntity:entityDescription];
	}
	else {
		NSAssert(entityDescription != nil, @"EntityDescription should not be nil");
	}
    
	return fetchRequest;
}

#pragma mark - Application's Documents directory

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end