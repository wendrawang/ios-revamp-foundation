import Testing
import UpgradeServiceFeature

// Memverifikasi upgrade has one entry route.
@Test func upgradeHasOneEntryRoute() {
    #expect(UpgradeServiceRoute.start == .start)
}
