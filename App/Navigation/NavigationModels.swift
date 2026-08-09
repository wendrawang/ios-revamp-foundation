import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Equatable, Hashable, Sendable {
    case dashboard
    case financial
    case scan
    case rewards
    case more

    var screenDescriptor: ScreenDescriptor {
        ScreenDescriptor(id: "tab.\(rawValue)")
    }
}

struct ScreenDescriptor: Equatable, Sendable {
    let id: String

    init(id: String) {
        self.id = id
    }
}

struct NavigationDestination<Route: Hashable>: Equatable {
    let route: Route
    let screen: ScreenDescriptor

    init(route: Route, screen: ScreenDescriptor) {
        self.route = route
        self.screen = screen
    }
}

enum AuthenticatedNavigationDecision<Route: Hashable>: Equatable {
    case push(NavigationDestination<Route>)
    case canonical(tab: AppTab, destination: NavigationDestination<Route>?)
}
