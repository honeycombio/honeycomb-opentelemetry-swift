import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

private enum RequestType {
    case dataTask
    case uploadTask
    case downloadTask
}

// To fully test network auto-instrumentation, there are several different parameters to adjust.
private class NetworkRequestSpec: ObservableObject, CustomStringConvertible {
    @Published var address: String = "http://localhost:1080/simple-api"

    /// The subtype of URLSessionTask to use.
    @Published var requestType: RequestType = .dataTask

    /// Whether to use an async method instead of the callback methods.
    /// The async methods have a different internal implementation.
    @Published var useAsync: Bool = false

    /// Whether to pass in a URLRequest, rather than a URL.
    @Published var useRequestObject: Bool = false

    /// Whether to use a delegate attacked directly to the URLSessionTask.
    @Published var useTaskDelegate: Bool = false

    /// Whether to attach a delegate to the URLSession.
    @Published var useSessionDelegate: Bool = false

    /// A descriptor to help us verify we are testing the config we intend to.
    var description: String {
        let typeStr =
            switch requestType {
            case .dataTask:
                "data"
            case .uploadTask:
                "upload"
            case .downloadTask:
                "download"
            }

        let asyncStr = useAsync ? "async" : "callback"
        let requestStr = useRequestObject ? "obj" : "url"
        let taskStr = useTaskDelegate ? "-task" : ""
        let sessionStr = useSessionDelegate ? "-session" : ""

        return "\(typeStr)-\(asyncStr)-\(requestStr)\(taskStr)\(sessionStr)"
    }
}

// Our instrumention futzes with the request delegates, so it's good to test that delegates set by
// the app developer still work.
var taskDelegate = SmokeTestSessionTaskDelegate()
var sessionDelegate = SmokeTestSessionTaskDelegate()

// A simple delegate that just records whether it got called.
class SmokeTestSessionTaskDelegate: NSObject, URLSessionTaskDelegate {
    var wasCalled: Bool = false

    /// This method is implemented to test the proxy forwarding a method it doesn't override.
    @available(iOS 16.0, *)
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
    }

    @available(iOS 10.0, *)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        self.wasCalled = true
    }
}

private func createSession(useSessionDelegate: Bool) -> URLSession {
    return if useSessionDelegate {
        URLSession(
            configuration: URLSessionConfiguration.default,
            delegate: sessionDelegate,
            delegateQueue: OperationQueue.main
        )
    } else {
        URLSession(configuration: URLSessionConfiguration.default)
    }
}

private func summarize(response: URLResponse?, error: (any Error)?) -> String {
    if let error = error {
        return "error: \(error)"
    }
    guard let httpResponse = response as? HTTPURLResponse else {
        return "error: response is not an http response"
    }
    let summary = "\(httpResponse.statusCode)"
    return summary
}

/// Method to do a network request with the given spec and return a summary of the response.
private func doNetworkRequest(_ requestSpec: NetworkRequestSpec) async -> String {
    guard let url = URL(string: requestSpec.address) else {
        return "invalid url"
    }
    let session = URLSession(
        configuration: URLSessionConfiguration.default,
        delegate: sessionDelegate,
        delegateQueue: OperationQueue.main
    )

    if (requestSpec.useAsync) {
        //        Task {
        //            let callback = { @Sendable (data: Data?, response: URLResponse?, error: Error?) in
        //                print("session delegate called? \(sessionDelegate.wasCalled)")
        //                print("response: \(summarize(response: response, error: error))")
        //            }
        //            let task = session.dataTask(with: url, completionHandler: callback)
        //            task.resume()
        //        }
        Task {
            await withCheckedContinuation { continuation in
                let callback = { @Sendable (data: Data?, response: URLResponse?, error: Error?) in
                    print("Task session delegate called? \(sessionDelegate.wasCalled)")
                    print("response: \(summarize(response: response, error: error))")
                    continuation.resume()
                }
                
                let task = session.dataTask(with: url, completionHandler: callback)
                task.resume()
            }
        }
    } else {
        let callback = { @Sendable (data: Data?, response: URLResponse?, error: Error?) in
            print("session delegate called? \(sessionDelegate.wasCalled)")
            print("response: \(summarize(response: response, error: error))")
        }
        let task = session.dataTask(with: url, completionHandler: callback)
        task.resume()
    }
    
    return ""
}

struct NetworkView: View {
    @StateObject private var request = NetworkRequestSpec()
    @State private var responseSummary = ""
    @State private var taskDelegateCalled = false
    @State private var sessionDelegateCalled = false

    var body: some View {
        VStack(
            alignment: .center,
            spacing: 20.0
        ) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text("Network Playground")

            TextField("address", text: $request.address)

            Picker("Request type", selection: $request.requestType) {
                Text("Data").tag(RequestType.dataTask)
                Text("Upload").tag(RequestType.uploadTask)
                Text("Download").tag(RequestType.downloadTask)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("requestType")

            Toggle(isOn: $request.useAsync) {
                Text("Use async function")
            }
            .accessibilityIdentifier("useAsync")

            Button(action: {
                responseSummary = "..."
                taskDelegate.wasCalled = false
                sessionDelegate.wasCalled = false
                taskDelegateCalled = false
                sessionDelegateCalled = false
                // Add an attribute with the request-id, so we can find it in the collector's output.
                let baggage = OpenTelemetry.instance.baggageManager.baggageBuilder()
                    .put(
                        key: EntryKey(name: "request-id")!,
                        value: EntryValue(string: request.description)!,
                        metadata: nil
                    )
                    .build()
                Task {
                    responseSummary = await OpenTelemetry.instance.contextProvider
                        .withActiveBaggage(baggage) {
                            await doNetworkRequest(request)
                        }
                    taskDelegateCalled = taskDelegate.wasCalled
                    sessionDelegateCalled = sessionDelegate.wasCalled
                }
            }) {
                Text("Do a network request")
            }
            .buttonStyle(.bordered)

            HStack {
                Text("Request ID")
                Spacer()
                Text(request.description)
            }
            HStack {
                Text("Response Status Code")
                Spacer()
                Text(responseSummary)
                    .accessibilityIdentifier("responseStatusCode")
            }
            HStack {
                Text("Task Delegate Called")
                Spacer()
                Text(taskDelegateCalled ? "✅" : "❌")
                    .accessibilityIdentifier("taskDelegateCalled")
            }
            HStack {
                Text("Session Delegate Called")
                Spacer()
                Text(sessionDelegateCalled ? "✅" : "❌")
                    .accessibilityIdentifier("sessionDelegateCalled")
            }

            Button(action: { responseSummary = "" }) {
                Text("Clear")
            }
        }
    }
}

#Preview {
    NetworkView()
}
