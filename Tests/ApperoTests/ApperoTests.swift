import XCTest
@testable import Appero

final class ApperoTests: XCTestCase {
    
    override func setUp() {
        Appero.instance.start(apiKey: "api_id", clientId: "client_id")
    }
    
    override class func tearDown() {
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kUserApperoDictionary)
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kUserIdKey)
    }
    
    func testUserId() {
        // given
        let testId = "foobar"
        // when
        Appero.instance.setUserId("foobar")
        // then
        XCTAssertEqual(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey), testId)
    }
    
    func testResetUser() {
        // given
        let testId = "foobar"
        Appero.instance.setUserId("foobar")
        // when
        Appero.instance.resetUser()
        // then
        XCTAssertNotEqual(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey), testId)
    }
    
    func testDefaultThresholdValue() {
        // given
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kRatingThreshold)
        // when
        Appero.instance.resetUser()
        // then
        XCTAssertEqual(Appero.instance.ratingThreshold, Appero.Constants.kDefaultRatingThreshold)
    }
    
    func testFeedbackGivenPerUser() {
        // given
        let userA = "foo123"
        let userB = "bar456"
        Appero.instance.resetUser()
        Appero.instance.setUserId(userA)
        Appero.instance.hasRatingBeenPrompted = true
        // when
        Appero.instance.resetUser()
        Appero.instance.setUserId(userB)
        Appero.instance.hasRatingBeenPrompted = false
        // then
        XCTAssertEqual(Appero.instance.hasRatingBeenPrompted, false)
    }
    
    func testFeedbackGivenPersistedForUser() {
        // given
        let userA = "foo123"
        let userB = "bar456"
        Appero.instance.resetUser()
        Appero.instance.setUserId(userA)
        Appero.instance.hasRatingBeenPrompted = true
        Appero.instance.resetUser()
        Appero.instance.setUserId(userB)
        Appero.instance.hasRatingBeenPrompted = false
        // when
        Appero.instance.resetUser()
        Appero.instance.setUserId(userA)
        // then
        XCTAssertEqual(Appero.instance.hasRatingBeenPrompted, true)
    }
    
    func testLoggingExperience() {
        // given
        Appero.instance.resetExperienceAndPrompt()
        // when
        Appero.instance.log(experience: .strongPositive)
        Appero.instance.log(experience: .mildPositive)
        Appero.instance.log(experience: .neutral)
        Appero.instance.log(experience: .mildNegative)
        Appero.instance.log(experience: .strongNegative)
        // then
        XCTAssertEqual(Appero.instance.experienceValue, Appero.Experience.strongPositive.rawValue + Appero.Experience.mildPositive.rawValue + Appero.Experience.neutral.rawValue + Appero.Experience.mildNegative.rawValue + Appero.Experience.strongNegative.rawValue)
    }
    
    func testSwitchingUserIds() {
        // given
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kUserApperoDictionary)
        let userA = "foo123"
        let userB = "bar456"
        Appero.instance.setUserId(userA)
        Appero.instance.log(experience: .strongPositive)
        // when
        Appero.instance.resetUser()
        Appero.instance.setUserId(userB)
        Appero.instance.log(experience: .strongNegative)
        
        print(Array(UserDefaults.standard.dictionaryRepresentation()))
        // then
        XCTAssertEqual(Appero.instance.userId, userB)
        XCTAssertEqual(Appero.instance.experienceValue, Appero.Experience.strongNegative.rawValue)
    }
    
    func testRestoringUserId() {
        
        // given
        let userA = "foo123"
        let userB = "bar456"
        
        Appero.instance.setUserId(userA)
        Appero.instance.resetExperienceAndPrompt()
        Appero.instance.log(experience: .strongPositive)
        Appero.instance.resetUser()
        Appero.instance.setUserId(userB)
        Appero.instance.log(experience: .strongNegative)
        // when
        Appero.instance.resetUser()
        Appero.instance.setUserId(userA)
        // then
        XCTAssertEqual(Appero.instance.experienceValue, Appero.Experience.strongPositive.rawValue)
    }
    
    func testLoggingPoints() {
        // given
        Appero.instance.resetExperienceAndPrompt()
        // when
        Appero.instance.log(points: 10)
        Appero.instance.log(points: -5)
        // then
        XCTAssertEqual(Appero.instance.experienceValue, 5)
    }
    
    func testOverThresholdTriggered() {
        // given
        Appero.instance.resetExperienceAndPrompt()
        Appero.instance.ratingThreshold = 5
        // when
        Appero.instance.log(points: 10)
        // then
        XCTAssertEqual(Appero.instance.shouldShowAppero, true)
    }
    
    func testUnderThresholdNotTriggered() {
        // given
        Appero.instance.resetExperienceAndPrompt()
        Appero.instance.ratingThreshold = 5
        // when
        Appero.instance.log(points: 2)
        // then
        XCTAssertEqual(Appero.instance.shouldShowAppero, false)
    }
}
