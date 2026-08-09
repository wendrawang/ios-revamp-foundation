import Foundation

public struct AnalyticsEvent: Equatable, Sendable {
    public let name: String
    public let properties: [String: String]

    public init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

public protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
}

public final class InMemoryAnalytics: AnalyticsTracking, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AnalyticsEvent] = []

    public init() {}

    public func track(_ event: AnalyticsEvent) {
        lock.withLock { storage.append(event) }
    }

    public func events() -> [AnalyticsEvent] {
        lock.withLock { storage }
    }
}

