import CoreAnalytics

@MainActor
final class ScreenVisitCoordinator {
    private let analytics: any AnalyticsTracking
    private(set) var visits: [ScreenDescriptor] = []

    init(analytics: any AnalyticsTracking) {
        self.analytics = analytics
    }

    func screenBecameTopmost(_ screen: ScreenDescriptor) {
        visits.append(screen)
        analytics.track(AnalyticsEvent(name: "screen_visit", properties: ["screen_id": screen.id]))
    }
}

