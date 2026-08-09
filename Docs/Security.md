# Security

No production secret, certificate, PIN, OTP, token, or customer payload is hardcoded. The sample credential values exist only in the deterministic fake login path.

CoreNetworking defines TLS, pinning, and mTLS integration seams. CoreSecurity supplies Keychain credentials, host policy adapters, and security-monitoring contracts. Real certificates, SDK initialization, and vendor shielding belong in app-composed adapters.

Structured logs classify fields as public or sensitive; sensitive values are redacted before reaching a destination. Analytics screen identifiers contain stable names only, never route payloads or customer identifiers.

Backend text may populate whitelisted display fields. Backend codes map to feature-owned typed actions and cannot name Swift types, Views, routes, arbitrary URLs, or classes.

Web application-link recognition and normal Web security are independent. Recognizing `iosrevamp` never relaxes HTTPS/host/bridge policy. WebKit delegates and handlers are removed during teardown.

Navigation is non-restorable by default because OTP, authorization, transfer, and approval journeys may be sensitive or transient.

