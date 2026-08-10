import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Equatable, Hashable, Sendable {
    case dashboard
    case financial
    case scan
    case rewards
    case more

    var screenDescriptor: ScreenDescriptor {
        ScreenDescriptor(identifier: "tab.\(rawValue)")
    }
}

struct ScreenDescriptor: Equatable, Sendable {
    let identifier: String
}

struct NavigationDestination<Route: Hashable>: Equatable {
    let route: Route
    let screen: ScreenDescriptor
}

enum AuthenticatedNavigationDecision<Route: Hashable>: Equatable {
    case push(NavigationDestination<Route>)
    case canonical(tab: AppTab, destination: NavigationDestination<Route>?)
}
