@testable import IOSRevampFoundation
import AuthenticationFeature
import CoreSession
import TransferFeature
import WealthFeature
import XCTest

@MainActor
final class DeepLinkAndSessionTests: XCTestCase {
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

    func testRegistrationDeepLinkStaysUnauthenticated() throws {
        let coordinator = AppCoordinator(container: AppContainer(isUITesting: true))
        let url = try XCTUnwrap(URL(string: "iosrevamp://registration/continue?token=demo"))

        coordinator.handleDeepLink(url, source: .universalOrAppURL)

        XCTAssertEqual(coordinator.phase, .unauthenticated)
        XCTAssertEqual(coordinator.unauthenticatedNavigation.pathCount, 1)
        XCTAssertEqual(coordinator.unauthenticatedNavigation.topScreen.id, "auth.registration.continuation")
    }

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
        XCTAssertFalse(coordinator.recognizesDeepLink(
            try XCTUnwrap(URL(string: "iosrevamp://unknown/path"))
        ))
    }

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

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { XCTFail("Timed out waiting for state"); return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
