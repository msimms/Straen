// Created by Michael Simms on 10/25/20.
// Copyright (c) 2020 Michael J. Simms. All rights reserved.

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <CoreLocation/CoreLocation.h>
#import "WatchHealthManager.h"
#import "BtleHeartRateMonitor.h"
#import "Preferences.h"

@implementation WatchHealthManager

- (id)init
{
	self = [super init];
	return self;
}

- (void)dealloc
{
}

#pragma mark methods for starting and stopping workouts

- (void)startWorkout:(NSString*)activityType withStartTime:(NSDate*)startTime
{
	HKWorkoutConfiguration* workoutConfig = [[HKWorkoutConfiguration alloc] init];

	if (workoutConfig)
	{
		workoutConfig.activityType = [super activityTypeToHKWorkoutType:activityType];
		workoutConfig.locationType = [super activityTypeToHKWorkoutSessionLocationType:activityType];

		self->workoutSession = [[HKWorkoutSession alloc] initWithHealthStore:self->healthStore configuration:workoutConfig error:nil];
		self->workoutSession.delegate = self;

		[self->workoutSession startActivityWithDate:startTime];

		if ([Preferences useWatchHeartRate])
		{
			[self subscribeToHeartRateUpdates];
		}
	}
}

- (void)stopWorkout:(NSDate*)endTime
{
	[self->workoutSession stopActivityWithDate:endTime];
	[self->workoutSession end];
}

#pragma mark workout session delegate methods

- (void)workoutSession:(HKWorkoutSession*)workoutSession didChangeToState:(HKWorkoutSessionState)toState fromState:(HKWorkoutSessionState)fromState date:(NSDate*)date
{
}

- (void)workoutSession:(HKWorkoutSession*)workoutSession didFailWithError:(NSError*)error
{
}

#pragma mark methods for getting heart rate updates from the watch

- (void)subscribeToHeartRateUpdates
{
	HKSampleType* sampleType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
	HKObserverQuery* query = [[HKObserverQuery alloc] initWithSampleType:sampleType
															   predicate:nil
														   updateHandler:^(HKObserverQuery* query, HKObserverQueryCompletionHandler completionHandler, NSError* error)
	{
		 if (!error)
		 {
			 HKQuantityType* hrType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];

			 [super mostRecentQuantitySampleOfType:hrType
										completion:^(HKQuantity* mostRecentQuantity, NSDate* startDate, NSError* error)
			  {
				  if (mostRecentQuantity)
				  {
					  double hr = [mostRecentQuantity doubleValueForUnit:[HKUnit heartBeatsPerMinuteUnit]];
					  time_t unixTime = (time_t) [startDate timeIntervalSince1970];
					  NSDictionary* heartRateData = [[NSDictionary alloc] initWithObjectsAndKeys:
													 [NSNumber numberWithLong:(long)hr], @KEY_NAME_HEART_RATE,
													 [NSNumber numberWithLongLong:unixTime], @KEY_NAME_HRM_TIMESTAMP_MS,
													nil];
					  if (heartRateData)
					  {
						  [[NSNotificationCenter defaultCenter] postNotificationName:@NOTIFICATION_NAME_HRM object:heartRateData];
					  }
				  }
			  }];
		 }
	}];

	// Execute asynchronously.
	[self->healthStore executeQuery:query];
}

@end
