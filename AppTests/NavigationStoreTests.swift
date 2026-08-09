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
        let store = AuthenticatedNavigationStore { visits.append($0) }

        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "transfer.landing"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(id: "transfer.result"))

        XCTAssertEqual(store.pathCount, 2)
        XCTAssertEqual(store.metadata.map(\.id), ["transfer.landing", "transfer.result"])
        XCTAssertEqual(store.topScreen.id, "transfer.result")

        store.pop()

        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata.map(\.id), ["transfer.landing"])
        XCTAssertEqual(store.topScreen.id, "transfer.landing")
        XCTAssertEqual(visits.last?.id, "transfer.landing")
    }

    // Memverifikasi system style path reduction trims metadata atomically.
    func testSystemStylePathReductionTrimsMetadataAtomically() {
        let store = AuthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "transfer.landing"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(id: "transfer.result"))

        var reducedPath = NavigationPath()
        reducedPath.append(TransferRoute.landing)
        store.reconcileSystemPath(reducedPath)

        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata, [ScreenDescriptor(id: "transfer.landing")])
        XCTAssertEqual(store.topScreen.id, "transfer.landing")
    }

    // Memverifikasi same count system echo cannot replace store owned route.
    func testSameCountSystemEchoCannotReplaceStoreOwnedRoute() {
        let store = AuthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "transfer.landing"))
        var unrelatedSameCountPath = NavigationPath()
        unrelatedSameCountPath.append(WealthRoute.product(id: "unexpected"))

        store.reconcileSystemPath(unrelatedSameCountPath)

        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata, [ScreenDescriptor(id: "transfer.landing")])
        XCTAssertEqual(store.topScreen.id, "transfer.landing")
    }

    // Memverifikasi pop to root keeps selected tab as top screen.
    func testPopToRootKeepsSelectedTabAsTopScreen() {
        let store = AuthenticatedNavigationStore { _ in }
        store.selectTab(.financial)
        store.push(WealthRoute.product(id: "one"), screen: ScreenDescriptor(id: "wealth.product"))

        store.popToRoot()

        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen, AppTab.financial.screenDescriptor)
    }

    // Memverifikasi canonical navigation selects tab and replaces journey.
    func testCanonicalNavigationSelectsTabAndReplacesJourney() {
        let store = AuthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "transfer.landing"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(id: "transfer.result"))

        store.openCanonical(
            tab: .financial,
            destination: NavigationDestination(
                route: WealthRoute.product(id: "wealth-001"),
                screen: ScreenDescriptor(id: "wealth.product")
            )
        )

        XCTAssertEqual(store.selectedTab, .financial)
        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata.map(\.id), ["wealth.product"])
    }

    // Memverifikasi unauthenticated system pop reconciles metadata.
    func testUnauthenticatedSystemPopReconcilesMetadata() {
        let store = UnauthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "temporary"))
        store.reconcileSystemPath(NavigationPath())
        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen.id, "auth.login")
    }

    // Memverifikasi unauthenticated programmatic pop and root reset stay consistent.
    func testUnauthenticatedProgrammaticPopAndRootResetStayConsistent() {
        let store = UnauthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "first"))
        store.push(TransferRoute.result(referenceID: "one"), screen: ScreenDescriptor(id: "second"))

        store.pop()
        XCTAssertEqual(store.pathCount, 1)
        XCTAssertEqual(store.metadata.map(\.id), ["first"])
        XCTAssertEqual(store.topScreen.id, "first")

        store.popToRoot()
        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen.id, "auth.login")
    }
}
