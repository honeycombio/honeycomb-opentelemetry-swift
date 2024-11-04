import XCTest

@testable import SmokeTest

extension XCUIApplication {

    /// Helper to get the state of a SwiftUI Toggle control.
    func getToggle(_ name: String) -> Bool {
        let toggle = self.switches[name]
        XCTAssertTrue(toggle.exists, "missing toggle: \(name)")
        
        return toggle.value as? String == "1"
    }
    
    /// Helper to set the state of a SwiftUI Toggle control.
    func setToggle(_ name: String, to value: Bool) {
        if getToggle(name) == value {
            return
        }
        
        let toggle = self.switches[name]
        XCTAssertTrue(toggle.exists, "missing toggle: \(name)")
        toggle.switches.firstMatch.tap()
    }
}

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
        app.but/Users/beeklimt/src/honeycomb-opentelemetry-swift/Examples/SmokeTest/SmokeTestUITests/SmokeTestUITests.swifttons["Flush"].tap()
    }
    
    func testAsyncNetworking() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Network"].tap()
        app.setToggle("useAsync", to: true)

        let requestTypes: [NetworkRequestSpec] = [.data, .download, .upload]
        for requestType in requestTypes {            
            app.setToggle("useSessionDelegate", to:true)

            app.buttons["Clear"].tap()
            app.buttons["Do a network request"].tap()
            let status = app.staticTexts["success[session]: success!"]
            XCTAssert(status.waitForExistence(timeout: 5.0))
        }
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
