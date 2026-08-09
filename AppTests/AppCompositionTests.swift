import CoreFeatureFlags
import DashboardFeature
import FinancialHubFeature
import MoreFeature
import TransferFeature
import WealthFeature
import XCTest

@testable import IOSRevampFoundation

@MainActor
final class AppCompositionTests: XCTestCase {
    // Memverifikasi transfer current journey appends wealth.
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

    // Memverifikasi transfer canonical wealth replaces journey.
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

    // Memverifikasi dashboard maps to shared feature routes and blocker.
    func testDashboardMapsToSharedFeatureRoutesAndBlocker() {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let composition = AppComposition(coordinator: coordinator)

        composition.handle(DashboardOutput.openTransfer)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "transfer.landing")

        coordinator.authenticatedNavigation.popToRoot()
        composition.handle(DashboardOutput.openUpgradeService)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "upgrade.root")

        composition.handle(DashboardOutput.toggleConnectivityBlocker)
        XCTAssertEqual(coordinator.container.blockerController.current, .connectivity)
    }

    // Memverifikasi financial hub honors wealth feature flag.
    func testFinancialHubHonorsWealthFeatureFlag() {
        let container = AppContainer(isUITesting: true)
        let coordinator = AppCoordinator(container: container)
        let composition = AppComposition(coordinator: coordinator)

        container.featureFlags.set(.wealthEntryEnabled, isEnabled: false)
        composition.handle(FinancialHubOutput.openWealth(productID: "disabled"))
        XCTAssertEqual(coordinator.authenticatedNavigation.pathCount, 0)

        container.featureFlags.set(.wealthEntryEnabled, isEnabled: true)
        composition.handle(FinancialHubOutput.openWealth(productID: "wealth-001"))
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "wealth.product")
    }

    // Memverifikasi more and rewards outputs map without feature imports.
    func testMoreAndRewardsOutputsMapWithoutFeatureImports() {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let composition = AppComposition(coordinator: coordinator)

        composition.handle(MoreOutput.openWebSample)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "web.sample")

        coordinator.authenticatedNavigation.popToRoot()
        composition.handle(MoreOutput.openUpgradeService)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "upgrade.root")

        coordinator.authenticatedNavigation.popToRoot()
        composition.openRewardDetail("reward-001")
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "rewards.detail")
    }

    // Memverifikasi transfer upgrade and blocker outputs remain app owned.
    func testTransferUpgradeAndBlockerOutputsRemainAppOwned() {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let composition = AppComposition(coordinator: coordinator)

        composition.handle(TransferOutput.openUpgradeService)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "upgrade.root")

        composition.handle(TransferOutput.toggleConnectivityBlocker)
        XCTAssertEqual(coordinator.container.blockerController.current, .connectivity)
    }
}
