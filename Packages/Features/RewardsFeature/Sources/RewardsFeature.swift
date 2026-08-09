import CoreNetworking
import DesignSystem
import Foundation
import SwiftUI

public enum RewardsAccessibilityID {
    public static let openDetail = "rewards.open.detail"
    public static let detail = "rewards.detail"
}

public enum RewardsRoute: Hashable, Sendable {
    case detail(id: String)
}

public enum RewardsDeepLinkIntent: Equatable, Sendable {
    case root
    case detail(id: String)
}

public struct RewardsDeepLinkParser: Sendable {
    public init() {}

    public func parse(_ url: URL) -> RewardsDeepLinkIntent? {
        guard url.scheme?.lowercased() == "iosrevamp", url.host?.lowercased() == "rewards" else { return nil }
        if url.path.isEmpty || url.path == "/" { return .root }
        guard url.path == "/detail",
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
              !id.isEmpty else { return nil }
        return .detail(id: id)
    }
}

public struct Reward: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
}

public protocol RewardsServicing: Sendable {
    func reward(id: String) async throws -> Reward
}

public struct RemoteRewardsService: RewardsServicing {
    private let client: any HTTPClient
    public init(client: any HTTPClient) { self.client = client }
    public func reward(id: String) async throws -> Reward {
        try await client.send(HTTPRequest(path: "/rewards/\(id)")).decode(Reward.self)
    }
}

public protocol RewardsPreflighting: Sendable {
    func prepare(rewardID: String) async throws
}

public struct DummyRewardsPreflightUseCase: RewardsPreflighting {
    private let delayNanoseconds: UInt64

    public init(delayNanoseconds: UInt64 = 300_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    public func prepare(rewardID: String) async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
    }
}

public struct RewardsRootView: View {
    private let openDetail: (String) -> Void

    public init(openDetail: @escaping (String) -> Void) {
        self.openDetail = openDetail
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.md) {
                Text("Rewards").font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
                DSFeatureCard(title: "Points") {
                    Text("1,478 points").font(.title2.bold())
                    DSPrimaryButton(title: "View featured reward", accessibilityIdentifier: RewardsAccessibilityID.openDetail) {
                        openDetail("reward-001")
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .navigationTitle("Rewards")
    }
}

public struct RewardDetailScreen: View {
    private let rewardID: String

    public init(rewardID: String) {
        self.rewardID = rewardID
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "gift.fill").font(.system(size: 60)).foregroundStyle(DSColor.accent)
            Text("Reward Detail").font(.largeTitle.bold())
            Text("Reward: \(rewardID)").foregroundStyle(.secondary)
        }
        .padding(DSSpacing.lg)
        .navigationTitle("Reward")
        .accessibilityIdentifier(RewardsAccessibilityID.detail)
    }
}
