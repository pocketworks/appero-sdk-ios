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
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@objc public class Appero: NSObject, ObservableObject {
    
    struct Constants {
        static let kUserIdKey = "appero_user_id"
        static let kApperoDataFile = "ApperoData.json"
        
        static let kFeedbackMaxLength = 240
        
        static let defaultTitle = String(localized: "DefaultTitle", bundle: .appero)
        static let defaultSubtitle = String(localized: "DefaultSubtitle", bundle: .appero)
        static let defaultPrompt = String(localized: "DefaultPrompt", bundle: .appero)
        
        // Retry timer configuration
        static let retryTimerInterval: TimeInterval = 180.0 // 3 minutes
    }
    
    /// Notification that is triggered when the feedback prompt should be shown, recommended for use in UIKit based apps
    public static let kApperoFeedbackPromptNotification = Notification.Name("kApperoFeedbackPromptNotification")
    
    @objc public enum ExperienceRating: Int, CaseIterable, Codable {
        case strongPositive = 5
        case positive = 4
        case neutral = 3
        case negative = 2
        case strongNegative = 1
    }
    
    internal struct Experience: Codable, Equatable {
        let date: Date
        let value: ExperienceRating
        let context: String?
        
        static public func == (lhs: Experience, rhs: Experience) -> Bool {
            lhs.date == rhs.date && lhs.value == rhs.value && lhs.context == rhs.context
        }
    }
    
    internal struct QueuedFeedback: Codable, Equatable {
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
    
    public enum FlowType: String, Codable {
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
    @objc public static let instance = Appero()

    // instance vars
    private var apiKey: String?
    
    /// an optional string to identify your user (uuid from your backend, account number, email address etc.)
    @objc public var userId: String?
    
    /// set to true to enable debug logging to the console
    @objc public var isDebug = false
    
    /// Specifies a delegate to handle analytics
    public var analyticsDelegate: ApperoAnalyticsDelegate?
    
    /// Specifies a theme to use for the Appero UI
    public var theme: ApperoTheme = DefaultTheme()
    
    // Network monitoring and retry timer
    private let networkMonitor = NWPathMonitor()
    // TODO: move to async stream when we can drop iOS 16 support.
    private let networkQueue = DispatchQueue(label: "appero.network.monitor")
    private let dataQueue = DispatchQueue(label: "appero.data.queue")
    private var retryTimer: Timer?
    private var isConnected = true
    
    /// For testing purposes - when set to true, forces offline queuing behavior regardless of actual network status
    @objc public var forceOfflineMode = false
    
    private override init() {
        super.init()
        setupNetworkMonitoring()
        startRetryTimer()
    }
    
    /// Initialise the Appero SDK. This should be called early on in your app's lifecycle.
    /// - Parameters:
    ///   - apiKey: your API key
    ///   - userId: optional user identifier, if none provided a UUID will be generated automatically
    @objc public func start(apiKey: String, userId: String?) {
        self.apiKey = apiKey
        self.userId = userId ?? generateOrRestoreUserId()
    }
    
    /// Generates a unique user ID that is cached in user defaults and subsequently returned on future calls.
    @objc public func generateOrRestoreUserId() -> String {
        if let existingId = UserDefaults.standard.string(forKey: Constants.kUserIdKey) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.setValue(newId, forKey: Constants.kUserIdKey)
            return newId
        }
    }
    
    /// Indicates whether the feedback UI should be shown in your app
    @objc @Published public var shouldShowFeedbackPrompt: Bool = false
    
    public var feedbackUIStrings: Appero.FeedbackUIStrings {
        get {
            return data.feedbackUIStrings
        }
    }
    
    public var flowType: Appero.FlowType {
        get {
            return data.flowType
        }
    }
    
    /// Computed property for reading and writing ApperoData to a JSON file
    private var data: ApperoData {
        get {
            // Try to load from file
            if let savedData = dataQueue.sync(execute: { loadApperoData() }) {
                return savedData
            }
            
            // Return default ApperoData if none exists
            return defaultApperoData()
        }
        set {
            dataQueue.sync {
                saveApperoData(newValue)
            }
            Task { @MainActor in
                shouldShowFeedbackPrompt = newValue.feedbackPromptShouldDisplay
            }
        }
    }
    
    /// Returns a default-initialized ApperoData value
    private func defaultApperoData() -> ApperoData {
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
    
    /// Atomically reads current data snapshot from disk
    private func readDataSnapshot() -> ApperoData {
        return dataQueue.sync {
            if let saved = loadApperoData() {
                return saved
            } else {
                return defaultApperoData()
            }
        }
    }
    
    /// Serializes a mutation of the file-backed state to avoid read-modify-write races
    private func mutateData(_ mutate: (inout ApperoData) -> Void) {
        dataQueue.sync {
            var current = loadApperoData() ?? defaultApperoData()
            mutate(&current)
            saveApperoData(current)
            Task { @MainActor in
                shouldShowFeedbackPrompt = current.feedbackPromptShouldDisplay
            }
        }
    }
    
    /// Gets the file URL for the ApperoData JSON file in the documents directory
    private func getApperoDataFileURL() -> URL {
        let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let apperoDirectory = applicationSupportDirectory.appendingPathComponent("Appero", isDirectory: true)
        
        if FileManager.default.fileExists(atPath: apperoDirectory.path) == false {
            do {
                try FileManager.default.createDirectory(at: apperoDirectory, withIntermediateDirectories: true)
            } catch {
                ApperoDebug.log("Error creating Application Support directory: \(error)")
            }
        }
        
        // Exclude from iCloud backups
        var directoryURL = apperoDirectory
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try directoryURL.setResourceValues(resourceValues)
        } catch {
            ApperoDebug.log("Failed to set do-not-backup attribute: \(error)")
        }
        
        return apperoDirectory.appendingPathComponent(Constants.kApperoDataFile)
    }
    
    /// Saves ApperoData to a JSON file
    private func saveApperoData(_ apperoData: ApperoData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(apperoData)
            let fileURL = getApperoDataFileURL()
            try data.write(to: fileURL)
        } catch {
            ApperoDebug.log("Error saving ApperoData to file: \(error)")
        }
    }
    
    /// Call this dismiss the feedback prompt and prevent it reappearing until we next get notified by the server to show it
    @objc public func dismissApperoPrompt() {
        shouldShowFeedbackPrompt = false
        mutateData { data in
            data.feedbackPromptShouldDisplay = false
        }
    }
    
    /// Loads ApperoData from a JSON file
    private func loadApperoData() -> ApperoData? {
        let fileURL = getApperoDataFileURL()
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let apperoData = try decoder.decode(ApperoData.self, from: data)
            return apperoData
        } catch {
            ApperoDebug.log("Error loading ApperoData from file: \(error)")
            return nil
        }
    }
 

    // MARK: - Network Monitoring
    
    /// Sets up network path monitoring to track connectivity status
    private func setupNetworkMonitoring() {
        
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else {
                    return
                }
                
                self.isConnected = path.status == .satisfied && !self.forceOfflineMode
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    /// Starts the retry timer that periodically attempts to send queued experiences
    private func startRetryTimer() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: Constants.retryTimerInterval, repeats: true) { [weak self] _ in
            Task {
                ApperoDebug.log("Checking for queued experiences/feedback to send")
                await self?.processUnsentExperiences()
                await self?.processUnsentFeedback()
            }
        }
        retryTimer?.fire() // trigger an initial fire on launch to clear out the queue
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
    @objc public func log(experience: ExperienceRating, context: String? = nil) {
        let experienceRecord = Experience(date: Date(), value: experience, context: context)
        
        Task {
            await postExperience(experienceRecord)
        }
    }
    
    /// Adds an experience to the unsent queue
    /// - Parameter experience: The experience to queue
    private func queueExperience(_ experience: Experience) {
        mutateData { data in
            data.unsentExperiences.append(experience)
        }
        ApperoDebug.log("Queued experience for retry.")
    }
    
    /// Processes all queued experiences, attempting to send them to the backend
    private func processUnsentExperiences() async {
        guard isConnected && !forceOfflineMode else {
            ApperoDebug.log("No connectivity - skipping unsent experience processing")
            return
        }
        
        let currentData = readDataSnapshot()
        
        guard currentData.unsentExperiences.isEmpty == false else {
            ApperoDebug.log("No unsent experiences found")
            return // No experiences to process
        }
        
        ApperoDebug.log("Processing \(currentData.unsentExperiences.count) unsent experiences")
        
        var successfullyProcessed: [Appero.Experience] = []
        
        for (index, experience) in currentData.unsentExperiences.enumerated() {
            guard let apiKey = apiKey, let clientId = userId else {
                ApperoDebug.log("Cannot process experience - API key or client ID not set")
                continue
            }
            
            do {
                let systemName = await MainActor.run { UIDevice.current.systemName }
                let experienceData: [String: Any] = [
                    "user_id": clientId,
                    "sent_at": experience.date.ISO8601Format(),
                    "value": experience.value.rawValue,
                    "context": experience.context ?? "",
                    "source": systemName,
                    "build_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                ]
                
                let response = try await ApperoAPIClient.sendRequest(
                    endPoint: "experiences",
                    fields: experienceData,
                    method: .post,
                    authorization: apiKey
                )
                
                ApperoDebug.log("Experience posted successfully")
                
                successfullyProcessed.append(experience)
                handleExperienceResponse(response: try JSONDecoder().decode(ExperienceResponse.self, from: response))
                
            } catch {
                ApperoDebug.log("Failed to send queued experience \(index + 1)/\(currentData.unsentExperiences.count): \(error)")
            }
            
        }
        
        mutateData { data in
            data.unsentExperiences.removeAll { experience in
                successfullyProcessed.contains(experience)
            }
        }
    }
    
    /// Adds feedback to the unsent queue
    /// - Parameter feedback: The feedback to queue
    private func queueFeedback(_ feedback: QueuedFeedback) {
        mutateData { data in
            data.unsentFeedback.append(feedback)
        }
        ApperoDebug.log("Queued feedback for retry.")
    }
    
    /// Processes all queued feedback, attempting to send them to the backend
    private func processUnsentFeedback() async {
        guard isConnected && !forceOfflineMode else {
            ApperoDebug.log("No connectivity - skipping unsent feedback processing")
            return
        }
        
        let currentData = readDataSnapshot()
        
        guard currentData.unsentFeedback.isEmpty == false else {
            ApperoDebug.log("No unsent feedback found")
            return // No feedback to process
        }
        
        ApperoDebug.log("Processing \(currentData.unsentFeedback.count) unsent feedback items")
        
        var successfullyProcessed: [QueuedFeedback] = []
        
        for (index, feedback) in currentData.unsentFeedback.enumerated() {
            guard let apiKey = apiKey else {
                ApperoDebug.log("Cannot process feedback - API key not set")
                return
            }
            guard let userId = userId else {
                ApperoDebug.log("Cannot process feedback - user ID key not set")
                return
            }
            
            do {
                let systemName = await MainActor.run { UIDevice.current.systemName }
                try await ApperoAPIClient.sendRequest(
                    endPoint: "feedback",
                    fields: [
                        "user_id": userId,
                        "sent_at": feedback.date.ISO8601Format(),
                        "feedback": feedback.feedback ?? "",
                        "source" : systemName,
                        "build_version" : Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "n/a",
                        "rating": String(feedback.rating)
                    ],
                    method: .post,
                    authorization: apiKey                    
                )
                ApperoDebug.log("Feedback posted successfully")
                
                successfullyProcessed.append(feedback)
                ApperoDebug.log("Successfully sent queued feedback \(index + 1)/\(currentData.unsentFeedback.count)")
                
            } catch {
                ApperoDebug.log("Failed to send queued feedback \(index + 1)/\(currentData.unsentFeedback.count): \(error)")
            }
        }
        
        // Remove successfully processed feedback from the queue
        mutateData { data in
            data.unsentFeedback.removeAll { feedback in
                successfullyProcessed.contains(feedback)
            }
        }
    }

    /// Sends an experience to the backend, queuing it if the request fails
    /// - Parameter experience: The experience to send
    private func postExperience(_ experience: Experience) async {
        guard let apiKey = apiKey, let clientId = userId else {
            ApperoDebug.log("Cannot send experience - API key or client ID not set")
            queueExperience(experience)
            return
        }
        
        // Check basic connectivity before attempting to send
        guard isConnected && !forceOfflineMode else {
            ApperoDebug.log("No network connectivity - queuing experience")
            queueExperience(experience)
            return
        }
        
        do {
            let systemName = await MainActor.run { UIDevice.current.systemName }
            let experienceData: [String: Any] = [
                "user_id": clientId,
                "sent_at": experience.date.ISO8601Format(),
                "value": experience.value.rawValue,
                "context": experience.context ?? "",
                "source": systemName,
                "build_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            ]
            
            let data = try await ApperoAPIClient.sendRequest(
                endPoint: "experiences",
                fields: experienceData,
                method: .post,
                authorization: apiKey
            )
            
            handleExperienceResponse(response: try JSONDecoder().decode(ExperienceResponse.self, from: data))
            ApperoDebug.log("✅ Experience logged")
            
        } catch let error as ApperoAPIError {
            ApperoDebug.log("Failed to send experience - queuing for retry")
            
            switch error {
                case .serverMessage(response: let response):
                    ApperoDebug.log(response?.description() ?? "Unknown")
                case .networkError(statusCode: let code):
                    ApperoDebug.log("Network error \(code)")
                case .noData:
                    ApperoDebug.log("No data received")
                case .noResponse:
                    ApperoDebug.log("No response received")
            }
            
            queueExperience(experience)
            
        } catch {
            ApperoDebug.log("Unknown error sending experience - queuing for retry: \(error)")
            queueExperience(experience)
        }
    }
    
    private func handleExperienceResponse(response: ExperienceResponse) {
        
        let snapshot = readDataSnapshot()
        
        // We won't let subsequent responses flip the value here if we're currently due to show the UI
        if snapshot.feedbackPromptShouldDisplay == false && response.shouldShowFeedbackUI {
            NotificationCenter.default.post(name: Appero.kApperoFeedbackPromptNotification, object: nil)
        }
        
        mutateData { data in
            if data.feedbackPromptShouldDisplay == false {
                data.feedbackPromptShouldDisplay = response.shouldShowFeedbackUI
            }
            data.feedbackUIStrings = response.feedbackUI ?? FeedbackUIStrings(
                title: Constants.defaultTitle,
                subtitle: Constants.defaultSubtitle,
                prompt: Constants.defaultPrompt
            )
            data.flowType = response.flowType
        }
    }
    
    // MARK: - API Calls
    
    /// Post user feedback to Appero.
    /// - Parameters:
    ///   - rating: A value between 1 and 5 inclusive.
    ///   - feedback: Optional feedback supplied by the user. Maximum length of 240 characters
    /// - Returns: Boolean indicating if the feedback supplied passed validation and successfully uploaded. On false, no data was sent to the API and validation possibly failed
    @discardableResult public func postFeedback(rating: Int, feedback: String?) async -> Bool {
        guard 1...5 ~= rating, (feedback?.count ?? 0) <= Appero.Constants.kFeedbackMaxLength else {
            return false
        }
        
        let queuedFeedback = QueuedFeedback(date: Date(), rating: rating, feedback: feedback)
        
        // Check basic connectivity before attempting to send
        guard isConnected && !forceOfflineMode else {
            ApperoDebug.log("No network connectivity - queuing feedback")
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
        
        guard let apiKey = apiKey else {
            ApperoDebug.log("Cannot send feedback - API key not set")
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
        
        guard let userId = userId else {
            ApperoDebug.log("Cannot send feedback - user ID not set")
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
        
        do {
            let systemName = await MainActor.run { UIDevice.current.systemName }
            try await ApperoAPIClient.sendRequest(
                endPoint: "feedback",
                fields: [
                    "user_id": userId,
                    "sent_at": queuedFeedback.date.ISO8601Format(),
                    "feedback": queuedFeedback.feedback ?? "",
                    "source" : systemName,
                    "build_version" : Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "n/a",
                    "rating": String(queuedFeedback.rating)
                ],
                method: .post,
                authorization: apiKey
            )
            ApperoDebug.log("✅ Appero Feedback sent")
            return true
        }
        catch let error as ApperoAPIError {
            ApperoDebug.log("Error submitting feedback - queuing for retry")
            
            switch error {
                case .serverMessage(response: let response):
                    ApperoDebug.log(response?.description() ?? "Unknown")
                case .networkError(statusCode: let code):
                    ApperoDebug.log("Network error \(code)")
                case .noData:
                    ApperoDebug.log("No data")
                case .noResponse:
                    ApperoDebug.log("No response")
            }
            
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
        catch _ {
            ApperoDebug.log("Unknown error submitting feedback - queuing for retry")
            queueFeedback(queuedFeedback)
            return true // Return true since we've queued it successfully
        }
    }
    
    // MARK: - Miscellaneous Functions
    
    /// Resets all local data (queued experiences, user ID etc). You might use this when the user logs out or when testing your integration, however in typical use it's not required.
    @objc public func reset() {
        // Clear user ID from UserDefaults
        UserDefaults.standard.removeObject(forKey: Constants.kUserIdKey)
        
        // Delete the ApperoData file
        let fileURL = getApperoDataFileURL()
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                ApperoDebug.log("Deleted ApperoData file successfully")
            }
        } catch {
            ApperoDebug.log("Error deleting ApperoData file: \(error)")
        }
        
        shouldShowFeedbackPrompt = false
        data = defaultApperoData()
        
        // Clear instance variables
        self.userId = nil
    }
    
    deinit {
        stopRetryTimer()
        networkMonitor.cancel()
    }
}

extension Bundle {
    public static var appero: Bundle = .module
}
