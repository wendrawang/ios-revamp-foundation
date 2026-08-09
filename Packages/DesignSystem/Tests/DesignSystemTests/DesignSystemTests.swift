import DesignSystem
import Testing

@Test func tabItemsKeepStableIdentifiers() {
    let item = DSTabItem(id: 1, title: "Scan", systemImage: "qrcode.viewfinder", accessibilityIdentifier: "tab.scan")
    #expect(item.accessibilityIdentifier == "tab.scan")
}

