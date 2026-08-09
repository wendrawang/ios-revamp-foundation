# Navigation

The app declares exactly two primary `NavigationStack`s. Authentication state changes replace the root flow; Login and Main are never pushed on top of one another.

The authenticated stack root is `MainTabContainer`. It uses native `TabView(selection:)`; the visible custom bar changes the same selection binding. Service journeys are values pushed above the whole container, so the originating tab and root state remain underneath.

Feature route enums are concrete `Hashable` values. Generic store methods append the concrete route to `NavigationPath`, preserving `navigationDestination(for: FeatureRoute.self)` dispatch. No `AnyView` or route wrapper is inserted into the runtime path.

Each store is the sole mutation boundary. Its `Binding<NavigationPath>` accepts system reductions caused by a back button or interactive swipe and atomically trims privacy-safe metadata to the same count. Unexpected path growth is rejected because features must use store operations.

Current-journey navigation appends a destination. Canonical navigation selects the owning tab, clears the service path, and appends the destination as one state operation. Navigation state is not persisted; sensitive flows are non-restorable by default.

