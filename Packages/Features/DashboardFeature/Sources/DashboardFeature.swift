import DesignSystem
import SwiftUI

public enum DashboardAccessibilityID {
    public static let transfer = "dashboard.transfer"
    public static let upgrade = "dashboard.upgrade"
    public static let blockerToggle = "dashboard.blocker.toggle"
}

public enum DashboardOutput: Equatable, Sendable {
    case openTransfer
    case openUpgradeService
    case toggleConnectivityBlocker
}

public struct DashboardRootView: View {
    private let isTransferEnabled: Bool
    private let output: (DashboardOutput) -> Void

    public init(isTransferEnabled: Bool, output: @escaping (DashboardOutput) -> Void) {
        self.isTransferEnabled = isTransferEnabled
        self.output = output
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("Good afternoon").font(.largeTitle.bold())
                DSFeatureCard(title: "Banking shortcuts") {
                    DSPrimaryButton(title: "Open Transfer", accessibilityIdentifier: DashboardAccessibilityID.transfer) {
                        output(.openTransfer)
                    }
                    .disabled(!isTransferEnabled)
                    DSPrimaryButton(title: "Upgrade Service", accessibilityIdentifier: DashboardAccessibilityID.upgrade) {
                        output(.openUpgradeService)
                    }
                }
                Button("Toggle no-internet blocker") { output(.toggleConnectivityBlocker) }
                    .accessibilityIdentifier(DashboardAccessibilityID.blockerToggle)
            }
            .padding(DSSpacing.lg)
        }
        .navigationTitle("Dashboard")
    }
}
