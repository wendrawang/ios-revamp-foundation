import Combine
import CoreSession
import DesignSystem
import Foundation
import SwiftUI

public enum AuthenticationAccessibilityID {
    public static let loginSubmit = "auth.login.submit"
    public static let registrationContinue = "auth.registration.continue"
}

public enum AuthenticationRoute: Hashable, Sendable {
    case login
    case registrationContinuation(token: String)
}

public enum AuthenticationDeepLinkIntent: Equatable, Sendable {
    case registrationContinuation(token: String)
}

public struct AuthenticationDeepLinkParser: Sendable {
    public init() {}

    public func parse(_ url: URL) -> AuthenticationDeepLinkIntent? {
        guard url.scheme?.lowercased() == "iosrevamp",
              url.host?.lowercased() == "registration",
              url.path == "/continue",
              let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            return nil
        }
        return .registrationContinuation(token: token)
    }
}

public enum AuthenticationOutput: Equatable, Sendable {
    case authenticated(SessionCredentials)
}

public protocol Authenticating: Sendable {
    func authenticate(password: String) async throws -> SessionCredentials
}

public enum AuthenticationError: Error, Equatable, Sendable {
    case emptyPassword
    case invalidCredentials
}

public struct FakeAuthenticationService: Authenticating {
    public init() {}

    public func authenticate(password: String) async throws -> SessionCredentials {
        guard !password.isEmpty else { throw AuthenticationError.emptyPassword }
        try await Task.sleep(nanoseconds: 80_000_000)
        try Task.checkCancellation()
        return SessionCredentials(accessToken: "demo-access", refreshToken: "demo-refresh", userID: "demo-user")
    }
}

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var password = "password"
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let authenticator: any Authenticating
    private let output: @MainActor (AuthenticationOutput) -> Void
    private var task: Task<Void, Never>?

    public init(
        authenticator: any Authenticating,
        output: @escaping @MainActor (AuthenticationOutput) -> Void
    ) {
        self.authenticator = authenticator
        self.output = output
    }

    public func submit() {
        task?.cancel()
        isLoading = true
        errorMessage = nil
        let password = password
        task = Task { [weak self, authenticator, output] in
            do {
                let credentials = try await authenticator.authenticate(password: password)
                guard !Task.isCancelled else { return }
                self?.isLoading = false
                output(.authenticated(credentials))
            } catch is CancellationError {
                self?.isLoading = false
            } catch {
                self?.isLoading = false
                self?.errorMessage = "Unable to sign in."
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }

    deinit {
        task?.cancel()
    }
}

public struct LoginScreen: View {
    @StateObject private var viewModel: LoginViewModel

    public init(
        authenticator: any Authenticating,
        output: @escaping @MainActor (AuthenticationOutput) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authenticator: authenticator, output: output))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text("Welcome back").font(.largeTitle.bold())
            Text("Use the demo password to continue.").foregroundStyle(.secondary)
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .padding()
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 12))
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            DSPrimaryButton(title: viewModel.isLoading ? "Signing in…" : "Log in", accessibilityIdentifier: AuthenticationAccessibilityID.loginSubmit) {
                viewModel.submit()
            }
            .disabled(viewModel.isLoading)
            Spacer()
        }
        .padding(DSSpacing.lg)
        .navigationTitle("Password")
        .onDisappear { viewModel.cancel() }
    }
}

public struct RegistrationContinuationScreen: View {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 52)).foregroundStyle(DSColor.accent)
            Text("Continue registration").font(.title2.bold())
            Text("Your secure registration invitation was recognized.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("Reference: \(token.prefix(4))•••").font(.caption).foregroundStyle(.secondary)
        }
        .padding(DSSpacing.lg)
        .navigationTitle("Registration")
        .accessibilityIdentifier(AuthenticationAccessibilityID.registrationContinue)
    }
}
