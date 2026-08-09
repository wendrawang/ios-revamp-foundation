@testable import IOSRevampFoundation
import SwiftUI
import TransferFeature
import WealthFeature
import XCTest

@MainActor
final class NavigationStoreTests: XCTestCase {
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

    func testPopToRootKeepsSelectedTabAsTopScreen() {
        let store = AuthenticatedNavigationStore { _ in }
        store.selectTab(.financial)
        store.push(WealthRoute.product(id: "one"), screen: ScreenDescriptor(id: "wealth.product"))

        store.popToRoot()

        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen, AppTab.financial.screenDescriptor)
    }

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

    func testUnauthenticatedSystemPopReconcilesMetadata() {
        let store = UnauthenticatedNavigationStore { _ in }
        store.push(TransferRoute.landing, screen: ScreenDescriptor(id: "temporary"))
        store.reconcileSystemPath(NavigationPath())
        XCTAssertEqual(store.pathCount, 0)
        XCTAssertTrue(store.metadata.isEmpty)
        XCTAssertEqual(store.topScreen.id, "auth.login")
    }

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
