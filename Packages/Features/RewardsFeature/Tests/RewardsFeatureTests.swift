import Foundation
import RewardsFeature
import Testing

@Test func rewardsRootAndDetailDeepLinksParse() {
    let parser = RewardsDeepLinkParser()
    #expect(parser.parse(URL(string: "iosrevamp://rewards")!) == .root)
    #expect(parser.parse(URL(string: "iosrevamp://rewards/detail?id=reward-001")!) == .detail(id: "reward-001"))
}

@Test func rewardsPreflightCompletesDeterministically() async throws {
    try await DummyRewardsPreflightUseCase(delayNanoseconds: 1).prepare(rewardID: "reward-001")
}

