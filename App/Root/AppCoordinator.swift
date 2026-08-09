import AuthenticationFeature
import Combine
import CoreSession
import Foundation
import TransferFeature
import WealthFeature

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var phase: AppPhase = .launching
    @Published private(set) var authenticatedState: AuthenticatedFlowState = .preparing
    @Published private(set) var authenticatedFlowScope: AuthenticatedFlowScope?
    @Published private(set) var sessionScope: SessionScope?

    let unauthenticatedNavigation: UnauthenticatedNavigationStore
    let authenticatedNavigation: AuthenticatedNavigationStore
    let container: AppContainer
    let deepLinks: DeepLinkOrchestrator

    private var pipelineTask: Task<Void, Never>?

    init(container: AppContainer) {
        self.container = container
        let screenVisits = ScreenVisitCoordinator(analytics: container.analytics)
        unauthenticatedNavigation = UnauthenticatedNavigationStore { screen in
            screenVisits.screenBecameTopmost(screen)
            AppPerformanceSignposts.navigationCommitted(screenID: screen.id)
        }
        authenticatedNavigation = AuthenticatedNavigationStore { screen in
            screenVisits.screenBecameTopmost(screen)
            AppPerformanceSignposts.navigationCommitted(screenID: screen.id)
        }
        deepLinks = DeepLinkOrchestrator(
            registry: container.deepLinkRegistry,
            pendingStore: PendingDeepLinkStore()
        )
    }

    func start(arguments: [String] = ProcessInfo.processInfo.arguments) {
        pipelineTask?.cancel()
        pipelineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self, !Task.isCancelled else { return }
            phase = .unauthenticated
            if let index = arguments.firstIndex(of: "-deepLink"), arguments.indices.contains(index + 1),
               let url = URL(string: arguments[index + 1]) {
                handleDeepLink(url, source: .launchArgument)
            }
        }
    }

    func handleAuthenticationOutput(_ output: AuthenticationOutput) {
        switch output {
        case let .authenticated(credentials):
            pipelineTask?.cancel()
            pipelineTask = Task { [weak self] in
                await self?.establishSession(credentials)
            }
        }
    }

    func handleDeepLink(_ url: URL, source: DeepLinkSource) {
        let request = DeepLinkRequest(url: url, source: source)
        guard let resolution = deepLinks.resolve(request) else { return }

        switch resolution.authentication {
        case .unauthenticated:
            guard phase != .authenticated else { return }
            phase = .unauthenticated
            resolution.applyUnauthenticated?(unauthenticatedNavigation)
        case .authenticated:
            guard sessionScope != nil else {
                deepLinks.savePending(request)
                phase = .unauthenticated
                unauthenticatedNavigation.popToRoot()
                return
            }
            executeAuthenticatedResolution(resolution)
        case .either:
            if phase == .authenticated {
                resolution.applyAuthenticated?(authenticatedNavigation)
            } else {
                phase = .unauthenticated
                resolution.applyUnauthenticated?(unauthenticatedNavigation)
            }
        }
    }

    func recognizesDeepLink(_ url: URL) -> Bool {
        deepLinks.recognizes(url)
    }

    func logout() {
        pipelineTask?.cancel()
        pipelineTask = Task { [weak self] in
            guard let self else { return }
            authenticatedFlowScope?.deactivate()
            authenticatedFlowScope = nil
            await sessionScope?.invalidate()
            sessionScope = nil
            authenticatedNavigation.resetWithoutTracking()
            unauthenticatedNavigation.resetWithoutTracking()
            deepLinks.clearPending()
            authenticatedState = .preparing
            phase = .unauthenticated
        }
    }

    private func establishSession(_ credentials: SessionCredentials) async {
        do {
            try await container.credentialManager.establish(credentials)
            let session = SessionScope(
                credentials: credentials,
                credentialManager: container.credentialManager,
                transferService: FakeTransferService(),
                wealthService: FakeWealthService()
            )
            sessionScope = session
            authenticatedFlowScope = AuthenticatedFlowScope()

            if let pending = deepLinks.takePending(), let resolution = deepLinks.resolve(pending) {
                executeAuthenticatedResolution(resolution)
            } else {
                authenticatedNavigation.resetWithoutTracking()
                authenticatedState = .ready
                phase = .authenticated
            }
        } catch {
            container.presentationController.present(GlobalPresentation(
                id: "session-establishment-failed",
                title: "Unable to create session",
                message: "Please try signing in again.",
                primaryButtonTitle: "Close"
            ))
            phase = .unauthenticated
        }
    }

    private func executeAuthenticatedResolution(_ resolution: ResolvedDeepLink) {
        pipelineTask?.cancel()
        pipelineTask = Task { [weak self] in
            guard let self else { return }
            phase = .authenticated
            if resolution.requiresPreflight {
                authenticatedState = .preparing
                let signpostID = AppPerformanceSignposts.beginAuthenticatedPreflight(
                    identifier: resolution.identifier
                )
                defer {
                    AppPerformanceSignposts.endAuthenticatedPreflight(
                        signpostID,
                        identifier: resolution.identifier
                    )
                }
                do {
                    try await resolution.preflight?()
                    guard !Task.isCancelled else { return }
                } catch {
                    container.presentationController.present(GlobalPresentation(
                        id: "preflight-failed",
                        title: "Unable to prepare destination",
                        message: "Please try again later.",
                        primaryButtonTitle: "Close"
                    ))
                    authenticatedNavigation.openCanonical(
                        tab: .dashboard,
                        destination: Optional<NavigationDestination<TransferRoute>>.none
                    )
                    authenticatedState = .ready
                    return
                }
            }
            resolution.applyAuthenticated?(authenticatedNavigation)
            authenticatedState = .ready
        }
    }
}
