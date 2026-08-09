import DesignSystem
import SwiftUI

public enum FinancialHubAccessibilityID {
    public static let investment = "financial.investment"
}

public enum FinancialHubOutput: Equatable, Sendable {
    case openWealth(productID: String)
}

public struct FinancialHubRootView: View {
    private let isWealthEnabled: Bool
    private let output: (FinancialHubOutput) -> Void

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(isWealthEnabled: Bool, output: @escaping (FinancialHubOutput) -> Void) {
        self.isWealthEnabled = isWealthEnabled
        self.output = output
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.md) {
                financialCard(title: "Savings", icon: "wallet.bifold")
                financialCard(title: "Investment", icon: "chart.line.uptrend.xyaxis")
                    .onTapGesture {
                        if isWealthEnabled { output(.openWealth(productID: "wealth-001")) }
                    }
                    .accessibilityIdentifier(FinancialHubAccessibilityID.investment)
                financialCard(title: "Loan", icon: "building.columns")
            }
            .padding(DSSpacing.lg)
        }
        .navigationTitle("Financial")
    }

    // Membangun card Financial dengan output navigation bertipe.
    private func financialCard(title: String, icon: String) -> some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: icon).font(.title2).foregroundStyle(DSColor.accent)
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(DSSpacing.lg)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
