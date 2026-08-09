import CoreNetworking
import Foundation

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

    // Membuat receipt dari reference ID yang dikembalikan service Transfer.
    public init(referenceID: String) {
        self.referenceID = referenceID
    }
}

public protocol TransferServicing: Sendable {
    // Mengirim sample transfer melalui implementasi service yang diinjeksi.
    func submitDemoTransfer() async throws -> TransferReceipt
}

public struct FakeTransferService: TransferServicing {
    // Membuat deterministic service untuk sample dan UI test.
    public init() {}

    // Mensimulasikan transfer yang tetap mendukung cancellation.
    public func submitDemoTransfer() async throws -> TransferReceipt {
        try await Task.sleep(nanoseconds: 60_000_000)
        try Task.checkCancellation()
        return TransferReceipt(referenceID: "transfer-001")
    }
}

public struct RemoteTransferService: TransferServicing {
    private let client: any HTTPClient

    // Membuat domain service menggunakan generic HTTP client.
    public init(client: any HTTPClient) {
        self.client = client
    }

    // Mengirim request Transfer dan mendekode receipt milik domain.
    public func submitDemoTransfer() async throws -> TransferReceipt {
        let response = try await client.send(HTTPRequest(path: "/transfers", method: .post))
        return try response.decode(TransferReceipt.self)
    }
}

public struct SubmitTransferUseCase: Sendable {
    private let service: any TransferServicing

    // Membuat use case dengan service yang dapat diganti saat test.
    public init(service: any TransferServicing) {
        self.service = service
    }

    // Menjalankan operasi bisnis pengiriman sample transfer.
    public func execute() async throws -> TransferReceipt {
        try await service.submitDemoTransfer()
    }
}

public struct BackendErrorDTO: Equatable, Sendable {
    public let code: String
    public let title: String
    public let message: String
    public let primaryButtonTitle: String

    // Menampung copy backend tanpa memberinya kewenangan membuat route.
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

    // Membuat model presentasi yang hanya membawa typed frontend action.
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
    // Membuat stateless mapper untuk backend presentation code.
    public init() {}

    // Memetakan whitelist code backend menjadi tindakan frontend yang aman.
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
