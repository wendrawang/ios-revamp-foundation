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
    let isPreflightRequired: Bool
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

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(registrations: [DeepLinkRegistration]) {
        self.registrations = registrations
    }

    // Mencari resolver domain yang mengenali URL atau request ini.
    func resolve(_ url: URL) -> ResolvedDeepLink? {
        for registration in registrations {
            if let resolution = registration.resolve(url) { return resolution }
        }
        return nil
    }

    // Memeriksa apakah URL dikenali sebagai application deep link.
    func recognizes(_ url: URL) -> Bool {
        resolve(url) != nil
    }
}

@MainActor
final class PendingDeepLinkStore {
    private(set) var request: DeepLinkRequest?

    // Menyimpan pending deep link sampai authentication selesai.
    func save(_ request: DeepLinkRequest) {
        self.request = request
    }

    // Mengambil sekaligus menghapus pending deep link yang tersimpan.
    func take() -> DeepLinkRequest? {
        defer { request = nil }
        return request
    }

    // Menghapus pending state agar tidak bocor ke session berikutnya.
    func clear() {
        request = nil
    }
}

@MainActor
final class DeepLinkOrchestrator {
    private let registry: DeepLinkRegistry
    private let pendingStore: PendingDeepLinkStore

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(registry: DeepLinkRegistry, pendingStore: PendingDeepLinkStore) {
        self.registry = registry
        self.pendingStore = pendingStore
    }

    // Memeriksa apakah URL dikenali sebagai application deep link.
    func recognizes(_ url: URL) -> Bool {
        registry.recognizes(url)
    }

    // Mencari resolver domain yang mengenali URL atau request ini.
    func resolve(_ request: DeepLinkRequest) -> ResolvedDeepLink? {
        registry.resolve(request.url)
    }

    // Meneruskan request ke penyimpanan pending authenticated deep link.
    func savePending(_ request: DeepLinkRequest) {
        pendingStore.save(request)
    }

    // Mengambil pending request untuk dilanjutkan setelah login.
    func takePending() -> DeepLinkRequest? {
        pendingStore.take()
    }

    // Membersihkan pending request saat flow dibatalkan atau logout.
    func clearPending() {
        pendingStore.clear()
    }
}

@MainActor
enum DeepLinkRegistryFactory {
    // Merakit registry global dari resolver yang tetap dimiliki masing-masing domain.
    static func make(featureFlags: any FeatureFlagProviding) -> DeepLinkRegistry {
        return DeepLinkRegistry(registrations: [
            authenticationRegistration(),
            rewardsRegistration(),
            wealthRegistration(featureFlags: featureFlags),
        ])
    }

    // Mendaftarkan parser dan navigation decision milik Authentication.
    private static func authenticationRegistration() -> DeepLinkRegistration {
        let parser = AuthenticationDeepLinkParser()
        return DeepLinkRegistration(identifier: "authentication") { url in
            guard case .registrationContinuation(let token)? = parser.parse(url) else { return nil }
            return ResolvedDeepLink(
                identifier: "registration.continuation",
                authentication: .unauthenticated,
                isPreflightRequired: false,
                preflight: nil,
                applyUnauthenticated: { store in
                    store.popToRoot()
                    store.push(
                        AuthenticationRoute.registrationContinuation(token: token),
                        screen: ScreenDescriptor(identifier: "auth.registration.continuation")
                    )
                },
                applyAuthenticated: nil
            )
        }
    }

    // Mendaftarkan root dan detail deep link milik Rewards.
    private static func rewardsRegistration() -> DeepLinkRegistration {
        let parser = RewardsDeepLinkParser()
        return DeepLinkRegistration(identifier: "rewards") { url in
            guard let intent = parser.parse(url) else { return nil }
            switch intent {
            case .root:
                return ResolvedDeepLink(
                    identifier: "rewards.root",
                    authentication: .authenticated,
                    isPreflightRequired: false,
                    preflight: nil,
                    applyUnauthenticated: nil,
                    applyAuthenticated: { store in
                        store.openCanonical(
                            tab: .rewards,
                            destination: Optional<NavigationDestination<RewardsRoute>>.none
                        )
                    }
                )
            case .detail(let rewardIdentifier):
                return rewardDetailResolution(rewardIdentifier: rewardIdentifier)
            }
        }
    }

    // Membuat typed Rewards detail decision tanpa mengekspos payload ke router global.
    private static func rewardDetailResolution(rewardIdentifier: String) -> ResolvedDeepLink {
        ResolvedDeepLink(
            identifier: "rewards.detail",
            authentication: .authenticated,
            isPreflightRequired: false,
            preflight: nil,
            applyUnauthenticated: nil,
            applyAuthenticated: { store in
                store.openCanonical(
                    tab: .rewards,
                    destination: NavigationDestination(
                        route: RewardsRoute.detail(identifier: rewardIdentifier),
                        screen: ScreenDescriptor(identifier: "rewards.detail")
                    )
                )
            }
        )
    }

    // Mendaftarkan Wealth deep link dan dedicated authenticated preflight.
    private static func wealthRegistration(
        featureFlags: any FeatureFlagProviding
    ) -> DeepLinkRegistration {
        let parser = WealthDeepLinkParser()
        return DeepLinkRegistration(identifier: "wealth") { url in
            guard featureFlags.isEnabled(.wealthEntryEnabled),
                case .product(let productIdentifier)? = parser.parse(url)
            else { return nil }
            let preflight = DummyWealthPreflightUseCase(delayNanoseconds: 250_000_000)
            return ResolvedDeepLink(
                identifier: "wealth.product",
                authentication: .authenticated,
                isPreflightRequired: true,
                preflight: { try await preflight.prepare(productID: productIdentifier) },
                applyUnauthenticated: nil,
                applyAuthenticated: { store in
                    store.openCanonical(
                        tab: .financial,
                        destination: NavigationDestination(
                            route: WealthRoute.product(identifier: productIdentifier),
                            screen: ScreenDescriptor(identifier: "wealth.product")
                        )
                    )
                }
            )
        }
    }
}
