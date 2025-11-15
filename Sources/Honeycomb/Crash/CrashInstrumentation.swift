
import CrashReporter
import OpenTelemetryApi
import Foundation

// MARK: - JSON Crash Report Format

/// Represents a stack frame in the OpenTelemetry crash report format
private struct StackFrame: Codable {
    let binaryName: String?
    let binaryUUID: String?
    let offsetAddress: Int?
}

/// Represents a call stack for a single thread
private struct CallStack: Codable {
    let threadAttributed: Bool?
    let callStackFrames: [StackFrame]
}

/// Root structure for the OpenTelemetry crash report JSON
private struct StackTraceReport: Codable {
    let callStackPerThread: Bool
    let callStacks: [CallStack]
}

// MARK: - Helper Functions

func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    var size = MemoryLayout.stride(ofValue: info)
    let sysctlResult = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

    guard sysctlResult == 0 else {
        print("sysctl failed: \(String(describing: strerror(errno)))")
        return false
    }

    // Check the P_TRACED flag in the process status
    return (info.kp_proc.p_flag & P_TRACED) != 0
}

/// Builds a JSON crash report from a PLCrashReport following the OpenTelemetry stack trace format
private func buildCrashReportJSON(from crash: PLCrashReport) -> String? {
    guard let threads = crash.threads as? [PLCrashReportThreadInfo] else {
        return nil
    }

    var callStacks: [CallStack] = []

    // Process each thread
    for thread in threads {
        guard let stackFrames = thread.stackFrames as? [PLCrashReportStackFrameInfo] else {
            continue
        }

        var frames: [StackFrame] = []

        // Process each frame in the thread
        for frameInfo in stackFrames {
            let instructionPointer = frameInfo.instructionPointer

            // Look up the binary image containing this address
            let image = crash.image(forAddress: instructionPointer)

            // Extract available information
            let binaryName = image.map { URL(fileURLWithPath: $0.imageName).lastPathComponent }
            let binaryUUID = image?.imageUUID
            let offsetAddress = image.map { Int(instructionPointer - $0.imageBaseAddress) }

            let frame = StackFrame(
                binaryName: binaryName,
                binaryUUID: binaryUUID,
                offsetAddress: offsetAddress
            )
            frames.append(frame)
        }

        // Only include threads that have frames
        if !frames.isEmpty {
            let callStack = CallStack(
                threadAttributed: thread.crashed ? true : nil,
                callStackFrames: frames
            )
            callStacks.append(callStack)
        }
    }

    // Build the complete report
    let report = StackTraceReport(
        callStackPerThread: false,
        callStacks: callStacks
    )

    // Encode to JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    guard let jsonData = try? encoder.encode(report) else {
        return nil
    }

    return String(data: jsonData, encoding: .utf8)
}

private func log(
    crash: PLCrashReport,
    attributes: [String: AttributeValue] = [:],
    thread: Thread?,
    severity: Severity = .error,
    logger: OpenTelemetryApi.Logger = Honeycomb.getDefaultErrorLogger()
) {
    let timestamp = Date()
    var errorAttributes: [String:AttributeValue] = [:]

    if let machExceptionInfo = crash.machExceptionInfo {
        let type = String(cString: strsignal(Int32(machExceptionInfo.type)))
        errorAttributes[SemanticAttributes.exceptionType.rawValue] = type.attributeValue()
    }
    
    // Exception
    if crash.hasExceptionInfo {
        let type: String = crash.exceptionInfo.exceptionName
        let message: String = crash.exceptionInfo.exceptionReason

        errorAttributes[SemanticAttributes.exceptionType.rawValue] = type.attributeValue()
        errorAttributes[SemanticAttributes.exceptionMessage.rawValue] = message.attributeValue()
    }

    // Generate JSON crash report with all threads
    if let crashReportJSON = buildCrashReportJSON(from: crash) {
        errorAttributes[SemanticAttributes.exceptionStacktrace.rawValue] = crashReportJSON.attributeValue()
    }
    
    // Signal
    // Objective C Exception

    // TODO: Do this more better?
    if let name = thread?.name {
        errorAttributes["thread.name"] = name.attributeValue()
    }

    if let text = PLCrashReportTextFormatter.stringValue(for: crash, with: PLCrashReportTextFormatiOS) {
        errorAttributes["plcrashreporter.text"] = text.attributeValue()
    }

    // TODO: Figure out how to include sessionID.
    
    errorAttributes = errorAttributes.merging(attributes, uniquingKeysWith: { (_, last) in last })

    Honeycomb.logError(errorAttributes, .fatal, logger, timestamp)
}


func installCrashInstrumentation() {
    let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: [])
    guard let crashReporter = PLCrashReporter(configuration: config) else {
        print("Could not create an instance of PLCrashReporter")
        return
    }
    
    // TODO: Is this the right place to do this?
    if !isDebuggerAttached() {
        do {
            try crashReporter.enableAndReturnError()
        } catch let error {
            print("Warning: Could not enable crash reporter: \(error)")
        }
    } else {
        print("Skipping install of crash signal handler, as app is running in debugger.")
    }
    
    // TODO: Should this be done async?
    // Try loading the crash report.
    if crashReporter.hasPendingCrashReport() {
        do {
            let data = try crashReporter.loadPendingCrashReportDataAndReturnError()

            // Retrieving crash reporter data.
            let report = try PLCrashReport(data: data)

            // We could send the report from here, but we'll just print out some debugging info instead.
            /*
            if let text = PLCrashReportTextFormatter.stringValue(for: report, with: PLCrashReportTextFormatiOS) {
                print(text)
            } else {
                print("CrashReporter: can't convert report to text")
            }
            */
            
            // TODO: Infer the thread from the report.
            log(crash: report, thread: nil, severity: .fatal)
        } catch let error {
            print("CrashReporter failed to load and parse with error: \(error)")
        }
    }

    // Purge the report.
    crashReporter.purgePendingCrashReport()
}
