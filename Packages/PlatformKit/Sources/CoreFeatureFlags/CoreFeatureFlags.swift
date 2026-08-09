import CoreLogging
import Foundation

public struct FeatureFlag: Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public extension FeatureFlag {
    static let wealthEntryEnabled: FeatureFlag = "wealth_entry_enabled"
    static let webSampleEnabled: FeatureFlag = "web_sample_enabled"
}

public protocol FeatureFlagProviding: Sendable {
    func isEnabled(_ flag: FeatureFlag) -> Bool
}

public final class InMemoryFeatureFlags: FeatureFlagProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var enabledFlags: Set<FeatureFlag>
    private let logger: any AppLogging

    public init(enabled: Set<FeatureFlag> = [], logger: any AppLogging) {
        enabledFlags = enabled
        self.logger = logger
    }

    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        lock.withLock { enabledFlags.contains(flag) }
    }

    public func set(_ flag: FeatureFlag, enabled: Bool) {
        lock.withLock {
            if enabled {
                enabledFlags.insert(flag)
            } else {
                enabledFlags.remove(flag)
            }
        }
        logger.log(LogEntry(
            level: .info,
            category: "feature_flags",
            message: "Feature flag changed",
            fields: [
                LogField(name: "flag", value: flag.rawValue, privacy: .public),
                LogField(name: "enabled", value: String(enabled), privacy: .public),
            ]
        ))
    }
}

