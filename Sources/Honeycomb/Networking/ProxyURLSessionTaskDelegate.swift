import Foundation
import OpenTelemetryApi

// A key for associating a span with a task.
private var spanKey: UInt8 = 0

/// A proxy for the URLSession or URLSessionTask's delegate, so that we can intercept calls to it.
///
/// The only reliable way to know if a URLSession is finished is to attach a delegate to it.
/// But the app may have already attached a delegate to it. So, we need to wrap it and forward
/// messages.
///
/// This proxy is attached to the URLSession and possibly also the URLSessionTask using swizzled methods.
///
internal class ProxyURLSessionTaskDelegate: NSObject, URLSessionTaskDelegate {
    // The original delegate that this proxy replaces.
    private let wrapped: URLSessionTaskDelegate?

    init(_ wrapped: URLSessionTaskDelegate?) {
        self.wrapped = wrapped
    }

    // Gets the span for a particular task. We have to use an "associated object" because we can't extend URLSessionTask.
    static func getSpan(for task: URLSessionTask) -> Span? {
        return objc_getAssociatedObject(task, &spanKey) as? Span
    }

    static func setSpan(_ span: Span, for task: URLSessionTask) {
        objc_setAssociatedObject(
            task,
            &spanKey,
            span,
            objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN
        )
    }

    // Because the protocol is full of optional methods, we have to forward requests about which
    // methods are actually implemented.
    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)) {
            return true
        }
        if aSelector == #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)) {
            return true
        }

        guard let wrapped = self.wrapped else {
            return false
        }
        let answer = wrapped.responds(to: aSelector)
        return answer
    }

    // Forward any unhandled methods to the underlying delegate.
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return self.wrapped
    }

    // Called whenever a request completes.
    @available(iOS 10.0, *)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        if let span = ProxyURLSessionTaskDelegate.getSpan(for: task) {
            if let response = task.response {
                if let httpResponse = response as? HTTPURLResponse {
                    updateSpan(span, with: httpResponse)
                }
            }
            span.end()
        }

        wrapped?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }
}
