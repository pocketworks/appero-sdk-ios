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
        static let kApperoData = "appero_unsent_experiences"
        static let kUserApperoDictionary = "appero_data"
        
        static let defaultTitle = "Thanks for using our app!"
        static let defaultSubtitle = "Please let us know how we're doing"
        static let defaultPrompt = "Share your thoughts here"
    }
    
    public enum ExperienceRating: Int, Codable {
        case strongPositive = 5
        case positive = 4
        case neutral = 3
        case negative = 2
        case strongNegative = 1
    }
    
    public struct Experience: Codable {
        let date: Date
        let value: ExperienceRating
        let context: String?
    }
    
    private struct ApperoData: Codable {
        /// stores any experiences we've been unable to log with the backend due to network issues
        var unsentExperiences: [Experience]
        /// set to true when we're notified by the backend that the feedback UI is ready for display, can be used to defer display
        var feedbackPromptShouldDisplay: Bool
        /// caches the text for the feedback UI for when the prompt is deferred
        var feedbackUIStrings: FeedbackUIStrings
        /// the last date that the rating prompt was shown to the user, can be used to reprompt at a later date if the user declines initially
        var lastPromptDate: Date?
    }
    
    /// contains the text to display in the feedback UI, can be customised to align with your app's branding and tone via the backend
    public struct FeedbackUIStrings: Codable {
        let title: String
        let subtitle: String
        let prompt: String
    }
    
    private enum FlowType: String, Codable {
        case positive = "normal"
        case neutral = "neutral"
        case negative = "frustration"
    }
    
    /// models the response to the
    private struct ExperienceResponse: Codable {
        let shouldShowFeedbackUI: Bool
        let flowType: FlowType
        let feedbackUI: FeedbackUIStrings?
        
        enum CodingKeys: String, CodingKey {
            case shouldShowFeedbackUI = "should_show_feedback"
            case flowType = "flow_type"
            case feedbackUI = "feedback_ui"
        }
    }
    
    // config constants
    public static let instance = Appero()

    // instance vars
    private var apiKey: String?
    
    /// an optional string to identify your user (uuid from your backend, account number, email address etc.)
    var clientId: String?
    
    /// Specifies a delegate to handle analytics
    public var analyticsDelegate: ApperoAnalyticsDelegate?
    
    /// Specifies a theme to use for the Appero UI
    public var theme: ApperoTheme = DefaultTheme()
    
    /// Initialise the Appero SDK. This should be called early on in your app's lifecycle.
    /// - Parameters:
    ///   - apiKey: your API key
    ///   - clientId: optional user identifier, if none provided one will be generated automatically
    public func start(apiKey: String, clientId: String?) {
        self.apiKey = apiKey
        self.clientId = clientId ?? generateOrRestoreClientId()
    }
    
    /// Generates a unique user ID that is cached in user defaults and subsequently returned on future calls.
    public func generateOrRestoreClientId() -> String {
        if let existingId = UserDefaults.standard.string(forKey: Constants.kUserIdKey) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.setValue(newId, forKey: Constants.kUserIdKey)
            return newId
        }
    }
    
    public var shouldShowFeedbackPrompt: Bool {
        get {
            return data.feedbackPromptShouldDisplay
        }
        set {
            data.feedbackPromptShouldDisplay = newValue
        }
    }
    
    public var feedbackUIStrings: Appero.FeedbackUIStrings {
        get {
            return data.feedbackUIStrings
        }
    }
    
    /// Computed property for reading and writing ApperoData to UserDefaults
    private var data: ApperoData {
        get {
            guard let data = UserDefaults.standard.data(forKey: Constants.kApperoData) else {
                // Return default ApperoData if none exists
                return ApperoData(
                    unsentExperiences: [],
                    feedbackPromptShouldDisplay: false,
                    feedbackUIStrings: FeedbackUIStrings(
                        title: Constants.defaultTitle,
                        subtitle: Constants.defaultSubtitle,
                        prompt: Constants.defaultSubtitle
                    ),
                    lastPromptDate: nil
                )
            }
            
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(ApperoData.self, from: data)
            } catch {
                print("[Appero] Error decoding ApperoData: \(error)")
                // Return default ApperoData if decoding fails
                return ApperoData(
                    unsentExperiences: [],
                    feedbackPromptShouldDisplay: false,
                    feedbackUIStrings: FeedbackUIStrings(
                        title: Constants.defaultTitle,
                        subtitle: Constants.defaultSubtitle,
                        prompt: Constants.defaultSubtitle
                    ),
                    lastPromptDate: nil
                )
            }
        }
        set {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(newValue)
                UserDefaults.standard.set(data, forKey: Constants.kApperoData)
            } catch {
                print("[Appero] Error encoding ApperoData: \(error)")
            }
        }
    }
 
    /// Resets all local data (queued experiences, user ID etc).
    public func reset() {
        // Clear all UserDefaults keys
        UserDefaults.standard.removeObject(forKey: Constants.kUserIdKey)
        UserDefaults.standard.removeObject(forKey: Constants.kApperoData)
        UserDefaults.standard.removeObject(forKey: Constants.kUserApperoDictionary)
        
        // Clear instance variables
        self.clientId = nil
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
