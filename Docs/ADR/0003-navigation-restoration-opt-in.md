# ADR 0003: Navigation restoration is opt-in

## Decision

Do not persist `NavigationPath` by default.

## Why

Banking paths often contain transient authorization, OTP, PIN, approval, or transaction context. Automatic restoration can revive invalid state and unnecessarily persist sensitive identifiers.

## Consequences

Routes remain lightweight values but are not required to be `Codable`. A future restorable journey must define a sanitized restoration model, expiry policy, revalidation step, and security review independently of its runtime route.
