import CoreAnalytics
import TransferFeature
import Testing


private final class WeakReference<Object: AnyObject> {
    weak var value: Object?

    init(_ value: Object?) {
        self.value = value
    }
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
@Test func transferViewModelReleasesAfterFeatureLifetimeEnds() {
    let weakViewModel = WeakReference<TransferViewModel>(nil)
    do {
        let viewModel = TransferViewModel(
            useCase: SubmitTransferUseCase(service: FakeTransferService()),
            analytics: InMemoryAnalytics(),
            navigate: { _ in }
        )
        weakViewModel.value = viewModel
    }
    #expect(weakViewModel.value == nil)
}
