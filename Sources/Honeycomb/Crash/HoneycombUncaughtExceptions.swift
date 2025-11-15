import Foundation

internal class HoneycombUncaughtExceptionHandler {
    private static var initialUncaughtExceptionHandler: ((NSException) -> Void)? = nil

    public static func initializeUnhandledExceptionInstrumentation() {
        HoneycombUncaughtExceptionHandler.initialUncaughtExceptionHandler =
            NSGetUncaughtExceptionHandler()

        NSSetUncaughtExceptionHandler { exception in
            Honeycomb.log(exception: exception, thread: Thread.current, severity: .fatal)

            // App is about to close taking Otel with it, give it some time to finish
            Thread.sleep(forTimeInterval: 3.0)

            if let initialHanlder = HoneycombUncaughtExceptionHandler
                .initialUncaughtExceptionHandler
            {
                initialHanlder(exception)
            }
        }
    }
}
