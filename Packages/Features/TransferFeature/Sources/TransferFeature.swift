import Combine
import CoreAnalytics
import CoreLogging
import CoreNetworking
import DesignSystem
import Foundation
import SwiftUI

public enum TransferAccessibilityID {
    public static let submit = "transfer.submit"
    public static let result = "transfer.result"
    public static let wealthCurrent = "transfer.wealth.current"
    public static let wealthCanonical = "transfer.wealth.canonical"
    public static let sheetShow = "transfer.sheet.show"
    public static let sheetPrimary = "transfer.sheet.primary"
    public static let blockerToggle = "transfer.blocker.toggle"
}

public enum TransferRoute: Hashable, Sendable {
    case landing
    case result(referenceID: String)
}

public enum WealthOpenMode: Equatable, Sendable {
    case currentJourney
    case canonicalFinancial
}

public enum TransferOutput: Equatable, Sendable {
    case openWealth(productID: String, mode: WealthOpenMode)
    case openUpgradeService
    case toggleConnectivityBlocker
}

public struct TransferReceipt: Codable, Equatable, Sendable {
    public let referenceID: String

    public init(referenceID: String) {
        self.referenceID = referenceID
    }
}

public protocol TransferServicing: Sendable {
    func submitDemoTransfer() async throws -> TransferReceipt
}

public struct FakeTransferService: TransferServicing {
    public init() {}

    public func submitDemoTransfer() async throws -> TransferReceipt {
        try await Task.sleep(nanoseconds: 60_000_000)
        try Task.checkCancellation()
        return TransferReceipt(referenceID: "transfer-001")
    }
}

public struct RemoteTransferService: TransferServicing {
    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func submitDemoTransfer() async throws -> TransferReceipt {
        let response = try await client.send(HTTPRequest(path: "/transfers", method: .post))
        return try response.decode(TransferReceipt.self)
    }
}

public struct SubmitTransferUseCase: Sendable {
    private let service: any TransferServicing

    public init(service: any TransferServicing) {
        self.service = service
    }

    public func execute() async throws -> TransferReceipt {
        try await service.submitDemoTransfer()
    }
}

public struct BackendErrorDTO: Equatable, Sendable {
    public let code: String
    public let title: String
    public let message: String
    public let primaryButtonTitle: String

    public init(code: String, title: String, message: String, primaryButtonTitle: String) {
        self.code = code
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
    }
}

public enum TransferSheetAction: Equatable, Sendable {
    case requestUpgrade
    case dismiss
}

public struct TransferSheetPresentation: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let message: String
    public let primaryButtonTitle: String
    public let primaryAction: TransferSheetAction

    public init(
        id: String,
        title: String,
        message: String,
        primaryButtonTitle: String,
        primaryAction: TransferSheetAction
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
    }
}

public struct TransferPresentationMapper: Sendable {
    public init() {}

    public func map(_ error: BackendErrorDTO) -> TransferSheetPresentation {
        if error.code == "UPGRADE_REQUIRED" {
            return TransferSheetPresentation(
                id: error.code,
                title: error.title,
                message: error.message,
                primaryButtonTitle: error.primaryButtonTitle,
                primaryAction: .requestUpgrade
            )
        }
        return TransferSheetPresentation(
            id: "GENERIC",
            title: "Unable to continue",
            message: "Please try again later.",
            primaryButtonTitle: "Close",
            primaryAction: .dismiss
        )
    }
}

@MainActor
public final class TransferViewModel: ObservableObject {
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var errorMessage: String?

    private let useCase: SubmitTransferUseCase
    private let analytics: any AnalyticsTracking
    private let navigate: @MainActor (TransferRoute) -> Void
    private var task: Task<Void, Never>?

    public init(
        useCase: SubmitTransferUseCase,
        analytics: any AnalyticsTracking,
        navigate: @escaping @MainActor (TransferRoute) -> Void
    ) {
        self.useCase = useCase
        self.analytics = analytics
        self.navigate = navigate
    }

    public func submit() {
        task?.cancel()
        isSubmitting = true
        task = Task { [weak self, useCase, analytics, navigate] in
            do {
                let receipt = try await useCase.execute()
                guard !Task.isCancelled else { return }
                analytics.track(AnalyticsEvent(name: "transfer_submitted"))
                self?.isSubmitting = false
                navigate(.result(referenceID: receipt.referenceID))
            } catch is CancellationError {
                self?.isSubmitting = false
            } catch {
                self?.isSubmitting = false
                self?.errorMessage = "Transfer could not be submitted."
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isSubmitting = false
    }

    deinit { task?.cancel() }
}

public struct TransferScreen: View {
    private let route: TransferRoute
    private let service: any TransferServicing
    private let analytics: any AnalyticsTracking
    private let navigate: @MainActor (TransferRoute) -> Void
    private let output: @MainActor (TransferOutput) -> Void

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
        case let .result(referenceID):
            TransferResultScreen(referenceID: referenceID, output: output)
        }
    }
}

private struct TransferLandingScreen: View {
    @StateObject private var viewModel: TransferViewModel

    init(
        service: any TransferServicing,
        analytics: any AnalyticsTracking,
        navigate: @escaping @MainActor (TransferRoute) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TransferViewModel(
            useCase: SubmitTransferUseCase(service: service),
            analytics: analytics,
            navigate: navigate
        ))
    }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "arrow.left.arrow.right.circle.fill").font(.system(size: 60)).foregroundStyle(DSColor.accent)
            Text("Transfer").font(.largeTitle.bold())
            Text("A deterministic sample transfer demonstrates domain-owned service and use-case boundaries.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            DSPrimaryButton(title: viewModel.isSubmitting ? "Submitting…" : "Complete demo transfer", accessibilityIdentifier: TransferAccessibilityID.submit) {
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
            VStack(spacing: DSSpacing.md) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(.green)
                Text("Transfer Result")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier(TransferAccessibilityID.result)
                Text("Reference: \(referenceID)").foregroundStyle(.secondary)
                DSPrimaryButton(title: "Open Wealth in current journey", accessibilityIdentifier: TransferAccessibilityID.wealthCurrent) {
                    output(.openWealth(productID: "wealth-001", mode: .currentJourney))
                }
                DSPrimaryButton(title: "Open Wealth canonically", accessibilityIdentifier: TransferAccessibilityID.wealthCanonical) {
                    output(.openWealth(productID: "wealth-001", mode: .canonicalFinancial))
                }
                Button("Simulate upgrade-required response") {
                    presentation = TransferPresentationMapper().map(BackendErrorDTO(
                        code: "UPGRADE_REQUIRED",
                        title: "Upgrade required",
                        message: "This transfer limit needs a higher service tier.",
                        primaryButtonTitle: "Upgrade"
                    ))
                }
                .accessibilityIdentifier(TransferAccessibilityID.sheetShow)
                Button("Toggle connectivity blocker") {
                    output(.toggleConnectivityBlocker)
                }
                .accessibilityIdentifier(TransferAccessibilityID.blockerToggle)
            }
            .padding(DSSpacing.lg)

            if let presentation {
                DSBottomSheetScaffold(
                    title: presentation.title,
                    message: presentation.message,
                    primaryTitle: presentation.primaryButtonTitle,
                    primaryAccessibilityIdentifier: TransferAccessibilityID.sheetPrimary,
                    onPrimary: {
                        self.presentation = nil
                        if presentation.primaryAction == .requestUpgrade { output(.openUpgradeService) }
                    },
                    onDismiss: { self.presentation = nil }
                )
            }
        }
        .navigationTitle("Result")
    }
}
