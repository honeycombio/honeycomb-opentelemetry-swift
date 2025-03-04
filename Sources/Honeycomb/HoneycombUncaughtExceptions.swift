import Foundation

internal class HoneycombUncaughtExceptionHandler {
    private static var initialUncaughtExceptionHandler: ((NSException) -> Void)? = nil

    public static func initializeUnhandledExceptionInstrumentation() {
        HoneycombUncaughtExceptionHandler.initialUncaughtExceptionHandler =
            NSGetUncaughtExceptionHandler()

        NSSetUncaughtExceptionHandler { exception in
            Honeycomb.log(exception: exception, thread: Thread.current)

            if HoneycombUncaughtExceptionHandler.initialUncaughtExceptionHandler != nil {
                HoneycombUncaughtExceptionHandler.initialUncaughtExceptionHandler!(exception)
            }
        }
    }
}
