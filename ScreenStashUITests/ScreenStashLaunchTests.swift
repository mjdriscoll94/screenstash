import XCTest

@MainActor
final class ScreenStashLaunchTests: XCTestCase {
    func testOnboardingExplainsDeletingTheOriginal() {
        let app = XCUIApplication()
        app.launchArguments = ["-show-onboarding", "-onboarding-page=2"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Delete the Original"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["onboarding.guide.deleteOriginal"].exists)
        XCTAssertTrue(app.buttons["onboarding.continue"].exists)
    }

    func testLaunchesToInboxForReturningUser() {
        let app = XCUIApplication()
        app.launchArguments = ["-skip-onboarding"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
    }
}
