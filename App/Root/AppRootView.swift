import DesignSystem
import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            DSColor.accent.ignoresSafeArea()
            VStack(spacing: DSSpacing.md) {
                Image(systemName: "building.columns.fill").font(.system(size: 64))
                Text("IOS Revamp Foundation").font(.title.bold())
            }
            .foregroundStyle(.white)
        }
        .accessibilityIdentifier(AppAccessibilityID.splash)
    }
}

struct AuthenticatedPreparingView: View {
    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            ProgressView().controlSize(.large)
            Text("Preparing your secure destination").font(.headline)
            Text("Completing the required inquiry before navigation.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .accessibilityIdentifier(AppAccessibilityID.authenticatedPreparing)
    }
}

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        ZStack {
            flow
            GlobalPresentationHost(controller: coordinator.container.presentationController)
            GlobalBlockerHost(controller: coordinator.container.blockerController)
        }
        .onAppear {
            coordinator.container.lifecycleController.transition(from: scenePhase)
            coordinator.start()
        }
        .onChange(of: scenePhase) {
            coordinator.container.lifecycleController.transition(from: $0)
        }
        .onOpenURL { coordinator.handleDeepLink($0, source: .universalOrAppURL) }
    }

    @ViewBuilder private var flow: some View {
        switch coordinator.phase {
        case .launching:
            SplashView()
        case .unauthenticated:
            UnauthenticatedNavigationHost(
                store: coordinator.unauthenticatedNavigation,
                coordinator: coordinator
            )
        case .authenticated:
            switch coordinator.authenticatedState {
            case .preparing:
                AuthenticatedPreparingView()
            case .ready:
                if let scope = coordinator.authenticatedFlowScope {
                    AuthenticatedNavigationHost(
                        store: coordinator.authenticatedNavigation,
                        lifecycle: coordinator.container.lifecycleController,
                        blockers: coordinator.container.blockerController,
                        coordinator: coordinator,
                        scope: scope
                    )
                }
            }
        }
    }
}
