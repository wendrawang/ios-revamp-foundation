import CoreLogging
import Foundation

public struct FeatureFlag: Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

extension FeatureFlag {
    public static let wealthEntryEnabled: FeatureFlag = "wealth_entry_enabled"
    public static let webSampleEnabled: FeatureFlag = "web_sample_enabled"
}

public protocol FeatureFlagProviding: Sendable {
    // Membaca runtime feature flag secara thread-safe.
    func isEnabled(_ flag: FeatureFlag) -> Bool
}

public final class InMemoryFeatureFlags: FeatureFlagProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var enabledFlags: Set<FeatureFlag>
    private let logger: any AppLogging

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(enabled: Set<FeatureFlag> = [], logger: any AppLogging) {
        enabledFlags = enabled
        self.logger = logger
    }

    // Membaca runtime feature flag secara thread-safe.
    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        lock.withLock { enabledFlags.contains(flag) }
    }

    // Memperbarui runtime feature flag secara thread-safe dan terlog redacted.
    public func set(_ flag: FeatureFlag, isEnabled: Bool) {
        lock.withLock {
            if isEnabled {
                enabledFlags.insert(flag)
            } else {
                enabledFlags.remove(flag)
            }
        }
        logger.log(
            LogEntry(
                level: .info,
                category: "feature_flags",
                message: "Feature flag changed",
                fields: [
                    LogField(name: "flag", value: flag.rawValue, privacy: .public),
                    LogField(name: "enabled", value: String(isEnabled), privacy: .public),
                ]
            ))
    }
}
