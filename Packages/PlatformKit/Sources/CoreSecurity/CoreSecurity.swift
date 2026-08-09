import CoreLogging
import CoreNetworking
import Foundation
import Security

public protocol SecureCredentialStoring: Sendable {
    func read(key: String) async throws -> Data?
    func write(_ value: Data, key: String) async throws
    func remove(key: String) async throws
}

public enum CredentialVaultError: Error, Equatable, Sendable {
    case unexpectedStatus(Int32)
}

public actor InMemoryCredentialVault: SecureCredentialStoring {
    private var values: [String: Data] = [:]

    public init() {}

    public func read(key: String) -> Data? { values[key] }
    public func write(_ value: Data, key: String) { values[key] = value }
    public func remove(key: String) { values.removeValue(forKey: key) }
}

public actor KeychainCredentialVault: SecureCredentialStoring {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func read(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialVaultError.unexpectedStatus(status) }
        return result as? Data
    }

    public func write(_ value: Data, key: String) throws {
        try remove(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialVaultError.unexpectedStatus(status) }
    }

    public func remove(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialVaultError.unexpectedStatus(status)
        }
    }
}

public struct AppTransportSecurityEvaluator: TransportSecurityEvaluating {
    public enum PinningMode: Sendable {
        case systemTrust
        case certificatePins(Set<String>)
    }

    private let allowedHosts: Set<String>
    private let pinningMode: PinningMode
    private let clientIdentityLabel: String?
    private let logger: any AppLogging

    public init(
        allowedHosts: Set<String>,
        pinningMode: PinningMode,
        clientIdentityLabel: String? = nil,
        logger: any AppLogging
    ) {
        self.allowedHosts = allowedHosts
        self.pinningMode = pinningMode
        self.clientIdentityLabel = clientIdentityLabel
        self.logger = logger
    }

    public func prepareRequest(for host: String) async throws {
        guard allowedHosts.isEmpty || allowedHosts.contains(host) else {
            throw NetworkError.securityPolicyRejected
        }
        logger.log(LogEntry(
            level: .debug,
            category: "security",
            message: "Transport security policy selected",
            fields: [
                LogField(name: "host", value: host, privacy: .public),
                LogField(name: "mtls_identity", value: clientIdentityLabel ?? "none", privacy: .sensitive),
            ]
        ))
        switch pinningMode {
        case .systemTrust:
            return
        case let .certificatePins(pins):
            guard !pins.isEmpty else { throw NetworkError.securityPolicyRejected }
        }
    }
}

public enum SecurityEvent: Equatable, Sendable {
    case screenCaptureChanged(Bool)
    case runtimeRestriction(String)
}

public protocol SecurityMonitoring: Sendable {
    func start() async
    func stop() async
}

public actor NoOpSecurityMonitor: SecurityMonitoring {
    public init() {}
    public func start() async {}
    public func stop() async {}
}

