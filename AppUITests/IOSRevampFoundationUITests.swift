import XCTest

@MainActor
final class IOSRevampFoundationUITests: XCTestCase {
    private lazy var app: XCUIApplication = {
        let application = XCUIApplication()
        application.launchArguments = ["-uiTesting"]
        return application
    }()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testNormalLogin() {
        launchAndLogin()
        XCTAssertTrue(app.buttons["dashboard.transfer"].waitForExistence(timeout: 2))
    }

    func testRegistrationContinuationDeepLink() {
        app.launchArguments += ["-deepLink", "iosrevamp://registration/continue?token=demo"]
        app.launch()
        XCTAssertTrue(element("auth.registration.continue").waitForExistence(timeout: 3))
    }

    func testAuthenticatedRewardDeepLinkGoesDirectlyAfterLogin() {
        app.launchArguments += ["-deepLink", "iosrevamp://rewards/detail?id=reward-001"]
        app.launch()
        tapLogin()
        XCTAssertTrue(element("rewards.detail").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["dashboard.transfer"].exists)
    }

    func testDashboardOpensSharedUpgradeService() {
        launchAndLogin()
        app.buttons["dashboard.upgrade"].tap()
        XCTAssertTrue(element("upgrade.root").waitForExistence(timeout: 2))
    }

    func testMoreOpensSameUpgradeService() {
        launchAndLogin()
        app.buttons["tab.more"].tap()
        app.buttons["more.upgrade"].tap()
        XCTAssertTrue(element("upgrade.root").waitForExistence(timeout: 2))
    }

    func testDashboardTransferJourney() {
        launchToTransferResult()
        XCTAssertTrue(element("transfer.result").exists)
    }

    func testCurrentJourneyWealthBackReturnsToTransferResult() {
        launchToTransferResult()
        app.buttons["transfer.wealth.current"].tap()
        XCTAssertTrue(element("wealth.product").waitForExistence(timeout: 2))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("transfer.result").waitForExistence(timeout: 2))
    }

    func testCanonicalWealthBackReturnsToFinancialRoot() {
        launchToTransferResult()
        app.buttons["transfer.wealth.canonical"].tap()
        XCTAssertTrue(element("wealth.product").waitForExistence(timeout: 2))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("financial.investment").waitForExistence(timeout: 2))
    }

    func testCustomScanTabActivatesCameraResource() {
        launchAndLogin()
        app.buttons["tab.scan"].tap()
        XCTAssertTrue(app.staticTexts["Camera resource active"].waitForExistence(timeout: 2))
    }

    func testBackendSheetActionOpensUpgradeService() {
        launchToTransferResult()
        app.buttons["transfer.sheet.show"].tap()
        XCTAssertTrue(app.buttons["transfer.sheet.primary"].waitForExistence(timeout: 2))
        app.buttons["transfer.sheet.primary"].tap()
        XCTAssertTrue(element("upgrade.root").waitForExistence(timeout: 2))
    }

    func testBlockerRecoveryPreservesTransferResult() {
        launchToTransferResult()
        app.buttons["transfer.blocker.toggle"].tap()
        XCTAssertTrue(element("global.blocker.connectivity").waitForExistence(timeout: 2))
        app.buttons["Connection restored"].tap()
        XCTAssertTrue(element("transfer.result").waitForExistence(timeout: 2))
    }

    func testWebApplicationDeepLinkOpensNativeReward() {
        launchAndLogin()
        app.buttons["tab.more"].tap()
        app.buttons["more.web"].tap()
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 3))
        let nativeLink = app.links["Open native Reward Detail"]
        XCTAssertTrue(nativeLink.waitForExistence(timeout: 3))
        nativeLink.tap()
        XCTAssertTrue(element("rewards.detail").waitForExistence(timeout: 3))
    }

    private func launchAndLogin() {
        app.launch()
        tapLogin()
        XCTAssertTrue(app.buttons["tab.dashboard"].waitForExistence(timeout: 3))
    }

    private func tapLogin() {
        XCTAssertTrue(app.buttons["auth.login.submit"].waitForExistence(timeout: 3))
        app.buttons["auth.login.submit"].tap()
    }

    private func launchToTransferResult() {
        launchAndLogin()
        app.buttons["dashboard.transfer"].tap()
        XCTAssertTrue(app.buttons["transfer.submit"].waitForExistence(timeout: 2))
        app.buttons["transfer.submit"].tap()
        XCTAssertTrue(element("transfer.result").waitForExistence(timeout: 3))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
