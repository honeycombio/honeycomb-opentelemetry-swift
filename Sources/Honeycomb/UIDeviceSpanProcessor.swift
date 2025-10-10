#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import OpenTelemetryApi
    import OpenTelemetrySdk
    import UIKit

    public struct UIDeviceSpanProcessor: SpanProcessor {
        public let isStartRequired = true
        public let isEndRequired = false

        public func onStart(
            parentContext: SpanContext?,
            span: any ReadableSpan
        ) {
            let device = UIDevice.current

            // OpenTelemetry semantic conventions
            span.setAttribute(key: "device.manufacturer", value: "Apple")
            span.setAttribute(key: "device.model.name", value: device.model)

            // Additional device attributes
            span.setAttribute(key: "device.name", value: device.name)
            span.setAttribute(key: "device.systemName", value: device.systemName)
            span.setAttribute(key: "device.systemVersion", value: device.systemVersion)
            span.setAttribute(key: "device.model", value: device.model)
            span.setAttribute(key: "device.localizedModel", value: device.localizedModel)
            span.setAttribute(
                key: "device.userInterfaceIdiom",
                value: device.userInterfaceIdiom.description
            )
            span.setAttribute(
                key: "device.isMultitaskingSupported",
                value: device.isMultitaskingSupported
            )

            #if !os(tvOS)
                span.setAttribute(key: "device.orientation", value: device.orientation.description)
                span.setAttribute(
                    key: "device.isBatteryMonitoringEnabled",
                    value: device.isBatteryMonitoringEnabled
                )

                if device.isBatteryMonitoringEnabled {
                    span.setAttribute(
                        key: "device.batteryLevel",
                        value: String(describing: device.batteryLevel)
                    )
                    span.setAttribute(
                        key: "device.batteryState",
                        value: device.batteryState.description
                    )
                }
            #endif

            span.setAttribute(
                key: "device.isLowPowerModeEnabled",
                value: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        }

        public func onEnd(span: any ReadableSpan) {}

        public func shutdown(explicitTimeout: TimeInterval? = nil) {}

        public func forceFlush(timeout: TimeInterval? = nil) {}
    }

    #if !os(tvOS)
        extension UIDeviceOrientation {
            fileprivate var description: String {
                switch self {
                case .faceUp: return "faceUp"
                case .faceDown: return "faceDown"
                case .landscapeLeft: return "landscapeLeft"
                case .landscapeRight: return "landscapeRight"
                case .portrait: return "portrait"
                case .portraitUpsideDown: return "portraitUpsideDown"
                case .unknown: return "unknown"
                @unknown default:
                    return "unknown"
                }
            }
        }

        extension UIDevice.BatteryState {
            fileprivate var description: String {
                switch self {
                case .unknown:
                    return "unknown"
                case .unplugged:
                    return "unplugged"
                case .charging:
                    return "charging"
                case .full:
                    return "full"
                @unknown default:
                    return "unknown"
                }
            }
        }
    #endif

    extension UIUserInterfaceIdiom {
        fileprivate var description: String {
            switch self {
            case .pad:
                return "pad"
            case .phone:
                return "phone"
            case .tv:
                return "tv"
            case .carPlay:
                return "carPlay"
            case .mac: return "mac"
            case .vision: return "vision"
            case .unspecified: return "unspecified"
            @unknown default:
                return "unknown"
            }
        }
    }
#endif
