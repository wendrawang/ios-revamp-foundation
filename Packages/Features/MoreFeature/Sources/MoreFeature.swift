import DesignSystem
import SwiftUI

public enum MoreAccessibilityID {
    public static let upgrade = "more.upgrade"
    public static let web = "more.web"
    public static let logout = "more.logout"
}

public enum MoreOutput: Equatable, Sendable {
    case openUpgradeService
    case openWebSample
    case logout
}

public struct MoreRootView: View {
    private let isWebEnabled: Bool
    private let output: (MoreOutput) -> Void

    public init(isWebEnabled: Bool, output: @escaping (MoreOutput) -> Void) {
        self.isWebEnabled = isWebEnabled
        self.output = output
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text("Services").font(.largeTitle.bold())
                DSPrimaryButton(title: "Upgrade Service", accessibilityIdentifier: MoreAccessibilityID.upgrade) {
                    output(.openUpgradeService)
                }
                if isWebEnabled {
                    DSPrimaryButton(title: "Open Web sample", accessibilityIdentifier: MoreAccessibilityID.web) {
                        output(.openWebSample)
                    }
                }
                Button("Log out", role: .destructive) { output(.logout) }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier(MoreAccessibilityID.logout)
            }
            .padding(DSSpacing.lg)
        }
        .navigationTitle("More")
    }
}
