//
//  UserActivityBuilder.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import Intents
import OBAKitCore

/// Simplifies creating `NSUserActivity` objects suitable for use with Handoff and Siri.
class UserActivityBuilder: NSObject {
    private let application: Application

    /// Creates the `UserActivityBuilder` object
    /// - Parameter application: The application object.
    public init(application: Application) {
        self.application = application
        super.init()

        validateInfoPlistUserActivityTypes()
    }

    /// A list of keys used in the `userInfo` properties of the activity types generated by this class.
    public struct UserInfoKeys {
        public static let regionID = "regionID"
        public static let serviceDate = "serviceDate"
        public static let stopID = "stopID"
        public static let stopSequence = "stopSequence"
        public static let tripID = "tripID"
        public static let vehicleID = "vehicleID"
    }

    // MARK: - Stop User Activity

    /// Creates an `NSUserActivity` for a `Stop`.
    ///
    /// In addition to configuring the activity for Handoff, this method also includes support for Siri predictions and invocations.
    ///
    /// - Parameters:
    ///   - stop: The stop for which the activity will be created.
    ///   - region: The region that hosts the stop.
    public func userActivity(for stop: Stop, region: Region) -> NSUserActivity {
        let activity = NSUserActivity(activityType: stopActivityType)
        activity.title = Formatters.formattedTitle(stop: stop)

        activity.isEligibleForHandoff = true

        // Per WWDC 2018 Session "Intro to Siri Shortcuts", this must be set to `true`
        // for `isEligibleForPrediction` to have any effect. Timecode: 8:30
        activity.isEligibleForSearch = true

        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = OBALoc("user_activity_builder.show_me_my_bus", value: "Show me my bus", comment: "Suggested invocation phrase for Siri Shortcut")
        activity.persistentIdentifier = "region_\(region.regionIdentifier)_stop_\(stop.id)"

        activity.requiredUserInfoKeys = [UserInfoKeys.stopID, UserInfoKeys.regionID]
        activity.userInfo = [UserInfoKeys.stopID: stop.id, UserInfoKeys.regionID: region.regionIdentifier]

        if let router = application.appLinksRouter {
            activity.webpageURL = router.url(for: stop, region: region)
        }

        return activity
    }

    /// An identifier for `NSUserActivity`s for stops. This must be unique across all iOS apps.
    public var stopActivityType: String {
        return "\(application.applicationBundle.bundleIdentifier).user_activity.stop"
    }

    // MARK: - Trip User Activity

    /// Creates an `NSUserActivity` for a trip.
    ///
    ///- Note: Due to technical limitations, this method will only create an `NSUserActivity` if `trip`
    ///        contains an `ArrivalDeparture`.
    ///
    /// - Parameters:
    ///   - trip: This can be sourced from `TripViewController`, for example.
    ///   - region: The region that contains the `trip`.
    public func userActivity(for trip: TripConvertible, region: Region) -> NSUserActivity? {
        guard let arrDep = trip.arrivalDeparture else {
            return nil
        }

        let activity = NSUserActivity(activityType: tripActivityType)
        activity.title = arrDep.routeAndHeadsign

        activity.isEligibleForHandoff = true
        activity.persistentIdentifier = "region_\(region.regionIdentifier)_trip_\(arrDep.tripID)"

        activity.requiredUserInfoKeys = [UserInfoKeys.regionID, UserInfoKeys.serviceDate, UserInfoKeys.stopID, UserInfoKeys.stopSequence, UserInfoKeys.tripID]

        var userInfo: [String: Any] = [
            UserInfoKeys.regionID: region.regionIdentifier,
            UserInfoKeys.serviceDate: arrDep.serviceDate,
            UserInfoKeys.stopID: arrDep.stopID,
            UserInfoKeys.stopSequence: arrDep.stopSequence,
            UserInfoKeys.tripID: arrDep.tripID
        ]

        if let vehicleID = arrDep.vehicleID {
            userInfo[UserInfoKeys.vehicleID] = vehicleID
        }

        if let router = application.appLinksRouter {
            activity.webpageURL = router.encode(arrivalDeparture: arrDep, region: region)
        }

        return activity
    }

    /// An identifier for `NSUserActivity`s for trips. This must be unique across all iOS apps.
    public var tripActivityType: String {
        return "\(application.applicationBundle.bundleIdentifier).user_activity.trip"
    }

    // MARK: - Private Helpers

    /// Checks to see if the application's Info.plist file contains `NSUserActivityTypes` data
    /// that matches what this class expects it to have.
    private func validateInfoPlistUserActivityTypes() {
        guard
            let activityTypes = application.applicationBundle.userActivityTypes,
            activityTypes.contains(stopActivityType),
            activityTypes.contains(tripActivityType)
        else {
            fatalError("The Info.plist file must include the necessary NSUserActivityTypes values.")
        }
    }
}
