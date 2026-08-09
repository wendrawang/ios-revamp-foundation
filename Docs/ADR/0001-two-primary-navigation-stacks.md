# ADR 0001: Two primary navigation stacks

## Decision

Use one unauthenticated and one authenticated `NavigationStack`. The authenticated stack has the native five-tab container as its root.

## Why

Authentication is application state, not screen history. A stack per tab or package fragments global journeys and makes cross-domain back behavior inconsistent. One authenticated path allows a service journey to sit above the complete tab container while preserving its originating state.

## Consequences

Feature outputs are mapped by app composition. Features do not create nested stacks to match module boundaries. Isolated modal navigation may be added later only for a concrete presentation context.

