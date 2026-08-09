# Architecture

The application separates process lifetime, authenticated session lifetime, authenticated UI lifetime, and short feature lifetime because those resources must be invalidated at different moments.

`AppContainer` owns process-wide technical dependencies. `SessionScope` owns credentials, authenticated contexts, caches, repositories, and session work; it never owns SwiftUI state. `AuthenticatedFlowScope` owns the tab-root presentation resources that survive tab selection but must disappear at logout. Pushed destination Views own their short-lived ViewModels.

Business packages represent stable capabilities. They import exact PlatformKit products and DesignSystem, never another unrelated feature. Cross-domain intent terminates at a typed feature output. Small app-owned mapping files translate that output into concrete route insertion.

Presentation, navigation mechanics, lifecycle normalization, generic screen visits, global blockers, and the deep-link registry stay in the app because they coordinate multiple packages. Shared modules are introduced only when there is a real independent consumer.

SwiftUI is the default. UIKit/WebKit integration exists only where iOS 16 has no equivalent native SwiftUI surface or control, such as `WKWebView` and a future camera preview.

