import CoreLogging
import Foundation
import SecureWebKit
import SwiftUI

enum AppWebRoute: Hashable, Sendable {
    case sample
}

@MainActor
struct SecureWebDestination: View {
    let coordinator: AppCoordinator

    private let sampleHTML = """
    <!doctype html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: -apple-system; padding: 32px; background: #f6f6f6; }
          a { display: block; padding: 18px; color: white; background: #d71920;
              border-radius: 12px; text-decoration: none; text-align: center; font-weight: 600; }
        </style>
      </head>
      <body>
        <h1>Secure Web sample</h1>
        <p>This local HTML page requires no external production service.</p>
        <a href="iosrevamp://rewards/detail?id=reward-001">Open native Reward Detail</a>
      </body>
    </html>
    """

    var body: some View {
        SecureWebView(
            configuration: SecureWebConfiguration(
                allowedHosts: ["example.test"],
                initialHTML: sampleHTML,
                baseURL: URL(string: "https://example.test")
            ),
            logger: coordinator.container.logger,
            isApplicationDeepLink: { [weak coordinator] url in
                MainActor.assumeIsolated { coordinator?.recognizesDeepLink(url) ?? false }
            },
            submitApplicationDeepLink: { [weak coordinator] url in
                Task { @MainActor in coordinator?.handleDeepLink(url, source: .webView) }
            }
        )
        .navigationTitle("Secure Web")
        .accessibilityIdentifier(AppAccessibilityID.webSample)
    }
}
