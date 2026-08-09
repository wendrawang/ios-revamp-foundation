import Combine
import SwiftUI

@MainActor
final class UnauthenticatedNavigationStore: ObservableObject {
    @Published private var path = NavigationPath()
    @Published private(set) var metadata: [ScreenDescriptor] = []
    private let onTopScreenChanged: (ScreenDescriptor) -> Void
    private let rootScreen = ScreenDescriptor(id: "auth.login")

    init(onTopScreenChanged: @escaping (ScreenDescriptor) -> Void) {
        self.onTopScreenChanged = onTopScreenChanged
    }

    var pathCount: Int { path.count }
    var topScreen: ScreenDescriptor { metadata.last ?? rootScreen }

    var pathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.path },
            set: { self.reconcileSystemPath($0) }
        )
    }

    func push<Route: Hashable>(_ route: Route, screen: ScreenDescriptor) {
        var updated = path
        updated.append(route)
        path = updated
        metadata.append(screen)
        onTopScreenChanged(screen)
    }

    func pop() {
        guard !metadata.isEmpty else { return }
        var updated = path
        updated.removeLast()
        path = updated
        metadata.removeLast()
        onTopScreenChanged(topScreen)
    }

    func popToRoot() {
        guard !metadata.isEmpty else { return }
        path = NavigationPath()
        metadata.removeAll()
        onTopScreenChanged(rootScreen)
    }

    func resetWithoutTracking() {
        path = NavigationPath()
        metadata.removeAll()
    }

    func reconcileSystemPath(_ systemPath: NavigationPath) {
        if systemPath.count == path.count { return }
        guard systemPath.count < path.count else {
            assertionFailure("Navigation path growth must go through UnauthenticatedNavigationStore.push")
            return
        }
        path = systemPath
        if metadata.count > systemPath.count {
            metadata.removeLast(metadata.count - systemPath.count)
            onTopScreenChanged(topScreen)
        }
    }
}

@MainActor
final class AuthenticatedNavigationStore: ObservableObject {
    @Published private var path = NavigationPath()
    @Published private(set) var metadata: [ScreenDescriptor] = []
    @Published private(set) var selectedTab: AppTab = .dashboard
    private let onTopScreenChanged: (ScreenDescriptor) -> Void

    init(onTopScreenChanged: @escaping (ScreenDescriptor) -> Void) {
        self.onTopScreenChanged = onTopScreenChanged
    }

    var pathCount: Int { path.count }
    var topScreen: ScreenDescriptor { metadata.last ?? selectedTab.screenDescriptor }

    var pathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.path },
            set: { self.reconcileSystemPath($0) }
        )
    }

    var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { self.selectedTab },
            set: { self.selectTab($0) }
        )
    }

    func push<Route: Hashable>(_ route: Route, screen: ScreenDescriptor) {
        var updated = path
        updated.append(route)
        path = updated
        metadata.append(screen)
        onTopScreenChanged(screen)
    }

    func apply<Route: Hashable>(_ decision: AuthenticatedNavigationDecision<Route>) {
        switch decision {
        case let .push(destination):
            push(destination.route, screen: destination.screen)
        case let .canonical(tab, destination):
            openCanonical(tab: tab, destination: destination)
        }
    }

    func pop() {
        guard !metadata.isEmpty else { return }
        var updated = path
        updated.removeLast()
        path = updated
        metadata.removeLast()
        onTopScreenChanged(topScreen)
    }

    func popToRoot() {
        guard !metadata.isEmpty else { return }
        path = NavigationPath()
        metadata.removeAll()
        onTopScreenChanged(selectedTab.screenDescriptor)
    }

    func selectTab(_ tab: AppTab) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        if metadata.isEmpty {
            onTopScreenChanged(tab.screenDescriptor)
        }
    }

    func openCanonical<Route: Hashable>(
        tab: AppTab,
        destination: NavigationDestination<Route>?
    ) {
        selectedTab = tab
        path = NavigationPath()
        metadata.removeAll()
        if let destination {
            var updated = path
            updated.append(destination.route)
            path = updated
            metadata.append(destination.screen)
            onTopScreenChanged(destination.screen)
        } else {
            onTopScreenChanged(tab.screenDescriptor)
        }
    }

    func resetWithoutTracking() {
        path = NavigationPath()
        metadata.removeAll()
        selectedTab = .dashboard
    }

    func reconcileSystemPath(_ systemPath: NavigationPath) {
        if systemPath.count == path.count { return }
        guard systemPath.count < path.count else {
            assertionFailure("Navigation path growth must go through AuthenticatedNavigationStore.push")
            return
        }
        path = systemPath
        if metadata.count > systemPath.count {
            metadata.removeLast(metadata.count - systemPath.count)
            onTopScreenChanged(topScreen)
        }
    }
}
