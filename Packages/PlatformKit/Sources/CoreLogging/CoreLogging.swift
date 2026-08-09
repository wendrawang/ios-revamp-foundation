import Foundation
import OSLog

public enum LogLevel: String, Sendable {
    case debug
    case info
    case notice
    case warning
    case error
}

public enum LogPrivacy: Sendable {
    case `public`
    case sensitive
}

public struct LogField: Equatable, Sendable {
    public let name: String
    public let value: String
    public let privacy: LogPrivacy

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(name: String, value: String, privacy: LogPrivacy) {
        self.name = name
        self.value = value
        self.privacy = privacy
    }

    public var renderedValue: String {
        privacy == .public ? value : "<redacted>"
    }
}

public struct LogEntry: Equatable, Sendable {
    public let level: LogLevel
    public let category: String
    public let message: String
    public let fields: [LogField]

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(level: LogLevel, category: String, message: String, fields: [LogField] = []) {
        self.level = level
        self.category = category
        self.message = message
        self.fields = fields
    }

    public var sanitizedDescription: String {
        let suffix = fields.map { field in
            "\(field.name)=\(field.renderedValue)"
        }.joined(separator: " ")
        return suffix.isEmpty ? message : "\(message) \(suffix)"
    }
}

public protocol AppLogging: Sendable {
    // Menerima structured log dan meredaksi field sensitif sebelum disimpan.
    func log(_ entry: LogEntry)
}

public final class InMemoryLogger: AppLogging, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [LogEntry] = []

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}

    // Menerima structured log dan meredaksi field sensitif sebelum disimpan.
    public func log(_ entry: LogEntry) {
        let sanitized = LogEntry(
            level: entry.level,
            category: entry.category,
            message: entry.message,
            fields: entry.fields.map { field in
                LogField(name: field.name, value: field.renderedValue, privacy: .public)
            }
        )
        lock.withLock { storage.append(sanitized) }
    }

    // Mengambil snapshot structured log untuk debug atau assertion test.
    public func entries() -> [LogEntry] {
        lock.withLock { storage }
    }
}

public final class OSAppLogger: AppLogging, @unchecked Sendable {
    private let subsystem: String

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(subsystem: String) {
        self.subsystem = subsystem
    }

    // Menerima structured log dan meredaksi field sensitif sebelum disimpan.
    public func log(_ entry: LogEntry) {
        let logger = Logger(subsystem: subsystem, category: entry.category)
        let value = entry.sanitizedDescription
        switch entry.level {
        case .debug: logger.debug("\(value, privacy: .public)")
        case .info: logger.info("\(value, privacy: .public)")
        case .notice: logger.notice("\(value, privacy: .public)")
        case .warning: logger.warning("\(value, privacy: .public)")
        case .error: logger.error("\(value, privacy: .public)")
        }
    }
}
