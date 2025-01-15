#if canImport(UIKit)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    extension UIViewController {
        var storyboardId: String? {
            return value(forKey: "storyboardIdentifier") as? String
        }

        private var viewName: String {
            // prefer storyboardId over title for UINavigationController
            // prefer title over storyboardId for other classes
            if self.isKind(of: UINavigationController.self) {
                return self.view.accessibilityIdentifier
                    ?? self.storyboardId
                    ?? self.title
                    ?? NSStringFromClass(type(of: self))
            }
            return self.view.accessibilityIdentifier
                ?? self.title
                ?? self.storyboardId
                ?? NSStringFromClass(type(of: self))
        }

        private func viewStack() -> [String] {
            if var parentPath = self.parent?.viewStack() {
                parentPath.append(self.viewName)
                return parentPath
            }
            return [self.viewName]
        }

        private func setAttributes(span: Span, className: String, animated: Bool) {

            span.setAttribute(key: "screen.name", value: self.viewName)
            span.setAttribute(key: "screen.path", value: self.viewStack().joined(separator: "/"))

            if let nibName = self.nibName {
                span.setAttribute(key: "view.nibName", value: nibName)
            }
            span.setAttribute(key: "view.animated", value: animated)
            span.setAttribute(key: "view.class", value: className)
        }

        @objc func traceViewDidAppear(_ animated: Bool) {
            let className = NSStringFromClass(type(of: self))

            // Internal classes from SwiftUI will likely begin with an underscore
            if !className.hasPrefix("_") {
                // set this _before_ creating the span
                HoneycombNavigationProcessor.shared.setCurrentNavigationPath(viewStack())

                let span = getUIKitViewTracer().spanBuilder(spanName: "viewDidAppear").startSpan()
                setAttributes(span: span, className: className, animated: animated)
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
                setAttributes(span: span, className: className, animated: animated)
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
