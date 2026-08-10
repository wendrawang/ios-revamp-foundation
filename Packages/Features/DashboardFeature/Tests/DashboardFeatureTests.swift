import DashboardFeature
import Testing

// Memverifikasi dashboard outputs remain typed.
@Test func dashboardOutputsRemainTyped() {
    #expect(DashboardOutput.openTransfer != DashboardOutput.openUpgradeService)
}
