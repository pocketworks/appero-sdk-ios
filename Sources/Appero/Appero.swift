
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
//  Copyright Pocketworks Mobile Limited 2024
//

import Foundation
import StoreKit

public class Appero {
    
    public enum Experience: Int {
        case strongPositive = 5
        case mildPositive = 4
        case neutral = 3
        case mildNegative = 2
        case strongNegative = 1
    }
    
    // default key constants
    
    struct Constants {
        static let kUserIdKey = "appero_user_id"
        static let kUserApperoDictionary = "appero_user"
        static let kUserExperienceValue = "appero_experience_value"
        static let kRatingThreshold = "appero_rating_threshold"
        static let kRatingPromptedDictionary = "appero_rating_prompted"
        
        static let kDefaultRatingThreshold = 10
    }
    
    // config constants
    
    public static let instance = Appero()

    // instance vars
    private var apiKey: String?
    private var clientId: String?
    
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
    
    // MARK: - Functions
    
    /// Initialise the Appero SDK. This should be called early on in your app's lifecycle.
    /// - Parameters:
    ///   - apiKey: your API key
    ///   - clientId: your client ID
    public func start(apiKey: String, clientId: String) {
        self.apiKey = apiKey
        self.clientId = clientId
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
                    "client_id" : clientId!,
                    "sent_at": Date().ISO8601Format(),
                    "api_key" : apiKey!,
                    "feedback": feedback ?? "",
                    "rating": String(rating)
                ],
                method: .post
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

