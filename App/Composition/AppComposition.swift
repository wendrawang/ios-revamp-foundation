import CoreFeatureFlags
import DashboardFeature
import FinancialHubFeature
import MoreFeature
import RewardsFeature
import TransferFeature
import UpgradeServiceFeature
import WealthFeature

@MainActor
struct AppComposition {
    let coordinator: AppCoordinator

    // Memetakan typed feature output menjadi keputusan milik AppComposition.
    func handle(_ output: DashboardOutput) {
        switch output {
        case .openTransfer:
            coordinator.authenticatedNavigation.push(
                TransferRoute.landing,
                screen: ScreenDescriptor(identifier: "transfer.landing")
            )
        case .openUpgradeService:
            coordinator.authenticatedNavigation.push(
                UpgradeServiceRoute.start,
                screen: ScreenDescriptor(identifier: "upgrade.root")
            )
        case .toggleConnectivityBlocker:
            coordinator.container.blockerController.toggleConnectivity()
        }
    }

    // Memetakan typed feature output menjadi keputusan milik AppComposition.
    func handle(_ output: FinancialHubOutput) {
        switch output {
        case .openWealth(let productID):
            guard coordinator.container.featureFlags.isEnabled(.wealthEntryEnabled) else { return }
            coordinator.authenticatedNavigation.push(
                WealthRoute.product(identifier: productID),
                screen: ScreenDescriptor(identifier: "wealth.product")
            )
        }
    }

    // Memetakan typed feature output menjadi keputusan milik AppComposition.
    func handle(_ output: MoreOutput) {
        switch output {
        case .openUpgradeService:
            coordinator.authenticatedNavigation.push(
                UpgradeServiceRoute.start,
                screen: ScreenDescriptor(identifier: "upgrade.root")
            )
        case .openWebSample:
            guard coordinator.container.featureFlags.isEnabled(.webSampleEnabled) else { return }
            coordinator.authenticatedNavigation.push(
                AppWebRoute.sample,
                screen: ScreenDescriptor(identifier: "web.sample")
            )
        case .logout:
            coordinator.logout()
        }
    }

    // Memetakan typed feature output menjadi keputusan milik AppComposition.
    func handle(_ output: TransferOutput) {
        switch output {
        case .openWealth(let productID, let mode):
            guard coordinator.container.featureFlags.isEnabled(.wealthEntryEnabled) else { return }
            let destination = NavigationDestination(
                route: WealthRoute.product(identifier: productID),
                screen: ScreenDescriptor(identifier: "wealth.product")
            )
            switch mode {
            case .currentJourney:
                coordinator.authenticatedNavigation.apply(.push(destination))
            case .canonicalFinancial:
                coordinator.authenticatedNavigation.apply(.canonical(tab: .financial, destination: destination))
            }
        case .openUpgradeService:
            coordinator.authenticatedNavigation.push(
                UpgradeServiceRoute.start,
                screen: ScreenDescriptor(identifier: "upgrade.root")
            )
        case .toggleConnectivityBlocker:
            coordinator.container.blockerController.toggleConnectivity()
        }
    }

    // Membuka Rewards detail melalui route konkret milik RewardsFeature.
    func openRewardDetail(_ rewardIdentifier: String) {
        coordinator.authenticatedNavigation.push(
            RewardsRoute.detail(identifier: rewardIdentifier),
            screen: ScreenDescriptor(identifier: "rewards.detail")
        )
    }
}
