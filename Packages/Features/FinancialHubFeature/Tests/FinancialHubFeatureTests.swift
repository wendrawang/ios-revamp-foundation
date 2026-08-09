import FinancialHubFeature
import Testing

// Memverifikasi financial hub uses typed wealth output.
@Test func financialHubUsesTypedWealthOutput() {
    #expect(FinancialHubOutput.openWealth(productID: "one") != .openWealth(productID: "two"))
}
