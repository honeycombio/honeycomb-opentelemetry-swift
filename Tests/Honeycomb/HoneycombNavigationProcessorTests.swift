import XCTest

@testable import Honeycomb

final class HoneycombNavigationProcessorTests: XCTestCase {
    override func tearDown() {
        HoneycombNavigationProcessor.shared.setCurrentNavigationPath([])
        super.tearDown()
    }

    func testCurrentNavigationPathReturnsLatestPath() {
        let processor = HoneycombNavigationProcessor.shared
        processor.setCurrentNavigationPath(["Home", "Detail"])

        XCTAssertEqual(processor.currentNavigationPath, ["Home", "Detail"])
    }

    // Regression test for an unsynchronized read of the navigation path racing with writes.
    // Run with Thread Sanitizer enabled to detect the race deterministically.
    func testCurrentNavigationPathIsSafeUnderConcurrentReadsAndWrites() {
        let processor = HoneycombNavigationProcessor.shared
        let paths: [[String]] = [
            ["Root"],
            ["Root", "List"],
            ["Root", "List", "Detail"],
        ]

        DispatchQueue.concurrentPerform(iterations: 10_000) { iteration in
            if iteration % 2 == 0 {
                processor.setCurrentNavigationPath(paths[iteration % paths.count])
            } else {
                let path = processor.currentNavigationPath
                XCTAssertTrue(path.isEmpty || paths.contains(path))
            }
        }
    }
}
