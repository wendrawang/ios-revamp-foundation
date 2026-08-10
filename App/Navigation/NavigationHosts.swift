import AuthenticationFeature
import CoreFeatureFlags
import DashboardFeature
import DesignSystem
import FinancialHubFeature
import MoreFeature
import RewardsFeature
import ScanFeature
import SwiftUI
import TransferFeature
import UpgradeServiceFeature
import WealthFeature

struct UnauthenticatedNavigationHost: View {
    @ObservedObject var store: UnauthenticatedNavigationStore
    let coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: store.pathBinding) {
            LoginScreen(authenticator: FakeAuthenticationService()) { authenticationOutput in
                coordinator.handleAuthenticationOutput(authenticationOutput)
            }
            .navigationDestination(for: AuthenticationRoute.self) { route in
                switch route {
                case .login:
                    LoginScreen(authenticator: FakeAuthenticationService()) { authenticationOutput in
                        coordinator.handleAuthenticationOutput(authenticationOutput)
                    }
                case .registrationContinuation(let token):
                    RegistrationContinuationScreen(token: token)
                }
            }
        }
    }
}

struct AuthenticatedNavigationHost: View {
    @ObservedObject var store: AuthenticatedNavigationStore
    @ObservedObject var lifecycle: AppLifecycleController
    @ObservedObject var blockers: GlobalBlockerController
    let coordinator: AppCoordinator
    let scope: AuthenticatedFlowScope

    private var composition: AppComposition { AppComposition(coordinator: coordinator) }

    var body: some View {
        NavigationStack(path: store.pathBinding) {
            MainTabContainer(
                store: store,
                lifecycle: lifecycle,
                blockers: blockers,
                scope: scope,
                coordinator: coordinator
            )
            .navigationDestination(for: TransferRoute.self) { route in
                if let session = coordinator.sessionScope {
                    TransferScreen(
                        route: route,
                        service: session.transferService,
                        analytics: coordinator.container.analytics,
                        navigate: { transferRoute in
                            store.push(
                                transferRoute,
                                screen: ScreenDescriptor(identifier: screenID(for: transferRoute))
                            )
                        },
                        output: { transferOutput in composition.handle(transferOutput) }
                    )
                }
            }
            .navigationDestination(for: WealthRoute.self) { route in
                if let session = coordinator.sessionScope {
                    switch route {
                    case .product(let productIdentifier):
                        WealthProductScreen(productID: productIdentifier, service: session.wealthService)
                    }
                }
            }
            .navigationDestination(for: RewardsRoute.self) { route in
                switch route {
                case .detail(let rewardIdentifier):
                    RewardDetailScreen(rewardID: rewardIdentifier)
                }
            }
            .navigationDestination(for: UpgradeServiceRoute.self) { _ in
                UpgradeServiceScreen()
            }
            .navigationDestination(for: AppWebRoute.self) { _ in
                SecureWebDestination(coordinator: coordinator)
            }
        }
    }

    // Mengubah route internal Transfer menjadi privacy-safe analytics identifier.
    private func screenID(for route: TransferRoute) -> String {
        switch route {
        case .landing: "transfer.landing"
        case .result: "transfer.result"
        }
    }
}

struct MainTabContainer: View {
    @ObservedObject var store: AuthenticatedNavigationStore
    @ObservedObject var lifecycle: AppLifecycleController
    @ObservedObject var blockers: GlobalBlockerController
    let scope: AuthenticatedFlowScope
    let coordinator: AppCoordinator

    private var composition: AppComposition { AppComposition(coordinator: coordinator) }

    var body: some View {
        TabView(selection: store.selectedTabBinding) {
            DashboardRootView(isTransferEnabled: true) { dashboardOutput in
                composition.handle(dashboardOutput)
            }
            .tag(AppTab.dashboard)

            FinancialHubRootView(
                isWealthEnabled: coordinator.container.featureFlags.isEnabled(.wealthEntryEnabled)
            ) { financialOutput in
                composition.handle(financialOutput)
            }
            .tag(AppTab.financial)

            ScanRootView(
                viewModel: scope.scanViewModel,
                isOperational: activity.isOperational(.scan)
            )
            .tag(AppTab.scan)

            RewardsRootView { rewardIdentifier in
                composition.openRewardDetail(rewardIdentifier)
            }
            .tag(AppTab.rewards)

            MoreRootView(isWebEnabled: coordinator.container.featureFlags.isEnabled(.webSampleEnabled)) {
                moreOutput in
                composition.handle(moreOutput)
            }
            .tag(AppTab.more)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DSCustomTabBar(items: tabItems, selection: store.selectedTab) { selectedTab in
                store.selectTab(selectedTab)
            }
        }
    }

    private var activity: TabActivityState {
        TabActivityState(
            selectedTab: store.selectedTab,
            lifecycle: lifecycle.state,
            isGloballyBlocked: blockers.isBlocking
        )
    }

    private var tabItems: [DSTabItem<AppTab>] {
        [
            DSTabItem(
                identifier: .dashboard, title: "Home", systemImage: "house",
                accessibilityIdentifier: AppAccessibilityID.tabDashboard),
            DSTabItem(
                identifier: .financial, title: "Financial", systemImage: "chart.pie",
                accessibilityIdentifier: AppAccessibilityID.tabFinancial),
            DSTabItem(
                identifier: .scan, title: "Scan", systemImage: "qrcode.viewfinder",
                accessibilityIdentifier: AppAccessibilityID.tabScan, isElevated: true),
            DSTabItem(
                identifier: .rewards, title: "Rewards", systemImage: "gift",
                accessibilityIdentifier: AppAccessibilityID.tabRewards),
            DSTabItem(
                identifier: .more, title: "More", systemImage: "circle.grid.2x2",
                accessibilityIdentifier: AppAccessibilityID.tabMore),
        ]
    }
}
