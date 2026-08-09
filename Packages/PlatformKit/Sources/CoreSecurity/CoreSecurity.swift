import CoreLogging
import CoreNetworking
import Foundation
import Security

public protocol SecureCredentialStoring: Sendable {
    // Membaca credential data dari storage abstraction.
    func read(key: String) async throws -> Data?
    // Menyimpan credential data melalui storage abstraction.
    func write(_ value: Data, key: String) async throws
    // Menghapus credential data dari storage abstraction.
    func remove(key: String) async throws
}

public enum CredentialVaultError: Error, Equatable, Sendable {
    case unexpectedStatus(Int32)
}

public actor InMemoryCredentialVault: SecureCredentialStoring {
    private var values: [String: Data] = [:]

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}

    // Membaca credential data dari storage abstraction.
    public func read(key: String) -> Data? { values[key] }
    // Menyimpan credential data melalui storage abstraction.
    public func write(_ value: Data, key: String) { values[key] = value }
    // Menghapus credential data dari storage abstraction.
    public func remove(key: String) { values.removeValue(forKey: key) }
}

public actor KeychainCredentialVault: SecureCredentialStoring {
    private let service: String

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(service: String) {
        self.service = service
    }

    // Membaca credential data dari storage abstraction.
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

    // Menyimpan credential data melalui storage abstraction.
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

    // Menghapus credential data dari storage abstraction.
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

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
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

    // Memvalidasi kebijakan transport dan TLS sebelum request dikirim.
    public func prepareRequest(for host: String) async throws {
        guard allowedHosts.isEmpty || allowedHosts.contains(host) else {
            throw NetworkError.securityPolicyRejected
        }
        logger.log(
            LogEntry(
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
        case .certificatePins(let pins):
            guard !pins.isEmpty else { throw NetworkError.securityPolicyRejected }
        }
    }
}

public enum SecurityEvent: Equatable, Sendable {
    case screenCaptureChanged(isCaptured: Bool)
    case runtimeRestriction(String)
}

public protocol SecurityMonitoring: Sendable {
    // Memulai resource atau flow yang dimiliki tipe ini.
    func start() async
    // Menghentikan resource agar tidak melewati lifetime pemiliknya.
    func stop() async
}

public actor NoOpSecurityMonitor: SecurityMonitoring {
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}
    // Memulai resource atau flow yang dimiliki tipe ini.
    public func start() async {}
    // Menghentikan resource agar tidak melewati lifetime pemiliknya.
    public func stop() async {}
}
