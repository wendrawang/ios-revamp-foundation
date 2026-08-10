import DesignSystem
import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            DSColor.accent.ignoresSafeArea()
            VStack(spacing: DSSpacing.medium) {
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
        VStack(spacing: DSSpacing.large) {
            ProgressView().controlSize(.large)
            Text("Preparing your secure destination").font(.headline)
            Text("Completing the required inquiry before navigation.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.large)
        .accessibilityIdentifier(AppAccessibilityID.authenticatedPreparing)
    }
}

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator: AppCoordinator

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
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
        .onChange(of: scenePhase) { updatedPhase in
            coordinator.container.lifecycleController.transition(from: updatedPhase)
        }
        .onOpenURL { openedURL in
            coordinator.handleDeepLink(openedURL, source: .universalOrAppURL)
        }
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
