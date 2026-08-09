# IOS Revamp Foundation

A greenfield, SwiftUI-first architecture foundation for a long-lived iOS banking application. The sample deliberately validates boundaries and runtime behavior rather than reproducing a production banking design.

## Requirements

- Xcode 26 or a compatible Swift 6 toolchain
- iOS 16.0 minimum deployment target
- An installed iOS Simulator runtime

If `xcode-select` points to Command Line Tools, prefix commands with:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Open and run

Open `IOSRevampFoundation.xcodeproj`, choose the `IOSRevampFoundation` scheme, and run on an iPhone simulator. No workspace, project generator, CocoaPods, or third-party architecture framework is required.

Command-line build:

```bash
xcodebuild \
  -project IOSRevampFoundation.xcodeproj \
  -scheme IOSRevampFoundation \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath DerivedData \
  build
```

Run app tests:

```bash
xcodebuild \
  -project IOSRevampFoundation.xcodeproj \
  -scheme IOSRevampFoundation \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath DerivedData \
  test
```

Run dependency checks:

```bash
./Scripts/check-architecture.sh
```

Run the complete local quality gate—every Local SPM test target, app build,
unit/integration tests, UI tests, performance metrics, and coverage:

```bash
./Scripts/run-quality-gates.sh
```

The script selects an available iPhone Simulator automatically. Override it
when validating a specific runtime:

```bash
SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
./Scripts/run-quality-gates.sh
```

## Demonstrated flows

- Login and logout with separate app/session/UI lifetimes
- Exactly one unauthenticated and one authenticated `NavigationStack`
- Native `TabView` with a custom five-item bar and elevated Scan control
- Dashboard and More opening the same Upgrade Service implementation
- Transfer Result opening Wealth with current-journey and canonical semantics
- Registration, Rewards, and Wealth deep links through one app registry
- Login followed directly by Reward Detail without Dashboard appearing first
- Authenticated preparing state for a deterministic Wealth preflight
- Reusable secure WebView forwarding recognized application links
- Feature-owned dynamic sheet with a whitelisted typed action
- Global blocker that preserves the current path
- Runtime feature flags, structured logging, analytics, and screen visits

Architecture rationale and ownership rules live in `Docs/` and `AGENTS.md`.
Quality policy and the physical-device performance acceptance process live in
`Docs/QualityGates.md` and `Docs/Performance.md`.
