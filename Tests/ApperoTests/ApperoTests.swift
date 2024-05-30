import XCTest
@testable import Appero

final class ApperoTests: XCTestCase {
    
    override func setUp() {
        Appero.instance.start(apiKey: "api_id", clientId: "client_id")
    }
    
    func testUserId() {
        // given
        Appero.instance.resetExperienceAndPrompt()
        // when
        let testId = "foobar"
        Appero.instance.setUserId("foobar")
        // then
        XCTAssertEqual(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey), testId)
    }
    
    func testResetUser() {
        // given
        Appero.instance.resetExperienceAndPrompt()
        let testId = "foobar"
        Appero.instance.setUserId("foobar")
        // when
        Appero.instance.resetUser()
        // then
        XCTAssertNotEqual(UserDefaults.standard.string(forKey: Appero.Constants.kUserIdKey), testId)
    }
    
    func testDefaultThresholdValue() {
        // given
        Appero.instance.resetExperienceAndPrompt()
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kRatingThreshold)
        // when
        Appero.instance.resetUser()
        // then
        XCTAssertEqual(Appero.instance.ratingThreshold, Appero.Constants.kDefaultRatingThreshold)
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
