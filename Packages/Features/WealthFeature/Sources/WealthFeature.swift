import Combine
import CoreNetworking
import DesignSystem
import Foundation
import SwiftUI

public enum WealthAccessibilityID {
    public static let product = "wealth.product"
}

public enum WealthRoute: Hashable, Sendable {
    case product(id: String)
}

public enum WealthDeepLinkIntent: Equatable, Sendable {
    case product(id: String)
}

public struct WealthDeepLinkParser: Sendable {
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}

    // Mengubah URL yang cocok menjadi intent domain bertipe.
    public func parse(_ url: URL) -> WealthDeepLinkIntent? {
        guard url.scheme?.lowercased() == "iosrevamp",
            url.host?.lowercased() == "wealth",
            url.path == "/product",
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
            !id.isEmpty
        else { return nil }
        return .product(id: id)
    }
}

public struct WealthProduct: Codable, Equatable, Sendable {
    public let id: String
    public let name: String

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public protocol WealthServicing: Sendable {
    // Mengambil data produk Wealth melalui service domain.
    func product(id: String) async throws -> WealthProduct
}

public struct FakeWealthService: WealthServicing {
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}
    // Mengambil data produk Wealth melalui service domain.
    public func product(id: String) async throws -> WealthProduct {
        WealthProduct(id: id, name: "Balanced Growth Fund")
    }
}

public struct RemoteWealthService: WealthServicing {
    private let client: any HTTPClient
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(client: any HTTPClient) { self.client = client }
    // Mengambil data produk Wealth melalui service domain.
    public func product(id: String) async throws -> WealthProduct {
        try await client.send(HTTPRequest(path: "/wealth/products/\(id)")).decode(WealthProduct.self)
    }
}

public struct LoadWealthProductUseCase: Sendable {
    private let service: any WealthServicing
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(service: any WealthServicing) { self.service = service }
    // Menjalankan operasi dependency atau use case yang dibungkus tipe ini.
    public func execute(id: String) async throws -> WealthProduct { try await service.product(id: id) }
}

public protocol WealthPreflighting: Sendable {
    // Menjalankan inquiry atau preflight sebelum destination ditampilkan.
    func prepare(productID: String) async throws
}

public struct DummyWealthPreflightUseCase: WealthPreflighting {
    private let delayNanoseconds: UInt64

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(delayNanoseconds: UInt64 = 250_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    // Menjalankan inquiry atau preflight sebelum destination ditampilkan.
    public func prepare(productID: String) async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
    }
}

@MainActor
public final class WealthProductViewModel: ObservableObject {
    @Published public private(set) var product: WealthProduct?
    @Published public private(set) var isLoading = false
    private let productID: String
    private let useCase: LoadWealthProductUseCase
    private var task: Task<Void, Never>?

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(productID: String, useCase: LoadWealthProductUseCase) {
        self.productID = productID
        self.useCase = useCase
    }

    // Memuat data layar satu kali dan menerbitkan hasilnya ke UI state.
    public func load() {
        guard product == nil, !isLoading else { return }
        isLoading = true
        task = Task { [weak self, productID, useCase] in
            let loaded = try? await useCase.execute(id: productID)
            guard !Task.isCancelled else { return }
            self?.product = loaded
            self?.isLoading = false
        }
    }

    // Membatalkan Task agar tidak melewati lifetime layar.
    public func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
    // Menghentikan resource yang masih dimiliki saat instance dilepas.
    deinit { task?.cancel() }
}

public struct WealthProductScreen: View {
    @StateObject private var viewModel: WealthProductViewModel

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(productID: String, service: any WealthServicing) {
        _viewModel = StateObject(
            wrappedValue: WealthProductViewModel(
                productID: productID,
                useCase: LoadWealthProductUseCase(service: service)
            ))
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "chart.pie.fill").font(.system(size: 60)).foregroundStyle(DSColor.accent)
            Text(viewModel.product?.name ?? "Loading product…").font(.title2.bold())
            if let product = viewModel.product {
                Text("Product ID: \(product.id)").foregroundStyle(.secondary)
            }
        }
        .padding(DSSpacing.lg)
        .navigationTitle("Wealth Product")
        .accessibilityIdentifier(WealthAccessibilityID.product)
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}
