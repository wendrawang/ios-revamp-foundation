import SwiftUI

@main
struct IOSRevampFoundationApp: App {
    private let container: AppContainer
    private let coordinator: AppCoordinator

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let container = AppContainer(isUITesting: isUITesting)
        self.container = container
        coordinator = AppCoordinator(container: container)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}

