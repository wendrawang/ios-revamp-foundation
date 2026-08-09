import DashboardFeature
import Testing

@Test func dashboardOutputsRemainTyped() {
    #expect(DashboardOutput.openTransfer != DashboardOutput.openUpgradeService)
}

