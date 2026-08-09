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
    public init() {}

    public func parse(_ url: URL) -> WealthDeepLinkIntent? {
        guard url.scheme?.lowercased() == "iosrevamp",
              url.host?.lowercased() == "wealth",
              url.path == "/product",
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
              !id.isEmpty else { return nil }
        return .product(id: id)
    }
}

public struct WealthProduct: Codable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public protocol WealthServicing: Sendable {
    func product(id: String) async throws -> WealthProduct
}

public struct FakeWealthService: WealthServicing {
    public init() {}
    public func product(id: String) async throws -> WealthProduct {
        WealthProduct(id: id, name: "Balanced Growth Fund")
    }
}

public struct RemoteWealthService: WealthServicing {
    private let client: any HTTPClient
    public init(client: any HTTPClient) { self.client = client }
    public func product(id: String) async throws -> WealthProduct {
        try await client.send(HTTPRequest(path: "/wealth/products/\(id)")).decode(WealthProduct.self)
    }
}

public struct LoadWealthProductUseCase: Sendable {
    private let service: any WealthServicing
    public init(service: any WealthServicing) { self.service = service }
    public func execute(id: String) async throws -> WealthProduct { try await service.product(id: id) }
}

public protocol WealthPreflighting: Sendable {
    func prepare(productID: String) async throws
}

public struct DummyWealthPreflightUseCase: WealthPreflighting {
    private let delayNanoseconds: UInt64

    public init(delayNanoseconds: UInt64 = 250_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

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

    public init(productID: String, useCase: LoadWealthProductUseCase) {
        self.productID = productID
        self.useCase = useCase
    }

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

    public func cancel() { task?.cancel(); task = nil; isLoading = false }
    deinit { task?.cancel() }
}

public struct WealthProductScreen: View {
    @StateObject private var viewModel: WealthProductViewModel

    public init(productID: String, service: any WealthServicing) {
        _viewModel = StateObject(wrappedValue: WealthProductViewModel(
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
