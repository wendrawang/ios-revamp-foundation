import Combine
import CoreAnalytics
import SwiftUI

enum AppLifecycleState: Equatable, Sendable {
    case foreground
    case inactive
    case background
}

@MainActor
final class AppLifecycleController: ObservableObject {
    @Published private(set) var state: AppLifecycleState = .inactive
    private let analytics: any AnalyticsTracking

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(analytics: any AnalyticsTracking) {
        self.analytics = analytics
    }

    // Menormalisasi lifecycle transition dan menghindari duplicate event.
    func transition(from scenePhase: ScenePhase) {
        let next: AppLifecycleState
        switch scenePhase {
        case .active: next = .foreground
        case .inactive: next = .inactive
        case .background: next = .background
        @unknown default: next = .inactive
        }
        transition(to: next)
    }

    // Menormalisasi lifecycle transition dan menghindari duplicate event.
    func transition(to next: AppLifecycleState) {
        guard state != next else { return }
        state = next
        analytics.track(AnalyticsEvent(name: "app_lifecycle", properties: ["state": String(describing: next)]))
    }
}
