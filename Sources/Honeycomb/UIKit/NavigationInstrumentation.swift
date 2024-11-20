#if canImport(UIKit)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    public func installUINavigationInstrumentation() {
        UIViewController.swizzle()
    }
#endif
