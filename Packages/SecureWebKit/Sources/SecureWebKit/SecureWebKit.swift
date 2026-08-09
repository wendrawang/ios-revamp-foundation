import CoreLogging
import Foundation
import SwiftUI
import WebKit

public struct SecureWebConfiguration: Sendable {
    public let allowedHosts: Set<String>
    public let initialHTML: String
    public let baseURL: URL?

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

    public init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    public func decision(for url: URL) -> WebNavigationDecision {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return .reject }
        return allowedHosts.contains(host) ? .allow : .reject
    }
}

public struct SecureWebNavigationDecider: Sendable {
    private let policy: WebNavigationPolicy
    private let isApplicationDeepLink: @Sendable (URL) -> Bool

    public init(policy: WebNavigationPolicy, isApplicationDeepLink: @escaping @Sendable (URL) -> Bool) {
        self.policy = policy
        self.isApplicationDeepLink = isApplicationDeepLink
    }

    public func decision(for url: URL) -> WebNavigationDecision {
        isApplicationDeepLink(url) ? .applicationDeepLink : policy.decision(for: url)
    }
}

public struct SecureWebView: UIViewRepresentable {
    private let configuration: SecureWebConfiguration
    private let logger: any AppLogging
    private let isApplicationDeepLink: @Sendable (URL) -> Bool
    private let submitApplicationDeepLink: @Sendable (URL) -> Void

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

    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(configuration.initialHTML, baseURL: configuration.baseURL)
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {}

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

    public init(
        decider: SecureWebNavigationDecider,
        submitApplicationDeepLink: @escaping @Sendable (URL) -> Void,
        logger: any AppLogging
    ) {
        self.decider = decider
        self.submitApplicationDeepLink = submitApplicationDeepLink
        self.logger = logger
    }

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

    public func navigationPolicy(for url: URL) -> WKNavigationActionPolicy {
        switch decider.decision(for: url) {
        case .applicationDeepLink:
            logger.log(LogEntry(level: .info, category: "web", message: "Forwarding application deep link"))
            submitApplicationDeepLink(url)
            return .cancel
        case .allow:
            return .allow
        case .reject:
            logger.log(LogEntry(
                level: .warning,
                category: "web",
                message: "Rejected web navigation",
                fields: [LogField(name: "host", value: url.host ?? "unknown", privacy: .public)]
            ))
            return .cancel
        }
    }

    public func cleanup(webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
        isCleanedUp = true
    }
}
