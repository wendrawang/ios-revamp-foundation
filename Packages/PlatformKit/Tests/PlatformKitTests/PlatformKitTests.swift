import CoreFeatureFlags
import CoreLogging
import CoreNetworking
import CoreSecurity
import CoreSession
import Foundation
import Testing

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

@Test func sessionInvalidationClearsCredentials() async throws {
    let manager = SessionCredentialManager(vault: InMemoryCredentialVault(), logger: InMemoryLogger())
    try await manager.establish(SessionCredentials(accessToken: "a", refreshToken: "r", userID: "u"))
    #expect(try await manager.current()?.userID == "u")

    try await manager.invalidate(reason: .logout)
    #expect(try await manager.current() == nil)
    #expect(await manager.invalidationReason == .logout)
}

