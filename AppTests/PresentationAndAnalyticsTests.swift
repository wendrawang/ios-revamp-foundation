@testable import IOSRevampFoundation
import CoreAnalytics
import TransferFeature
import XCTest

@MainActor
final class PresentationAndAnalyticsTests: XCTestCase {
    func testGlobalPresentationDismissalReleasesPresentedValue() {
        let controller = GlobalPresentationController()
        controller.present(GlobalPresentation(
            id: "sample",
            title: "Title",
            message: "Message",
            primaryButtonTitle: "Close"
        ))

        controller.dismiss()

        XCTAssertNil(controller.current)
    }

    func testBlockerPriorityIsDeterministicAndNavigationIsUntouched() {
        let blockers = GlobalBlockerController()
        let navigation = AuthenticatedNavigationStore { _ in }
        navigation.push(TransferRoute.landing, screen: ScreenDescriptor(id: "transfer.landing"))

        blockers.show(.connectivity)
        blockers.show(.maintenance)
        blockers.show(.securityRestriction)
        XCTAssertEqual(blockers.current, .securityRestriction)

        blockers.hide(.securityRestriction)
        XCTAssertEqual(blockers.current, .maintenance)
        blockers.hide(.maintenance)
        blockers.hide(.connectivity)

        XCTAssertEqual(navigation.pathCount, 1)
        XCTAssertEqual(navigation.topScreen.id, "transfer.landing")
    }

    func testScreenVisitsComeFromCommittedNavigationAndTabState() {
        let analytics = InMemoryAnalytics()
        let visits = ScreenVisitCoordinator(analytics: analytics)
        let store = AuthenticatedNavigationStore { visits.screenBecameTopmost($0) }

        store.selectTab(.rewards)
        store.selectTab(.rewards)
        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "transfer.landing"))
        store.pop()

        XCTAssertEqual(visits.visits.map(\.id), ["tab.rewards", "transfer.landing", "tab.rewards"])
        XCTAssertEqual(analytics.events().filter { $0.name == "screen_visit" }.count, 3)
    }

    func testTabActivityRequiresSelectionForegroundAndNoBlocker() {
        XCTAssertTrue(TabActivityState(
            selectedTab: .scan,
            lifecycle: .foreground,
            isGloballyBlocked: false
        ).isOperational(.scan))
        XCTAssertFalse(TabActivityState(
            selectedTab: .dashboard,
            lifecycle: .foreground,
            isGloballyBlocked: false
        ).isOperational(.scan))
        XCTAssertFalse(TabActivityState(
            selectedTab: .scan,
            lifecycle: .background,
            isGloballyBlocked: false
        ).isOperational(.scan))
        XCTAssertFalse(TabActivityState(
            selectedTab: .scan,
            lifecycle: .foreground,
            isGloballyBlocked: true
        ).isOperational(.scan))
    }
}
