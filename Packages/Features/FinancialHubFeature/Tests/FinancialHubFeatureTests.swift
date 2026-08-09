import FinancialHubFeature
import Testing

@Test func financialHubUsesTypedWealthOutput() {
    #expect(FinancialHubOutput.openWealth(productID: "one") != .openWealth(productID: "two"))
}

