import Foundation

internal func debugOptions(options: HoneycombOptions) {
    

    if options.debug {
        print("Honeycomb SDK Debug Mode Enabled")

        print("API Key configured for traces: \(options.tracesApiKey)")
        print("Service Name configured for traces: \(options.serviceName)")
        print("Endpoint configured for traces: \(options.tracesEndpoint)")
        print("Sample Rate configured for traces: \(options.sampleRate)")
    }
}