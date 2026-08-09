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

These are acceptance criteria, not compile-time promises. iOS controls display
refresh rate and may reduce it for power, thermal, accessibility, or system
reasons. Simulator results cannot prove 60 or 120 Hz behavior.

## Required device matrix

Before a performance-sensitive release, profile a Release configuration on:

- the oldest supported physical iPhone at 60 Hz;
- a current physical ProMotion iPhone with 120 Hz enabled;
- Low Power Mode as a separate observation, not as the 120 Hz acceptance run.

For the agreed Dashboard scroll, tab switch, Transfer result, and scanner
activation journeys, capture:

- Animation Hitches and SwiftUI Instruments traces;
- p50/p95 interaction latency and main-thread stalls;
- frame/hitch behavior against 16.67 ms at 60 Hz;
- app-owned synchronous work against 8.33 ms at 120 Hz where practical;
- cold/warm launch, steady-state memory, and five repeated navigation cycles.

A release is blocked by reproducible app-owned hitches above the agreed budget,
an unexplained memory growth trend, or a retained feature/session graph. A
single average-FPS number is insufficient because it can hide severe hitches.

Views perform no networking, decoding, synchronous IO, image decoding, or heavy mapping. Observable state is feature-scoped, collections are lazy, routes are values, and inactive tabs stop expensive resources.

Profile release-like builds on an oldest-supported reference device and a current ProMotion device using SwiftUI Instruments, Animation Hitches, Time Profiler, Allocations, Leaks, Network Instruments, and points of interest around launch, preflight, decoding, and navigation commits. Adopt UIKit/Core Animation only when profiling proves a concrete SwiftUI limitation.

`Navigation Commit` and `Authenticated Deep Link Preflight` points of interest
are emitted by the app. XCTest records navigation clock/memory metrics and app
launch metrics, providing regression evidence between device profiling runs.
