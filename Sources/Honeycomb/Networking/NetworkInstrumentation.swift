
import Foundation
import OpenTelemetryApi
import SwiftUI
import UIKit

// TODO: Test a failed request (404).
// TODO: Test a request that fails to find the host.
// TODO: Test with both URL and URLRequest methods.
// TODO: Test with download and upload tasks.
// TODO: 
// TODO: Sync up the fields with the semconv
// TODO: Write smoke tests.

// TODO: Why don't these match?
// https://opentelemetry.io/docs/specs/semconv/http/http-spans/#http-client
// https://github.com/open-telemetry/opentelemetry-js/tree/main/experimental/packages/opentelemetry-instrumentation-xml-http-request


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
