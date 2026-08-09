@testable import IOSRevampFoundation
import TransferFeature
import XCTest

@MainActor
final class RuntimePerformanceTests: XCTestCase {
    func testNavigationMutationPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let store = AuthenticatedNavigationStore { _ in }
            for index in 0..<250 {
                store.push(
                    TransferRoute.result(referenceID: "reference-\(index)"),
                    screen: ScreenDescriptor(id: "transfer.result")
                )
                store.pop()
            }
            XCTAssertEqual(store.pathCount, 0)
            XCTAssertTrue(store.metadata.isEmpty)
        }
    }
}
