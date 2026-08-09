import Foundation

enum AppPhase: Equatable, Sendable {
    case launching
    case unauthenticated
    case authenticated
}

enum AuthenticatedFlowState: Equatable, Sendable {
    case preparing
    case ready
}

struct TabActivityState: Equatable, Sendable {
    let selectedTab: AppTab
    let lifecycle: AppLifecycleState
    let isGloballyBlocked: Bool

    func isOperational(_ tab: AppTab) -> Bool {
        selectedTab == tab && lifecycle == .foreground && !isGloballyBlocked
    }
}

