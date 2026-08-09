import CoreAnalytics
import Foundation
import TransferFeature
import Testing

private final class WeakReference<Object: AnyObject> {
    weak var value: Object?

    init(_ value: Object?) {
        self.value = value
    }
}

private enum StubTransferMode: Sendable {
    case success(TransferReceipt)
    case failure
    case suspended
}

private enum StubTransferError: Error {
    case rejected
}

private struct StubTransferService: TransferServicing {
    let mode: StubTransferMode

    func submitDemoTransfer() async throws -> TransferReceipt {
        switch mode {
        case let .success(receipt): return receipt
        case .failure: throw StubTransferError.rejected
        case .suspended:
            try await Task.sleep(nanoseconds: 2_000_000_000)
            throw CancellationError()
        }
    }
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    Issue.record("Timed out waiting for transfer state")
}

@Test func submitTransferUseCaseReturnsReceipt() async throws {
    let receipt = try await SubmitTransferUseCase(service: FakeTransferService()).execute()
    #expect(receipt.referenceID == "transfer-001")
}

@Test func upgradeCodeMapsToTypedAction() {
    let result = TransferPresentationMapper().map(BackendErrorDTO(
        code: "UPGRADE_REQUIRED",
        title: "Dynamic title",
        message: "Dynamic message",
        primaryButtonTitle: "Dynamic button"
    ))
    #expect(result.primaryAction == .requestUpgrade)
    #expect(result.title == "Dynamic title")
}

@Test func unknownBackendCodeCannotCreateNavigationAction() {
    let result = TransferPresentationMapper().map(BackendErrorDTO(
        code: "SOME_SERVER_ROUTE_NAME",
        title: "Unsafe",
        message: "Unsafe",
        primaryButtonTitle: "Go"
    ))
    #expect(result.primaryAction == .dismiss)
    #expect(result.id == "GENERIC")
}

@MainActor
@Test func transferViewModelTracksSuccessAndNavigates() async throws {
    let analytics = InMemoryAnalytics()
    var route: TransferRoute?
    let viewModel = TransferViewModel(
        useCase: SubmitTransferUseCase(service: StubTransferService(
            mode: .success(TransferReceipt(referenceID: "receipt-001"))
        )),
        analytics: analytics,
        navigate: { route = $0 }
    )

    viewModel.submit()
    try await waitUntil { route != nil }

    #expect(route == .result(referenceID: "receipt-001"))
    #expect(analytics.events().map(\.name) == ["transfer_submitted"])
    #expect(!viewModel.isSubmitting)
}

@MainActor
@Test func transferViewModelMapsServiceFailure() async throws {
    let viewModel = TransferViewModel(
        useCase: SubmitTransferUseCase(service: StubTransferService(mode: .failure)),
        analytics: InMemoryAnalytics(),
        navigate: { _ in Issue.record("Failure must not navigate") }
    )

    viewModel.submit()
    try await waitUntil { viewModel.errorMessage != nil }

    #expect(viewModel.errorMessage == "Transfer could not be submitted.")
    #expect(!viewModel.isSubmitting)
}

@MainActor
@Test func transferViewModelCancelsAndReleasesAfterFeatureLifetimeEnds() async throws {
    let weakViewModel = WeakReference<TransferViewModel>(nil)
    var navigationCount = 0
    do {
        let viewModel = TransferViewModel(
            useCase: SubmitTransferUseCase(service: StubTransferService(mode: .suspended)),
            analytics: InMemoryAnalytics(),
            navigate: { _ in navigationCount += 1 }
        )
        weakViewModel.value = viewModel
        viewModel.submit()
        viewModel.cancel()
    }
    try await Task.sleep(nanoseconds: 10_000_000)

    #expect(navigationCount == 0)
    #expect(weakViewModel.value == nil)
}
