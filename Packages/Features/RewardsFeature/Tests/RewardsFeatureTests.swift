import CoreNetworking
import Foundation
import RewardsFeature
import Testing

private struct StubHTTPClient: HTTPClient {
    let response: HTTPResponse
    let expectedPath: String

    // Membangun dan mengirim HTTP request dengan retry serta logging aman.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.path == expectedPath)
        return response
    }
}

// Memverifikasi rewards root and detail deep links parse.
@Test func rewardsRootAndDetailDeepLinksParse() {
    let parser = RewardsDeepLinkParser()
    #expect(parser.parse(URL(string: "iosrevamp://rewards")!) == .root)
    #expect(parser.parse(URL(string: "iosrevamp://rewards/detail?id=reward-001")!) == .detail(id: "reward-001"))
}

// Memverifikasi rewards preflight completes deterministically.
@Test func rewardsPreflightCompletesDeterministically() async throws {
    try await DummyRewardsPreflightUseCase(delayNanoseconds: 1).prepare(rewardID: "reward-001")
}

// Memverifikasi malformed rewards deep links are rejected.
@Test func malformedRewardsDeepLinksAreRejected() {
    let parser = RewardsDeepLinkParser()
    #expect(parser.parse(URL(string: "iosrevamp://rewards/detail")!) == nil)
    #expect(parser.parse(URL(string: "iosrevamp://wealth/product?id=reward-001")!) == nil)
}

// Memverifikasi remote rewards service decodes domain model.
@Test func remoteRewardsServiceDecodesDomainModel() async throws {
    let response = HTTPResponse(
        statusCode: 200,
        body: Data(#"{"id":"reward-001","title":"Featured"}"#.utf8)
    )
    let service = RemoteRewardsService(
        client: StubHTTPClient(
            response: response,
            expectedPath: "/rewards/reward-001"
        ))

    let reward = try await service.reward(id: "reward-001")

    #expect(reward == Reward(id: "reward-001", title: "Featured"))
}
