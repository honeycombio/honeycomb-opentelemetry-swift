import Foundation
import MetricKit
import OpenTelemetryApi

class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
  func didReceive(_ payloads: [MXMetricPayload]) {
    for payload in payloads {
      reportMetrics(payload: payload)
    }
  }

  @available(iOS 14.0, *)
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
    AttributeValue.double(self)
  }
}
extension Measurement: AttributeValueConvertable {
  func attributeValue() -> AttributeValue {
    AttributeValue.double(self.value)
  }
}

// MARK: - MetricKit helpers

// TODO: Figure out how to set OTel Metrics as well.

func reportMetrics(payload: MXMetricPayload) {
  // TODO: Use the correct version.
  let version = "0.0.1"

  let tracer = OpenTelemetry.instance.tracerProvider.get(
    instrumentationName: "@honeycombio/instrumentation-metric-kit-metrics",
    instrumentationVersion: version)

  let span = tracer.spanBuilder(spanName: "metric-kit-metrics")
    .setStartTime(time: payload.timeStampBegin)
    .startSpan()
  defer { span.end(time: payload.timeStampEnd) }

  // There are so many nested metrics we want to capture, it's worth setting up some helper
  // methods to reduce the amount of repeated code.

  func captureMetric(key: String, value: AttributeValueConvertable) {
    span.setAttribute(key: key, value: value.attributeValue())
  }

  // Helper functions for sending histograms, specifically.
  func captureMetric<T>(key: String, value histogram: MXHistogram<T>) {
    // Estimate the average value of the whole histogram, and attach that to the span.
    var estimatedSum = 0.0
    var sampleCount = 0.0
    for bucket in histogram.bucketEnumerator {
      let bucket = bucket as! MXHistogramBucket<T>
      let estimatedValue = (bucket.bucketStart + bucket.bucketEnd) / 2.0
      let count = Double(bucket.bucketCount)
      estimatedSum += estimatedValue.value * count
      sampleCount += count
    }
    let estimatedAverage = estimatedSum / sampleCount
    captureMetric(key: key, value: estimatedAverage)
  }

  // This helper makes it easier to process each category without typing its name repeatedly.
  func withCategory<T>(_ parent: T?, using closure: (T) -> Void) {
    if let p = parent {
      closure(p)
    }
  }

  captureMetric(
    key: "includes-multiple-application-versions",
    value: payload.includesMultipleApplicationVersions)
  captureMetric(key: "latest-application-version", value: payload.latestApplicationVersion)
  captureMetric(key: "timestamp-begin", value: payload.timeStampBegin.timeIntervalSince1970)
  captureMetric(key: "timestamp-end", value: payload.timeStampEnd.timeIntervalSince1970)

  withCategory(payload.applicationLaunchMetrics) {
    captureMetric(key: "time-to-first-draw-histogram", value: $0.histogrammedTimeToFirstDraw)
    if #available(iOS 15.2, *) {
      captureMetric(
        key: "optimized-time-to-first-draw-histogram",
        value: $0.histogrammedOptimizedTimeToFirstDraw)
    }
    if #available(iOS 16.0, *) {
      captureMetric(key: "extended-launch-histogram", value: $0.histogrammedExtendedLaunch)
    }
    captureMetric(
      key: "application-resume-time-histogram", value: $0.histogrammedApplicationResumeTime)
  }
  withCategory(payload.applicationResponsivenessMetrics) {
    captureMetric(key: "application-hang-time-histogram", value: $0.histogrammedApplicationHangTime)
  }
  if #available(iOS 14.0, *) {
    withCategory(payload.applicationExitMetrics) {
      captureMetric(
        key: "foreground-cumulative-abnormal-exit-count",
        value: $0.foregroundExitData.cumulativeAbnormalExitCount)
      captureMetric(
        key: "foreground-cumulative-app-watchdog-exit-count",
        value: $0.foregroundExitData.cumulativeAppWatchdogExitCount)
      captureMetric(
        key: "foreground-cumulative-bad-access-exit-count",
        value: $0.foregroundExitData.cumulativeBadAccessExitCount)
      captureMetric(
        key: "foreground-cumulative-illegal-instruction-exit-count",
        value: $0.foregroundExitData.cumulativeIllegalInstructionExitCount)
      captureMetric(
        key: "foreground-cumulative-memory-resource-limit-exit-count",
        value: $0.foregroundExitData.cumulativeMemoryResourceLimitExitCount)
      captureMetric(
        key: "foreground-cumulative-normal-app-exit-count",
        value: $0.foregroundExitData.cumulativeNormalAppExitCount)

      captureMetric(
        key: "background-cumulative-abnormal-exit-count",
        value: $0.backgroundExitData.cumulativeAbnormalExitCount)
      captureMetric(
        key: "background-cumulative-app-watchdog-exit-count",
        value: $0.backgroundExitData.cumulativeAppWatchdogExitCount)
      captureMetric(
        key: "background-cumulative-bad-access-exit-count",
        value: $0.backgroundExitData.cumulativeBadAccessExitCount)
      captureMetric(
        key: "background-cumulative-normal-app-exit-count",
        value: $0.backgroundExitData.cumulativeNormalAppExitCount)
      captureMetric(
        key: "background-cumulative-memory-pressure-exit-count",
        value: $0.backgroundExitData.cumulativeMemoryPressureExitCount)
      captureMetric(
        key: "background-cumulative-illegal-instruction-exit-count",
        value: $0.backgroundExitData.cumulativeIllegalInstructionExitCount)
      captureMetric(
        key: "background-cumulative-cpu-resource-limit-exit-count",
        value: $0.backgroundExitData.cumulativeCPUResourceLimitExitCount)
      captureMetric(
        key: "background-cumulative-memory-resource-limit-exit-count",
        value: $0.backgroundExitData.cumulativeMemoryResourceLimitExitCount)
      captureMetric(
        key: "background-cumulative-suspended-with-locked-file-exit-count",
        value: $0.backgroundExitData.cumulativeSuspendedWithLockedFileExitCount)
      captureMetric(
        key: "background-cumulative-background-task-assertion-timeout-exit-count",
        value: $0.backgroundExitData.cumulativeBackgroundTaskAssertionTimeoutExitCount)
    }
  }
  if #available(iOS 14.0, *) {
    withCategory(payload.animationMetrics) {
      captureMetric(key: "scroll-hitch-time-ratio", value: $0.scrollHitchTimeRatio)
    }
  }
  withCategory(payload.applicationTimeMetrics) {
    captureMetric(
      key: "cumulative-foreground-time",
      value: $0.cumulativeForegroundTime)
    captureMetric(
      key: "cumulative-background-time",
      value: $0.cumulativeBackgroundTime)
    captureMetric(
      key: "cumulative-background-audio-time",
      value: $0.cumulativeBackgroundAudioTime)
    captureMetric(
      key: "cumulative-background-location-time",
      value: $0.cumulativeBackgroundLocationTime)
  }
  withCategory(payload.cellularConditionMetrics) {
    captureMetric(
      key: "cellular-condition-time-histogram",
      value: $0.histogrammedCellularConditionTime)
  }
  withCategory(payload.cpuMetrics) {
    if #available(iOS 14.0, *) {
      captureMetric(key: "cumulative-cpu-instructions", value: $0.cumulativeCPUInstructions)
    }
    captureMetric(key: "cumulative-cpu-time", value: $0.cumulativeCPUTime)
  }
  withCategory(payload.gpuMetrics) {
    captureMetric(key: "cumulative-gpu-time", value: $0.cumulativeGPUTime)
  }
  withCategory(payload.diskIOMetrics) {
    captureMetric(key: "cumulative-logical-writes", value: $0.cumulativeLogicalWrites)
  }
  // Display metrics *only* has pixel luminance, and it's an MXAverage value.
  withCategory(payload.displayMetrics?.averagePixelLuminance) {
    captureMetric(key: "average-pixel-luminance", value: $0.averageMeasurement)
    captureMetric(key: "average-pixel-luminance-stddev", value: $0.standardDeviation)
    captureMetric(key: "average-pixel-luminance-sample-count", value: $0.sampleCount)
  }

  // Signpost metrics are a little different from the other metrics, since they can have arbitrary names.
  if let signpostMetrics = payload.signpostMetrics {
    for signpostMetric in signpostMetrics {
      let span = tracer.spanBuilder(spanName: "signpost-metric").startSpan()
      span.setAttribute(key: "name", value: signpostMetric.signpostName)
      span.setAttribute(key: "category", value: signpostMetric.signpostCategory)
      span.setAttribute(key: "count", value: signpostMetric.totalCount)
      span.end()
    }
  }
}

@available(iOS 14.0, *)
func reportDiagnostics(payload: MXDiagnosticPayload) {
  // TODO: Use the correct version.
  let version = "0.0.1"

  let tracer = OpenTelemetry.instance.tracerProvider.get(
    instrumentationName: "@honeycombio/instrumentation-metric-kit-diagnostics",
    instrumentationVersion: version)

  let span = tracer.spanBuilder(spanName: "metric-kit-diagnostics")
    .setStartTime(time: payload.timeStampBegin)
    .startSpan()
  defer { span.end() }

  let logger = OpenTelemetry.instance.loggerProvider.get(
    instrumentationScopeName: "@honeycombio/instrumentation-metric-kit-diagnostics")

  let now = Date()

  // A helper for looping over the items in an optional list and logging each one.
  func logForEach<T>(_ parent: [T]?, using closure: (T) -> [String: AttributeValueConvertable]) {
    if let arr = parent {
      for item in arr {
        let attributes = closure(item).mapValues { $0.attributeValue() }

        logger.logRecordBuilder()
          .setTimestamp(payload.timeStampEnd)
          .setObservedTimestamp(now)
          .setAttributes(attributes)
          .emit()
      }
    }
  }

  if #available(iOS 16.0, *) {
    logForEach(payload.appLaunchDiagnostics) {
      ["name": "app-launch", "launch-duration": $0.launchDuration.value]
    }
  }
  logForEach(payload.diskWriteExceptionDiagnostics) {
    ["name": "disk-write-exception", "total-writes-caused": $0.totalWritesCaused.value]
  }
  logForEach(payload.hangDiagnostics) {
    ["name": "hang", "hang-duration": $0.hangDuration.value]
  }
  logForEach(payload.cpuExceptionDiagnostics) {
    [
      "name": "cpu-exception",
      "total-cpu-time": $0.totalCPUTime,
      "total-sampled-time": $0.totalSampledTime.value,
    ]
  }
  logForEach(payload.crashDiagnostics) {
    var attrs: [String: AttributeValueConvertable] = ["name": "crash"]
    if let exceptionCode = $0.exceptionCode {
      attrs["exception-code"] = exceptionCode.intValue
    }
    if let exceptionType = $0.exceptionType {
      // Include the original field, but also the semantic convention otel equivalent.
      attrs["exception-type"] = exceptionType.intValue
      attrs["exception.type"] = "\(exceptionType.intValue)"
    }
    if let signal = $0.signal {
      attrs["signal"] = signal.intValue
    }
    if let terminationReason = $0.terminationReason {
      attrs["termination-reason"] = terminationReason
    }
    if #available(iOS 17.0, *) {
      if let exceptionReason = $0.exceptionReason {
        attrs["exception.type"] = exceptionReason.exceptionType
        attrs["exception.message"] = exceptionReason.composedMessage

        attrs["exception-reason-class-name"] = exceptionReason.className
        attrs["exception-reason-composed-message"] = exceptionReason.composedMessage
        attrs["exception-reason-exception-name"] = exceptionReason.exceptionName
        attrs["exception-reason-exception-type"] = exceptionReason.exceptionType
      }
    }
    return attrs
  }
}
