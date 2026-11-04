import Foundation
import OpenTelemetryApi
import SwiftUI

private let urlSessionInstrumentationName = "io.honeycomb.urlsession"

/// Creates a span with attributes for the given http request.
internal func createSpan(from request: URLRequest) -> any Span {
    let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: urlSessionInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )

    let spanName = urlSessionSpanNameProvider?(request) ?? request.httpMethod ?? "UNKNOWN"
    var span = tracer.spanBuilder(spanName: spanName)
        .setSpanKind(spanKind: SpanKind.client)
        .startSpan()
    if let method = request.httpMethod {
        span.setAttribute(key: SemanticAttributes.httpRequestMethod, value: method)
    }
    if let url = request.url {
        span.setAttribute(key: SemanticAttributes.urlFull, value: url.absoluteString)
        if let host = url.host {
            span.setAttribute(key: SemanticAttributes.serverAddress, value: host)
        }
        if let port = url.port {
            span.setAttribute(key: SemanticAttributes.serverPort, value: port)
        }
        if let scheme = url.scheme {
            span.setAttribute(key: SemanticAttributes.httpScheme, value: scheme)
        }
    }
    return span
}

/// Updates the given span with the given http response.
///
/// Status codes of 400 and above, which the OpenTelemetry semantic conventions treat as errors for
/// HTTP clients, set the span's status to error. Anything below that is left unset.
internal func updateSpan(_ span: Span, with response: HTTPURLResponse) {
    let code = response.statusCode
    span.setAttribute(key: SemanticAttributes.httpResponseStatusCode, value: code)
    if code >= 400 {
        span.status = .error(description: String(code))
    }
}

/// Updates the given span with a transport-level error, such as a timeout or a refused connection.
///
/// These requests have no HTTP status code, so without this the span is indistinguishable from a
/// successful one.
internal func updateSpan(_ span: Span, with error: any Error) {
    let nsError = error as NSError
    span.status = .error(description: nsError.localizedDescription)
    span.setAttribute(key: "error.type", value: "\(nsError.domain).\(nsError.code)")
    span.setAttribute(key: "error.message", value: nsError.localizedDescription)
    span.setAttribute(key: "nserror.domain", value: nsError.domain)
    span.setAttribute(key: "nserror.code", value: nsError.code)
}

/// The app's filter for which requests to instrument, from `HoneycombOptions`. Nil instruments all.
///
/// Written once by `installNetworkInstrumentation` before the swizzles are installed, and only
/// read afterwards, from whichever thread resumes a task.
internal var urlSessionRequestFilter: ((URLRequest) -> Bool)? = nil

/// The app's function for naming spans, from `HoneycombOptions`. Nil names spans by HTTP method.
/// Written and read the same way as `urlSessionRequestFilter`.
internal var urlSessionSpanNameProvider: ((URLRequest) -> String?)? = nil

/// Installs the auto-instrumentation for URLSession.
///
/// For now, networking auto-instrumentation is only available on iOS 15.0+, because older versions
/// don't support URLSessionTaskDelegate. As of June 2024, this covers at least 97% of devices.
///
func installNetworkInstrumentation(options: HoneycombOptions) {
    // Set before swizzling, so the filter is in place before any task can be resumed through it.
    urlSessionRequestFilter = options.urlSessionRequestFilter
    urlSessionSpanNameProvider = options.urlSessionSpanNameProvider
    URLSession.swizzle()
    URLSessionTask.swizzle()
}
