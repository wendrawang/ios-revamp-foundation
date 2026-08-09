import CoreLogging
import Foundation
import SecureWebKit
import Testing
import WebKit

private final class URLSink: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    // Menyimpan URL callback WebKit secara thread-safe untuk assertion.
    func append(_ url: URL) { lock.withLock { storage.append(url) } }
    // Mengambil snapshot URL callback WebKit secara thread-safe.
    func values() -> [URL] { lock.withLock { storage } }
}

// Memverifikasi application deep link takes priority over web host policy.
@Test func applicationDeepLinkTakesPriorityOverWebHostPolicy() {
    let decider = SecureWebNavigationDecider(
        policy: WebNavigationPolicy(allowedHosts: ["allowed.test"]),
        isApplicationDeepLink: { $0.scheme == "iosrevamp" }
    )
    #expect(decider.decision(for: URL(string: "iosrevamp://rewards")!) == .applicationDeepLink)
}

// Memverifikasi application deep link is cancelled and forwarded.
@MainActor
@Test func applicationDeepLinkIsCancelledAndForwarded() {
    let sink = URLSink()
    let coordinator = SecureWebCoordinator(
        decider: SecureWebNavigationDecider(
            policy: WebNavigationPolicy(allowedHosts: ["allowed.test"]),
            isApplicationDeepLink: { $0.scheme == "iosrevamp" }
        ),
        submitApplicationDeepLink: { sink.append($0) },
        logger: InMemoryLogger()
    )
    let url = URL(string: "iosrevamp://rewards/detail?id=reward-001")!

    #expect(coordinator.navigationPolicy(for: url) == .cancel)
    #expect(sink.values() == [url])
}

// Memverifikasi allowed httpshost loads.
@Test func allowedHTTPSHostLoads() {
    let policy = WebNavigationPolicy(allowedHosts: ["allowed.test"])
    #expect(policy.decision(for: URL(string: "https://allowed.test/page")!) == .allow)
}

// Memverifikasi unknown host is rejected.
@Test func unknownHostIsRejected() {
    let policy = WebNavigationPolicy(allowedHosts: ["allowed.test"])
    #expect(policy.decision(for: URL(string: "https://evil.test/page")!) == .reject)
}

// Memverifikasi coordinator cleanup detaches web view delegate.
@MainActor
@Test func coordinatorCleanupDetachesWebViewDelegate() {
    let coordinator = SecureWebCoordinator(
        decider: SecureWebNavigationDecider(
            policy: WebNavigationPolicy(allowedHosts: ["allowed.test"]),
            isApplicationDeepLink: { _ in false }
        ),
        submitApplicationDeepLink: { _ in },
        logger: InMemoryLogger()
    )
    let webView = WKWebView()
    webView.navigationDelegate = coordinator

    coordinator.cleanup(webView: webView)

    #expect(coordinator.isCleanedUp)
    #expect(webView.navigationDelegate == nil)
}
