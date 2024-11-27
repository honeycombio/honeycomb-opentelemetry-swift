import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

// A helper for getting attributes about a UIView that was interacted with.

enum TouchType {
    case began
    case ended
    case cancelled
}

private func recordTouch(_ touch: UITouch, type: TouchType) {
    let spanName =
        switch type {
        case .began: "Touch Began"
        case .ended: "Touch Ended"
        case .cancelled: "Touch Cancelled"
        }

    // Try to find the name of the view this touch was on.
    let viewAttrs: ViewAttributes? = touch.view.map({ view in ViewAttributes(view: view) })

    let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: honeycombUIKitInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
    let span = tracer.spanBuilder(spanName: spanName).startSpan()
    viewAttrs?.setAttributes(span: span)
    span.end()

    // Do a special check for button clicks.
    if type == .ended {
        if let button = touch.view as? UIButton {
            if button.isHighlighted {
                let span = tracer.spanBuilder(spanName: "click")
                    .startSpan()
                viewAttrs?.setAttributes(span: span)
                span.end()
            }
        }
    }
}

private func recordTouch(_ touch: UITouch) {
    guard
        let type: TouchType =
            switch touch.phase {
            case .began: TouchType.began
            case .cancelled: TouchType.cancelled
            case .ended: TouchType.ended
            default: nil
            }
    else {
        return
    }

    recordTouch(touch, type: type)
}

extension UIWindow {
    // swift-format-ignore
    @objc func _instrumented_sendEvent(_ event: UIEvent) {
        switch event.type {
        case .touches:
            if let touches = event.allTouches {
                for touch in touches {
                    recordTouch(touch)
                }
            }
        default:
            break
        }

        // Because the methods were swapped, this calls the original method.
        _instrumented_sendEvent(event)
    }

    static func swizzle() {
        let sendEventSelector = #selector(UIWindow.sendEvent)
        let instrumentedSendEventSelector = #selector(UIWindow._instrumented_sendEvent)
        let sendEventMethod = class_getInstanceMethod(self, sendEventSelector)
        let instrumentedSendEventMethod = class_getInstanceMethod(
            self,
            instrumentedSendEventSelector
        )
        method_exchangeImplementations(sendEventMethod!, instrumentedSendEventMethod!)
    }
}

func installWindowInstrumentation() {
    UIWindow.swizzle()
}
