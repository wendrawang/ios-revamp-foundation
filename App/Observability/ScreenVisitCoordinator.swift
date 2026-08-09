import CoreAnalytics

@MainActor
final class ScreenVisitCoordinator {
    private let analytics: any AnalyticsTracking
    private(set) var visits: [ScreenDescriptor] = []

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(analytics: any AnalyticsTracking) {
        self.analytics = analytics
    }

    // Mencatat screen visit hanya dari navigation state yang sudah committed.
    func screenBecameTopmost(_ screen: ScreenDescriptor) {
        visits.append(screen)
        analytics.track(AnalyticsEvent(name: "screen_visit", properties: ["screen_id": screen.id]))
    }
}
