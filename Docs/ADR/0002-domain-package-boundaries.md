# ADR 0002: Stable domain packages

## Decision

Use one package per stable business capability and one physical PlatformKit package with separately importable technical targets.

## Why

This gives teams ownership and incremental build boundaries without producing a package per screen or a manifest per utility. Wealth is independent from Financial Hub because the hub composes product entry points but does not own investment implementation.

## Consequences

Features communicate across domains through outputs and app mappings. New shared business modules require two real consumers and matching semantics. Empty future-domain packages are prohibited.

