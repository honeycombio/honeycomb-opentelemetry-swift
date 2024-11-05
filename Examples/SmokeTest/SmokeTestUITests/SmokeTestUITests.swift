import XCTest

private let uiUpdateTimeout = 0.200
private let networkRequestTimeout = 5.0

extension XCUIApplication {

    /// Helper to get the state of a SwiftUI Toggle control.
    func getToggle(_ name: String) -> Bool {
        let toggle = self.switches[name]
        XCTAssertTrue(toggle.waitForExistence(timeout: uiUpdateTimeout), "missing toggle: \(name)")
        
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
        app.buttons["Flush"].tap()
    }
    
    func testNetworking() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Network"].tap()
        XCTAssert(app.staticTexts["Network Playground"].waitForExistence(timeout: uiUpdateTimeout))

        // Test all combinations of networking options.
        for (requestType, typeStr) in [("Data", "data"), ("Download", "download"), ("Upload", "upload")] {
            for (useAsync, asyncStr) in [(true, "async"), (false, "callback")] {
                for (useRequestObject, requestStr) in [(true, "obj"), (false, "url")] {
                    for (useTaskDelegate, taskStr) in [(true, "-task"), (false, "")] {
                        for (useSessionDelegate, sessionStr) in [(true, "-session"), (false, "")] {
                            if useAsync && useTaskDelegate {
                                // The await/async API doesn't allow passing in a delegate.
                                continue
                            }
                            if requestType == "Upload" && !useRequestObject {
                                // Using only a URL with an upload request doesn't really make sense.
                                continue
                            }

                            // Configure the request.
                            app.segmentedControls.buttons[requestType].tap()
                            app.setToggle("useAsync", to: useAsync)
                            app.setToggle("useRequestObject", to:useRequestObject)
                            app.setToggle("useTaskDelegate", to: useTaskDelegate)
                            app.setToggle("useSessionDelegate", to:useSessionDelegate)

                            // Make sure that the request is configured correctly.
                            let requestID = "\(typeStr)-\(asyncStr)-\(requestStr)\(taskStr)\(sessionStr)"
                            XCTAssert(app.staticTexts[requestID].waitForExistence(timeout: uiUpdateTimeout), requestID)

                            // Do the request.
                            app.buttons["Clear"].tap()
                            app.buttons["Do a network request"].tap()

                            // Wait for the request to finish.
                            let status = app.staticTexts["200"]
                            XCTAssert(status.waitForExistence(timeout: networkRequestTimeout), requestID)

                            // Verify that the callbacks we called correctly.
                            let expectTaskDelegateCalled = useTaskDelegate ? "✅" : "❌"
                            let actualTaskDelegateCalled = app.staticTexts["taskDelegateCalled"].label
                            XCTAssertEqual(expectTaskDelegateCalled, actualTaskDelegateCalled, requestID)

                            let expectSessionDelegateCalled = (useSessionDelegate && !useTaskDelegate) ? "✅" : "❌"
                            let actualSessionDelegateCalled = app.staticTexts["sessionDelegateCalled"].label
                            XCTAssertEqual(expectSessionDelegateCalled, actualSessionDelegateCalled, requestID)

                        }
                    }
                }
            }
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
