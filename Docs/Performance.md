# Performance

The baseline is smooth 60 Hz interaction. On ProMotion hardware, app-owned synchronous interaction work should fit within 8.33 ms where practical; the app does not claim that iOS always schedules 120 Hz.

Initial acceptance targets:

- App-owned frame work within 16.67 ms at 60 Hz.
- Interaction-critical synchronous work targeting 8.33 ms on a reference ProMotion device.
- No app-caused main-thread stall above 100 ms in acceptance journeys.
- p95 interaction response below 100 ms excluding network completion.
- Animation hitch-time ratio below 1% in defined scroll/transition journeys.
- Cold-launch p95 target at or below two seconds, recalibrated after real security SDK integration.
- No retained feature scopes and no unexplained steady-state growth after five repeated journeys.

Views perform no networking, decoding, synchronous IO, image decoding, or heavy mapping. Observable state is feature-scoped, collections are lazy, routes are values, and inactive tabs stop expensive resources.

Profile release-like builds on an oldest-supported reference device and a current ProMotion device using SwiftUI Instruments, Animation Hitches, Time Profiler, Allocations, Leaks, Network Instruments, and points of interest around launch, preflight, decoding, and navigation commits. Adopt UIKit/Core Animation only when profiling proves a concrete SwiftUI limitation.

