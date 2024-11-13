import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

@testable import Honeycomb

private struct ExpensiveView: View {
    var body: some View {
        HStack {
            Text("test:")
            HoneycombInstrumentedView(name: "nested expensive text") {
                Text(String(timeConsumingCalculation()))
            }
        }
    }
}

struct ViewInstrumentationView: View {
    var body: some View {
        HoneycombInstrumentedView(name: "main view") {
            VStack {

                HoneycombInstrumentedView(name: "expensive text 1") {
                    Text(String(timeConsumingCalculation()))
                }

                HoneycombInstrumentedView(name: "expensive text 2") {
                    Text(String(timeConsumingCalculation()))
                }

                HoneycombInstrumentedView(name: "expensive text 3") {
                    Text(String(timeConsumingCalculation()))
                }

                HoneycombInstrumentedView(name: "nested expensive view") {
                    ExpensiveView()
                }

                HoneycombInstrumentedView(name: "expensive text 4") {
                    Text(String(timeConsumingCalculation()))
                }
            }
        }
    }
}

private func timeConsumingCalculation() -> Int {
    print("starting time consuming calculation")
    return (1...10_000_000).reduce(0, +)
}

#Preview {
    ViewInstrumentationView()
}
