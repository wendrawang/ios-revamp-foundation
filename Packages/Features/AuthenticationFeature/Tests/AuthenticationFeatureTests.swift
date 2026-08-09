import AuthenticationFeature
import Foundation
import Testing

@Test func registrationContinuationDeepLinkParses() {
    let url = URL(string: "iosrevamp://registration/continue?token=demo")!
    #expect(AuthenticationDeepLinkParser().parse(url) == .registrationContinuation(token: "demo"))
}

@Test func unrelatedDeepLinkDoesNotParseAsAuthentication() {
    let url = URL(string: "iosrevamp://rewards")!
    #expect(AuthenticationDeepLinkParser().parse(url) == nil)
}

