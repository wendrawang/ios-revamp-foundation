import XCTest

@MainActor
final class IOSRevampFoundationUITests: XCTestCase {
    private lazy var app: XCUIApplication = {
        let application = XCUIApplication()
        application.launchArguments = ["-uiTesting"]
        return application
    }()

    // Menyiapkan kondisi bersih sebelum setiap UI test.
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // Memverifikasi normal login.
    func testNormalLogin() {
        launchAndLogin()
        XCTAssertTrue(app.buttons["dashboard.transfer"].waitForExistence(timeout: 2))
    }

    // Memverifikasi application launch performance.
    func testApplicationLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            app.launch()
            app.terminate()
        }
    }

    // Memverifikasi registration continuation deep link.
    func testRegistrationContinuationDeepLink() {
        app.launchArguments += ["-deepLink", "iosrevamp://registration/continue?token=demo"]
        app.launch()
        XCTAssertTrue(element("auth.registration.continue").waitForExistence(timeout: 3))
    }

    // Memverifikasi authenticated reward deep link goes directly after login.
    func testAuthenticatedRewardDeepLinkGoesDirectlyAfterLogin() {
        app.launchArguments += ["-deepLink", "iosrevamp://rewards/detail?id=reward-001"]
        app.launch()
        tapLogin()
        XCTAssertTrue(element("rewards.detail").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["dashboard.transfer"].exists)
    }

    // Memverifikasi dashboard opens shared upgrade service.
    func testDashboardOpensSharedUpgradeService() {
        launchAndLogin()
        app.buttons["dashboard.upgrade"].tap()
        XCTAssertTrue(element("upgrade.root").waitForExistence(timeout: 2))
    }

    // Memverifikasi more opens same upgrade service.
    func testMoreOpensSameUpgradeService() {
        launchAndLogin()
        app.buttons["tab.more"].tap()
        app.buttons["more.upgrade"].tap()
        XCTAssertTrue(element("upgrade.root").waitForExistence(timeout: 2))
    }

    // Memverifikasi dashboard transfer journey.
    func testDashboardTransferJourney() {
        launchToTransferResult()
        XCTAssertTrue(element("transfer.result").exists)
    }

    // Memverifikasi current journey wealth back returns to transfer result.
    func testCurrentJourneyWealthBackReturnsToTransferResult() {
        launchToTransferResult()
        app.buttons["transfer.wealth.current"].tap()
        XCTAssertTrue(element("wealth.product").waitForExistence(timeout: 2))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("transfer.result").waitForExistence(timeout: 2))
    }

    // Memverifikasi canonical wealth back returns to financial root.
    func testCanonicalWealthBackReturnsToFinancialRoot() {
        launchToTransferResult()
        app.buttons["transfer.wealth.canonical"].tap()
        XCTAssertTrue(element("wealth.product").waitForExistence(timeout: 2))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("financial.investment").waitForExistence(timeout: 2))
    }

    // Memverifikasi custom scan tab activates camera resource.
    func testCustomScanTabActivatesCameraResource() {
        launchAndLogin()
        app.buttons["tab.scan"].tap()
        XCTAssertTrue(app.staticTexts["Camera resource active"].waitForExistence(timeout: 2))
    }

    // Memverifikasi backend sheet action opens upgrade service.
    func testBackendSheetActionOpensUpgradeService() {
        launchToTransferResult()
        app.buttons["transfer.sheet.show"].tap()
        XCTAssertTrue(app.buttons["transfer.sheet.primary"].waitForExistence(timeout: 2))
        app.buttons["transfer.sheet.primary"].tap()
        XCTAssertTrue(element("upgrade.root").waitForExistence(timeout: 2))
    }

    // Memverifikasi blocker recovery preserves transfer result.
    func testBlockerRecoveryPreservesTransferResult() {
        launchToTransferResult()
        app.buttons["transfer.blocker.toggle"].tap()
        XCTAssertTrue(element("global.blocker.connectivity").waitForExistence(timeout: 2))
        app.buttons["Connection restored"].tap()
        XCTAssertTrue(element("transfer.result").waitForExistence(timeout: 2))
    }

    // Memverifikasi web application deep link opens native reward.
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

    // Menjalankan aplikasi dengan fake services lalu menyelesaikan login.
    private func launchAndLogin() {
        app.launch()
        tapLogin()
        XCTAssertTrue(app.buttons["tab.dashboard"].waitForExistence(timeout: 3))
    }

    // Menekan tombol login yang memiliki accessibility identifier stabil.
    private func tapLogin() {
        XCTAssertTrue(app.buttons["auth.login.submit"].waitForExistence(timeout: 3))
        app.buttons["auth.login.submit"].tap()
    }

    // Menavigasi UI secara deterministik sampai Transfer Result.
    private func launchToTransferResult() {
        launchAndLogin()
        app.buttons["dashboard.transfer"].tap()
        XCTAssertTrue(app.buttons["transfer.submit"].waitForExistence(timeout: 2))
        app.buttons["transfer.submit"].tap()
        XCTAssertTrue(element("transfer.result").waitForExistence(timeout: 3))
    }

    // Mencari elemen UI lintas tipe menggunakan accessibility identifier.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
