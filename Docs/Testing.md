# Testing

Platform tests cover logging redaction, feature flags, deterministic HTTP transport/decoding, and session invalidation. Feature tests cover domain parsers, meaningful use cases, typed outputs, backend presentation mapping, and Scan resource activity.

App tests cover generic route insertion, metadata synchronization, native-style path reductions, canonical/current-journey behavior, output mappings, pending links, direct post-login destinations, authenticated preflight state, blocker priority, screen visits, and logout lifetime.

UI tests launch with `-uiTesting` and optional `-deepLink <URL>`. They use in-memory services and never contact production. Accessibility identifiers are namespaced by owning surface.

Lifetime tests use weak references to representative session/UI scopes and ViewModels. These checks catch ownership regressions but do not replace Allocations and Leaks instruments. Repeated device profiling is required before releases and after navigation, WebKit, camera, or SDK ownership changes.

Every business domain has an independent Local SPM test target. The quality
script runs all package test targets separately, then the app integration and
UI targets. This prevents an app build from masking a broken or untested domain
package.

Coverage is collected for every package and for the complete app/UI run. The
combined app target has a 75% line-coverage floor. This is a regression floor,
not a substitute for behavior assertions: generated/declarative SwiftUI paths
make a blanket 100% line target misleading. Domain services, parsers, use cases,
state machines, routing decisions, error branches, cancellation, and ownership
paths require explicit tests. SwiftUI composition and accessibility journeys
are additionally covered through UI automation.

Performance XCTests record navigation time/memory and launch metrics. They
detect regressions but cannot certify refresh rate; the physical-device process
in `Performance.md` remains mandatory.
