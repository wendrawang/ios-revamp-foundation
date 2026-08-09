@testable import IOSRevampFoundation
import AuthenticationFeature
import CoreSession
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
