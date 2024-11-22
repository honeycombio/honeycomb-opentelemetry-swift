#if canImport(UIKit)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    extension UIViewController {
        @objc func traceViewDidAppear(_ animated: Bool) {
            let className = NSStringFromClass(type(of: self))

            // Internal classes from SwiftUI will likely begin with an underscore
            if !className.hasPrefix("_") {
                let span = getUIKitViewTracer().spanBuilder(spanName: "viewDidAppear").startSpan()
                if self.title != nil {
                    span.setAttribute(key: "title", value: self.title!)
                }
                if self.nibName != nil {
                    span.setAttribute(key: "nibName", value: self.nibName!)
                }
                span.setAttribute(key: "animated", value: animated)
                span.setAttribute(key: "className", value: className)

                span.end()
            }

            traceViewDidAppear(animated)
        }

        @objc func traceViewDidDisappear(_ animated: Bool) {

            let className = NSStringFromClass(type(of: self))

            // Internal classes from SwiftUI will likely begin with an underscore
            if !className.hasPrefix("_") {
                let span = getUIKitViewTracer().spanBuilder(spanName: "viewDidDisappear")
                    .startSpan()
                if self.title != nil {
                    span.setAttribute(key: "title", value: self.title!)
                }
                if self.nibName != nil {
                    span.setAttribute(key: "nibName", value: self.nibName!)
                }
                span.setAttribute(key: "animated", value: animated)
                span.setAttribute(key: "className", value: className)
                span.end()
            }

            traceViewDidDisappear(animated)
        }

        public static func swizzle() {
            let originalAppearSelector = #selector(UIViewController.viewDidAppear(_:))
            let swizzledAppearSelector = #selector(UIViewController.traceViewDidAppear(_:))
            let originalDisappearSelector = #selector(UIViewController.viewDidDisappear(_:))
            let swizzledDisappearSelector = #selector(UIViewController.traceViewDidDisappear(_:))

            guard
                let originalAppearMethod = class_getInstanceMethod(self, originalAppearSelector),
                let swizzledAppearMethod = class_getInstanceMethod(self, swizzledAppearSelector)
            else {
                print("unable to swizzle \(originalAppearSelector): original method not found")
                return
            }

            method_exchangeImplementations(originalAppearMethod, swizzledAppearMethod)

            guard
                let originalDisappearMethod = class_getInstanceMethod(
                    self,
                    originalDisappearSelector
                ),
                let swizzledDisappearMethod = class_getInstanceMethod(
                    self,
                    swizzledDisappearSelector
                )
            else {
                print("unable to swizzle \(originalDisappearSelector): original method not found")
                return
            }

            method_exchangeImplementations(originalDisappearMethod, swizzledDisappearMethod)
        }
    }

#endif
