
import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

private let urlSessionInstrumentationName = "@honeycombio/instrumentation-urlsession"

// Creates a span with attributes for the given http request.
internal func createSpan(from request: URLRequest) -> any Span {
    let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: urlSessionInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
    
    var builder = tracer.spanBuilder(spanName: request.httpMethod ?? "UNKNOWN")
    builder.setSpanKind(spanKind: SpanKind.client)
    if let method = request.httpMethod {
        builder = builder.setAttribute(key: "http.request.method", value: method)
    }
    if let url = request.url {
        builder = builder.setAttribute(key: "url.full", value: url.absoluteString)
        if let host = url.host {
            builder = builder.setAttribute(key: "server.address", value: host)
        }
        if let port = url.port {
            builder = builder.setAttribute(key: "server.port", value: port)
        }
        if let scheme = url.scheme {
            builder = builder.setAttribute(key: "http.scheme", value: scheme)
        }
    }
    return builder.startSpan()
}

internal func updateSpan(_ span: Span, with response: HTTPURLResponse) {
    let code = response.statusCode
    span.setAttribute(key: "http.response.status_code", value: .int(code))
}

/// Installs the auto-instrumentation for URLSession.
///
/// For now, networking auto-instrumentation is only available on iOS 15.0+, because older versions
/// don't support URLSessionTaskDelegate. As of June 2024, this covers at least 97% of devices.
///
func installNetworkInstrumentation(options: HoneycombOptions) {
    if #available(iOS 15.0, *) {
        URLSessionTask.swizzle()
        URLSession.swizzle()
    } else {
        if options.debug {
            print("Honeycomb URLSession instrumentation disabled on iOS <15")
        }
    }
}
