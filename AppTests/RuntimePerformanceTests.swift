import TransferFeature
import XCTest

@testable import IOSRevampFoundation

@MainActor
final class RuntimePerformanceTests: XCTestCase {
    // Memverifikasi navigation mutation performance.
    func testNavigationMutationPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let store = AuthenticatedNavigationStore { _ in }
            for index in 0..<250 {
                store.push(
                    TransferRoute.result(referenceID: "reference-\(index)"),
                    screen: ScreenDescriptor(identifier: "transfer.result")
                )
                store.pop()
            }
            XCTAssertEqual(store.pathCount, 0)
            XCTAssertTrue(store.metadata.isEmpty)
        }
    }
}
