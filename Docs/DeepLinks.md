# Deep links

Push notifications, app URLs, WebView URLs, QR results, banners, and launch arguments enter one `DeepLinkOrchestrator`. A registry aggregates app adapters around feature-owned parsers, avoiding a global URL switch and keeping feature knowledge in its domain.

A resolution states its authentication requirement, optional preflight, and typed navigation application. Parsing never performs networking. The orchestrator retains only the source URL while authentication is pending, then resolves it again after `SessionScope` exists.

For an authenticated link received while logged out, login creates the session first. Links without preflight prime tab/path state before authenticated-ready is rendered. Links with preflight switch to authenticated-preparing, replacing Password with a loading surface, run the use case, prime navigation, then reveal authenticated-ready. `MainTabContainer` is not constructed underneath the preparing state, so Dashboard cannot flash or emit a false visit.

SecureWebKit asks the same app registry whether a URL is an application link. Recognized links cancel WebKit navigation and re-enter the orchestrator. Unrecognized URLs are independently evaluated by HTTPS and host security policy.

