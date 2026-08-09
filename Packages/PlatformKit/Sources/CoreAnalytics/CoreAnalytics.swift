import Foundation

public struct AnalyticsEvent: Equatable, Sendable {
    public let name: String
    public let properties: [String: String]

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

public protocol AnalyticsTracking: Sendable {
    // Meneruskan event analytics yang sudah privacy-safe ke adapter.
    func track(_ event: AnalyticsEvent)
}

public final class InMemoryAnalytics: AnalyticsTracking, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AnalyticsEvent] = []

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}

    // Meneruskan event analytics yang sudah privacy-safe ke adapter.
    public func track(_ event: AnalyticsEvent) {
        lock.withLock { storage.append(event) }
    }

    // Mengambil snapshot event analytics untuk debug atau assertion test.
    public func events() -> [AnalyticsEvent] {
        lock.withLock { storage }
    }
}
