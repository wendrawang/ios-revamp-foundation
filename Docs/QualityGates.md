# Quality gates

`Scripts/run-quality-gates.sh` is the required pre-merge validation entry point.
The GitHub Actions workflow runs the same command so local and CI behavior do
not diverge.

The gate performs, in order:

1. architecture and package-boundary validation;
2. all PlatformKit, DesignSystem, SecureWebKit, and domain package tests;
3. local package resolution and simulator application build;
4. app unit/integration tests and deterministic UI journeys;
5. navigation memory/clock and application-launch performance metrics;
6. code-coverage generation and the combined app coverage floor.

The architecture step also runs the repository-owned Swift style linter. It
enforces a 250-line file limit, a 50-line method limit, a purpose comment for
every method, a 3–35 character range for variable-style identifiers, and the
`is` prefix for boolean flags and parameters. `_` remains valid only as an
intentional discard token. The range applies to declarations owned by this
repository; external API labels and serialized wire keys retain their required
contract names. Apple `swift-format` also runs in strict mode using the checked-in
`.swift-format`.

## Definition of covered

“Covered” means an important behavior has a deterministic assertion, not merely
that a line executed. Every domain must cover its parsers, business services,
meaningful use cases, error mapping, cancellation, and outputs when those
concepts exist. UI-only hub packages are validated through their typed boundary
tests and app UI journeys; pass-through use cases are not created to inflate a
percentage.

## Memory safety

Automated tests verify representative ViewModels, authenticated UI scope, and
SessionScope release or invalidate after cancellation, pop, dismissal, and
logout. SecureWebKit verifies delegate cleanup. Release acceptance additionally
requires Allocations and Leaks traces across five repetitions. Neither XCTest
nor Instruments can prove that all future code is leak-free, so ownership tests
must be updated whenever a new Task, observer, timer, delegate, or SDK is added.

## Performance

CI performance measurements are regression signals. The 60 Hz baseline and
120 Hz readiness decision is made only from the physical-device matrix in
`Performance.md`; iOS, thermal state, and power policy ultimately control the
actual refresh rate.
