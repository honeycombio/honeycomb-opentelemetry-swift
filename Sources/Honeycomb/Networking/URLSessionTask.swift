import Foundation
import OpenTelemetryApi

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

extension URLSessionTask {
    // A replacement for URLSessionTask.resume(), which captures the start of any network request.
    // swift-format-ignore
    @objc func _instrumented_resume() {
        if let request = self.originalRequest {
            if !isOTLPRequest(request) {
                let span = createSpan(from: request)

                ProxyURLSessionTaskDelegate.setSpan(span, for: self)

                // In iOS 15+, it's possible to set a delegate for the task that overrides the delegate for the session.
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
