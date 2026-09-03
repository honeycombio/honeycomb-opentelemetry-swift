import Foundation
import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import Honeycomb

/// A task delegate that implements some optional methods but not
/// urlSession(_:task:didCompleteWithError:).
///
/// This is the shape of SwiftUI's AsyncImageDownloader on iOS 27, which attaches itself as a
/// per-task delegate. See ONCALL-4996.
private class PartialTaskDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {}

    // A method the proxy does not implement itself, so it has to be forwarded.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        completionHandler(.performDefaultHandling, nil)
    }
}

/// A task delegate that implements didCompleteWithError, to check that forwarding still happens.
private class CompletingTaskDelegate: NSObject, URLSessionTaskDelegate {
    var receivedCompletion = false

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        receivedCompletion = true
    }
}

final class ProxyURLSessionTaskDelegateTests: XCTestCase {
    // The selectors URLSession may send to a task delegate. If responds(to:) claims one of these
    // but nothing in the forwarding chain implements it, the ObjC runtime traps with
    // "unrecognized selector" and the app dies.
    private let taskDelegateSelectors: [Selector] = [
        #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)),
        #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)),
        #selector(
            URLSessionTaskDelegate.urlSession(
                _:
                task:
                willPerformHTTPRedirection:
                newRequest:
                completionHandler:
            )
        ),
        #selector(URLSessionTaskDelegate.urlSession(_:task:didReceive:completionHandler:)),
        #selector(URLSessionTaskDelegate.urlSession(_:task:needNewBodyStream:)),
        #selector(URLSessionTaskDelegate.urlSession(_:taskIsWaitingForConnectivity:)),
        #selector(
            URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)
                as (URLSessionDataDelegate) -> ((URLSession, URLSessionDataTask, Data) -> Void)?
        ),
        #selector(URLSessionDelegate.urlSession(_:didBecomeInvalidWithError:)),
    ]

    /// Whatever responds(to:) claims must actually be reachable, either on the proxy itself or on
    /// the delegate it wraps. Anything else is a crash waiting to happen.
    private func assertClaimsAreHonest(
        _ proxy: ProxyURLSessionTaskDelegate,
        wrapped: NSObject?,
        _ message: String
    ) {
        for selector in taskDelegateSelectors {
            guard proxy.responds(to: selector) else { continue }

            let implementedByProxy =
                class_getInstanceMethod(type(of: proxy), selector) != nil
            let implementedByWrapped = wrapped?.responds(to: selector) ?? false

            XCTAssertTrue(
                implementedByProxy || implementedByWrapped,
                """
                \(message): responds(to: \(NSStringFromSelector(selector))) is true, but neither \
                the proxy nor its wrapped delegate implements it. This traps at runtime.
                """
            )
        }
    }

    func testDoesNotClaimUnimplementedSelectorsWhenWrappingNil() {
        let proxy = ProxyURLSessionTaskDelegate(nil)
        assertClaimsAreHonest(proxy, wrapped: nil, "wrapping nil")
    }

    func testDoesNotClaimUnimplementedSelectorsWhenWrappingPartialDelegate() {
        let wrapped = PartialTaskDelegate()
        let proxy = ProxyURLSessionTaskDelegate(wrapped)
        assertClaimsAreHonest(proxy, wrapped: wrapped, "wrapping a partial delegate")
    }

    /// The specific crash from ONCALL-4996: the proxy must implement didCompleteWithError itself
    /// rather than advertising it and forwarding to a delegate that can't handle it.
    func testImplementsDidCompleteWithError() {
        let selector = #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:))

        XCTAssertNotNil(
            class_getInstanceMethod(ProxyURLSessionTaskDelegate.self, selector),
            "the proxy must implement didCompleteWithError, not just claim it"
        )
        XCTAssertTrue(ProxyURLSessionTaskDelegate(nil).responds(to: selector))
        XCTAssertTrue(ProxyURLSessionTaskDelegate(PartialTaskDelegate()).responds(to: selector))
    }

    /// forwardingTarget must never hand back a delegate that can't handle the selector, because
    /// that reaches the end of the forwarding chain and traps.
    func testForwardingTargetOnlyReturnsDelegatesThatRespond() {
        let selector = #selector(URLSessionTaskDelegate.urlSession(_:task:needNewBodyStream:))

        XCTAssertNil(ProxyURLSessionTaskDelegate(nil).forwardingTarget(for: selector))
        XCTAssertNil(
            ProxyURLSessionTaskDelegate(PartialTaskDelegate()).forwardingTarget(for: selector)
        )
    }

    /// Methods the wrapped delegate does implement, but the proxy does not, must still reach it.
    func testStillForwardsToDelegatesThatRespond() {
        let selector = #selector(
            URLSessionTaskDelegate.urlSession(_:task:didReceive:completionHandler:)
        )
        let wrapped = PartialTaskDelegate()
        let proxy = ProxyURLSessionTaskDelegate(wrapped)

        XCTAssertNil(
            class_getInstanceMethod(ProxyURLSessionTaskDelegate.self, selector),
            "precondition: the proxy must not implement this itself, or nothing is forwarded"
        )
        XCTAssertTrue(proxy.responds(to: selector))
        XCTAssertIdentical(proxy.forwardingTarget(for: selector) as? NSObject, wrapped)
    }

    /// A wrapped delegate that implements didCompleteWithError must still be called.
    func testForwardsDidCompleteWithErrorToWrappedDelegate() {
        let wrapped = CompletingTaskDelegate()
        let proxy = ProxyURLSessionTaskDelegate(wrapped)
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: URL(string: "https://example.com")!)

        proxy.urlSession(session, task: task, didCompleteWithError: nil)

        XCTAssertTrue(wrapped.receivedCompletion)
        session.invalidateAndCancel()
    }
}

/// Tests that drive a real URLSession against a port nothing is listening on, to check what the
/// proxy records for requests that fail below the HTTP layer.
///
/// These use a loopback address rather than an unresolvable hostname so they don't depend on DNS,
/// and port 1 because binding it requires root, so nothing will be there.
final class ProxyURLSessionTaskDelegateErrorTests: XCTestCase {
    private let unreachable = URL(string: "http://127.0.0.1:1/")!

    private var exporter: InMemoryExporter!

    override func setUp() {
        super.setUp()
        exporter = InMemoryExporter()
        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderBuilder()
                .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
                .build()
        )
    }

    /// Starts a task the way _instrumented_resume does, and waits for the proxy to end its span.
    private func exportedSpan(
        for makeTask: (URLSession, URLRequest) -> URLSessionTask
    ) throws -> SpanData {
        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProxyURLSessionTaskDelegate(nil),
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        let request = URLRequest(url: unreachable)
        let task = makeTask(session, request)
        ProxyURLSessionTaskDelegate.setSpan(createSpan(from: request), for: task)
        task.resume()

        let exported = expectation(description: "span exported")
        let poll = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
            [weak self] timer in
            if self?.exporter.getFinishedSpanItems().isEmpty == false {
                timer.invalidate()
                exported.fulfill()
            }
        }
        defer { poll.invalidate() }
        wait(for: [exported], timeout: 10)

        return try XCTUnwrap(exporter.getFinishedSpanItems().first)
    }

    private func assertRecordsConnectionFailure(_ span: SpanData, _ message: String) {
        guard case .error = span.status else {
            return XCTFail("\(message): span status is \(span.status), expected .error")
        }
        XCTAssertEqual(
            span.attributes["error.type"],
            AttributeValue.string("\(NSURLErrorDomain).\(NSURLErrorCannotConnectToHost)"),
            message
        )
    }

    /// A delegate-driven task gets didCompleteWithError, which is handed the error directly.
    func testRecordsErrorForDelegateDrivenTask() throws {
        let span = try exportedSpan { session, request in
            session.dataTask(with: request)
        }
        assertRecordsConnectionFailure(span, "delegate-driven task")
    }

    /// A task with a completion handler never gets didCompleteWithError, so the span is ended by
    /// didFinishCollecting, which has to read task.error instead. This test exists to confirm that
    /// task.error is already populated at that point.
    func testRecordsErrorForCompletionHandlerTask() throws {
        let span = try exportedSpan { session, request in
            session.dataTask(with: request) { _, _, _ in }
        }
        assertRecordsConnectionFailure(span, "completion-handler task")
    }
}
