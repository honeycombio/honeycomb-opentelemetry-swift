import Foundation
import MetricKit
import OpenTelemetryApi

private let metricKitInstrumentationName = "@honeycombio/instrumentation-metric-kit"

@available(iOS 13.0, macOS 12.0, *)
class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    #if os(iOS)
        func didReceive(_ payloads: [MXMetricPayload]) {
            for payload in payloads {
                reportMetrics(payload: payload)
            }
        }
    #endif

    @available(iOS 14.0, macOS 12.0, *)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            reportDiagnostics(payload: payload)
        }
    }
}

// MARK: - AttributeValue helpers

/// A protocol to make it easier to write generic functions for AttributeValues.
protocol AttributeValueConvertable {
    func attributeValue() -> AttributeValue
}

extension Int: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        AttributeValue.int(self)
    }
}
extension Bool: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        AttributeValue.bool(self)
    }
}
extension String: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        AttributeValue.string(self)
    }
}
extension TimeInterval: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        // The OTel standard for time durations is seconds, which is also what TimeInterval is.
        // https://opentelemetry.io/docs/specs/semconv/general/metrics/
        AttributeValue.double(self)
    }
}
extension Measurement: AttributeValueConvertable {
    func attributeValue() -> AttributeValue {
        // Convert to the "base unit", such as seconds or bytes.
        let value =
            if let unit = self.unit as? Dimension {
                unit.converter.baseUnitValue(fromValue: self.value)
            } else {
                self.value
            }
        return AttributeValue.double(value)
    }
}

// MARK: - MetricKit helpers

// TODO: Figure out how to set OTel Metrics as well.

func getMetricKitTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: metricKitInstrumentationName,
        instrumentationVersion: honeycombLibraryVersion
    )
}

/// Estimates the average value of the whole histogram.
@available(iOS 13.0, macOS 12.0, *)
func estimateHistogramAverage<UnitType>(_ histogram: MXHistogram<UnitType>) -> Measurement<
    UnitType
>? {
    var estimatedSum: Measurement<UnitType>?
    var sampleCount = 0.0
    for bucket in histogram.bucketEnumerator {
        let bucket = bucket as! MXHistogramBucket<UnitType>
        let estimatedValue = (bucket.bucketStart + bucket.bucketEnd) / 2.0
        let count = Double(bucket.bucketCount)
        estimatedSum =
            if let previousSum = estimatedSum {
                previousSum + estimatedValue * count
            } else {
                estimatedValue * count
            }
        sampleCount += count
    }
    return estimatedSum.map { $0 / sampleCount }
}

#if os(iOS)
    func reportMetrics(payload: MXMetricPayload) {
        let span = getMetricKitTracer().spanBuilder(spanName: "MXMetricPayload")
            .setStartTime(time: payload.timeStampBegin)
            .startSpan()
        defer { span.end(time: payload.timeStampEnd) }

        // There are so many nested metrics we want to capture, it's worth setting up some helper
        // methods to reduce the amount of repeated code.

        var namespaceStack = ["metrickit"]

        func captureMetric(key: String, value: AttributeValueConvertable) {
            let namespace = namespaceStack.joined(separator: ".")
            span.setAttribute(key: "\(namespace).\(key)", value: value.attributeValue())
        }

        // Helper functions for sending histograms, specifically.
        func captureMetric<UnitType>(key: String, value histogram: MXHistogram<UnitType>) {
            if let average = estimateHistogramAverage(histogram) {
                captureMetric(key: key, value: average)
            }
        }

        // This helper makes it easier to process each category without typing its name repeatedly.
        func withCategory<T>(_ parent: T?, _ namespace: String, using closure: (T) -> Void) {
            namespaceStack.append(namespace)
            if let p = parent {
                closure(p)
            }
            namespaceStack.removeLast()
        }

        // These attribute names follow the guidelines at
        // https://opentelemetry.io/docs/specs/semconv/general/attribute-naming/

        captureMetric(
            key: "includes_multiple_application_versions",
            value: payload.includesMultipleApplicationVersions
        )
        captureMetric(key: "latest_application_version", value: payload.latestApplicationVersion)
        captureMetric(key: "timestamp_begin", value: payload.timeStampBegin.timeIntervalSince1970)
        captureMetric(key: "timestamp_end", value: payload.timeStampEnd.timeIntervalSince1970)

        withCategory(payload.metaData, "metadata") {
            captureMetric(key: "app_build_version", value: $0.applicationBuildVersion)
            captureMetric(key: "device_type", value: $0.deviceType)
            captureMetric(key: "os_version", value: $0.osVersion)
            captureMetric(key: "region_format", value: $0.regionFormat)
            if #available(iOS 14.0, *) {
                captureMetric(key: "platform_arch", value: $0.platformArchitecture)
            }
            if #available(iOS 17.0, *) {
                captureMetric(key: "is_test_flight_app", value: $0.isTestFlightApp)
                captureMetric(key: "low_power_mode_enabled", value: $0.lowPowerModeEnabled)
                captureMetric(key: "pid", value: Int($0.pid))
            }
        }
        withCategory(payload.applicationLaunchMetrics, "app_launch") {
            captureMetric(key: "time_to_first_draw_average", value: $0.histogrammedTimeToFirstDraw)
            captureMetric(
                key: "app_resume_time_average",
                value: $0.histogrammedApplicationResumeTime
            )
            if #available(iOS 15.2, *) {
                captureMetric(
                    key: "optimized_time_to_first_draw_average",
                    value: $0.histogrammedOptimizedTimeToFirstDraw
                )
            }
            if #available(iOS 16.0, *) {
                captureMetric(key: "extended_launch_average", value: $0.histogrammedExtendedLaunch)
            }
        }
        withCategory(payload.applicationResponsivenessMetrics, "app_responsiveness") {
            captureMetric(key: "hang_time_average", value: $0.histogrammedApplicationHangTime)
        }
        withCategory(payload.cellularConditionMetrics, "cellular_condition") {
            captureMetric(key: "bars_average", value: $0.histogrammedCellularConditionTime)
        }
        withCategory(payload.locationActivityMetrics, "location_activity") {
            captureMetric(key: "best_accuracy_time", value: $0.cumulativeBestAccuracyTime)
            captureMetric(
                key: "best_accuracy_for_nav_time",
                value: $0.cumulativeBestAccuracyForNavigationTime
            )
            captureMetric(
                key: "accuracy_10m_time",
                value: $0.cumulativeNearestTenMetersAccuracyTime
            )
            captureMetric(key: "accuracy_100m_time", value: $0.cumulativeHundredMetersAccuracyTime)
            captureMetric(key: "accuracy_1km_time", value: $0.cumulativeKilometerAccuracyTime)
            captureMetric(key: "accuracy_3km_time", value: $0.cumulativeThreeKilometersAccuracyTime)
        }
        withCategory(payload.networkTransferMetrics, "network_transfer") {
            captureMetric(key: "cellular_download", value: $0.cumulativeCellularDownload)
            captureMetric(key: "cellular_upload", value: $0.cumulativeCellularUpload)
            captureMetric(key: "wifi_download", value: $0.cumulativeWifiDownload)
            captureMetric(key: "wifi_upload", value: $0.cumulativeWifiUpload)
        }
        if #available(iOS 14.0, *) {
            withCategory(payload.applicationExitMetrics, "app_exit") {
                withCategory($0.foregroundExitData, "foreground") {
                    captureMetric(
                        key: "abnormal_exit_count",
                        value: $0.cumulativeAbnormalExitCount
                    )
                    captureMetric(
                        key: "app_watchdog_exit_count",
                        value: $0.cumulativeAppWatchdogExitCount
                    )
                    captureMetric(
                        key: "bad_access_exit_count",
                        value: $0.cumulativeBadAccessExitCount
                    )
                    captureMetric(
                        key: "illegal_instruction_exit_count",
                        value: $0.cumulativeIllegalInstructionExitCount
                    )
                    captureMetric(
                        key: "memory_resource_limit_exit-count",
                        value: $0.cumulativeMemoryResourceLimitExitCount
                    )
                    captureMetric(
                        key: "normal_app_exit_count",
                        value: $0.cumulativeNormalAppExitCount
                    )
                }

                withCategory($0.backgroundExitData, "background") {
                    captureMetric(
                        key: "abnormal_exit_count",
                        value: $0.cumulativeAbnormalExitCount
                    )
                    captureMetric(
                        key: "app_watchdog_exit_count",
                        value: $0.cumulativeAppWatchdogExitCount
                    )
                    captureMetric(
                        key: "bad_access-exit_count",
                        value: $0.cumulativeBadAccessExitCount
                    )
                    captureMetric(
                        key: "normal_app_exit_count",
                        value: $0.cumulativeNormalAppExitCount
                    )
                    captureMetric(
                        key: "memory_pressure_exit_count",
                        value: $0.cumulativeMemoryPressureExitCount
                    )
                    captureMetric(
                        key: "illegal_instruction_exit_count",
                        value: $0.cumulativeIllegalInstructionExitCount
                    )
                    captureMetric(
                        key: "cpu_resource_limit_exit_count",
                        value: $0.cumulativeCPUResourceLimitExitCount
                    )
                    captureMetric(
                        key: "memory_resource_limit_exit_count",
                        value: $0.cumulativeMemoryResourceLimitExitCount
                    )
                    captureMetric(
                        key: "suspended_with_locked_file_exit_count",
                        value: $0.cumulativeSuspendedWithLockedFileExitCount
                    )
                    captureMetric(
                        key: "background_task_assertion_timeout_exit_count",
                        value: $0.cumulativeBackgroundTaskAssertionTimeoutExitCount
                    )
                }
            }
        }
        if #available(iOS 14.0, *) {
            withCategory(payload.animationMetrics, "animation") {
                captureMetric(key: "scroll_hitch_time_ratio", value: $0.scrollHitchTimeRatio)
            }
        }
        withCategory(payload.applicationTimeMetrics, "app_time") {
            captureMetric(
                key: "foreground_time",
                value: $0.cumulativeForegroundTime
            )
            captureMetric(
                key: "background_time",
                value: $0.cumulativeBackgroundTime
            )
            captureMetric(
                key: "background_audio_time",
                value: $0.cumulativeBackgroundAudioTime
            )
            captureMetric(
                key: "background_location_time",
                value: $0.cumulativeBackgroundLocationTime
            )
        }
        withCategory(payload.cellularConditionMetrics, "cellular_condition") {
            captureMetric(
                key: "cellular_condition_time_average",
                value: $0.histogrammedCellularConditionTime
            )
        }
        withCategory(payload.cpuMetrics, "cpu") {
            if #available(iOS 14.0, *) {
                captureMetric(key: "instruction_count", value: $0.cumulativeCPUInstructions)
            }
            captureMetric(key: "cpu_time", value: $0.cumulativeCPUTime)
        }
        withCategory(payload.gpuMetrics, "gpu") {
            captureMetric(key: "time", value: $0.cumulativeGPUTime)
        }
        withCategory(payload.diskIOMetrics, "diskio") {
            captureMetric(key: "logical_write_count", value: $0.cumulativeLogicalWrites)
        }
        withCategory(payload.memoryMetrics, "memory") {
            captureMetric(key: "peak_memory_usage", value: $0.peakMemoryUsage)
            captureMetric(
                key: "suspended_memory_average",
                value: $0.averageSuspendedMemory.averageMeasurement
            )
        }
        // Display metrics *only* has pixel luminance, and it's an MXAverage value.
        withCategory(payload.displayMetrics, "display") {
            if let averagePixelLuminance = $0.averagePixelLuminance {
                captureMetric(
                    key: "pixel_luminance_average",
                    value: averagePixelLuminance.averageMeasurement
                )
            }
        }

        // Signpost metrics are a little different from the other metrics, since they can have arbitrary names.
        if let signpostMetrics = payload.signpostMetrics {
            for signpostMetric in signpostMetrics {
                let span = getMetricKitTracer().spanBuilder(spanName: "MXSignpostMetric")
                    .startSpan()
                span.setAttribute(key: "signpost.name", value: signpostMetric.signpostName)
                span.setAttribute(key: "signpost.category", value: signpostMetric.signpostCategory)
                span.setAttribute(key: "signpost.count", value: signpostMetric.totalCount)
                if let intervalData = signpostMetric.signpostIntervalData {
                    if let cpuTime = intervalData.cumulativeCPUTime {
                        span.setAttribute(
                            key: "signpost.cpu_time",
                            value: cpuTime.attributeValue()
                        )
                    }
                    if let memoryAverage = intervalData.averageMemory {
                        span.setAttribute(
                            key: "signpost.memory_average",
                            value: memoryAverage.averageMeasurement.attributeValue()
                        )
                    }
                    if let logicalWriteCount = intervalData.cumulativeLogicalWrites {
                        span.setAttribute(
                            key: "signpost.logical_write_count",
                            value: logicalWriteCount.attributeValue()
                        )
                    }
                    if #available(iOS 15.0, *) {
                        if let hitchTimeRatio = intervalData.cumulativeHitchTimeRatio {
                            span.setAttribute(
                                key: "signpost.hitch_time_ratio",
                                value: hitchTimeRatio.attributeValue()
                            )
                        }
                    }
                }
                span.end()
            }
        }
    }
#endif

@available(iOS 14.0, macOS 12.0, *)
func reportDiagnostics(payload: MXDiagnosticPayload) {
    let span = getMetricKitTracer().spanBuilder(spanName: "MXDiagnosticPayload")
        .setStartTime(time: payload.timeStampBegin)
        .startSpan()
    defer { span.end() }

    let logger = OpenTelemetry.instance.loggerProvider.get(
        instrumentationScopeName: metricKitInstrumentationName
    )

    let now = Date()

    // A helper for looping over the items in an optional list and logging each one.
    func logForEach<T>(
        _ parent: [T]?,
        _ namespace: String,
        using closure: (T) -> [String: AttributeValueConvertable]
    ) {
        if let arr = parent {
            for item in arr {
                var attributes: [String: AttributeValue] = [
                    "name": "metrickit.diagnostic.\(namespace)".attributeValue()
                ]
                for (key, value) in closure(item) {
                    let namespacedKey = "metrickit.diagnostic.\(namespace).\(key)"
                    attributes[namespacedKey] = value.attributeValue()
                }
                logger.logRecordBuilder()
                    .setTimestamp(payload.timeStampEnd)
                    .setObservedTimestamp(now)
                    .setAttributes(attributes)
                    .emit()
            }
        }
    }

    #if os(iS)
        if #available(iOS 16.0, *) {
            logForEach(payload.appLaunchDiagnostics, "app_launch") {
                [
                    "launch_duration": $0.launchDuration
                ]
            }
        }
    #endif
    logForEach(payload.diskWriteExceptionDiagnostics, "disk_write_exception") {
        [
            "total_writes_caused": $0.totalWritesCaused
        ]
    }
    logForEach(payload.hangDiagnostics, "hang") {
        [
            "hang_duration": $0.hangDuration
        ]
    }
    logForEach(payload.cpuExceptionDiagnostics, "cpu_exception") {
        [
            "total_cpu_time": $0.totalCPUTime,
            "total_sampled_time": $0.totalSampledTime,
        ]
    }
    logForEach(payload.crashDiagnostics, "crash") {
        var attrs: [String: AttributeValueConvertable] = [:]
        if let exceptionCode = $0.exceptionCode {
            attrs["exception.code"] = exceptionCode.intValue
        }
        if let exceptionType = $0.exceptionType {
            attrs["exception.mach_execution_type"] = exceptionType.intValue
        }
        if let signal = $0.signal {
            attrs["exception.signal"] = signal.intValue
        }
        if let terminationReason = $0.terminationReason {
            attrs["exception.termination_reason"] = terminationReason
        }
        if #available(iOS 17.0, macOS 14.0, *) {
            if let exceptionReason = $0.exceptionReason {
                attrs["exception.objc.type"] = exceptionReason.exceptionType
                attrs["exception.objc.message"] = exceptionReason.composedMessage
                attrs["exception.objc.classname"] = exceptionReason.className
                attrs["exception.objc.name"] = exceptionReason.exceptionName
            }
        }
        return attrs
    }
}
