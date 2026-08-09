import CoreAnalytics
import DesignSystem
import SwiftUI

public struct TransferScreen: View {
    private let route: TransferRoute
    private let service: any TransferServicing
    private let analytics: any AnalyticsTracking
    private let navigate: @MainActor (TransferRoute) -> Void
    private let output: @MainActor (TransferOutput) -> Void

    // Membuat feature root dengan dependency dan typed output callback.
    public init(
        route: TransferRoute,
        service: any TransferServicing,
        analytics: any AnalyticsTracking,
        navigate: @escaping @MainActor (TransferRoute) -> Void,
        output: @escaping @MainActor (TransferOutput) -> Void
    ) {
        self.route = route
        self.service = service
        self.analytics = analytics
        self.navigate = navigate
        self.output = output
    }

    @ViewBuilder public var body: some View {
        switch route {
        case .landing:
            TransferLandingScreen(service: service, analytics: analytics, navigate: navigate)
        case .result(let referenceID):
            TransferResultScreen(referenceID: referenceID, output: output)
        }
    }
}

private struct TransferLandingScreen: View {
    @StateObject private var viewModel: TransferViewModel

    // Membuat landing screen dan menjadikan ViewModel milik lifetime layar.
    init(
        service: any TransferServicing,
        analytics: any AnalyticsTracking,
        navigate: @escaping @MainActor (TransferRoute) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: TransferViewModel(
                useCase: SubmitTransferUseCase(service: service),
                analytics: analytics,
                navigate: navigate
            ))
    }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(DSColor.accent)
            Text("Transfer").font(.largeTitle.bold())
            Text("A deterministic sample transfer demonstrates domain-owned service and use-case boundaries.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            DSPrimaryButton(
                title: viewModel.isSubmitting ? "Submitting…" : "Complete demo transfer",
                accessibilityIdentifier: TransferAccessibilityID.submit
            ) {
                viewModel.submit()
            }
            .disabled(viewModel.isSubmitting)
        }
        .padding(DSSpacing.lg)
        .navigationTitle("Transfer")
        .onDisappear { viewModel.cancel() }
    }
}

private struct TransferResultScreen: View {
    let referenceID: String
    let output: @MainActor (TransferOutput) -> Void
    @State private var presentation: TransferSheetPresentation?

    var body: some View {
        ZStack {
            resultContent
            if let presentation {
                sheet(for: presentation)
            }
        }
        .navigationTitle("Result")
    }

    private var resultContent: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(.green)
            Text("Transfer Result")
                .font(.largeTitle.bold())
                .accessibilityIdentifier(TransferAccessibilityID.result)
            Text("Reference: \(referenceID)").foregroundStyle(.secondary)
            wealthButtons
            Button("Simulate upgrade-required response", action: showUpgradeSheet)
                .accessibilityIdentifier(TransferAccessibilityID.sheetShow)
            Button("Toggle connectivity blocker") { output(.toggleConnectivityBlocker) }
                .accessibilityIdentifier(TransferAccessibilityID.blockerToggle)
        }
        .padding(DSSpacing.lg)
    }

    private var wealthButtons: some View {
        Group {
            DSPrimaryButton(
                title: "Open Wealth in current journey",
                accessibilityIdentifier: TransferAccessibilityID.wealthCurrent
            ) { output(.openWealth(productID: "wealth-001", mode: .currentJourney)) }
            DSPrimaryButton(
                title: "Open Wealth canonically",
                accessibilityIdentifier: TransferAccessibilityID.wealthCanonical
            ) { output(.openWealth(productID: "wealth-001", mode: .canonicalFinancial)) }
        }
    }

    // Membuat feature-owned sheet dari presentation model yang sudah di-whitelist.
    private func sheet(for presentation: TransferSheetPresentation) -> some View {
        DSBottomSheetScaffold(
            title: presentation.title,
            message: presentation.message,
            primaryTitle: presentation.primaryButtonTitle,
            primaryAccessibilityIdentifier: TransferAccessibilityID.sheetPrimary,
            onPrimary: { handlePrimaryAction(presentation.primaryAction) },
            onDismiss: { self.presentation = nil }
        )
    }

    // Memetakan tombol sheet ke typed feature output, bukan backend route.
    private func handlePrimaryAction(_ action: TransferSheetAction) {
        presentation = nil
        if action == .requestUpgrade { output(.openUpgradeService) }
    }

    // Menampilkan copy backend melalui mapper frontend yang aman.
    private func showUpgradeSheet() {
        presentation = TransferPresentationMapper().map(
            BackendErrorDTO(
                code: "UPGRADE_REQUIRED",
                title: "Upgrade required",
                message: "This transfer limit needs a higher service tier.",
                primaryButtonTitle: "Upgrade"
            ))
    }
}
