import XCTest
@testable import Appero

final class ApperoFrustrationTests: XCTestCase {
    
    // MARK: - Test Constants
    private struct TestFrustrationIdentifiers {
        static let loginFailed = "Login Failed"
        static let networkError = "Network Error"
        static let appCrash = "App Crash"
        static let slowLoading = "Slow Loading"
    }
    
    override func setUp() {
        super.setUp()
        Appero.instance.start(apiKey: "api_id", clientId: "client_id")
        Appero.instance.resetUser()
        Appero.instance.resetAllFrustrations()
    }
    
    override func tearDown() {
        super.tearDown()
        Appero.instance.resetAllFrustrations()
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kUserIdKey)
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kFrustrationDictionary)
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kFrustrationPromptedDictionary)
    }
    
    func testRegisterFrustration() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.loginFailed, threshold: 3)
        
        // when
        Appero.instance.register(frustration: frustration)
        
        // then
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrationIdentifiers.loginFailed)
        XCTAssertNotNil(retrievedFrustration)
        XCTAssertEqual(retrievedFrustration?.identifier, TestFrustrationIdentifiers.loginFailed)
        XCTAssertEqual(retrievedFrustration?.threshold, 3)
        XCTAssertEqual(retrievedFrustration?.events, 0)
    }
    
    func testLogFrustration() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.networkError, threshold: 2)
        Appero.instance.register(frustration: frustration)

        
        // when
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.log(frustration: frustration.identifier)
        
        // then
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrationIdentifiers.networkError)
        XCTAssertEqual(retrievedFrustration?.events, 2)
    }
    
    func testLogNonExistentFrustration() {
        // given
        let frustration = Appero.Frustration(identifier: "Non Existent", threshold: 1)
        
        // when
        Appero.instance.log(frustration: frustration.identifier)
        
        // then
        let retrievedFrustration = Appero.instance.frustration(for: "Non Existent")
        XCTAssertNil(retrievedFrustration)
    }
    
    func testThresholdCrossed() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.appCrash, threshold: 2)
        Appero.instance.register(frustration: frustration)
        
        // when
        Appero.instance.log(frustration: frustration.identifier)
        XCTAssertFalse(Appero.instance.isThresholdCrossed(for: frustration.identifier))
        
        Appero.instance.log(frustration: frustration.identifier)
        
        // then
        XCTAssertTrue(Appero.instance.isThresholdCrossed(for: frustration.identifier))
    }
    
    func testThresholdExceeded() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.slowLoading, threshold: 2)
        Appero.instance.register(frustration: frustration)
        
        // when
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.log(frustration: frustration.identifier)
        
        // then
        XCTAssertTrue(Appero.instance.isThresholdCrossed(for: frustration.identifier))
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrationIdentifiers.slowLoading)
        XCTAssertEqual(retrievedFrustration?.events, 3)
    }
    
    func testResetAllFrustrations() {
        // given
        let frustration1 = Appero.Frustration(identifier: TestFrustrationIdentifiers.loginFailed, threshold: 1)
        let frustration2 = Appero.Frustration(identifier: TestFrustrationIdentifiers.networkError, threshold: 2)
        Appero.instance.register(frustration: frustration1)
        Appero.instance.register(frustration: frustration2)
        Appero.instance.log(frustration: frustration1.identifier)
        Appero.instance.log(frustration: frustration2.identifier)
        
        // when
        Appero.instance.resetAllFrustrations()
        
        // then
        XCTAssertNil(Appero.instance.frustration(for: TestFrustrationIdentifiers.loginFailed))
        XCTAssertNil(Appero.instance.frustration(for: TestFrustrationIdentifiers.networkError))
    }
    
    func testFrustrationPerUser() {
        // given
        let userA = "user_a"
        let userB = "user_b"
        let frustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.appCrash, threshold: 1)
        
        // setup user A
        Appero.instance.setUserId(userA)
        Appero.instance.register(frustration: frustration)
        Appero.instance.log(frustration: frustration.identifier)
        
        // when switching to user B
        Appero.instance.resetUser()
        Appero.instance.setUserId(userB)
        
        // then user B should not see user A's frustrations
        XCTAssertNil(Appero.instance.frustration(for: TestFrustrationIdentifiers.appCrash))
        
        // when switching back to user A
        Appero.instance.resetUser()
        Appero.instance.setUserId(userA)
        
        // then user A's frustrations should be restored
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrationIdentifiers.appCrash)
        XCTAssertNotNil(retrievedFrustration)
        XCTAssertEqual(retrievedFrustration?.events, 1)
    }
    
    func testMultipleFrustrations() {
        // given
        let loginFrustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.loginFailed, threshold: 3)
        let networkFrustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.networkError, threshold: 2)
        let crashFrustration = Appero.Frustration(identifier: TestFrustrationIdentifiers.appCrash, threshold: 1)
        
        // when
        Appero.instance.register(frustration: loginFrustration)
        Appero.instance.register(frustration: networkFrustration)
        Appero.instance.register(frustration: crashFrustration)
        
        Appero.instance.log(frustration: loginFrustration.identifier)
        Appero.instance.log(frustration: networkFrustration.identifier)
        Appero.instance.log(frustration: networkFrustration.identifier)
        Appero.instance.log(frustration: crashFrustration.identifier)
        
        // then
        XCTAssertFalse(Appero.instance.isThresholdCrossed(for: loginFrustration.identifier))
        XCTAssertTrue(Appero.instance.isThresholdCrossed(for: networkFrustration.identifier))
        XCTAssertTrue(Appero.instance.isThresholdCrossed(for: crashFrustration.identifier))
        
        let retrievedLogin = Appero.instance.frustration(for: TestFrustrationIdentifiers.loginFailed)
        let retrievedNetwork = Appero.instance.frustration(for: TestFrustrationIdentifiers.networkError)
        let retrievedCrash = Appero.instance.frustration(for: TestFrustrationIdentifiers.appCrash)
        
        XCTAssertEqual(retrievedLogin?.events, 1)
        XCTAssertEqual(retrievedNetwork?.events, 2)
        XCTAssertEqual(retrievedCrash?.events, 1)
    }
}
