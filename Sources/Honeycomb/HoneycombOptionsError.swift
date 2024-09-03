import Foundation

/// An error when loading Honeycomb options from key-value pairs.
public enum HoneycombOptionsError: Error, Equatable {
    case incorrectType(String)
    case malformedKeyValueString(String)
    case malformedURL(String)
    case missingAPIKey(String)
    case unsupportedExporter(String)
    case unsupportedProtocol(String)
}
