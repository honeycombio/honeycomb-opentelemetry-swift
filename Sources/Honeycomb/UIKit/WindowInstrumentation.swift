import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

struct ViewNames {
    var accessibilityLabel: String?
    var accessibilityIdentifier: String?
    var currentTitle: String?
    var titleLabelText: String?
    var className: String?

    var name: String? {
        return accessibilityIdentifier ?? accessibilityLabel ?? currentTitle ?? titleLabelText
    }

    init(view: UIView) {
        findNames(view: view)
    }

    private mutating func findNames(view: UIView) {
        // Gather various identifiers about the view.
        if let identifier = view.accessibilityIdentifier {
            self.accessibilityIdentifier = identifier
        }
        if let label = view.accessibilityLabel {
            self.accessibilityLabel = label
        }
        if let button = view as? UIButton {
            if let title = button.currentTitle {
                self.currentTitle = title
            }
            if let label = button.titleLabel?.text {
                self.titleLabelText = label
            }
        }

        // If we've gotten _some_ identifier, stop. Otherwise, walk up the hierarchy.
        if self.name == nil {
            if let parent = view.superview {
                self.findNames(view: parent)
            }
        }

        // Set the class name for the bottom-most view.
        self.className = String(describing: type(of: view))
    }

    func setAttributes(span: Span) {
        if let accessibilityLabel = self.accessibilityLabel {
            span.setAttribute(key: "view.accessibilityLabel", value: accessibilityLabel)
        }
        if let accessibilityIdentifier = self.accessibilityIdentifier {
            span.setAttribute(key: "view.accessibilityIdentifier", value: accessibilityIdentifier)
        }
        if let currentTitle = self.currentTitle {
            span.setAttribute(key: "view.currentTitle", value: currentTitle)
        }
        if let titleLabelText = self.titleLabelText {
            span.setAttribute(key: "view.titleLabel.text", value: titleLabelText)
        }
        if let name = self.name {
            span.setAttribute(key: "view.name", value: name)
        }
        if let className = self.className {
            span.setAttribute(key: "view.class", value: className)
        }
    }
}

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
    let viewNames: ViewNames? = touch.view.map({ view in ViewNames(view: view) })

    let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: honeycombUIKitInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
    let span = tracer.spanBuilder(spanName: spanName).startSpan()
    viewNames?.setAttributes(span: span)
    span.end()

    // Do a special check for button clicks.
    if type == .ended {
        if let button = touch.view as? UIButton {
            if button.isHighlighted {
                let span = tracer.spanBuilder(spanName: "click")
                    .startSpan()
                viewNames?.setAttributes(span: span)
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
    @objc func _instrumented_sendEvent(_ event: UIEvent) {
        switch event.type {
        case .touches:
            //if let touches = event.touches(for: self) {
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
