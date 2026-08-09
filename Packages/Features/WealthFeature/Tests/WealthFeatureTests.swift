import Foundation
import Testing
import WealthFeature

@Test func wealthProductRoutePreservesIdentifier() {
    #expect(WealthRoute.product(id: "wealth-001") == .product(id: "wealth-001"))
}

@Test func wealthDeepLinkParses() {
    let url = URL(string: "iosrevamp://wealth/product?id=wealth-001")!
    #expect(WealthDeepLinkParser().parse(url) == .product(id: "wealth-001"))
}

