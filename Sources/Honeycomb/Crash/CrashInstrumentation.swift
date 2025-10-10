
import CrashReporter
import OpenTelemetryApi

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

        if let stackFrames = crash.exceptionInfo.stackFrames {
            let frames = stackFrames.map { frame in
                let frame = frame as! PLCrashReportStackFrameInfo
                let instructionPointer = frame.instructionPointer
                if let symbolName = frame.symbolInfo.symbolName {
                    return String(format: "%x %s")
                } else {
                    return String(format: "%x")
                }
            }
            errorAttributes[SemanticAttributes.exceptionStacktrace.rawValue] = frames.joined(separator: "\n").attributeValue()
        }
    }

    if crash.hasProcessInfo {
    }

    // crash.applicationInfo

    // TODO: Do something useful with this.
    // TODO: Consider image(forAddress)?
    if let crashImages = crash.images {
        let images = crashImages.map { image in
            let image = image as! PLCrashReportBinaryImageInfo
            if let uuid = image.imageUUID {
                return uuid
            } else {
                return ""
            }
        }
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
