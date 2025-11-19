
import SwiftUI

private enum CrashType {
    case segfault
    case cocoaException
    case swiftException
}

private func crash(type: CrashType) {
    print("Crashing \(type)")
    switch type {
    case .segfault:
        HNYCrashHelper.segfault()
    case .cocoaException:
        HNYCrashHelper.throwNSException()
    case .swiftException:
        fatalError("fatal swift error")
    }
}

struct CrashView: SwiftUI.View {
    @State private var crashType: CrashType = .segfault
    
    var body: some SwiftUI.View {
        HStack(
            alignment: .center,
            spacing: 20.0
        ) {
            //Image(systemName: "car")
            //    .imageScale(.large)
            //    .foregroundStyle(.tint)
            
            Picker("Request type", selection: $crashType) {
                Text("segfault").tag(CrashType.segfault)
                Text("cocoa").tag(CrashType.cocoaException)
                Text("swift").tag(CrashType.swiftException)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("crashType")

            Button(action: {
                crash(type: crashType)
            }) {
                Text("Crash")
            }
            .buttonStyle(.bordered)
        }.padding()
    }
}

#Preview {
    CrashView()
}
