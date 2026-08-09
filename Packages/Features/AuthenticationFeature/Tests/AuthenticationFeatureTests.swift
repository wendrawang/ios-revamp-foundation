import AuthenticationFeature
import CoreSession
import Foundation
import Testing

private enum StubAuthenticationMode: Sendable {
    case success(SessionCredentials)
    case failure
    case suspended
}

private struct StubAuthenticator: Authenticating {
    let mode: StubAuthenticationMode

    // Memvalidasi credential dan mengembalikan authenticated session value.
    func authenticate(password: String) async throws -> SessionCredentials {
        switch mode {
        case .success(let credentials):
            return credentials
        case .failure:
            throw AuthenticationError.invalidCredentials
        case .suspended:
            try await Task.sleep(nanoseconds: 2_000_000_000)
            throw CancellationError()
        }
    }
}

private final class WeakReference<Object: AnyObject> {
    weak var value: Object?
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(_ value: Object?) { self.value = value }
}

// Menunggu perubahan async dengan timeout agar test tidak menggantung.
@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    Issue.record("Timed out waiting for view-model state")
}

// Memverifikasi registration continuation deep link parses.
@Test func registrationContinuationDeepLinkParses() {
    let url = URL(string: "iosrevamp://registration/continue?token=demo")!
    #expect(AuthenticationDeepLinkParser().parse(url) == .registrationContinuation(token: "demo"))
}

// Memverifikasi unrelated deep link does not parse as authentication.
@Test func unrelatedDeepLinkDoesNotParseAsAuthentication() {
    let url = URL(string: "iosrevamp://rewards")!
    #expect(AuthenticationDeepLinkParser().parse(url) == nil)
}

// Memverifikasi fake authentication rejects empty password.
@Test func fakeAuthenticationRejectsEmptyPassword() async {
    do {
        _ = try await FakeAuthenticationService().authenticate(password: "")
        Issue.record("Expected empty-password failure")
    } catch let error as AuthenticationError {
        #expect(error == .emptyPassword)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

// Memverifikasi login view model publishes successful output.
@MainActor
@Test func loginViewModelPublishesSuccessfulOutput() async throws {
    let credentials = SessionCredentials(accessToken: "a", refreshToken: "r", userID: "u")
    var receivedOutput: AuthenticationOutput?
    let viewModel = LoginViewModel(
        authenticator: StubAuthenticator(mode: .success(credentials)),
        output: { receivedOutput = $0 }
    )

    viewModel.submit()
    try await waitUntil { receivedOutput != nil }

    #expect(receivedOutput == .authenticated(credentials))
    #expect(!viewModel.isLoading)
    #expect(viewModel.errorMessage == nil)
}

// Memverifikasi login view model maps failure to safe message.
@MainActor
@Test func loginViewModelMapsFailureToSafeMessage() async throws {
    let viewModel = LoginViewModel(
        authenticator: StubAuthenticator(mode: .failure),
        output: { _ in Issue.record("Failure must not authenticate") }
    )

    viewModel.submit()
    try await waitUntil { viewModel.errorMessage != nil }

    #expect(viewModel.errorMessage == "Unable to sign in.")
    #expect(!viewModel.isLoading)
}

// Memverifikasi login cancellation stops work and view model releases.
@MainActor
@Test func loginCancellationStopsWorkAndViewModelReleases() async throws {
    let weakViewModel = WeakReference<LoginViewModel>(nil)
    var outputCount = 0
    do {
        let viewModel = LoginViewModel(
            authenticator: StubAuthenticator(mode: .suspended),
            output: { _ in outputCount += 1 }
        )
        weakViewModel.value = viewModel
        viewModel.submit()
        #expect(viewModel.isLoading)
        viewModel.cancel()
        #expect(!viewModel.isLoading)
    }
    try await Task.sleep(nanoseconds: 10_000_000)

    #expect(outputCount == 0)
    #expect(weakViewModel.value == nil)
}
