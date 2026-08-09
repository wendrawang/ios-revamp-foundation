import CoreLogging
import CoreSecurity
import Foundation

public struct SessionCredentials: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let userID: String

    public init(accessToken: String, refreshToken: String, userID: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
    }
}

public enum SessionInvalidationReason: Equatable, Sendable {
    case logout
    case expired
    case securityRestriction
}

public actor SessionCredentialManager {
    private let vault: any SecureCredentialStoring
    private let logger: any AppLogging
    private let storageKey: String
    private var credentials: SessionCredentials?
    private(set) public var invalidationReason: SessionInvalidationReason?

    public init(
        vault: any SecureCredentialStoring,
        logger: any AppLogging,
        storageKey: String = "authenticated_session"
    ) {
        self.vault = vault
        self.logger = logger
        self.storageKey = storageKey
    }

    public func establish(_ credentials: SessionCredentials) async throws {
        let data = try JSONEncoder().encode(credentials)
        try await vault.write(data, key: storageKey)
        self.credentials = credentials
        invalidationReason = nil
        logger.log(LogEntry(level: .notice, category: "session", message: "Session established"))
    }

    public func current() async throws -> SessionCredentials? {
        if let credentials { return credentials }
        guard let data = try await vault.read(key: storageKey) else { return nil }
        let decoded = try JSONDecoder().decode(SessionCredentials.self, from: data)
        credentials = decoded
        return decoded
    }

    public func invalidate(reason: SessionInvalidationReason) async throws {
        credentials = nil
        invalidationReason = reason
        try await vault.remove(key: storageKey)
        logger.log(LogEntry(
            level: .notice,
            category: "session",
            message: "Session invalidated",
            fields: [LogField(name: "reason", value: String(describing: reason), privacy: .public)]
        ))
    }
}

