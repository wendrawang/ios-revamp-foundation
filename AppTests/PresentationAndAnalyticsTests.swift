import CoreAnalytics
import TransferFeature
import XCTest

@testable import IOSRevampFoundation

@MainActor
final class PresentationAndAnalyticsTests: XCTestCase {
    // Memverifikasi global presentation dismissal releases presented value.
    func testGlobalPresentationDismissalReleasesPresentedValue() {
        let controller = GlobalPresentationController()
        controller.present(
            GlobalPresentation(
                identifier: "sample",
                title: "Title",
                message: "Message",
                primaryButtonTitle: "Close"
            ))

        controller.dismiss()

        XCTAssertNil(controller.current)
    }

    // Memverifikasi global presentations are queued in order.
    func testGlobalPresentationsAreQueuedInOrder() {
        let controller = GlobalPresentationController()
        let first = GlobalPresentation(identifier: "first", title: "First", message: "One", primaryButtonTitle: "Next")
        let second = GlobalPresentation(
            identifier: "second", title: "Second", message: "Two", primaryButtonTitle: "Close")

        controller.present(first)
        controller.present(second)
        XCTAssertEqual(controller.current, first)

        controller.dismiss()
        XCTAssertEqual(controller.current, second)
        controller.dismiss()
        XCTAssertNil(controller.current)
    }

    // Memverifikasi blocker priority is deterministic and navigation is untouched.
    func testBlockerPriorityIsDeterministicAndNavigationIsUntouched() {
        let blockers = GlobalBlockerController()
        let navigation = AuthenticatedNavigationStore { _ in }
        navigation.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "transfer.landing"))

        blockers.show(.connectivity)
        blockers.show(.maintenance)
        blockers.show(.securityRestriction)
        XCTAssertEqual(blockers.current, .securityRestriction)

        blockers.hide(.securityRestriction)
        XCTAssertEqual(blockers.current, .maintenance)
        blockers.hide(.maintenance)
        blockers.hide(.connectivity)

        XCTAssertEqual(navigation.pathCount, 1)
        XCTAssertEqual(navigation.topScreen.identifier, "transfer.landing")
    }

    // Memverifikasi screen visits come from committed navigation and tab state.
    func testScreenVisitsComeFromCommittedNavigationAndTabState() {
        let analytics = InMemoryAnalytics()
        let visits = ScreenVisitCoordinator(analytics: analytics)
        let store = AuthenticatedNavigationStore { screen in visits.screenBecameTopmost(screen) }

        store.selectTab(.rewards)
        store.selectTab(.rewards)
        store.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "transfer.landing"))
        store.pop()

        XCTAssertEqual(visits.visits.map(\.identifier), ["tab.rewards", "transfer.landing", "tab.rewards"])
        XCTAssertEqual(analytics.events().filter { event in event.name == "screen_visit" }.count, 3)
    }

    // Memverifikasi tab activity requires selection foreground and no blocker.
    func testTabActivityRequiresSelectionForegroundAndNoBlocker() {
        XCTAssertTrue(
            TabActivityState(
                selectedTab: .scan,
                lifecycle: .foreground,
                isGloballyBlocked: false
            ).isOperational(.scan))
        XCTAssertFalse(
            TabActivityState(
                selectedTab: .dashboard,
                lifecycle: .foreground,
                isGloballyBlocked: false
            ).isOperational(.scan))
        XCTAssertFalse(
            TabActivityState(
                selectedTab: .scan,
                lifecycle: .background,
                isGloballyBlocked: false
            ).isOperational(.scan))
        XCTAssertFalse(
            TabActivityState(
                selectedTab: .scan,
                lifecycle: .foreground,
                isGloballyBlocked: true
            ).isOperational(.scan))
    }

    // Memverifikasi lifecycle analytics only tracks committed transitions.
    func testLifecycleAnalyticsOnlyTracksCommittedTransitions() {
        let analytics = InMemoryAnalytics()
        let lifecycle = AppLifecycleController(analytics: analytics)

        lifecycle.transition(to: .foreground)
        lifecycle.transition(to: .foreground)
        lifecycle.transition(to: .background)

        let events = analytics.events().filter { event in event.name == "app_lifecycle" }
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.map { event in event.properties["state"] }, ["foreground", "background"])
    }
}
