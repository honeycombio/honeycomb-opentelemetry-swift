import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// The instrumentation scope that Honeycomb's own URLSession instrumentation has always used.
/// Saved queries filter on it, so the upstream instrumentation is configured to use it as well.
let honeycombURLSessionScope = "io.honeycomb.urlsession"

/// Upstream `URLSessionInstrumentation` (with `semanticConvention: .stable`) sets a few things that
/// Honeycomb's own instrumentation never set, and names one attribute differently:
///
/// | Upstream (2.5.1 / 2.6.0)                        | Honeycomb today                    |
/// | ----------------------------------------------- | ---------------------------------- |
/// | `url.scheme`                                    | `http.scheme`                      |
/// | `url.path`                                      | (none)                             |
/// | `http.request.body.size`                        | (none)                             |
/// | `http.response.body.size`                       | (none)                             |
/// | status `error` for every HTTP status >= 400     | status stays unset                 |
/// | `http.response.status_code = 0` on a transport failure | no status code attribute    |
///
/// This shaper makes upstream's span look like Honeycomb's. Transport-failure attributes
/// (`error.type`, `nserror.*`) need the live `Error`, so they are added by the `receivedError`
/// hook in `makeHoneycombURLSessionConfiguration`, not here.
public func urlSessionSpanShaper(keepUpstreamAdditions: Bool = false) -> SpanShaper {
    return { span in
        guard span.instrumentationScope.name == honeycombURLSessionScope else { return span }

        var attributes = span.attributes
        if let scheme = attributes.removeValue(forKey: "url.scheme") {
            attributes["http.scheme"] = scheme
        }
        if !keepUpstreamAdditions {
            attributes.removeValue(forKey: "url.path")
            attributes.removeValue(forKey: "http.request.body.size")
            attributes.removeValue(forKey: "http.response.body.size")
        }
        // Upstream records 0 when there was no HTTP response at all.
        if case .int(0)? = attributes["http.response.status_code"] {
            attributes.removeValue(forKey: "http.response.status_code")
        }

        var shaped = span
        shaped.settingAttributes(attributes)

        // A 4xx or 5xx response is not an error status in Honeycomb's shape. A transport failure is,
        // and it is recognizable because the `receivedError` hook adds `error.type`.
        if span.status.isError, attributes["error.type"] == nil {
            shaped.settingStatus(.unset)
        }
        return shaped
    }
}

/// Adds the attributes Honeycomb has always put on a URLSession span when the request failed
/// before any HTTP response arrived (timeout, refused connection, DNS failure).
///
/// Called from upstream's `receivedError` hook, which runs on the live span just before it ends.
public func recordTransportFailure(on span: Span, error: any Error) {
    let nsError = error as NSError
    span.status = .error(description: nsError.localizedDescription)
    span.setAttribute(key: "error.type", value: "\(nsError.domain).\(nsError.code)")
    span.setAttribute(key: "error.message", value: nsError.localizedDescription)
    span.setAttribute(key: "nserror.domain", value: nsError.domain)
    span.setAttribute(key: "nserror.code", value: nsError.code)
}
