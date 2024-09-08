import XCTest

final class SmokeTestUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testSimpleSpan() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Send simple span"].tap()
        app.buttons["Flush"].tap()
    }

    func testMetricKit() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Send fake MetricKit data"].tap()
        app.buttons["Flush"].tap()
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
