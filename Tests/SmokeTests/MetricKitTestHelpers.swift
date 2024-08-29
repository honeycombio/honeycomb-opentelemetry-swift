import Foundation
import MetricKit

@testable import Honeycomb

class FakeMetricPayload: MXMetricPayload {
  private let now = Date()
  
  override init() {
    super.init()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override var latestApplicationVersion: String { "3.14.159" }
  
  override var includesMultipleApplicationVersions: Bool { false }

  override var timeStampBegin: Date {
    // MetricKit generally reports data from the previous day.
    now.advanced(by: TimeInterval(-1 * 60 * 60 * 24))
  }

  override var timeStampEnd: Date { now }

  override var cpuMetrics: MXCPUMetric? { get }

  override var gpuMetrics: MXGPUMetric? { get }

  override var cellularConditionMetrics: MXCellularConditionMetric? { get }

  override var applicationTimeMetrics: MXAppRunTimeMetric? { get }

  override var locationActivityMetrics: MXLocationActivityMetric? { get }

  override var networkTransferMetrics: MXNetworkTransferMetric? { get }

  override var applicationLaunchMetrics: MXAppLaunchMetric? { get }

  override var applicationResponsivenessMetrics: MXAppResponsivenessMetric? { get }

  override var diskIOMetrics: MXDiskIOMetric? { get }

  override var memoryMetrics: MXMemoryMetric? { get }

  override var displayMetrics: MXDisplayMetric? { get }

  @available(iOS 14.0, *)
  override var animationMetrics: MXAnimationMetric? { get }

  @available(iOS 14.0, *)
  override var applicationExitMetrics: MXAppExitMetric? { get }

  override var signpostMetrics: [MXSignpostMetric]? { get }

  override var metaData: MXMetaData? { get }
}

func makeFakeMetricPayload() -> MXMetricPayload {
  FakeMetricPayload()
}
