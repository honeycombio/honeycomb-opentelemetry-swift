import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

struct ViewAttributes {
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
