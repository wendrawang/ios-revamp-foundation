import Foundation
import Testing
import WealthFeature

private enum StubWealthMode: Sendable {
    case success(WealthProduct)
    case suspended
}

private struct StubWealthService: WealthServicing {
    let mode: StubWealthMode

    // Mengambil data produk Wealth melalui service domain.
    func product(id: String) async throws -> WealthProduct {
        switch mode {
        case .success(let product): return product
        case .suspended:
            try await Task.sleep(nanoseconds: 2_000_000_000)
            throw CancellationError()
        }
    }
}

private final class WeakReference<Object: AnyObject> {
    weak var value: Object?
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(_ value: Object?) { self.value = value }
}

// Menunggu perubahan async dengan timeout agar test tidak menggantung.
@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    Issue.record("Timed out waiting for wealth state")
}

// Memverifikasi wealth product route preserves identifier.
@Test func wealthProductRoutePreservesIdentifier() {
    #expect(WealthRoute.product(id: "wealth-001") == .product(id: "wealth-001"))
}

// Memverifikasi wealth deep link parses.
@Test func wealthDeepLinkParses() {
    let url = URL(string: "iosrevamp://wealth/product?id=wealth-001")!
    #expect(WealthDeepLinkParser().parse(url) == .product(id: "wealth-001"))
}

// Memverifikasi malformed wealth deep links are rejected.
@Test func malformedWealthDeepLinksAreRejected() {
    let parser = WealthDeepLinkParser()
    #expect(parser.parse(URL(string: "iosrevamp://wealth/product")!) == nil)
    #expect(parser.parse(URL(string: "iosrevamp://rewards/detail?id=wealth-001")!) == nil)
}

// Memverifikasi wealth view model loads product once.
@MainActor
@Test func wealthViewModelLoadsProductOnce() async throws {
    let product = WealthProduct(id: "wealth-001", name: "Growth")
    let viewModel = WealthProductViewModel(
        productID: product.id,
        useCase: LoadWealthProductUseCase(service: StubWealthService(mode: .success(product)))
    )

    viewModel.load()
    try await waitUntil { viewModel.product != nil }

    #expect(viewModel.product == product)
    #expect(!viewModel.isLoading)
    viewModel.load()
    #expect(viewModel.product == product)
}

// Memverifikasi wealth view model cancels and releases.
@MainActor
@Test func wealthViewModelCancelsAndReleases() async throws {
    let weakViewModel = WeakReference<WealthProductViewModel>(nil)
    do {
        let viewModel = WealthProductViewModel(
            productID: "wealth-001",
            useCase: LoadWealthProductUseCase(service: StubWealthService(mode: .suspended))
        )
        weakViewModel.value = viewModel
        viewModel.load()
        #expect(viewModel.isLoading)
        viewModel.cancel()
        #expect(!viewModel.isLoading)
    }
    try await Task.sleep(nanoseconds: 10_000_000)

    #expect(weakViewModel.value == nil)
}
