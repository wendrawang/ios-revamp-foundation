import Combine
import CoreAnalytics
import Foundation

@MainActor
public final class TransferViewModel: ObservableObject {
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var errorMessage: String?

    private let useCase: SubmitTransferUseCase
    private let analytics: any AnalyticsTracking
    private let navigate: @MainActor (TransferRoute) -> Void
    private var task: Task<Void, Never>?

    // Membuat ViewModel dengan use case, analytics, dan local navigation callback.
    public init(
        useCase: SubmitTransferUseCase,
        analytics: any AnalyticsTracking,
        navigate: @escaping @MainActor (TransferRoute) -> Void
    ) {
        self.useCase = useCase
        self.analytics = analytics
        self.navigate = navigate
    }

    // Memulai transfer, menerbitkan state UI, lalu membuka result jika berhasil.
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

    // Membatalkan pekerjaan yang dimiliki ketika layar tidak lagi aktif.
    public func cancel() {
        task?.cancel()
        task = nil
        isSubmitting = false
    }

    // Membatalkan Task agar tidak melewati lifetime ViewModel.
    deinit { task?.cancel() }
}
