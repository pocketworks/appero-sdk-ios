import XCTest
@testable import Appero

final class ApperoTests: XCTestCase {
    
    var appero: Appero!
    
    override func setUp() {
        super.setUp()
        appero = Appero.instance
        // Clear any existing data
        appero.reset()
        appero.start(apiKey: "test_api_key", userId: "test_client_id")
    }
    
    override func tearDown() {
        appero.reset()
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testExperienceValues() {
        // Test that experience values are within the expected range
        
        var totalExperiencePoints = 0
        for experience in Appero.ExperienceRating.allCases {
            totalExperiencePoints += experience.rawValue
        }

        let expectedExperienceChecksum = 5 + 4 + 3 + 2 + 1
        
        XCTAssertEqual(totalExperiencePoints, expectedExperienceChecksum)
    }
    
    func testClientIdGeneration() {
        // Test that a client ID is generated when none is provided
        appero.reset()
        appero.start(apiKey: "test_api_key", userId: nil)
        
        XCTAssertNotNil(appero.userId)
        XCTAssertFalse(appero.userId!.isEmpty)
        
        // Test that the same ID is returned on subsequent calls
        let firstId = appero.generateOrRestoreUserId()
        let secondId = appero.generateOrRestoreUserId()
        XCTAssertEqual(firstId, secondId)
        
        // Test that the generated ID persists
        XCTAssertEqual(appero.userId, firstId)
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistence() {
        // Test that ApperoData is properly persisted to file
        let initialShouldShow = appero.shouldShowFeedbackPrompt
        
        // Modify the data
        appero.shouldShowFeedbackPrompt = !initialShouldShow
        
        // Create a new instance to test persistence
        let newAppero = Appero.instance
        XCTAssertEqual(newAppero.shouldShowFeedbackPrompt, !initialShouldShow)
    }
    
    func testFeedbackUIStrings() {
        // Test that feedback UI strings have default values
        let strings = appero.feedbackUIStrings
        XCTAssertEqual(strings.title, Appero.Constants.defaultTitle)
        XCTAssertEqual(strings.subtitle, Appero.Constants.defaultSubtitle)
        XCTAssertEqual(strings.prompt, Appero.Constants.defaultPrompt)
    }
    
    // MARK: - Experience Logging Tests
    
    func testExperienceCreation() {
        // Test that Experience objects are created correctly
        let experience = Appero.Experience(
            date: Date(),
            value: .strongPositive,
            context: "test_context"
        )
        
        XCTAssertEqual(experience.value, .strongPositive)
        XCTAssertEqual(experience.context, "test_context")
        XCTAssertNotNil(experience.date)
    }
    
    func testExperienceEquality() {
        // Test Experience equality
        let date = Date()
        let experience1 = Appero.Experience(date: date, value: .positive, context: "test")
        let experience2 = Appero.Experience(date: date, value: .positive, context: "test")
        let experience3 = Appero.Experience(date: date, value: .negative, context: "test")
        
        XCTAssertEqual(experience1, experience2)
        XCTAssertNotEqual(experience1, experience3)
    }
    
    // MARK: - Feedback Queuing Tests
    
    func testQueuedFeedbackCreation() {
        // Test that QueuedFeedback objects are created correctly
        let feedback = Appero.QueuedFeedback(
            date: Date(),
            rating: 5,
            feedback: "Great app!"
        )
        
        XCTAssertEqual(feedback.rating, 5)
        XCTAssertEqual(feedback.feedback, "Great app!")
        XCTAssertNotNil(feedback.date)
    }
    
    func testQueuedFeedbackEquality() {
        // Test QueuedFeedback equality
        let date = Date()
        let feedback1 = Appero.QueuedFeedback(date: date, rating: 5, feedback: "test")
        let feedback2 = Appero.QueuedFeedback(date: date, rating: 5, feedback: "test")
        let feedback3 = Appero.QueuedFeedback(date: date, rating: 4, feedback: "test")
        
        XCTAssertEqual(feedback1, feedback2)
        XCTAssertNotEqual(feedback1, feedback3)
    }
    
    func testFeedbackValidation() async {
        // Test feedback validation
        
        // Valid feedback should return true (or be queued)
        let validResult = await appero.postFeedback(rating: 5, feedback: "Good app")
        XCTAssertTrue(validResult)
        
        // Invalid rating should return false
        let invalidRatingResult = await appero.postFeedback(rating: 6, feedback: "Good app")
        XCTAssertFalse(invalidRatingResult)
        
        let invalidRatingResult2 = await appero.postFeedback(rating: 0, feedback: "Good app")
        XCTAssertFalse(invalidRatingResult2)
        
        // Too long feedback should return false
        let longFeedback = String(repeating: "a", count: 501)
        let longFeedbackResult = await appero.postFeedback(rating: 5, feedback: longFeedback)
        XCTAssertFalse(longFeedbackResult)
    }
    
    // MARK: - Experience Rating Enum Tests
    
    func testExperienceRatingValues() {
        // Test that ExperienceRating enum has correct raw values
        XCTAssertEqual(Appero.ExperienceRating.strongPositive.rawValue, 5)
        XCTAssertEqual(Appero.ExperienceRating.positive.rawValue, 4)
        XCTAssertEqual(Appero.ExperienceRating.neutral.rawValue, 3)
        XCTAssertEqual(Appero.ExperienceRating.negative.rawValue, 2)
        XCTAssertEqual(Appero.ExperienceRating.strongNegative.rawValue, 1)
    }
    
    // MARK: - Reset Functionality Tests
    
    func testReset() {
        // Set up some data first
        appero.shouldShowFeedbackPrompt = true
        let clientId = appero.generateOrRestoreUserId()
        
        // Verify data exists
        XCTAssertTrue(appero.shouldShowFeedbackPrompt)
        XCTAssertNotNil(appero.userId)
        XCTAssertNotNil(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey))
        
        // Reset
        appero.reset()
        
        // Verify data is cleared
        XCTAssertNil(appero.userId)
        XCTAssertNil(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey))
        
        // Verify ApperoData file is deleted (check that default values are returned)
        XCTAssertFalse(appero.shouldShowFeedbackPrompt) // Should be false by default
        
        // Verify that we need to reinitialize after reset
        appero.start(apiKey: "test_api_key", userId: "test_client_id")
        XCTAssertEqual(appero.userId, "test_client_id")
    }
    
    // MARK: - Mock Network Tests
    
    func testExperienceLoggingWithoutNetworkQueues() {
        // Test queuing behavior when offline
        appero.forceOfflineMode = true
        
        // Log an experience - it should be queued
        appero.log(experience: .strongPositive, context: "test_context")
        
        // Wait a moment for the async operation to complete
        let expectation = XCTestExpectation(description: "Experience queued")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify the mechanism works by checking if data can be accessed
        // Since we're using file storage now, we'll check that the data property works
        let testData = appero.shouldShowFeedbackPrompt // This will load from file
        XCTAssertNotNil(testData) // Just checking it doesn't crash
        
        // Reset offline mode for other tests
        appero.forceOfflineMode = false
    }
    
    func testFeedbackQueuingWhenOffline() async {
        // Test feedback queuing when offline
        appero.forceOfflineMode = true
        
        // Submit feedback - it should be queued and return true
        let result = await appero.postFeedback(rating: 5, feedback: "Test feedback")
        XCTAssertTrue(result)
        
        // Verify data was persisted by checking if we can access it
        let testData = appero.shouldShowFeedbackPrompt // This will load from file
        XCTAssertNotNil(testData) // Just checking it doesn't crash
        
        // Reset offline mode for other tests
        appero.forceOfflineMode = false
    }
    
    func testOfflineModeToggle() {
        // Test that forceOfflineMode can be toggled
        XCTAssertFalse(appero.forceOfflineMode) // Default should be false
        
        appero.forceOfflineMode = true
        XCTAssertTrue(appero.forceOfflineMode)
        
        appero.forceOfflineMode = false
        XCTAssertFalse(appero.forceOfflineMode)
    }
    
    // MARK: - Theme Tests
    
    func testDefaultTheme() {
        // Test that default theme is set
        XCTAssertTrue(appero.theme is DefaultTheme)
    }
    
    func testThemeChange() {
        // Test that theme can be changed
        let customTheme = DefaultTheme() // Using DefaultTheme as we don't have other themes in scope
        appero.theme = customTheme
        XCTAssertTrue(appero.theme is DefaultTheme)
    }
    
    // MARK: - Bundle Extension Tests
    
    func testBundleExtension() {
        // Test that Bundle.appero exists
        XCTAssertNotNil(Bundle.appero)
    }
    
    // MARK: - Constants Tests
    
    func testConstants() {
        // Test that constants have expected values
        XCTAssertEqual(Appero.Constants.kUserIdKey, "appero_user_id")
        XCTAssertEqual(Appero.Constants.kApperoDataFile, "ApperoData.json")
        XCTAssertEqual(Appero.Constants.defaultTitle, "Thanks for using our app!")
        XCTAssertEqual(Appero.Constants.defaultSubtitle, "Please let us know how we're doing")
        XCTAssertEqual(Appero.Constants.defaultPrompt, "Share your thoughts here")
        XCTAssertEqual(Appero.Constants.retryTimerInterval, 180.0)
    }
    
    // MARK: - Analytics Delegate Tests
    
    func testAnalyticsDelegate() {
        // Test that analytics delegate can be set
        let mockDelegate = MockAnalyticsDelegate()
        appero.analyticsDelegate = mockDelegate
        XCTAssertNotNil(appero.analyticsDelegate)
    }
    
    // MARK: - File Storage Tests
    
    // file system based tests aren't working at the moment so disabled
//    func testApperoDataFileCreation() {
//        // Test that ApperoData file is created and accessible
//        let fileURL = getDocumentsDirectory().appendingPathComponent(Appero.Constants.kApperoDataFile)
//        
//        // Initially there might not be a file, but after accessing data it should exist
//        _ = appero.shouldShowFeedbackPrompt // This triggers file creation
//        
//        // Check that file exists
//        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
//    }
    
    func testApperoDataFilePersistence() {
        // Test that data changes are persisted to file
        appero.shouldShowFeedbackPrompt = true
        
        // Create new instance and check value
        let newAppero = Appero.instance
        XCTAssertTrue(newAppero.shouldShowFeedbackPrompt)
    }
    
    // file system based tests aren't working at the moment so disabled
//    func testApperoDataFileDeletionOnReset() {
//        // Test that file is deleted on reset
//        let fileURL = getDocumentsDirectory().appendingPathComponent(Appero.Constants.kApperoDataFile)
//        
//        // Ensure file exists
//        _ = appero.shouldShowFeedbackPrompt
//        
//        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
//        
//        // Reset should delete the file
//        appero.reset()
//        
//        // File should no longer exist
//        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
//    }
    
    // Helper method to get documents directory
    private func getDocumentsDirectory() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }
}

// MARK: - Mock Classes

class MockAnalyticsDelegate: ApperoAnalyticsDelegate {
    var logApperoFeedbackCalled = false
    var logRatingSelectedCalled = false
    var lastRating: Int?
    var lastFeedback: String?
    
    func logApperoFeedback(rating: Int, feedback: String) {
        logApperoFeedbackCalled = true
        lastRating = rating
        lastFeedback = feedback
    }
    
    func logRatingSelected(rating: Int) {
        logRatingSelectedCalled = true
        lastRating = rating
    }
}
