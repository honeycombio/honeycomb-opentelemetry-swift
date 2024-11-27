import Foundation
import Honeycomb
import OpenTelemetryApi
import SwiftUI
import UIKit

private struct NestedExpensiveView: View {
    let delay: Double

    var body: some View {
        HStack {
            HoneycombInstrumentedView(name: "nested expensive text") {
                Text(String(timeConsumingCalculation(delay)))
            }
        }
    }
}

// lets us adjust the slider value without re-rendering
// the main ExpensiveView
// once the user stops editing the slider, we propagate it back
// up to ExpensiveView and then that will re-render
struct DelayedSlider: View {
    @State private var sliderDelay = 2.0
    @State private var isEditing = false
    var delay: Binding<Double>

    var body: some View {
        Slider(
            value: $sliderDelay,
            in: 0...4,
            step: 0.5
        ) {
            Text("Delay")
        } minimumValueLabel: {
            Text("0")
        } maximumValueLabel: {
            Text("4")
        } onEditingChanged: { editing in
            isEditing = editing
            if !editing {
                delay.wrappedValue = sliderDelay
            }
        }
    }
}

private struct ExpensiveView: View {
    @State private var delay = 2.0

    var body: some View {
        HoneycombInstrumentedView(name: "main view") {
            VStack {
                Spacer()

                DelayedSlider(delay: $delay)

                HoneycombInstrumentedView(name: "expensive text 1") {
                    Text(timeConsumingCalculation(delay))
                }

                HoneycombInstrumentedView(name: "expensive text 2") {
                    Text(timeConsumingCalculation(delay))
                }

                HoneycombInstrumentedView(name: "expensive text 3") {
                    Text(timeConsumingCalculation(delay))
                }

                HoneycombInstrumentedView(name: "nested expensive view") {
                    NestedExpensiveView(delay: delay)
                }

                HoneycombInstrumentedView(name: "expensive text 4") {
                    Text(timeConsumingCalculation(delay))
                }

                Spacer()
            }
        }
    }
}

struct ViewInstrumentationView: View {
    @State private var isEnabled = false

    var body: some View {
        VStack {
            Toggle(isOn: $isEnabled) { Text("enable slow render") }
            Spacer()
            if isEnabled {
                ExpensiveView()
            }
        }
        .onDisappear {
            isEnabled = false
        }
    }
}

private func timeConsumingCalculation(_ delay: TimeInterval) -> String {
    print("starting time consuming calculation")
    Thread.sleep(forTimeInterval: delay)
    return "slow text: \(round(delay * 100) / 100)"
}

#Preview {
    ViewInstrumentationView()
}
