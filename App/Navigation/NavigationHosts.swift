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
            LoginScreen(authenticator: FakeAuthenticationService()) {
                coordinator.handleAuthenticationOutput($0)
            }
            .navigationDestination(for: AuthenticationRoute.self) { route in
                switch route {
                case .login:
                    LoginScreen(authenticator: FakeAuthenticationService()) {
                        coordinator.handleAuthenticationOutput($0)
                    }
                case let .registrationContinuation(token):
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
                        navigate: {
                            store.push($0, screen: ScreenDescriptor(id: screenID(for: $0)))
                        },
                        output: { composition.handle($0) }
                    )
                }
            }
            .navigationDestination(for: WealthRoute.self) { route in
                if let session = coordinator.sessionScope {
                    switch route {
                    case let .product(id):
                        WealthProductScreen(productID: id, service: session.wealthService)
                    }
                }
            }
            .navigationDestination(for: RewardsRoute.self) { route in
                switch route {
                case let .detail(id): RewardDetailScreen(rewardID: id)
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
            DashboardRootView(isTransferEnabled: true) { composition.handle($0) }
                .tag(AppTab.dashboard)

            FinancialHubRootView(
                isWealthEnabled: coordinator.container.featureFlags.isEnabled(.wealthEntryEnabled)
            ) { composition.handle($0) }
                .tag(AppTab.financial)

            ScanRootView(
                viewModel: scope.scanViewModel,
                isOperational: activity.isOperational(.scan)
            )
            .tag(AppTab.scan)

            RewardsRootView { composition.openRewardDetail($0) }
                .tag(AppTab.rewards)

            MoreRootView(isWebEnabled: coordinator.container.featureFlags.isEnabled(.webSampleEnabled)) {
                composition.handle($0)
            }
            .tag(AppTab.more)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DSCustomTabBar(items: tabItems, selection: store.selectedTab) {
                store.selectTab($0)
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
            DSTabItem(id: .dashboard, title: "Home", systemImage: "house", accessibilityIdentifier: AppAccessibilityID.tabDashboard),
            DSTabItem(id: .financial, title: "Financial", systemImage: "chart.pie", accessibilityIdentifier: AppAccessibilityID.tabFinancial),
            DSTabItem(id: .scan, title: "Scan", systemImage: "qrcode.viewfinder", accessibilityIdentifier: AppAccessibilityID.tabScan, isElevated: true),
            DSTabItem(id: .rewards, title: "Rewards", systemImage: "gift", accessibilityIdentifier: AppAccessibilityID.tabRewards),
            DSTabItem(id: .more, title: "More", systemImage: "circle.grid.2x2", accessibilityIdentifier: AppAccessibilityID.tabMore),
        ]
    }
}
