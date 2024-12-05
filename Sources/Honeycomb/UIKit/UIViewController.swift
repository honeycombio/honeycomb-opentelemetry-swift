#if canImport(UIKit)
    import Foundation
    import OpenTelemetryApi
    import UIKit

    extension UIViewController {
        // I would like to express my disdain with this code
        //
        // extensions can't add new stored properties so we have to hack around that
        // see also https://valv0.medium.com/computed-properties-and-extensions-a-pure-swift-approach-64733768112c
        private static var _honeycombIdentifiers = [UIViewController: String]()
        public var honeycombIdentifier: String? {
            get {
                return UIViewController._honeycombIdentifiers[self]
            }
            set {
                UIViewController._honeycombIdentifiers[self] = newValue
            }
        }

        var storyboardId: String? {
            return value(forKey: "storyboardIdentifier") as? String
        }

        private var viewName: String {
            return self.honeycombIdentifier ?? self.storyboardId ?? self.title ?? NSStringFromClass(type(of: self))
        }

        private func viewStack() -> [String] {
            if var parentPath = self.parent?.viewStack() {
                parentPath.append(self.viewName)
                return parentPath
            }
            return [self.viewName]
        }

        private func viewPath() -> String {
            self.viewStack()
                .filter { str in
                    !str.starts(with: ("_"))
                }
                .joined(separator: "/")
        }

        private func setAttributes(span: Span, className: String, animated: Bool) {
            if let title = self.title {
                span.setAttribute(key: "view.title", value: title)
            }
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
                let span = getUIKitViewTracer().spanBuilder(spanName: "viewDidAppear").startSpan()
                setAttributes(span: span, className: className, animated: animated)
                span.end()

                HoneycombNavigationProcessor.shared.setCurrentNavigationPath(viewPath())
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
