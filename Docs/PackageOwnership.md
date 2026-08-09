# Package ownership

Each business domain is its own physical Local SPM with its own `Package.swift`, source target, and test target. Teams normally change their feature and its tests. Dashboard, Financial Hub, and More are composition/hub features; they expose outputs instead of importing destination implementations.

App-owned composition files are the intentional cross-team integration points. A mapping file is split by source feature to avoid a single high-conflict switch.

PlatformKit additions require cross-team review because they broaden dependency surface. Core modules cannot contain feature services. Shared business values remain in their original domain until two independent domains require identical semantics; promotion then requires an ADR.

SwiftPM manifests enforce declared dependencies, `CODEOWNERS` identifies sensitive areas, and `Scripts/check-architecture.sh` detects obvious forbidden imports and stack proliferation.

The architecture check also fails when a domain loses its package manifest or executable tests, or when a feature manifest starts depending on another feature package. A new screen inside an existing domain stays in that domain package; a new package requires a stable business ownership boundary, not a Jira-sized task.
