import CoreAnalytics
import Foundation
import Testing
import TransferFeature

private final class WeakReference<Object: AnyObject> {
    weak var value: Object?

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
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

    // Mengembalikan hasil stub Transfer sesuai mode test yang dipilih.
    func submitDemoTransfer() async throws -> TransferReceipt {
        switch mode {
        case .success(let receipt): return receipt
        case .failure: throw StubTransferError.rejected
        case .suspended:
            try await Task.sleep(nanoseconds: 2_000_000_000)
            throw CancellationError()
        }
    }
}

// Menunggu perubahan async dengan timeout agar test tidak menggantung.
@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    Issue.record("Timed out waiting for transfer state")
}

// Memverifikasi submit transfer use case returns receipt.
@Test func submitTransferUseCaseReturnsReceipt() async throws {
    let receipt = try await SubmitTransferUseCase(service: FakeTransferService()).execute()
    #expect(receipt.referenceID == "transfer-001")
}

// Memverifikasi upgrade code maps to typed action.
@Test func upgradeCodeMapsToTypedAction() {
    let result = TransferPresentationMapper().map(
        BackendErrorDTO(
            code: "UPGRADE_REQUIRED",
            title: "Dynamic title",
            message: "Dynamic message",
            primaryButtonTitle: "Dynamic button"
        ))
    #expect(result.primaryAction == .requestUpgrade)
    #expect(result.title == "Dynamic title")
}

// Memverifikasi unknown backend code cannot create navigation action.
@Test func unknownBackendCodeCannotCreateNavigationAction() {
    let result = TransferPresentationMapper().map(
        BackendErrorDTO(
            code: "SOME_SERVER_ROUTE_NAME",
            title: "Unsafe",
            message: "Unsafe",
            primaryButtonTitle: "Go"
        ))
    #expect(result.primaryAction == .dismiss)
    #expect(result.identifier == "GENERIC")
}

// Memverifikasi transfer view model tracks success and navigates.
@MainActor
@Test func transferViewModelTracksSuccessAndNavigates() async throws {
    let analytics = InMemoryAnalytics()
    var route: TransferRoute?
    let viewModel = TransferViewModel(
        useCase: SubmitTransferUseCase(
            service: StubTransferService(
                mode: .success(TransferReceipt(referenceID: "receipt-001"))
            )),
        analytics: analytics,
        navigate: { navigatedRoute in route = navigatedRoute }
    )

    viewModel.submit()
    try await waitUntil { route != nil }

    #expect(route == .result(referenceID: "receipt-001"))
    #expect(analytics.events().map(\.name) == ["transfer_submitted"])
    #expect(!viewModel.isSubmitting)
}

// Memverifikasi transfer view model maps service failure.
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

// Memverifikasi transfer view model cancels and releases after feature lifetime ends.
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
