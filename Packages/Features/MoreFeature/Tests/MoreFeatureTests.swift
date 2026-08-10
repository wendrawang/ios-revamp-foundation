import MoreFeature
import Testing

// Memverifikasi logout is explicit output.
@Test func logoutIsExplicitOutput() {
    #expect(MoreOutput.logout != MoreOutput.openWebSample)
}
