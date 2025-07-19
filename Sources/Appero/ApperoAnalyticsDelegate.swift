//
//  ApperoAnalyticsDelegate.swift
//  Copyright Pocketworks Mobile Ltd.
//  Created by Rory Prior on 31/05/2024.
//

import Foundation

/// If you wish to hook Appero up to your existing analytics provider, adopt this protocol and pass your analytics handler to the ApperoRatingView
public protocol ApperoAnalyticsDelegate {
    /// Triggered when the user submits their feedback and rating (positive and neutral flows)
    func logApperoFeedback(rating: Int, feedback: String)
    /// Triggered when the user submits their feedback (negative flow)
    func logRatingSelected(rating: Int)
}
