# Testing

Platform tests cover logging redaction, feature flags, deterministic HTTP transport/decoding, and session invalidation. Feature tests cover domain parsers, meaningful use cases, typed outputs, backend presentation mapping, and Scan resource activity.

App tests cover generic route insertion, metadata synchronization, native-style path reductions, canonical/current-journey behavior, output mappings, pending links, direct post-login destinations, authenticated preflight state, blocker priority, screen visits, and logout lifetime.

UI tests launch with `-uiTesting` and optional `-deepLink <URL>`. They use in-memory services and never contact production. Accessibility identifiers are namespaced by owning surface.

Lifetime tests use weak references to representative session/UI scopes and ViewModels. These checks catch ownership regressions but do not replace Allocations and Leaks instruments. Repeated device profiling is required before releases and after navigation, WebKit, camera, or SDK ownership changes.

