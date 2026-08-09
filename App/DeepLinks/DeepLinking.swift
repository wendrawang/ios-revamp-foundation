import AuthenticationFeature
import CoreFeatureFlags
import Foundation
import RewardsFeature
import WealthFeature

enum DeepLinkSource: String, Equatable, Sendable {
    case pushNotification
    case universalOrAppURL
    case webView
    case qr
    case banner
    case launchArgument
}

enum AuthenticationRequirement: Equatable, Sendable {
    case unauthenticated
    case authenticated
    case either
}

struct DeepLinkRequest: Equatable, Sendable {
    let url: URL
    let source: DeepLinkSource
}

@MainActor
struct ResolvedDeepLink {
    let identifier: String
    let authentication: AuthenticationRequirement
    let requiresPreflight: Bool
    let preflight: (@Sendable () async throws -> Void)?
    let applyUnauthenticated: ((UnauthenticatedNavigationStore) -> Void)?
    let applyAuthenticated: ((AuthenticatedNavigationStore) -> Void)?
}

@MainActor
struct DeepLinkRegistration {
    let identifier: String
    let resolve: (URL) -> ResolvedDeepLink?
}

@MainActor
final class DeepLinkRegistry {
    private let registrations: [DeepLinkRegistration]

    init(registrations: [DeepLinkRegistration]) {
        self.registrations = registrations
    }

    func resolve(_ url: URL) -> ResolvedDeepLink? {
        for registration in registrations {
            if let resolution = registration.resolve(url) { return resolution }
        }
        return nil
    }

    func recognizes(_ url: URL) -> Bool {
        resolve(url) != nil
    }
}

@MainActor
final class PendingDeepLinkStore {
    private(set) var request: DeepLinkRequest?

    func save(_ request: DeepLinkRequest) {
        self.request = request
    }

    func take() -> DeepLinkRequest? {
        defer { request = nil }
        return request
    }

    func clear() {
        request = nil
    }
}

@MainActor
final class DeepLinkOrchestrator {
    private let registry: DeepLinkRegistry
    private let pendingStore: PendingDeepLinkStore

    init(registry: DeepLinkRegistry, pendingStore: PendingDeepLinkStore) {
        self.registry = registry
        self.pendingStore = pendingStore
    }

    func recognizes(_ url: URL) -> Bool {
        registry.recognizes(url)
    }

    func resolve(_ request: DeepLinkRequest) -> ResolvedDeepLink? {
        registry.resolve(request.url)
    }

    func savePending(_ request: DeepLinkRequest) {
        pendingStore.save(request)
    }

    func takePending() -> DeepLinkRequest? {
        pendingStore.take()
    }

    func clearPending() {
        pendingStore.clear()
    }
}

@MainActor
enum DeepLinkRegistryFactory {
    static func make(featureFlags: any FeatureFlagProviding) -> DeepLinkRegistry {
        let authenticationParser = AuthenticationDeepLinkParser()
        let rewardsParser = RewardsDeepLinkParser()
        let wealthParser = WealthDeepLinkParser()

        return DeepLinkRegistry(registrations: [
            DeepLinkRegistration(identifier: "authentication") { url in
                guard case let .registrationContinuation(token)? = authenticationParser.parse(url) else { return nil }
                return ResolvedDeepLink(
                    identifier: "registration.continuation",
                    authentication: .unauthenticated,
                    requiresPreflight: false,
                    preflight: nil,
                    applyUnauthenticated: { store in
                        store.popToRoot()
                        store.push(
                            AuthenticationRoute.registrationContinuation(token: token),
                            screen: ScreenDescriptor(id: "auth.registration.continuation")
                        )
                    },
                    applyAuthenticated: nil
                )
            },
            DeepLinkRegistration(identifier: "rewards") { url in
                guard let intent = rewardsParser.parse(url) else { return nil }
                switch intent {
                case .root:
                    return ResolvedDeepLink(
                        identifier: "rewards.root",
                        authentication: .authenticated,
                        requiresPreflight: false,
                        preflight: nil,
                        applyUnauthenticated: nil,
                        applyAuthenticated: { store in
                            store.openCanonical(
                                tab: .rewards,
                                destination: Optional<NavigationDestination<RewardsRoute>>.none
                            )
                        }
                    )
                case let .detail(id):
                    return ResolvedDeepLink(
                        identifier: "rewards.detail",
                        authentication: .authenticated,
                        requiresPreflight: false,
                        preflight: nil,
                        applyUnauthenticated: nil,
                        applyAuthenticated: { store in
                            store.openCanonical(
                                tab: .rewards,
                                destination: NavigationDestination(
                                    route: RewardsRoute.detail(id: id),
                                    screen: ScreenDescriptor(id: "rewards.detail")
                                )
                            )
                        }
                    )
                }
            },
            DeepLinkRegistration(identifier: "wealth") { url in
                guard featureFlags.isEnabled(.wealthEntryEnabled),
                      case let .product(id)? = wealthParser.parse(url) else { return nil }
                let preflight = DummyWealthPreflightUseCase(delayNanoseconds: 250_000_000)
                return ResolvedDeepLink(
                    identifier: "wealth.product",
                    authentication: .authenticated,
                    requiresPreflight: true,
                    preflight: { try await preflight.prepare(productID: id) },
                    applyUnauthenticated: nil,
                    applyAuthenticated: { store in
                        store.openCanonical(
                            tab: .financial,
                            destination: NavigationDestination(
                                route: WealthRoute.product(id: id),
                                screen: ScreenDescriptor(id: "wealth.product")
                            )
                        )
                    }
                )
            },
        ])
    }
}
