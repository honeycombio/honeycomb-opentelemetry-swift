import Foundation

/// Parses a string representing an OTLPProtocol.
private func parseOTLPProtocol(_ s: String) throws -> OTLPProtocol? {
    return switch s {
    case "": nil
    case "grpc": .grpc
    case "http/protobuf": .httpProtobuf
    case "http/json": .httpJSON
    default: throw HoneycombOptionsError.unsupportedProtocol("invalid protocol \(s)")
    }
}

/// Parses a list of key-value pairs, as used in specifying resources and headers.
///
/// Headers are comma-separated pairs with equals, such as:
///     key1=value1,key2=value2
/// See the format specified here:
/// https://opentelemetry.io/docs/specs/otel/resource/sdk/#specifying-resource-information-via-an-environment-variable
internal func parseKeyValueList(_ maybeKeyValueString: String?) throws -> [String: String] {
    var result: [String: String] = [:]
    guard let keyValueString = maybeKeyValueString else {
        return result
    }
    let parts: [String] = keyValueString.split(separator: ",")
        .map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
    for part: String in parts {
        if part == "" {
            continue
        }
        let keyAndVal: [String] = part.split(separator: "=", maxSplits: 1)
            .map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
        guard keyAndVal.count == 2 else {
            throw HoneycombOptionsError.malformedKeyValueString(part)
        }
        guard let key: String = keyAndVal[0].removingPercentEncoding else {
            throw HoneycombOptionsError.malformedKeyValueString(part)
        }
        guard let value = keyAndVal[1].removingPercentEncoding else {
            throw HoneycombOptionsError.malformedKeyValueString(part)
        }
        result[key] = value
    }
    return result
}

/// A dictionary with keys and values for configuring Honeycomb.
/// Provides getters that enforce type safety.
internal class HoneycombOptionsSource {
    let info: [String: Any]?

    init(info: [String: Any]?) {
        self.info = info
    }

    func getString(_ key: String) throws -> String? {
        return switch info?[key] {
        case nil:
            nil
        case let value as String:
            switch value.trimmingCharacters(in: .whitespaces) {
            case "":
                nil
            case let trimmed:
                trimmed
            }
        default:
            throw HoneycombOptionsError.incorrectType(key)
        }
    }

    func getInt(_ key: String) throws -> Int? {
        return switch info?[key] {
        case nil:
            nil
        case let value as Int:
            value
        case let value as String:
            switch value.trimmingCharacters(in: .whitespaces) {
            case "":
                nil
            case let trimmed:
                if let parsed = Int(trimmed) {
                    parsed
                } else {
                    throw HoneycombOptionsError.incorrectType(key)
                }
            }
        default:
            throw HoneycombOptionsError.incorrectType(key)
        }
    }

    func getBool(_ key: String) throws -> Bool? {
        return switch info?[key] {
        case nil:
            nil
        case let value as Bool:
            value
        case let value as String:
            switch value.trimmingCharacters(in: .whitespaces) {
            case "":
                nil
            case let trimmed:
                if let parsed = Bool(trimmed) {
                    parsed
                } else {
                    throw HoneycombOptionsError.incorrectType(key)
                }
            }
        default:
            throw HoneycombOptionsError.incorrectType(key)
        }
    }

    func getTimeInterval(_ key: String) throws -> TimeInterval? {
        // TimeIntervals are stored as milliseconds.
        return switch info?[key] {
        case nil:
            nil
        case let value as Double:
            TimeInterval(value / 1000.0)
        case let value as Int:
            TimeInterval(Double(value) / 1000.0)
        case let value as String:
            switch value.trimmingCharacters(in: .whitespaces) {
            case "":
                nil
            case let trimmed:
                if let parsed = Double(trimmed) {
                    TimeInterval(parsed / 1000.0)
                } else {
                    throw HoneycombOptionsError.incorrectType(key)
                }
            }
        default:
            throw HoneycombOptionsError.incorrectType(key)
        }
    }

    func getKeyValueList(_ key: String) throws -> [String: String] {
        let raw = try self.getString(key)
        return try parseKeyValueList(raw)
    }

    func getOTLPProtocol(_ key: String) throws -> OTLPProtocol? {
        return try getString(key)
            .flatMap { s in
                try parseOTLPProtocol(s)
            }
    }
}
