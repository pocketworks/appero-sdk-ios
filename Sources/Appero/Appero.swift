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
import Network

public class Appero {
    
    struct Constants {
        static let kUserIdKey = "appero_user_id"
        static let kApperoData = "appero_unsent_experiences"
        static let kUserApperoDictionary = "appero_data"
        
        static let defaultTitle = "Thanks for using our app!"
        static let defaultSubtitle = "Please let us know how we're doing"
        static let defaultPrompt = "Share your thoughts here"
        
        // Retry timer configuration
        static let retryTimerInterval: TimeInterval = 180.0 // 3 minutes
    }
    
    public enum ExperienceRating: Int, Codable {
        case strongPositive = 5
        case positive = 4
        case neutral = 3
        case negative = 2
        case strongNegative = 1
    }
    
    public struct Experience: Codable, Equatable {
        let date: Date
        let value: ExperienceRating
        let context: String?
        
        static public func == (lhs: Experience, rhs: Experience) -> Bool {
            lhs.date == rhs.date && lhs.value == rhs.value && lhs.context == rhs.context
        }
    }
    
    public struct QueuedFeedback: Codable, Equatable {
        let date: Date
        let rating: Int
        let feedback: String?
        
        static public func == (lhs: QueuedFeedback, rhs: QueuedFeedback) -> Bool {
            lhs.date == rhs.date && lhs.rating == rhs.rating && lhs.feedback == rhs.feedback
        }
    }
    
    private struct ApperoData: Codable {
        /// stores any experiences we've been unable to log with the backend due to network issues
        var unsentExperiences: [Experience]
        /// stores any feedback we've been unable to submit with the backend due to network issues
        var unsentFeedback: [QueuedFeedback]
        /// set to true when we're notified by the backend that the feedback UI is ready for display, can be used to defer display
        var feedbackPromptShouldDisplay: Bool
        /// caches the text for the feedback UI for when the prompt is deferred
        var feedbackUIStrings: FeedbackUIStrings
        /// the last date that the rating prompt was shown to the user, can be used to reprompt at a later date if the user declines initially
        var lastPromptDate: Date?
        /// flow type to show
        var flowType: Appero.FlowType
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
    
    // Network monitoring and retry timer
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "appero.network.monitor")
    private var retryTimer: Timer?
    private var isConnected = true
    
    /// For testing purposes - when set to true, forces offline queuing behavior regardless of actual network status
    public var forceOfflineMode = false
    
    private init() {
        setupNetworkMonitoring()
        startRetryTimer()
    }
    
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
                    unsentFeedback: [],
                    feedbackPromptShouldDisplay: false,
                    feedbackUIStrings: FeedbackUIStrings(
                        title: Constants.defaultTitle,
                        subtitle: Constants.defaultSubtitle,
                        prompt: Constants.defaultPrompt
                    ),
                    lastPromptDate: nil,
                    flowType: .neutral
                )
            }
            
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(ApperoData.self, from: data)
            } catch {
                print("[Appero] Error decoding local Appero data: \(error)")
                // Return default ApperoData if decoding fails
                return ApperoData(
                    unsentExperiences: [],
                    unsentFeedback: [],
                    feedbackPromptShouldDisplay: false,
                    feedbackUIStrings: FeedbackUIStrings(
                        title: Constants.defaultTitle,
                        subtitle: Constants.defaultSubtitle,
                        prompt: Constants.defaultPrompt
                    ),
                    lastPromptDate: nil,
                    flowType: .neutral
                )
            }
        }
        set {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(newValue)
                UserDefaults.standard.set(data, forKey: Constants.kApperoData)
            } catch {
                print("[Appero] Error encoding local Appero data: \(error)")
            }
        }
    }
 

    // MARK: - Network Monitoring
    
    /// Sets up network path monitoring to track connectivity status
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                
                guard let self = self else {
                    return
                }
                
                self.isConnected = path.status == .satisfied && !self.forceOfflineMode ?? false
                
                // If we regain connectivity and have unsent experiences, try to send them immediately
                if self.isConnected == true {
                    Task {
                        await self.processUnsentExperiences()
                        await self.processUnsentFeedback()
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    /// Starts the retry timer that periodically attempts to send queued experiences
    private func startRetryTimer() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: Constants.retryTimerInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.processUnsentExperiences()
                await self?.processUnsentFeedback()
            }
        }
    }
    
    /// Stops the retry timer (useful for cleanup)
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    // MARK: - Experience Logging
    
    /// Logs a user experience using the ExperienceRating enum
    /// - Parameters:
    ///   - experience: The experience rating
    ///   - context: Optional context string to provide additional information
    public func log(experience: ExperienceRating, context: String? = nil) {
        let experienceRecord = Experience(date: Date(), value: experience, context: context)
        
        Task {
            await postExperience(experienceRecord)
        }
    }
    
    /// Adds an experience to the unsent queue
    /// - Parameter experience: The experience to queue
    private func queueExperience(_ experience: Experience) {
        var currentData = data
        currentData.unsentExperiences.append(experience)
        data = currentData
        
        print("[Appero] Queued experience for retry. Total queued: \(currentData.unsentExperiences.count)")
    }
    
    /// Processes all queued experiences, attempting to send them to the backend
    private func processUnsentExperiences() async {
        guard isConnected && !forceOfflineMode else {
            print("[Appero] No connectivity - skipping unsent experience processing")
            return
        }
        
        var currentData = data
        
        guard currentData.unsentExperiences.isEmpty == false else {
            return // No experiences to process
        }
        
        print("[Appero] Processing \(currentData.unsentExperiences.count) unsent experiences")
        
        var successfullyProcessed: [Appero.Experience] = []
        
        for (index, experience) in currentData.unsentExperiences.enumerated() {
            guard let apiKey = apiKey, let clientId = clientId else {
                print("[Appero] Cannot process experience - API key or client ID not set")
                continue
            }
            
            do {
                let experienceData: [String: Any] = await [
                    "client_id": clientId,
                    "date": experience.date.ISO8601Format(),
                    "value": experience.value.rawValue,
                    "context": experience.context ?? "",
                    "source": UIDevice.current.systemName,
                    "build_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                ]
                
                let data = try await ApperoAPIClient.sendRequest(
                    endPoint: "experiences",
                    fields: experienceData,
                    method: .post,
                    authorization: apiKey
                )
                
                successfullyProcessed.append(experience)
                handleExperienceResponse(response: try JSONDecoder().decode(ExperienceResponse.self, from: data))
                
            } catch {
                print("[Appero] Failed to send queued experience \(index + 1)/\(currentData.unsentExperiences.count): \(error)")
            }
            
        }
        
        currentData.unsentExperiences.removeAll { experience in
            successfullyProcessed.contains(experience)
        }
        
        data = currentData
    }
    
    /// Adds feedback to the unsent queue
    /// - Parameter feedback: The feedback to queue
    private func queueFeedback(_ feedback: QueuedFeedback) {
        var currentData = data
        currentData.unsentFeedback.append(feedback)
        data = currentData
        
        print("[Appero] Queued feedback for retry. Total queued: \(currentData.unsentFeedback.count)")
    }
    
    /// Processes all queued feedback, attempting to send them to the backend
    private func processUnsentFeedback() async {
        guard isConnected && !forceOfflineMode else {
            print("[Appero] No connectivity - skipping unsent feedback processing")
            return
        }
        
        var currentData = data
        
        guard currentData.unsentFeedback.isEmpty == false else {
            return // No feedback to process
        }
        
        print("[Appero] Processing \(currentData.unsentFeedback.count) unsent feedback items")
        
        var successfullyProcessed: [QueuedFeedback] = []
        
        for (index, feedback) in currentData.unsentFeedback.enumerated() {
            guard let apiKey = apiKey else {
                print("[Appero] Cannot process feedback - API key not set")
                continue
            }
            
            do {
                try await ApperoAPIClient.sendRequest(
                    endPoint: "feedback",
                    fields: [
                        "sent_at": feedback.date.ISO8601Format(),
                        "feedback": feedback.feedback ?? "",
                        "source" : UIDevice.current.systemName,
                        "build_version" : Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "n/a",
                        "rating": String(feedback.rating)
                    ],
                    method: .post,
                    authorization: apiKey
                )
                
                successfullyProcessed.append(feedback)
                print("[Appero] Successfully sent queued feedback \(index + 1)/\(currentData.unsentFeedback.count)")
                
            } catch {
                print("[Appero] Failed to send queued feedback \(index + 1)/\(currentData.unsentFeedback.count): \(error)")
            }
        }
        
        // Remove successfully processed feedback from the queue
        currentData.unsentFeedback.removeAll { feedback in
            successfullyProcessed.contains(feedback)
        }
        
        data = currentData
    }

    /// Sends an experience to the backend, queuing it if the request fails
    /// - Parameter experience: The experience to send
    private func postExperience(_ experience: Experience) async {
        guard let apiKey = apiKey, let clientId = clientId else {
            print("[Appero] Cannot send experience - API key or client ID not set")
            queueExperience(experience)
            return
        }
        
        // Check basic connectivity before attempting to send
        guard isConnected && !forceOfflineMode else {
            print("[Appero] No network connectivity - queuing experience")
            queueExperience(experience)
            return
        }
        
        do {
            let experienceData: [String: Any] = [
                "client_id": clientId,
                "date": experience.date.ISO8601Format(),
                "value": experience.value.rawValue,
                "context": experience.context ?? "",
                "source": await UIDevice.current.systemName,
                "build_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            ]
            
            let data = try await ApperoAPIClient.sendRequest(
                endPoint: "experience",
                fields: experienceData,
                method: .post,
                authorization: apiKey
            )
            
            handleExperienceResponse(response: try JSONDecoder().decode(ExperienceResponse.self, from: data))
            
        } catch let error as ApperoAPIError {
            print("[Appero] Failed to send experience - queuing for retry")
            
            switch error {
            case .networkError(statusCode: let code):
                print("[Appero] Network error \(code)")
            case .noData:
                print("[Appero] No data received")
            case .noResponse:
                print("[Appero] No response received")
            }
            
            queueExperience(experience)
            
        } catch {
            print("[Appero] Unknown error sending experience - queuing for retry: \(error)")
            queueExperience(experience)
        }
    }
    
    /// Sends feedback to the backend, queuing it if the request fails
    /// - Parameter feedback: The feedback to send
    private func postFeedback(_ feedback: QueuedFeedback) async {
        guard let apiKey = apiKey, let clientId = clientId else {
            print("[Appero] Cannot send feedback - API key or client ID not set")
            queueFeedback(feedback)
            return
        }
        
        // Check basic connectivity before attempting to send
        guard isConnected && !forceOfflineMode else {
            print("[Appero] No network connectivity - queuing feedback")
            queueFeedback(feedback)
            return
        }
        
        do {
            let feedbackData: [String: Any] = [
                "client_id": clientId,
                "date": feedback.date.ISO8601Format(),
                "rating": String(feedback.rating),
                "feedback": feedback.feedback ?? "",
                "source": await UIDevice.current.systemName,
                "build_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            ]
            
            let data = try await ApperoAPIClient.sendRequest(
                endPoint: "feedback",
                fields: feedbackData,
                method: .post,
                authorization: apiKey
            )
            
        } catch let error as ApperoAPIError {
            print("[Appero] Failed to send feedback - queuing for retry")
            
            switch error {
                case .networkError(statusCode: let code):
                    print("[Appero] Network error \(code)")
                case .noData:
                    print("[Appero] No data received")
                case .noResponse:
                    print("[Appero] No response received")
            }
            
            queueFeedback(feedback)
            
        } catch {
            print("[Appero] Unknown error sending feedback - queuing for retry: \(error)")
            queueFeedback(feedback)
        }
    }
    
    private func handleExperienceResponse(response: ExperienceResponse) {
        
        var currentData = data
        
        // We won't let subsequent responses flip the value here if we're currently due to show the UI
        if currentData.feedbackPromptShouldDisplay == false {
            currentData.feedbackPromptShouldDisplay = response.shouldShowFeedbackUI
        }
        currentData.feedbackUIStrings = response.feedbackUI ?? FeedbackUIStrings(
            title: Constants.defaultTitle,
            subtitle: Constants.defaultSubtitle,
            prompt: Constants.defaultPrompt
        )
        currentData.flowType = response.flowType
        
        data = currentData
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
        
        let queuedFeedback = QueuedFeedback(date: Date(), rating: rating, feedback: feedback)
        
        // Check basic connectivity before attempting to send
        guard isConnected && !forceOfflineMode else {
            print("[Appero] No network connectivity - queuing feedback")
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
        
        guard let apiKey = apiKey else {
            print("[Appero] Cannot send feedback - API key not set")
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
        
        do {
            try await ApperoAPIClient.sendRequest(
                endPoint: "feedback",
                fields: [
                    "sent_at": queuedFeedback.date.ISO8601Format(),
                    "feedback": queuedFeedback.feedback ?? "",
                    "source" : UIDevice.current.systemName,
                    "build_version" : Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "n/a",
                    "rating": String(queuedFeedback.rating)
                ],
                method: .post,
                authorization: apiKey
            )
            return true
        }
        catch let error as ApperoAPIError {
            print("[Appero] Error submitting feedback - queuing for retry")
            
            switch error {
                case .networkError(statusCode: let code):
                    print("[Appero] Network error \(code)")
                case .noData:
                    print("[Appero] No data")
                case .noResponse:
                    print("[Appero] No response")
            }
            
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
        catch _ {
            print("[Appero] Unknown error submitting feedback - queuing for retry")
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
    }
    
    // MARK: - Miscellaneous Functions
    
    /// Resets all local data (queued experiences, user ID etc). You might use this when the user logs out or when testing your integration, however in typical use it's not required.
    public func reset() {
        // Clear all UserDefaults keys
        UserDefaults.standard.removeObject(forKey: Constants.kUserIdKey)
        UserDefaults.standard.removeObject(forKey: Constants.kApperoData)
        UserDefaults.standard.removeObject(forKey: Constants.kUserApperoDictionary)
        
        // Clear instance variables
        self.clientId = nil
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
    
    deinit {
        stopRetryTimer()
        networkMonitor.cancel()
    }
}

extension Bundle {
    public static var appero: Bundle = .module
}
