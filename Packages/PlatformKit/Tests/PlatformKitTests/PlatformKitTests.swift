import CoreAnalytics
import CoreFeatureFlags
import CoreLogging
import CoreNetworking
import CoreSecurity
import CoreSession
import Foundation
import Testing

private final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() -> Int {
        lock.withLock {
            storage += 1
            return storage
        }
    }

    var value: Int { lock.withLock { storage } }
}

@Test func analyticsStoresPrivacySafeEvents() {
    let analytics = InMemoryAnalytics()
    analytics.track(AnalyticsEvent(name: "screen_visit", properties: ["screen": "rewards.detail"]))

    #expect(analytics.events() == [
        AnalyticsEvent(name: "screen_visit", properties: ["screen": "rewards.detail"]),
    ])
}

@Test func sensitiveLoggingFieldsAreRedacted() {
    let logger = InMemoryLogger()
    logger.log(LogEntry(
        level: .info,
        category: "test",
        message: "Login",
        fields: [LogField(name: "token", value: "secret-token", privacy: .sensitive)]
    ))

    let rendered = logger.entries().map(\.sanitizedDescription).joined()
    #expect(!rendered.contains("secret-token"))
    #expect(rendered.contains("<redacted>"))
}

@Test func inMemoryFeatureFlagsAreDeterministic() {
    let flags = InMemoryFeatureFlags(enabled: [.wealthEntryEnabled], logger: InMemoryLogger())
    #expect(flags.isEnabled(.wealthEntryEnabled))
    flags.set(.wealthEntryEnabled, enabled: false)
    #expect(!flags.isEnabled(.wealthEntryEnabled))
}

@Test func HTTPClientUsesTransportAndDecodesResponse() async throws {
    struct Payload: Codable, Equatable, Sendable { let value: String }
    let transport = ClosureHTTPTransport { request in
        #expect(request.url?.absoluteString == "https://example.test/value")
        return HTTPResponse(statusCode: 200, body: Data("{\"value\":\"ok\"}".utf8))
    }
    let client = DefaultHTTPClient(
        baseURL: URL(string: "https://example.test")!,
        transport: transport,
        logger: InMemoryLogger()
    )

    let response = try await client.send(HTTPRequest(path: "/value"))
    #expect(try response.decode(Payload.self) == Payload(value: "ok"))
}

@Test func HTTPClientRetriesOnlyConfiguredStatuses() async throws {
    let attempts = AttemptCounter()
    let transport = ClosureHTTPTransport { _ in
        attempts.increment() == 1
            ? HTTPResponse(statusCode: 503, body: Data())
            : HTTPResponse(statusCode: 200, body: Data("ok".utf8))
    }
    let client = DefaultHTTPClient(
        baseURL: URL(string: "https://example.test")!,
        transport: transport,
        retryPolicy: RetryPolicy(maximumAttempts: 2),
        logger: InMemoryLogger()
    )

    let response = try await client.send(HTTPRequest(path: "/retry"))

    #expect(response.statusCode == 200)
    #expect(attempts.value == 2)
}

@Test func HTTPClientDoesNotRetryUnconfiguredClientError() async {
    let attempts = AttemptCounter()
    let transport = ClosureHTTPTransport { _ in
        _ = attempts.increment()
        return HTTPResponse(statusCode: 400, body: Data())
    }
    let client = DefaultHTTPClient(
        baseURL: URL(string: "https://example.test")!,
        transport: transport,
        retryPolicy: RetryPolicy(maximumAttempts: 3),
        logger: InMemoryLogger()
    )

    do {
        _ = try await client.send(HTTPRequest(path: "/invalid"))
        Issue.record("Expected an unacceptable-status error")
    } catch let error as NetworkError {
        #expect(error == .unacceptableStatus(400))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
    #expect(attempts.value == 1)
}

@Test func HTTPResponseReportsDecodingFailureWithoutPayloadLeak() {
    struct Payload: Codable, Sendable { let value: String }
    let response = HTTPResponse(statusCode: 200, body: Data("not-json".utf8))

    do {
        _ = try response.decode(Payload.self)
        Issue.record("Expected a decoding error")
    } catch let error as NetworkError {
        guard case .decoding = error else {
            Issue.record("Expected decoding error, received \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test func inMemoryCredentialVaultRoundTripsAndRemovesData() async throws {
    let vault = InMemoryCredentialVault()
    let value = Data("credential".utf8)

    await vault.write(value, key: "session")
    #expect(await vault.read(key: "session") == value)
    await vault.remove(key: "session")
    #expect(await vault.read(key: "session") == nil)
}

@Test func transportSecurityRejectsUnknownHostsAndEmptyPinConfiguration() async {
    let logger = InMemoryLogger()
    let hostRestricted = AppTransportSecurityEvaluator(
        allowedHosts: ["allowed.test"],
        pinningMode: .systemTrust,
        logger: logger
    )
    let emptyPins = AppTransportSecurityEvaluator(
        allowedHosts: ["allowed.test"],
        pinningMode: .certificatePins([]),
        logger: logger
    )

    do {
        try await hostRestricted.prepareRequest(for: "rejected.test")
        Issue.record("Expected host policy rejection")
    } catch let error as NetworkError {
        #expect(error == .securityPolicyRejected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    do {
        try await emptyPins.prepareRequest(for: "allowed.test")
        Issue.record("Expected empty pin policy rejection")
    } catch let error as NetworkError {
        #expect(error == .securityPolicyRejected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test func sessionInvalidationClearsCredentials() async throws {
    let manager = SessionCredentialManager(vault: InMemoryCredentialVault(), logger: InMemoryLogger())
    try await manager.establish(SessionCredentials(accessToken: "a", refreshToken: "r", userID: "u"))
    #expect(try await manager.current()?.userID == "u")

    try await manager.invalidate(reason: .logout)
    #expect(try await manager.current() == nil)
    #expect(await manager.invalidationReason == .logout)
}
