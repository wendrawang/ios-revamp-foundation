import CoreLogging
import Foundation
import SwiftUI
import WebKit

public struct SecureWebConfiguration: Sendable {
    public let allowedHosts: Set<String>
    public let initialHTML: String
    public let baseURL: URL?

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(allowedHosts: Set<String>, initialHTML: String, baseURL: URL? = nil) {
        self.allowedHosts = allowedHosts
        self.initialHTML = initialHTML
        self.baseURL = baseURL
    }
}

public enum WebNavigationDecision: Equatable, Sendable {
    case applicationDeepLink
    case allow
    case reject
}

public struct WebNavigationPolicy: Sendable {
    private let allowedHosts: Set<String>

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    // Memisahkan application deep-link interception dari HTTPS host policy.
    public func decision(for url: URL) -> WebNavigationDecision {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return .reject }
        return allowedHosts.contains(host) ? .allow : .reject
    }
}

public struct SecureWebNavigationDecider: Sendable {
    private let policy: WebNavigationPolicy
    private let isApplicationDeepLink: @Sendable (URL) -> Bool

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(policy: WebNavigationPolicy, isApplicationDeepLink: @escaping @Sendable (URL) -> Bool) {
        self.policy = policy
        self.isApplicationDeepLink = isApplicationDeepLink
    }

    // Memisahkan application deep-link interception dari HTTPS host policy.
    public func decision(for url: URL) -> WebNavigationDecision {
        isApplicationDeepLink(url) ? .applicationDeepLink : policy.decision(for: url)
    }
}

public struct SecureWebView: UIViewRepresentable {
    private let configuration: SecureWebConfiguration
    private let logger: any AppLogging
    private let isApplicationDeepLink: @Sendable (URL) -> Bool
    private let submitApplicationDeepLink: @Sendable (URL) -> Void

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(
        configuration: SecureWebConfiguration,
        logger: any AppLogging,
        isApplicationDeepLink: @escaping @Sendable (URL) -> Bool,
        submitApplicationDeepLink: @escaping @Sendable (URL) -> Void
    ) {
        self.configuration = configuration
        self.logger = logger
        self.isApplicationDeepLink = isApplicationDeepLink
        self.submitApplicationDeepLink = submitApplicationDeepLink
    }

    // Membuat coordinator WebKit yang memiliki policy dan callback terinjeksi.
    public func makeCoordinator() -> SecureWebCoordinator {
        SecureWebCoordinator(
            decider: SecureWebNavigationDecider(
                policy: WebNavigationPolicy(allowedHosts: configuration.allowedHosts),
                isApplicationDeepLink: isApplicationDeepLink
            ),
            submitApplicationDeepLink: submitApplicationDeepLink,
            logger: logger
        )
    }

    // Membuat WKWebView dan memasang delegate yang dimiliki coordinator.
    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(configuration.initialHTML, baseURL: configuration.baseURL)
        return webView
    }

    // Menjaga UIViewRepresentable tanpa memuat ulang halaman secara tidak perlu.
    public func updateUIView(_ webView: WKWebView, context: Context) {}

    // Membersihkan delegate WebKit sebelum view dilepas.
    public static func dismantleUIView(_ webView: WKWebView, coordinator: SecureWebCoordinator) {
        coordinator.cleanup(webView: webView)
    }
}

@MainActor
public final class SecureWebCoordinator: NSObject, WKNavigationDelegate {
    private let decider: SecureWebNavigationDecider
    private let submitApplicationDeepLink: @Sendable (URL) -> Void
    private let logger: any AppLogging
    public private(set) var isCleanedUp = false

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(
        decider: SecureWebNavigationDecider,
        submitApplicationDeepLink: @escaping @Sendable (URL) -> Void,
        logger: any AppLogging
    ) {
        self.decider = decider
        self.submitApplicationDeepLink = submitApplicationDeepLink
        self.logger = logger
    }

    // Memutuskan allow atau cancel untuk setiap WKWebView navigation action.
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(navigationPolicy(for: url))
    }

    // Mengevaluasi URL normal melalui HTTPS dan allowed-host policy.
    public func navigationPolicy(for url: URL) -> WKNavigationActionPolicy {
        switch decider.decision(for: url) {
        case .applicationDeepLink:
            logger.log(LogEntry(level: .info, category: "web", message: "Forwarding application deep link"))
            submitApplicationDeepLink(url)
            return .cancel
        case .allow:
            return .allow
        case .reject:
            logger.log(
                LogEntry(
                    level: .warning,
                    category: "web",
                    message: "Rejected web navigation",
                    fields: [LogField(name: "host", value: url.host ?? "unknown", privacy: .public)]
                ))
            return .cancel
        }
    }

    // Melepas delegate serta callback WebKit untuk mencegah retain cycle.
    public func cleanup(webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
        isCleanedUp = true
    }
}
