import Foundation
import OpenTelemetrySdk

internal class HoneycombUncaughtExceptionHandler {
    private static var initialUncaughtExceptionHandler: ((NSException) -> Void)? = nil
    private static var logProcessor: LogRecordProcessor? = nil

    public static func initializeUnhandledExceptionInstrumentation() {
        HoneycombUncaughtExceptionHandler.initialUncaughtExceptionHandler =
            NSGetUncaughtExceptionHandler()

        NSSetUncaughtExceptionHandler { exception in
            Honeycomb.log(exception: exception, thread: Thread.current)

            // Wait
            Thread.sleep(forTimeInterval: 3.0)

            if let initialHanlder = HoneycombUncaughtExceptionHandler
                .initialUncaughtExceptionHandler
            {
                initialHanlder(exception)
            }
        }
    }
}
