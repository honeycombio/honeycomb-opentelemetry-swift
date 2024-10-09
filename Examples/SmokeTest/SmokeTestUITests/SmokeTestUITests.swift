import XCTest

final class SmokeTestUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testSimpleSpan() async throws {
        let output = OutputListener()
        output.openConsolePipe()

        print("PRINT: simple")

        let app = XCUIApplication()
        app.launch()

        app.buttons["Send simple span"].tap()
        app.buttons["Flush"].tap()

        // output is async so need to wait for contents to be updated
        let contents = await output.contents
        XCTAssertEqual("hello world", contents)
        output.closeConsolePipe()
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

/// stolen wholesale from https://phatbl.at/2019/01/08/intercepting-stdout-in-swift.html
class OutputListener {
    /// consumes the messages on STDOUT
    let inputPipe = Pipe()

    /// outputs messages back to STDOUT
    let outputPipe = Pipe()

    /// Buffers strings written to stdout
    var contents = ""

    init() {
        // Set up a read handler which fires when data is written to our inputPipe
        inputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let strongSelf = self else { return }

            let data = fileHandle.availableData
            if let string = String(data: data, encoding: String.Encoding.utf8) {
                strongSelf.contents += string
            }

            // Write input back to stdout
            strongSelf.outputPipe.fileHandleForWriting.write(data)
        }
    }

    /// Sets up the "tee" of piped output, intercepting stdout then passing it through.
    func openConsolePipe() {
        // Copy STDOUT file descriptor to outputPipe for writing strings back to STDOUT
        dup2(STDOUT_FILENO, outputPipe.fileHandleForWriting.fileDescriptor)

        // Intercept STDOUT with inputPipe
        dup2(inputPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    }

    /// Tears down the "tee" of piped output.
    func closeConsolePipe() {
        // Restore stdout
        freopen("/dev/stdout", "a", stdout)

        [inputPipe.fileHandleForReading, outputPipe.fileHandleForWriting]
            .forEach { file in
                file.closeFile()
            }
    }
}
