import os;

internal func debugOptions(options: HoneycombOptions) {

    if !options.debug {
        return;
    }
    
    if #available(OSX 11.0, *) {
        let sdkLog = Logger(subsystem: "io.honeycomb", category: "SDK");

        sdkLog.debug("Honeycomb SDK Debug Mode Enabled")

        sdkLog.debug("API Key configured for traces: \(options.tracesApiKey)")
        sdkLog.debug("Service Name configured for traces: \(options.serviceName)")
        sdkLog.debug("Endpoint configured for traces: \(options.tracesEndpoint)")
        sdkLog.debug("Sample Rate configured for traces: \(options.sampleRate)")
    } else {
        let sdkLog = OSLog(subsystem: "io.honeycomb", category: "SDK")

        os_log("Honeycomb SDK Debug Mode Enabled", log: sdkLog, type: .debug)

        // API Key
        os_log("API Key configured for traces: %@", log: sdkLog, type: .debug, options.tracesApiKey)
        os_log("Service Name configured for traces: %@", log: sdkLog, type: .debug, options.serviceName)
        os_log("Endpoint configured for traces: %@", log: sdkLog, type: .debug, options.tracesEndpoint)
        os_log("Sample Rate configured for traces: %@", log: sdkLog, type: .debug, options.sampleRate)
    }

}