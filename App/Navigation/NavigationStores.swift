import Combine
import SwiftUI

@MainActor
final class UnauthenticatedNavigationStore: ObservableObject {
    @Published private var path = NavigationPath()
    @Published private(set) var metadata: [ScreenDescriptor] = []
    private let onTopScreenChanged: (ScreenDescriptor) -> Void
    private let rootScreen = ScreenDescriptor(identifier: "auth.login")

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(onTopScreenChanged: @escaping (ScreenDescriptor) -> Void) {
        self.onTopScreenChanged = onTopScreenChanged
    }

    var pathCount: Int { path.count }
    var topScreen: ScreenDescriptor { metadata.last ?? rootScreen }

    var pathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.path },
            set: { updatedPath in self.reconcileSystemPath(updatedPath) }
        )
    }

    // Menambahkan route konkret dan metadata melalui satu mutation boundary.
    func push<Route: Hashable>(_ route: Route, screen: ScreenDescriptor) {
        var updated = path
        updated.append(route)
        path = updated
        metadata.append(screen)
        onTopScreenChanged(screen)
    }

    // Menghapus route teratas sekaligus menyinkronkan metadata.
    func pop() {
        guard !metadata.isEmpty else { return }
        var updated = path
        updated.removeLast()
        path = updated
        metadata.removeLast()
        onTopScreenChanged(topScreen)
    }

    // Mengosongkan service journey sambil mempertahankan root flow yang benar.
    func popToRoot() {
        guard !metadata.isEmpty else { return }
        path = NavigationPath()
        metadata.removeAll()
        onTopScreenChanged(rootScreen)
    }

    // Mereset navigation saat pergantian session tanpa analytics visit palsu.
    func resetWithoutTracking() {
        path = NavigationPath()
        metadata.removeAll()
    }

    // Menyinkronkan metadata ketika SwiftUI melakukan native back navigation.
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

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(onTopScreenChanged: @escaping (ScreenDescriptor) -> Void) {
        self.onTopScreenChanged = onTopScreenChanged
    }

    var pathCount: Int { path.count }
    var topScreen: ScreenDescriptor { metadata.last ?? selectedTab.screenDescriptor }

    var pathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.path },
            set: { updatedPath in self.reconcileSystemPath(updatedPath) }
        )
    }

    var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { self.selectedTab },
            set: { selectedTab in self.selectTab(selectedTab) }
        )
    }

    // Menambahkan route konkret dan metadata melalui satu mutation boundary.
    func push<Route: Hashable>(_ route: Route, screen: ScreenDescriptor) {
        var updated = path
        updated.append(route)
        path = updated
        metadata.append(screen)
        onTopScreenChanged(screen)
    }

    // Menerapkan typed navigation decision ke runtime NavigationPath.
    func apply<Route: Hashable>(_ decision: AuthenticatedNavigationDecision<Route>) {
        switch decision {
        case .push(let destination):
            push(destination.route, screen: destination.screen)
        case .canonical(let tab, let destination):
            openCanonical(tab: tab, destination: destination)
        }
    }

    // Menghapus route teratas sekaligus menyinkronkan metadata.
    func pop() {
        guard !metadata.isEmpty else { return }
        var updated = path
        updated.removeLast()
        path = updated
        metadata.removeLast()
        onTopScreenChanged(topScreen)
    }

    // Mengosongkan service journey sambil mempertahankan root flow yang benar.
    func popToRoot() {
        guard !metadata.isEmpty else { return }
        path = NavigationPath()
        metadata.removeAll()
        onTopScreenChanged(selectedTab.screenDescriptor)
    }

    // Mengganti tab aktif dan menerbitkan screen visit yang deterministic.
    func selectTab(_ tab: AppTab) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        if metadata.isEmpty {
            onTopScreenChanged(tab.screenDescriptor)
        }
    }

    // Memilih tab canonical, mereset journey, lalu membuka destination opsional.
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

    // Mereset navigation saat pergantian session tanpa analytics visit palsu.
    func resetWithoutTracking() {
        path = NavigationPath()
        metadata.removeAll()
        selectedTab = .dashboard
    }

    // Menyinkronkan metadata ketika SwiftUI melakukan native back navigation.
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
