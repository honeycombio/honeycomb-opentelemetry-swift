#if canImport(UIKit)
import Foundation
import OpenTelemetryApi
import UIKit

extension UIViewController {
    @objc func trace_viewDidAppear(_ animated: Bool) {
        let span = getViewTracer().spanBuilder(spanName: "viewDidAppear").startSpan()
        span.setAttribute(key: "title", value: self.title ?? "")
        span.setAttribute(key: "animated", value: animated)
        span.setAttribute(key: "className", value: NSStringFromClass(type(of: self)))
        span.end()
        trace_viewDidAppear(animated)
    }

    @objc func trace_viewDidDisappear(_ animated: Bool) {
        let span = getViewTracer().spanBuilder(spanName: "viewDidDisappear").startSpan()
        span.setAttribute(key: "title", value: self.title ?? "")
        span.setAttribute(key: "animated", value: animated)
        span.setAttribute(key: "className", value: NSStringFromClass(type(of: self)))
        span.end()
        trace_viewDidDisappear(animated)
    }
    
    public static func swizzle() {
        let originalAppearSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledAppearSelector = #selector(UIViewController.trace_viewDidAppear(_:))
        let originalDisappearSelector = #selector(UIViewController.viewDidDisappear(_:))
        let swizzledDisappearSelector = #selector(UIViewController.trace_viewDidDisappear(_:))
        
        guard
            let originalAppearMethod = class_getInstanceMethod(UIViewController.self, originalAppearSelector),
            let swizzledAppearMethod = class_getClassMethod(UIViewController.self, swizzledAppearSelector)
        else { return }
        
        method_exchangeImplementations(originalAppearMethod, swizzledAppearMethod)
        
        guard
            let originalDisappearMethod = class_getInstanceMethod(UIViewController.self, originalDisappearSelector),
            let swizzledDisappearMethod = class_getInstanceMethod(UIViewController.self, swizzledDisappearSelector)
        else { return }
        
        method_exchangeImplementations(originalDisappearMethod, swizzledDisappearMethod)
    }
}

#endif
