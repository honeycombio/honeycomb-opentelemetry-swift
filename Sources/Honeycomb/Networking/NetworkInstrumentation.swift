import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

private let urlSessionInstrumentationName = "@honeycombio/instrumentation-urlsession"

/// Creates a span with attributes for the given http request.
internal func createSpan(from request: URLRequest) -> any Span {
    let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: urlSessionInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )

    var span = tracer.spanBuilder(spanName: request.httpMethod ?? "UNKNOWN")
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
internal func updateSpan(_ span: Span, with response: HTTPURLResponse) {
    let code = response.statusCode
    span.setAttribute(key: SemanticAttributes.httpResponseStatusCode, value: code)
}

/// Installs the auto-instrumentation for URLSession.
///
/// For now, networking auto-instrumentation is only available on iOS 15.0+, because older versions
/// don't support URLSessionTaskDelegate. As of June 2024, this covers at least 97% of devices.
///
func installNetworkInstrumentation(options: HoneycombOptions) {
    URLSession.swizzle()
    URLSessionTask.swizzle()
}
