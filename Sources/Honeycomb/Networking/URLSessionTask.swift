
import Foundation
import OpenTelemetryApi

private let urlSessionInstrumentationName = "@honeycombio/instrumentation-urlsession"

/// Returns true if this HTTP request is from our SDK itself, so that we don't recursively capture
/// our own requests.
private func isOTLPRequest(_ request: URLRequest) -> Bool {
    // Just check for the OTLP version header that's always set.
    if let headers = request.allHTTPHeaderFields {
        for (key, _) in headers {
            if key == "x-otlp-version" {
                return true
            }
        }
    }
    return false
}

// Creates a span with attributes for the given http request.
private func createSpan(from request: URLRequest) -> any Span {
    let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: urlSessionInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
    var builder = tracer.spanBuilder(spanName: request.httpMethod ?? "UNKNOWN")
    if let method = request.httpMethod {
        builder = builder.setAttribute(key: "http.method", value: method)
        builder = builder.setAttribute(key: "http.request.method", value: method)
    }
    if let url = request.url {
        builder = builder.setAttribute(key: "http.url", value: url.absoluteString)
        if let host = url.host {
            builder = builder.setAttribute(key: "http.host", value: host)
        }
        if let scheme = url.scheme {
            builder = builder.setAttribute(key: "http.scheme", value: scheme)
        }
    }
    return builder.startSpan()
}

extension URLSessionTask {
    // A replacement for URLSessionTask.resume(), which captures the start of any network request.
    @objc func _instrumented_resume() {
        if let request = self.originalRequest {
            if !isOTLPRequest(request) {
                let span = createSpan(from: request)

                ProxyURLSessionTaskDelegate.setSpan(span, for: self)

                // See the comment below about why this function is only called on iOS 15+.
                if #available(iOS 15.0, *) {
                    if self.delegate != nil {
                        self.delegate = ProxyURLSessionTaskDelegate(self.delegate)
                    }
                }
            }
        }

        // Because the methods were swapped, this calls the original method.
        return _instrumented_resume()
    }

    // A helper method to swizzle in our replacement for resume.
    static func swizzle() {
        let resumeSelector = #selector(URLSessionTask.resume)
        let instrumentedResumeSelector = #selector(URLSessionTask._instrumented_resume)
        let resumeMethod = class_getInstanceMethod(self, resumeSelector)
        let instrumentedResumeMethod = class_getInstanceMethod(self, instrumentedResumeSelector)
        method_exchangeImplementations(
            resumeMethod!,
            instrumentedResumeMethod!
        )
    }
}
