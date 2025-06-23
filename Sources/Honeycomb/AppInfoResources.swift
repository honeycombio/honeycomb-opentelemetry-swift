import Foundation
import MachO
import OpenTelemetryApi
import OpenTelemetrySdk

// none of these are in the semconv yet so we can call them whatever we like
let APP_BUNDLE_VERSION = "app.bundle.version"
let APP_BUNDLE_SHORT_VERSION_STRING = "app.bundle.shortVersionString"
let APP_DEBUG_BUILD_UUID = "app.debug.buildUUID"
let APP_DEBUG_BINARY_NAME = "app.debug.binaryName"
let APP_BUNDLE_EXECUTABLE = "app.bundle.executable"

public func getAppResources() -> [String: String] {
    var result: [String: String] = [:]
    if let version = getVersion() {
        result[APP_BUNDLE_VERSION] = version
    }
    if let shortVersionString = getShortVersionString() {
        result[APP_BUNDLE_SHORT_VERSION_STRING] = shortVersionString
    }
    if let buildUUID = getBuildUUID() {
        result[APP_DEBUG_BUILD_UUID] = buildUUID
        result[APP_DEBUG_BINARY_NAME] = getBinaryName()
    }
    if let executable = getExecutable() {
        result[APP_BUNDLE_EXECUTABLE] = executable
    }
    return result
}

private func getBinaryName() -> String {
    return String(cString: _dyld_get_image_name(0))
}

private func getBuildUUID() -> String? {
    guard let header = _dyld_get_image_header(0) else {
        return nil
    }

    var cursor = UnsafeRawPointer(header)
        .advanced(by: MemoryLayout<mach_header_64>.size)
        .assumingMemoryBound(to: load_command.self)

    for _ in 0..<header.pointee.ncmds {
        if cursor.pointee.cmd == LC_UUID {
            let uuidCmd = UnsafeRawPointer(cursor)
                .assumingMemoryBound(to: uuid_command.self)

            let uuidTuple = uuidCmd.pointee.uuid

            let uuidStr = withUnsafeBytes(of: uuidTuple) { rawPtr -> String in
                let bytes = rawPtr.bindMemory(to: UInt8.self)

                // Format: 8-4-4-4-12
                return String(
                    format:
                        "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                    bytes[0],
                    bytes[1],
                    bytes[2],
                    bytes[3],
                    bytes[4],
                    bytes[5],
                    bytes[6],
                    bytes[7],
                    bytes[8],
                    bytes[9],
                    bytes[10],
                    bytes[11],
                    bytes[12],
                    bytes[13],
                    bytes[14],
                    bytes[15]
                )
            }

            return uuidStr
        }
        cursor = UnsafeRawPointer(cursor)
            .advanced(by: Int(cursor.pointee.cmdsize))
            .assumingMemoryBound(to: load_command.self)
    }

    return nil
}

private func getShortVersionString() -> String? {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
}

private func getVersion() -> String? {
    return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
}

private func getExecutable() -> String? {
    return Bundle.main.infoDictionary?["CFBundleExecutable"] as? String
}
