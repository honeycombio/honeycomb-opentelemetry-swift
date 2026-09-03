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

    // Takes the span for a task, clearing it, so that a task's span is only ended once even
    // though more than one of the delegate methods below may fire for the same task.
    private static func takeSpan(for task: URLSessionTask) -> Span? {
        guard let span = getSpan(for: task) else {
            return nil
        }
        objc_setAssociatedObject(
            task,
            &spanKey,
            nil,
            objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN
        )
        return span
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    // Ends the span for a task, recording the response and any transport error.
    private static func endSpan(for task: URLSessionTask, error: (any Error)? = nil) {
        guard let span = takeSpan(for: task) else {
            return
        }
        if let httpResponse = task.response as? HTTPURLResponse {
            updateSpan(span, with: httpResponse)
        }
        if let error = error ?? task.error, !isCancellation(error) {
            updateSpan(span, with: error)
        }
        span.end()
    }

    // Because the protocol is full of optional methods, we have to forward requests about which
    // methods are actually implemented.
    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) {
            return true
        }
        return wrapped?.responds(to: aSelector) ?? false
    }

    // Forward any unhandled methods to the underlying delegate.
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        guard let wrapped = self.wrapped, wrapped.responds(to: aSelector) else {
            return nil
        }
        return wrapped
    }

    // Called whenever a request completes.
    @available(iOS 10.0, *)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        ProxyURLSessionTaskDelegate.endSpan(for: task)

        wrapped?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }

    // Called whenever a request completes, successfully or not.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        ProxyURLSessionTaskDelegate.endSpan(for: task, error: error)

        wrapped?.urlSession?(session, task: task, didCompleteWithError: error)
    }
}
