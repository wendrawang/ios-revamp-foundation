import DesignSystem
import SwiftUI

public enum UpgradeServiceAccessibilityID {
    public static let root = "upgrade.root"
}

public enum UpgradeServiceRoute: Hashable, Sendable {
    case start
}

public struct UpgradeServiceScreen: View {
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}

    public var body: some View {
        VStack(spacing: DSSpacing.large) {
            Image(systemName: "person.badge.shield.checkmark").font(.system(size: 60)).foregroundStyle(DSColor.accent)
            Text("Upgrade Service").font(.largeTitle.bold())
            Text("One shared service journey is used from every entry point.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(DSSpacing.large)
        .navigationTitle("Upgrade")
        .accessibilityIdentifier(UpgradeServiceAccessibilityID.root)
    }
}
