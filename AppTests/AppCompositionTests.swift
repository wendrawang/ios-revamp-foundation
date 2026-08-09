@testable import IOSRevampFoundation
import TransferFeature
import WealthFeature
import XCTest

@MainActor
final class AppCompositionTests: XCTestCase {
    func testTransferCurrentJourneyAppendsWealth() {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let composition = AppComposition(coordinator: coordinator)
        coordinator.authenticatedNavigation.push(
            TransferRoute.result(referenceID: "one"),
            screen: ScreenDescriptor(id: "transfer.result")
        )

        composition.handle(.openWealth(productID: "wealth-001", mode: .currentJourney))

        XCTAssertEqual(coordinator.authenticatedNavigation.pathCount, 2)
        XCTAssertEqual(coordinator.authenticatedNavigation.metadata.map(\.id), ["transfer.result", "wealth.product"])
        XCTAssertEqual(coordinator.authenticatedNavigation.selectedTab, .dashboard)
    }

    func testTransferCanonicalWealthReplacesJourney() {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let composition = AppComposition(coordinator: coordinator)
        coordinator.authenticatedNavigation.push(
            TransferRoute.result(referenceID: "one"),
            screen: ScreenDescriptor(id: "transfer.result")
        )

        composition.handle(.openWealth(productID: "wealth-001", mode: .canonicalFinancial))

        XCTAssertEqual(coordinator.authenticatedNavigation.pathCount, 1)
        XCTAssertEqual(coordinator.authenticatedNavigation.metadata.map(\.id), ["wealth.product"])
        XCTAssertEqual(coordinator.authenticatedNavigation.selectedTab, .financial)
    }
}

