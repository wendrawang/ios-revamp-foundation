import AuthenticationFeature
import CoreSession
import TransferFeature
import WealthFeature
import XCTest

@testable import IOSRevampFoundation

@MainActor
final class DeepLinkAndSessionTests: XCTestCase {
    // Memverifikasi authenticated deep link is pending then opens directly after login.
    func testAuthenticatedDeepLinkIsPendingThenOpensDirectlyAfterLogin() async throws {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let url = try XCTUnwrap(URL(string: "iosrevamp://rewards/detail?id=reward-001"))

        coordinator.handleDeepLink(url, source: .pushNotification)
        XCTAssertEqual(coordinator.phase, .unauthenticated)

        coordinator.handleAuthenticationOutput(.authenticated(demoCredentials))
        try await waitUntil { coordinator.phase == .authenticated && coordinator.authenticatedState == .ready }

        XCTAssertEqual(coordinator.authenticatedNavigation.selectedTab, .rewards)
        XCTAssertEqual(coordinator.authenticatedNavigation.pathCount, 1)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "rewards.detail")
    }

    // Memverifikasi registration deep link stays unauthenticated.
    func testRegistrationDeepLinkStaysUnauthenticated() throws {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let url = try XCTUnwrap(URL(string: "iosrevamp://registration/continue?token=demo"))

        coordinator.handleDeepLink(url, source: .universalOrAppURL)

        XCTAssertEqual(coordinator.phase, .unauthenticated)
        XCTAssertEqual(coordinator.unauthenticatedNavigation.pathCount, 1)
        XCTAssertEqual(coordinator.unauthenticatedNavigation.topScreen.id, "auth.registration.continuation")
    }

    // Memverifikasi preflight uses authenticated preparing before ready.
    func testPreflightUsesAuthenticatedPreparingBeforeReady() async throws {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let url = try XCTUnwrap(URL(string: "iosrevamp://wealth/product?id=wealth-001"))
        coordinator.handleDeepLink(url, source: .pushNotification)
        coordinator.handleAuthenticationOutput(.authenticated(demoCredentials))

        try await waitUntil { coordinator.phase == .authenticated }
        XCTAssertEqual(coordinator.authenticatedState, .preparing)

        try await waitUntil { coordinator.authenticatedState == .ready }
        XCTAssertEqual(coordinator.authenticatedNavigation.selectedTab, .financial)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "wealth.product")
    }

    // Memverifikasi logout releases uiscope and session scope.
    func testLogoutReleasesUIScopeAndSessionScope() async throws {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        coordinator.handleAuthenticationOutput(.authenticated(demoCredentials))
        try await waitUntil { coordinator.authenticatedState == .ready && coordinator.sessionScope != nil }

        let weakSession = WeakReference(coordinator.sessionScope)
        let weakFlow = WeakReference(coordinator.authenticatedFlowScope)

        coordinator.logout()
        try await waitUntil { coordinator.phase == .unauthenticated && coordinator.sessionScope == nil }

        XCTAssertNil(weakFlow.value)
        XCTAssertNil(weakSession.value)
        XCTAssertEqual(coordinator.authenticatedNavigation.pathCount, 0)
    }

    // Memverifikasi registry recognizes every supported domain and rejects unknown url.
    func testRegistryRecognizesEverySupportedDomainAndRejectsUnknownURL() throws {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let supported = [
            "iosrevamp://registration/continue?token=demo",
            "iosrevamp://rewards",
            "iosrevamp://rewards/detail?id=reward-001",
            "iosrevamp://wealth/product?id=wealth-001",
        ]

        for value in supported {
            XCTAssertTrue(coordinator.recognizesDeepLink(try XCTUnwrap(URL(string: value))))
        }
        XCTAssertFalse(
            coordinator.recognizesDeepLink(
                try XCTUnwrap(URL(string: "iosrevamp://unknown/path"))
            ))
    }

    // Memverifikasi authenticated reward root selects rewards without pushed detail.
    func testAuthenticatedRewardRootSelectsRewardsWithoutPushedDetail() async throws {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        coordinator.handleAuthenticationOutput(.authenticated(demoCredentials))
        try await waitUntil { coordinator.phase == .authenticated && coordinator.authenticatedState == .ready }

        coordinator.handleDeepLink(
            try XCTUnwrap(URL(string: "iosrevamp://rewards")),
            source: .universalOrAppURL
        )
        try await waitUntil { coordinator.authenticatedNavigation.selectedTab == .rewards }

        XCTAssertEqual(coordinator.authenticatedNavigation.pathCount, 0)
        XCTAssertEqual(coordinator.authenticatedNavigation.topScreen.id, "tab.rewards")
    }

    // Memverifikasi session invalidation cancels owned tasks.
    func testSessionInvalidationCancelsOwnedTasks() async {
        let container = AppContainer(isUITesting: true)
        let session = SessionScope(
            credentials: demoCredentials,
            credentialManager: container.credentialManager,
            transferService: FakeTransferService(),
            wealthService: FakeWealthService()
        )
        let task = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        session.retainBackgroundTask(task)

        await session.invalidate()

        XCTAssertTrue(task.isCancelled)
        XCTAssertTrue(session.isInvalidated)
    }

    private var demoCredentials: SessionCredentials {
        SessionCredentials(accessToken: "access", refreshToken: "refresh", userID: "user")
    }

    // Menunggu perubahan async dengan timeout agar test tidak menggantung.
    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for state")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
