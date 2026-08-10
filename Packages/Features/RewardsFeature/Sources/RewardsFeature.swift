import CoreNetworking
import DesignSystem
import Foundation
import SwiftUI

public enum RewardsAccessibilityID {
    public static let openDetail = "rewards.open.detail"
    public static let detail = "rewards.detail"
}

public enum RewardsRoute: Hashable, Sendable {
    case detail(identifier: String)
}

public enum RewardsDeepLinkIntent: Equatable, Sendable {
    case root
    case detail(identifier: String)
}

public struct RewardsDeepLinkParser: Sendable {
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init() {}

    // Mengubah URL yang cocok menjadi intent domain bertipe.
    public func parse(_ url: URL) -> RewardsDeepLinkIntent? {
        guard url.scheme?.lowercased() == "iosrevamp", url.host?.lowercased() == "rewards" else { return nil }
        if url.path.isEmpty || url.path == "/" { return .root }
        guard url.path == "/detail",
            let rewardIdentifier = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { queryItem in queryItem.name == "id" })?.value,
            !rewardIdentifier.isEmpty
        else { return nil }
        return .detail(identifier: rewardIdentifier)
    }
}

public struct Reward: Codable, Equatable, Sendable {
    public let identifier: String
    public let title: String

    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case title
    }

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(identifier: String, title: String) {
        self.identifier = identifier
        self.title = title
    }
}

public protocol RewardsServicing: Sendable {
    // Mengambil detail Rewards melalui service domain.
    func reward(identifier: String) async throws -> Reward
}

public struct RemoteRewardsService: RewardsServicing {
    private let client: any HTTPClient
    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(client: any HTTPClient) { self.client = client }
    // Mengambil detail Rewards melalui service domain.
    public func reward(identifier: String) async throws -> Reward {
        try await client.send(HTTPRequest(path: "/rewards/\(identifier)")).decode(Reward.self)
    }
}

public protocol RewardsPreflighting: Sendable {
    // Menjalankan inquiry atau preflight sebelum destination ditampilkan.
    func prepare(rewardID: String) async throws
}

public struct DummyRewardsPreflightUseCase: RewardsPreflighting {
    private let delayNanoseconds: UInt64

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(delayNanoseconds: UInt64 = 300_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    // Menjalankan inquiry atau preflight sebelum destination ditampilkan.
    public func prepare(rewardID: String) async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
    }
}

public struct RewardsRootView: View {
    private let openDetail: (String) -> Void

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(openDetail: @escaping (String) -> Void) {
        self.openDetail = openDetail
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                Text("Rewards").font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
                DSFeatureCard(title: "Points") {
                    Text("1,478 points").font(.title2.bold())
                    DSPrimaryButton(
                        title: "View featured reward", accessibilityIdentifier: RewardsAccessibilityID.openDetail
                    ) {
                        openDetail("reward-001")
                    }
                }
            }
            .padding(DSSpacing.large)
        }
        .navigationTitle("Rewards")
    }
}

public struct RewardDetailScreen: View {
    private let rewardID: String

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    public init(rewardID: String) {
        self.rewardID = rewardID
    }

    public var body: some View {
        VStack(spacing: DSSpacing.large) {
            Image(systemName: "gift.fill").font(.system(size: 60)).foregroundStyle(DSColor.accent)
            Text("Reward Detail").font(.largeTitle.bold())
            Text("Reward: \(rewardID)").foregroundStyle(.secondary)
        }
        .padding(DSSpacing.large)
        .navigationTitle("Reward")
        .accessibilityIdentifier(RewardsAccessibilityID.detail)
    }
}
