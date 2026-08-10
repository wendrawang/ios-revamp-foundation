import SwiftUI
import TransferFeature
import WealthFeature
import XCTest

@testable import IOSRevampFoundation

@MainActor
final class NavigationStoreTests: XCTestCase {
    // Memverifikasi push and programmatic pop keep path and metadata consistent.
    func testPushAndProgrammaticPopKeepPathAndMetadataConsistent() {
        var visits: [ScreenDescriptor] = []
        let store = AuthenticatedNavigationStore { screen in visits.append(screen) }

        store.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "transfer.landing"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(identifier: "transfer.result"))

        XCTAssertEqual(store.pathCount, 2)
        XCTAssertEqual(store.metadata.map(\.identifier), ["transfer.landing", "transfer.result"])
        XCTAssertEqual(store.topScreen.identifier, "transfer.result")

        store.pop()

        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata.map(\.identifier), ["transfer.landing"])
        XCTAssertEqual(store.topScreen.identifier, "transfer.landing")
        XCTAssertEqual(visits.last?.identifier, "transfer.landing")
    }

    // Memverifikasi system style path reduction trims metadata atomically.
    func testSystemStylePathReductionTrimsMetadataAtomically() {
        let store = AuthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "transfer.landing"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(identifier: "transfer.result"))

        var reducedPath = NavigationPath()
        reducedPath.append(TransferRoute.landing)
        store.reconcileSystemPath(reducedPath)

        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata, [ScreenDescriptor(identifier: "transfer.landing")])
        XCTAssertEqual(store.topScreen.identifier, "transfer.landing")
    }

    // Memverifikasi same count system echo cannot replace store owned route.
    func testSameCountSystemEchoCannotReplaceStoreOwnedRoute() {
        let store = AuthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "transfer.landing"))
        var unrelatedSameCountPath = NavigationPath()
        unrelatedSameCountPath.append(WealthRoute.product(identifier: "unexpected"))

        store.reconcileSystemPath(unrelatedSameCountPath)

        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata, [ScreenDescriptor(identifier: "transfer.landing")])
        XCTAssertEqual(store.topScreen.identifier, "transfer.landing")
    }

    // Memverifikasi pop to root keeps selected tab as top screen.
    func testPopToRootKeepsSelectedTabAsTopScreen() {
        let store = AuthenticatedNavigationStore { _ in }
        store.selectTab(.financial)
        store.push(WealthRoute.product(identifier: "one"), screen: ScreenDescriptor(identifier: "wealth.product"))

        store.popToRoot()

        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen, AppTab.financial.screenDescriptor)
    }

    // Memverifikasi canonical navigation selects tab and replaces journey.
    func testCanonicalNavigationSelectsTabAndReplacesJourney() {
        let store = AuthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "transfer.landing"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(identifier: "transfer.result"))

        store.openCanonical(
            tab: .financial,
            destination: NavigationDestination(
                route: WealthRoute.product(identifier: "wealth-001"),
                screen: ScreenDescriptor(identifier: "wealth.product")
            )
        )

        XCTAssertEqual(store.selectedTab, .financial)
        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata.map(\.identifier), ["wealth.product"])
    }

    // Memverifikasi unauthenticated system pop reconciles metadata.
    func testUnauthenticatedSystemPopReconcilesMetadata() {
        let store = UnauthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "temporary"))
        store.reconcileSystemPath(NavigationPath())
        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen.identifier, "auth.login")
    }

    // Memverifikasi unauthenticated programmatic pop and root reset stay consistent.
    func testUnauthenticatedProgrammaticPopAndRootResetStayConsistent() {
        let store = UnauthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(identifier: "first"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(identifier: "second"))

        store.pop()
        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata.map(\.identifier), ["first"])
        XCTAssertEqual(store.topScreen.identifier, "first")

        store.popToRoot()
        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen.identifier, "auth.login")
    }
}
