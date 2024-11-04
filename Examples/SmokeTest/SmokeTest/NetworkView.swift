import Foundation
import SwiftUI
import UIKit

internal enum RequestType {
    case dataTask
    case uploadTask
    case downloadTask
}

// To fully test network auto-instrumentation, there are several different parameters to adjust.
private class NetworkRequestSpec: ObservableObject, CustomStringConvertible {
    @Published var address: String = "http://localhost:3000/get"

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
    
    var description: String {
        let typeStr = switch requestType {
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
var taskDelegate = SmokeTestSessionTaskDelegate(name: "task")
var sessionDelegate = SmokeTestSessionTaskDelegate(name: "session")

// A simple delegate that just records whether it got called.
class SmokeTestSessionTaskDelegate: NSObject, URLSessionTaskDelegate {
    let name: String
    var wasCalled: Bool = false

    init(name: String) {
        self.name = name
    }

    // TODO: Delete this.
    /*
    @available(iOS 16.0, *)
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let now = Date.now
        print("[\(name):\(now)] URLSession:didCreateTask:")

        // TODO: Add a comment here.
        // TODO: No, this doesn't work at all; what was I thinking?
        /*
        if task.delegate == nil {
            if let delegate = session.delegate as? URLSessionTaskDelegate {
                task.delegate = delegate
            }
        }
        */
    }
    */

    @available(iOS 10.0, *)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        self.wasCalled = true
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        print("[\(name)] URLSession:task:didCompleteWithError")
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

private func doNetworkRequest(_ requestSpec: NetworkRequestSpec) async -> String {
    guard let url = URL(string: requestSpec.address) else {
        return "invalid url"
    }
    let session = createSession(useSessionDelegate: requestSpec.useSessionDelegate)
    let request = URLRequest(url: url)

    do {
        switch requestSpec.requestType {
        case .dataTask:
            switch requestSpec.useAsync {
            case true:
                let (_, response) = switch requestSpec.useRequestObject {
                case true:
                    switch requestSpec.useTaskDelegate {
                    case true:
                        try await session.data(for: request, delegate: taskDelegate)
                    case false:
                        try await session.data(for: request)
                    }
                case false:
                    switch requestSpec.useTaskDelegate {
                    case true:
                        try await session.data(from: url, delegate: taskDelegate)
                    case false:
                        try await session.data(from: url)
                    }
                }
                return summarize(response: response, error: nil)
            case false:
                return await withCheckedContinuation { continuation in
                    let callback = { @Sendable (data: Data?, response: URLResponse?, error: Error?) in
                        let summary = summarize(response: response, error: error)
                        continuation.resume(returning: summary)
                    };
                    let task = switch requestSpec.useRequestObject {
                    case true:
                        session.dataTask(with: request, completionHandler: callback)
                    case false:
                        session.dataTask(with: url, completionHandler: callback)
                    }
                    task.resume()
                }
            }
        case .downloadTask:
            switch requestSpec.useAsync {
            case true:
                let (_, response) = switch requestSpec.useRequestObject {
                case true:
                    switch requestSpec.useTaskDelegate {
                    case true:
                        try await session.download(for: request, delegate: taskDelegate)
                    case false:
                        try await session.download(for: request)
                    }
                case false:
                    switch requestSpec.useTaskDelegate {
                    case true:
                        try await session.download(from: url, delegate: taskDelegate)
                    case false:
                        try await session.download(from: url)
                    }
                }
                return summarize(response: response, error: nil)
            case false:
                return await withCheckedContinuation { continuation in
                    let callback = { @Sendable (url: URL?, response: URLResponse?, error: Error?) in
                        let summary = summarize(response: response, error: error)
                        continuation.resume(returning: summary)
                    };
                    let task = switch requestSpec.useRequestObject {
                    case true:
                        session.downloadTask(with: request, completionHandler: callback)
                    case false:
                        session.downloadTask(with: url, completionHandler: callback)
                    }
                    task.resume()
                }
            }
            
        case .uploadTask:
            switch requestSpec.useRequestObject {
            case false:
                return "upload with URL unsupported"
            case true:
                let dataToUpload = Data()
                switch requestSpec.useAsync {
                case true:
                    let (_, response) = switch requestSpec.useTaskDelegate {
                    case true:
                        try await session.upload(for: request, from: dataToUpload, delegate: taskDelegate)
                    case false:
                        try await session.upload(for: request, from: dataToUpload)
                    }
                    return summarize(response: response, error: nil)
                case false:
                    return await withCheckedContinuation { continuation in
                        let callback = { @Sendable (data: Data?, response: URLResponse?, error: Error?) in
                            let summary = summarize(response: response, error: error)
                            continuation.resume(returning: summary)
                        };
                        let task = session.uploadTask(with: request, from: dataToUpload, completionHandler: callback)
                        task.resume()
                    }
                }
            }
        }
    } catch {
        return summarize(response: nil, error: error)
    }
}

/*
private func doNetworkRequestAsync(_ requestSpec: NetworkRequestSpec) async -> String {
    guard let url = URL(string: requestSpec.address) else {
        return "invalid url"
    }
    let session = createSession(useSessionDelegate: requestSpec.useSessionDelegate)
    let request = URLRequest(url: url)
    do {
        let (data, response) =
        if requestSpec.useRequestObject {
            if requestSpec.useTaskDelegate {
                try await session.data(for: request, delegate: taskDelegate)
            } else {
                try await session.data(for: request)
            }
        } else {
            if requestSpec.useTaskDelegate {
                try await session.data(from: url, delegate: taskDelegate)
            } else {
                try await session.data(from: url)
            }
        }
        return summarizeResponse(data: data, response: response, error: nil)
    } catch {
        return summarizeResponse(data: nil, response: nil, error: error)
    }
}

private func doNetworkRequestCallback(_ requestSpec: NetworkRequestSpec) async -> String {
    guard let url = URL(string: requestSpec.address) else {
        return "invalid url"
    }
    let request = URLRequest(url: url)
    let session = createSession(useSessionDelegate: requestSpec.useSessionDelegate)
    return await withCheckedContinuation { continuation in
        let task = session.dataTask(with: request) { (data, response, error) in
            let summary = summarizeResponse(data: data, response: response, error: error)
            continuation.resume(returning: summary)
        }
        task.resume()
    }
}

private func doNetworkRequest(_ requestSpec: NetworkRequestSpec) async
-> String {
    taskDelegate.wasCalled = false
    sessionDelegate.wasCalled = false

    if requestSpec.useAsync {
        return await doNetworkRequestAsync(requestSpec)
    } else {
        return await doNetworkRequestCallback(requestSpec)
    }
}
*/

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
            
            Toggle(isOn: $request.useAsync) {
                Text("Use async function")
            }
            Toggle(isOn: $request.useRequestObject) {
                Text("Use URLRequest object")
            }
            if request.useAsync {
                Toggle(isOn: $request.useTaskDelegate) {
                    Text("Use a task delegate")
                }
            }
            Toggle(isOn: $request.useSessionDelegate) {
                Text("Use a session delegate")
            }.accessibilityIdentifier("useSessionDelegate")

            Button(action: {
                responseSummary = "..."
                taskDelegate.wasCalled = false
                sessionDelegate.wasCalled = false
                taskDelegateCalled = false
                sessionDelegateCalled = false
                Task {
                    responseSummary = await doNetworkRequest(request)
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
            }
            HStack {
                Text("Task Delegate Called")
                Spacer()
                Text(taskDelegateCalled ? "✅" : "❌")
            }
            HStack {
                Text("Session Delegate Called")
                Spacer()
                Text(sessionDelegateCalled ? "✅" : "❌")
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
