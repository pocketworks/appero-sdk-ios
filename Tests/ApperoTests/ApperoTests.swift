import XCTest
@testable import Appero

final class ApperoTests: XCTestCase {
    
    var appero: Appero!
    
    override func setUp() {
        super.setUp()
        appero = Appero.instance
        // Clear any existing data
        appero.reset()
        appero.start(apiKey: "test_api_key", clientId: "test_client_id")
    }
    
    override func tearDown() {
        appero.reset()
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testClientIdGeneration() {
        // Test that a client ID is generated when none is provided
        appero.reset()
        appero.start(apiKey: "test_api_key", clientId: nil)
        
        XCTAssertNotNil(appero.clientId)
        XCTAssertFalse(appero.clientId!.isEmpty)
        
        // Test that the same ID is returned on subsequent calls
        let firstId = appero.generateOrRestoreClientId()
        let secondId = appero.generateOrRestoreClientId()
        XCTAssertEqual(firstId, secondId)
        
        // Test that the generated ID persists
        XCTAssertEqual(appero.clientId, firstId)
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistence() {
        // Test that ApperoData is properly persisted to UserDefaults
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
        let clientId = appero.generateOrRestoreClientId()
        
        // Verify data exists
        XCTAssertTrue(appero.shouldShowFeedbackPrompt)
        XCTAssertNotNil(appero.clientId)
        XCTAssertNotNil(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey))
        
        // Reset
        appero.reset()
        
        // Verify data is cleared
        XCTAssertNil(appero.clientId)
        XCTAssertNil(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey))
        XCTAssertNil(UserDefaults.standard.data(forKey: Appero.Constants.kApperoData))
        
        // Verify that we need to reinitialize after reset
        appero.start(apiKey: "test_api_key", clientId: "test_client_id")
        XCTAssertEqual(appero.clientId, "test_client_id")
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
        
        // Verify the mechanism works by checking the data structure exists
        let hasData = UserDefaults.standard.data(forKey: Appero.Constants.kApperoData) != nil
        XCTAssertTrue(hasData)
        
        // Reset offline mode for other tests
        appero.forceOfflineMode = false
    }
    
    func testFeedbackQueuingWhenOffline() async {
        // Test feedback queuing when offline
        appero.forceOfflineMode = true
        
        // Submit feedback - it should be queued and return true
        let result = await appero.postFeedback(rating: 5, feedback: "Test feedback")
        XCTAssertTrue(result)
        
        // Verify data was persisted
        let hasData = UserDefaults.standard.data(forKey: Appero.Constants.kApperoData) != nil
        XCTAssertTrue(hasData)
        
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
        XCTAssertEqual(Appero.Constants.kApperoData, "appero_unsent_experiences")
        XCTAssertEqual(Appero.Constants.kUserApperoDictionary, "appero_data")
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
