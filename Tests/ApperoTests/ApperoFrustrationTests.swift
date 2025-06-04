import XCTest
@testable import Appero

final class ApperoFrustrationTests: XCTestCase {
    
    // MARK: - Test Constants
    private struct TestFrustrations {
        static let loginFailed = "Login Failed"
        static let networkError = "Network Error"
        static let appCrash = "App Crash"
        static let slowLoading = "Slow Loading"
    }
    
    override func setUp() {
        super.setUp()
        Appero.instance.start(apiKey: "api_id", userId: "user_1")
        Appero.instance.resetUser()
        Appero.instance.resetAllFrustrations()
    }
    
    override func tearDown() {
        super.tearDown()
        Appero.instance.resetAllFrustrations()
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kUserIdKey)
        UserDefaults.standard.setValue(nil, forKey: Appero.Constants.kFrustrationDictionary)
    }
    
    func testRegisterFrustration() {
        // given
        let frustration = Appero.Frustration(
            identifier: TestFrustrations.loginFailed,
            threshold: 3,
            userPrompt: "We noticed you're having trouble logging in"
        )
        
        // when
        Appero.instance.register(frustration: frustration)
        
        // then
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrations.loginFailed)
        XCTAssertNotNil(retrievedFrustration)
        XCTAssertEqual(retrievedFrustration?.identifier, TestFrustrations.loginFailed)
        XCTAssertEqual(retrievedFrustration?.threshold, 3)
        XCTAssertEqual(retrievedFrustration?.events, 0)
    }
    
    func testLogFrustration() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrations.networkError, threshold: 2)
        Appero.instance.register(frustration: frustration)

        
        // when
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.log(frustration: frustration.identifier)
        
        // then
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrations.networkError)
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
        let frustration = Appero.Frustration(identifier: TestFrustrations.appCrash, threshold: 2)
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
        let frustration = Appero.Frustration(identifier: TestFrustrations.slowLoading, threshold: 2)
        Appero.instance.register(frustration: frustration)
        
        // when
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.log(frustration: frustration.identifier)
        
        // then
        XCTAssertTrue(Appero.instance.isThresholdCrossed(for: frustration.identifier))
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrations.slowLoading)
        XCTAssertEqual(retrievedFrustration?.events, 3)
    }
    
    func testResetAllFrustrations() {
        // given
        let frustration1 = Appero.Frustration(identifier: TestFrustrations.loginFailed, threshold: 1)
        let frustration2 = Appero.Frustration(identifier: TestFrustrations.networkError, threshold: 2)
        Appero.instance.register(frustration: frustration1)
        Appero.instance.register(frustration: frustration2)
        Appero.instance.log(frustration: frustration1.identifier)
        Appero.instance.log(frustration: frustration2.identifier)
        
        // when
        Appero.instance.resetAllFrustrations()
        
        // then
        XCTAssertNil(Appero.instance.frustration(for: TestFrustrations.loginFailed))
        XCTAssertNil(Appero.instance.frustration(for: TestFrustrations.networkError))
    }
    
    func testFrustrationPerUser() {
        // given
        let userA = "user_a"
        let userB = "user_b"
        let frustration = Appero.Frustration(identifier: TestFrustrations.appCrash, threshold: 1)
        
        // setup user A
        Appero.instance.setUserId(userA)
        Appero.instance.register(frustration: frustration)
        Appero.instance.log(frustration: frustration.identifier)
        
        // when switching to user B
        Appero.instance.resetUser()
        Appero.instance.setUserId(userB)
        
        // then user B should not see user A's frustrations
        XCTAssertNil(Appero.instance.frustration(for: TestFrustrations.appCrash))
        
        // when switching back to user A
        Appero.instance.resetUser()
        Appero.instance.setUserId(userA)
        
        // then user A's frustrations should be restored
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrations.appCrash)
        XCTAssertNotNil(retrievedFrustration)
        XCTAssertEqual(retrievedFrustration?.events, 1)
    }
    
    func testMultipleFrustrations() {
        // given
        let loginFrustration = Appero.Frustration(identifier: TestFrustrations.loginFailed, threshold: 3)
        let networkFrustration = Appero.Frustration(identifier: TestFrustrations.networkError, threshold: 2)
        let crashFrustration = Appero.Frustration(identifier: TestFrustrations.appCrash, threshold: 1)
        
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
        
        let retrievedLogin = Appero.instance.frustration(for: TestFrustrations.loginFailed)
        let retrievedNetwork = Appero.instance.frustration(for: TestFrustrations.networkError)
        let retrievedCrash = Appero.instance.frustration(for: TestFrustrations.appCrash)
        
        XCTAssertEqual(retrievedLogin?.events, 1)
        XCTAssertEqual(retrievedNetwork?.events, 2)
        XCTAssertEqual(retrievedCrash?.events, 1)
    }
    
    func testMarkPrompted() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrations.loginFailed, threshold: 1)
        Appero.instance.register(frustration: frustration)
        
        // when
        Appero.instance.markPrompted(frustration: frustration.identifier)
        
        // then
        XCTAssertTrue(Appero.instance.isPrompted(frustration: frustration.identifier))
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrations.loginFailed)
        XCTAssertEqual(retrievedFrustration?.prompted, true)
    }
    
    func testIsPrompted() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrations.networkError, threshold: 1)
        Appero.instance.register(frustration: frustration)
        
        // then initially not prompted
        XCTAssertFalse(Appero.instance.isPrompted(frustration: frustration.identifier))
        
        // when marked as prompted
        Appero.instance.markPrompted(frustration: frustration.identifier)
        
        // then should be prompted
        XCTAssertTrue(Appero.instance.isPrompted(frustration: frustration.identifier))
    }
    
    func testIsPromptedNonExistent() {
        // when checking non-existent frustration
        let isPrompted = Appero.instance.isPrompted(frustration: "Non Existent")
        
        // then should return false
        XCTAssertFalse(isPrompted)
    }
    
    func testDeferPromptFor() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrations.appCrash, threshold: 1)
        Appero.instance.register(frustration: frustration)
        
        // when deferring the prompt
        Appero.instance.deferPromptFor(frustration: frustration.identifier)
        
        // then should be deferred
        XCTAssertTrue(Appero.instance.isDeferred(frustration: frustration.identifier))
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrations.appCrash)
        XCTAssertNotNil(retrievedFrustration?.nextPromptDate)
        XCTAssertTrue(retrievedFrustration!.nextPromptDate! > Date())
    }
    
    func testIsDeferred() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrations.slowLoading, threshold: 1)
        Appero.instance.register(frustration: frustration)
        
        // then initially not deferred
        XCTAssertFalse(Appero.instance.isDeferred(frustration: frustration.identifier))
        
        // when deferred
        Appero.instance.deferPromptFor(frustration: frustration.identifier)
        
        // then should be deferred
        XCTAssertTrue(Appero.instance.isDeferred(frustration: frustration.identifier))
    }
    
    func testIsDeferredNonExistent() {
        // when checking non-existent frustration
        let isDeferred = Appero.instance.isDeferred(frustration: "Non Existent")
        
        // then should return false (distant past < current date)
        XCTAssertFalse(isDeferred)
    }
    
    func testNeedsPrompt() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrations.loginFailed, threshold: 2)
        Appero.instance.register(frustration: frustration)
        
        // when threshold not crossed
        XCTAssertFalse(Appero.instance.needsPrompt(frustration: frustration.identifier))
        
        // when threshold crossed but not prompted
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.log(frustration: frustration.identifier)
        XCTAssertTrue(Appero.instance.needsPrompt(frustration: frustration.identifier))
        
        // when already prompted
        Appero.instance.markPrompted(frustration: frustration.identifier)
        XCTAssertFalse(Appero.instance.needsPrompt(frustration: frustration.identifier))
    }
    
    func testNeedsPromptWithDeferred() {
        // given
        let frustration = Appero.Frustration(identifier: TestFrustrations.networkError, threshold: 1)
        Appero.instance.register(frustration: frustration)
        
        // when threshold crossed and deferred
        Appero.instance.log(frustration: frustration.identifier)
        Appero.instance.deferPromptFor(frustration: frustration.identifier)
        
        // then should not need prompt (deferred)
        XCTAssertFalse(Appero.instance.needsPrompt(frustration: frustration.identifier))
    }
    
    func testRegisterExistingFrustration() {
        // given
        let frustration1 = Appero.Frustration(identifier: TestFrustrations.appCrash, threshold: 1, userPrompt: "First prompt")
        let frustration2 = Appero.Frustration(identifier: TestFrustrations.appCrash, threshold: 5, userPrompt: "Second prompt")
        
        // when registering first frustration
        Appero.instance.register(frustration: frustration1)
        Appero.instance.log(frustration: frustration1.identifier)
        
        // when trying to register another with same identifier
        Appero.instance.register(frustration: frustration2)
        
        // then original frustration should remain unchanged
        let retrievedFrustration = Appero.instance.frustration(for: TestFrustrations.appCrash)
        XCTAssertEqual(retrievedFrustration?.threshold, 1)
        XCTAssertEqual(retrievedFrustration?.userPrompt, "First prompt")
        XCTAssertEqual(retrievedFrustration?.events, 1)
    }
}
