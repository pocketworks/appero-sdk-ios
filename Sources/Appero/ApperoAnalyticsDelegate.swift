//
//  ApperoAnalyticsDelegate.swift
//  Copyright Pocketworks Mobile Ltd.
//  Created by Rory Prior on 31/05/2024.
//

import Foundation

/// If you wish to hook Appero up to your existing analytics provider, adopt this protocol and pass your analytics handler to the ApperoRatingView
public protocol ApperoAnalyticsDelegate {
    /// Triggered when the user submits their feedback and rating
    func logApperoFeedback(rating: Int, feedback: String)
    /// Triggered when the user submits their frustration reason
    func logApperoFrustration(feedback: String)
    /// Triggered each time the user taps a different rating, allows you to capture some idea of user happiness even if they don't submit feedback
    func logRatingSelected(rating: Int)
}
