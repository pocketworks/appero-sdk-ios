//
//       /\
//      /  \   _ __  _ __   ___ _ __ ___
//     / /\ \ | '_ \| '_ \ / _ \ '__/ _ \
//    / ____ \| |_) | |_) |  __/ | | (_) |
//   /_/    \_\ .__/| .__/ \___|_|  \___/
//            | |   | |
//            |_|   |_|
//
//  A Swift package to integrate with the Appero service
//  Copyright Pocketworks Mobile Limited 2024-2025
//

import Foundation
import StoreKit

public class Appero {
    
    struct Constants {
        static let kUserIdKey = "appero_user_id"
        static let kUserApperoDictionary = "appero_user"
        static let kUserExperienceValue = "appero_experience_value"
        static let kRatingThreshold = "appero_rating_threshold"
        static let kRatingPromptedDictionary = "appero_rating_prompted"
        static let kRatingPromptLastShownDictionary = "appero_rating_prompt_last_shown"
        static let kFrustrationDictionary = "appero_frustration_dictionary"
        
        
        static let kDefaultRatingThreshold = 10
    }
    
    public enum Experience: Int {
        case strongPositive = 5
        case mildPositive = 4
        case neutral = 3
        case mildNegative = 2
        case strongNegative = 1
    }
    
    public struct Frustration: Codable {
        /// The identifier should be unique
        let identifier: String
        /// Trigger threshold for showing the frustration feedback UI
        let threshold: Int
        /// Number of times this has been triggered
        var events: Int
        /// Has the frustration triggered the feedback UI?
        var prompted: Bool
        /// Text shown to the user when prompting feedback
        var userPrompt: String?
        /// If the user dismisses, the date we should next prompt for feedback
        var nextPromptDate: Date?
        
        init(identifier: String, threshold: Int, userPrompt: String? = nil) {
            self.identifier = identifier
            self.threshold = threshold
            self.userPrompt = userPrompt
            self.events = 0
            self.prompted = false
        }
    }
    
    // config constants
    
    public static let instance = Appero()

    // instance vars
    private var apiKey: String?
    
    /// Specifies a delegate to handle analytics
    public var analyticsDelegate: ApperoAnalyticsDelegate?
    
    /// Specifies a theme to use for the Appero UI
    public var theme: ApperoTheme = DefaultTheme()
    
    // MARK: - Computed properties
    public var userId: String {
        get {
            if let id = UserDefaults.standard.string(forKey: Constants.kUserIdKey) {
                return id
            } else {
                let id = UUID().uuidString
                UserDefaults.standard.setValue(id, forKey: Constants.kUserIdKey)
                return id
            }
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.kUserIdKey)
        }
    }
    
    public var ratingThreshold: Int {
        get {
            let id = UserDefaults.standard.integer(forKey: Constants.kRatingThreshold)
            if id == 0 {
                return Constants.kDefaultRatingThreshold
            } else {
                return id
            }
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.kRatingThreshold)
        }
    }
    
    public var experienceValue: Int {
        get {
            if let dict = UserDefaults.standard.dictionary(forKey: Constants.kUserApperoDictionary) as? [String: Int] {
                return dict[userId] ?? 0
            } else {
                return 0
            }
        }
        set {
            if var dict = UserDefaults.standard.dictionary(forKey: Constants.kUserApperoDictionary) {
                dict[userId] = newValue
                UserDefaults.standard.setValue(dict, forKey: Constants.kUserApperoDictionary)
            } else {
                UserDefaults.standard.setValue([userId : newValue], forKey: Constants.kUserApperoDictionary)
            }
        }
    }
    
    var ratingPromptLastShown: Date? {
        get {
            if let dict = UserDefaults.standard.dictionary(forKey: Constants.kRatingPromptLastShownDictionary) as? [String: Date] {
                return dict[userId]
            } else {
                return nil
            }
        }
        set {
            if var dict = UserDefaults.standard.dictionary(forKey: Constants.kRatingPromptLastShownDictionary) {
                dict[userId] = newValue
                UserDefaults.standard.setValue(dict, forKey: Constants.kRatingPromptLastShownDictionary)
            } else {
                UserDefaults.standard.setValue([userId : newValue], forKey: Constants.kRatingPromptLastShownDictionary)
            }
        }
    }
    
    /// Flag used to record if the current user has been prompted for their feedback or not. When this is true subsequent crossings of the experience point thresholds will not have an effect.
    public var hasRatingBeenPrompted: Bool {
        get {
            if let dict = UserDefaults.standard.dictionary(forKey: Constants.kRatingPromptedDictionary) as? [String: Bool] {
                return dict[userId] ?? false
            } else {
                return false
            }
        }
        set {
            if var dict = UserDefaults.standard.dictionary(forKey: Constants.kRatingPromptedDictionary) {
                dict[userId] = newValue
                UserDefaults.standard.setValue(dict, forKey: Constants.kRatingPromptedDictionary)
            } else {
                UserDefaults.standard.setValue([userId : newValue], forKey: Constants.kRatingPromptedDictionary)
            }
        }
    }
    
    /// Flag to indicate if the Appero feedback prompt should be displayed based on whether the prompt has already been shown to this user and if they have crossed the experience point threshold.
    public var shouldShowAppero: Bool {
        return hasRatingBeenPrompted == false && experienceValue >= ratingThreshold
    }
    
    /// Initialise the Appero SDK. This should be called early on in your app's lifecycle.
    /// - Parameters:
    ///   - apiKey: your API key
    ///   - userId: optional user identifier, if none provided one will be generated automatically
    public func start(apiKey: String, userId: String?) {
        self.apiKey = apiKey
        if let userId = userId {
            setUserId(userId)
        }
    }
    
    /// Allows a custom user identifier to be set, otherwise Appero will create its own unique user identifier. Identifiers persist until ``resetUser`` is called.
    /// - Parameter id: string identifier, e.g. a unid
    public func setUserId(_ id: String) {
        UserDefaults.standard.setValue(id, forKey: Constants.kUserIdKey)
    }
    
    /// Resets the user ID this Appero session will be recorded against. Typically you would call this when the user logs out of your app.
    public func resetUser() {
        UserDefaults.standard.setValue(nil, forKey: Constants.kUserIdKey)
    }
    
    /// Convenience function to reset the experience point value to zero and remove the feedback prompted flags
    public func resetExperienceAndPrompt() {
        hasRatingBeenPrompted = false
        experienceValue = 0
    }
    
    // MARK: - Experience Logging
    
    /// Call when the user has a meaningfully positive or negative interaction with your app.
    /// - Parameter experience: choose a rating on our Likert scale
    public func log(experience: Experience) {
        experienceValue += experience.rawValue
    }
    
    /// Call when the user has a meaningfully positive or negative interaction with your app. Use this when you want to define your own system for scoring your users interactions
    /// - Parameter points: a positive or negative number of points
    public func log(points: Int) {
        experienceValue += points
    }
    
    // MARK: - Frustrations
    
    /// Creates storage for the frustration
    public func register(frustration: Appero.Frustration) {
        var frustrations = getFrustrations()
        // only register a frustration if one doesn't already exist for this identifier
        if frustrations[frustration.identifier] == nil {
            frustrations[frustration.identifier] = frustration
            saveFrustrations(frustrations)
        }
    }
    
    /// Log an instance of a given frustration occuring
    public func log(frustration identifier: String) {
        var frustrations = getFrustrations()
        if var existingFrustration = frustrations[identifier] {
            existingFrustration.events += 1
            frustrations[identifier] = existingFrustration
            saveFrustrations(frustrations)
        }
    }
    
    /// Check if a given frustration has crossed the threshold value. Generally you should ``needsPrompt(frustration:)`` instead of calling this directly.
    public func isThresholdCrossed(for identifier: String) -> Bool {
        if let storedFrustration = self.frustration(for: identifier) {
            return storedFrustration.events >= storedFrustration.threshold
        }
        return false
    }
    
    /// Mark a frustration as having triggered the feedback UI
    public func markPrompted(frustration identifier: String) {
        var frustrations = getFrustrations()
        if var existingFrustration = frustrations[identifier] {
            existingFrustration.prompted = true
            frustrations[identifier] = existingFrustration
            saveFrustrations(frustrations)
        }
    }
    
    /// Has a given frustration been prompted yet? Generally you should ``needsPrompt(frustration:)`` instead of calling this directly.
    public func isPrompted(frustration identifier: String) -> Bool {
        return frustration(for: identifier)?.prompted ?? false
    }
    
    /// Is the frustration deferred due to a previous dismissal?
    public func isDeferred(frustration identifier: String) -> Bool {
        guard let nextPromptDate = frustration(for: identifier)?.nextPromptDate else {
            return false
        }
        return nextPromptDate > Date()
    }
    
    /// If user dismissed a prompt without providing feedback, we can defer the prompt for 30 days and try again
    public func deferPromptFor(frustration identifier: String) {
        var frustrations = getFrustrations()
        if var existingFrustration = frustrations[identifier] {
            existingFrustration.nextPromptDate = Date(timeIntervalSinceNow: 86400 * 30) // 30 days from now
            frustrations[identifier] = existingFrustration
            saveFrustrations(frustrations)
        }
    }
    
    /// Reset all registered frustrations for the current user
    public func resetAllFrustrations() {
        saveFrustrations([:])
    }

    /// Look up a frustration that has been registered
    /// - Parameter identifier: identifier for the frustration
    /// - Returns: the Frustration or nil if the identifier is unregistered
    internal func frustration(for identifier: String) -> Frustration? {
        let frustrations = getFrustrations()
        return frustrations[identifier]
    }
    
    /// Check if a given frustration needs to be prompted; for this to be true it must have reach the event threshold and not already have beeb prompted and not within the deferral period if previously dismissed
    public func needsPrompt(frustration identifier: String) -> Bool {
        return isThresholdCrossed(for: identifier) == true && isPrompted(frustration: identifier) == false && isDeferred(frustration: identifier) == false
    }
    
    // MARK: - Miscellaneous Functions
    
    /// Convenience function for requesting an app store rating. We recommend letting Appero handle when this is called to maximise your chances of a positive rating.
    public func requestAppStoreRating() {
        #if os(macOS)
        SKStoreReviewController.requestReview()
        #else
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        #endif
    }
    
    // MARK: - Private Helper Methods
    
    /// Get all frustrations for the current user from UserDefaults
    private func getFrustrations() -> [String: Frustration] {
        if let data = UserDefaults.standard.data(forKey: Constants.kFrustrationDictionary),
           let userFrustrations = try? JSONDecoder().decode([String: [String: Frustration]].self, from: data) {
            return userFrustrations[userId] ?? [:]
        }
        return [:]
    }
    
    /// Save frustrations for the current user to UserDefaults
    private func saveFrustrations(_ frustrations: [String: Frustration]) {
        var allUserFrustrations: [String: [String: Frustration]] = [:]
        
        if let data = UserDefaults.standard.data(forKey: Constants.kFrustrationDictionary),
           let existing = try? JSONDecoder().decode([String: [String: Frustration]].self, from: data) {
            allUserFrustrations = existing
        }
        
        allUserFrustrations[userId] = frustrations
        
        if let data = try? JSONEncoder().encode(allUserFrustrations) {
            UserDefaults.standard.set(data, forKey: Constants.kFrustrationDictionary)
        }
    }
    
    // MARK: - API Calls
    
    /// Post user feedback to Appero.
    /// - Parameters:
    ///   - rating: A value between 1 and 5 inclusive.
    ///   - feedback: Optional feedback supplied by the user. Maximum length of 500 characters
    /// - Returns: Boolean indicating if the feedback supplied passed validation and successfully uploaded. On false, no data was sent to the API and validation possibly failed
    @discardableResult public func postFeedback(rating: Int, feedback: String?) async -> Bool {
        guard 1...5 ~= rating, feedback?.count ?? 0 < 500 else {
            return false
        }
        
        do {
            try await ApperoAPIClient.sendRequest(
                endPoint: "feedback",
                fields: [
                    "client_id" : userId,
                    "sent_at": Date().ISO8601Format(),
                    "feedback": feedback ?? "",
                    "source" : UIDevice.current.systemName,
                    "build_version" : Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    "rating": String(rating)
                ],
                method: .post,
                authorization: apiKey!
            )
            return true
        }
        catch let error as ApperoAPIError {
            print("[Appero] Error submitting feedback")
            
            switch error {
                case .networkError(statusCode: let code):
                    print("[Appero] Network error \(code)")
                case .noData:
                    print("[Appero] No data")
                case .noResponse:
                    print("[Appero] No response")
            }
            return false
        }
        catch _ {
            print("[Appero] Unknown error submitting feedback")
            return false
        }
    }
}

extension Bundle {
    public static var appero: Bundle = .module
}
