import Foundation
import os

enum AppPerformanceSignposts {
    private static let log = OSLog(
        subsystem: "com.wendrawang.iosrevampfoundation",
        category: .pointsOfInterest
    )

    static func navigationCommitted(screenID: String) {
        os_signpost(
            .event,
            log: log,
            name: "Navigation Commit",
            "%{public}s",
            screenID
        )
    }

    static func beginAuthenticatedPreflight(identifier: String) -> OSSignpostID {
        let signpostID = OSSignpostID(log: log)
        os_signpost(
            .begin,
            log: log,
            name: "Authenticated Deep Link Preflight",
            signpostID: signpostID,
            "%{public}s",
            identifier
        )
        return signpostID
    }

    static func endAuthenticatedPreflight(_ signpostID: OSSignpostID, identifier: String) {
        os_signpost(
            .end,
            log: log,
            name: "Authenticated Deep Link Preflight",
            signpostID: signpostID,
            "%{public}s",
            identifier
        )
    }
}
