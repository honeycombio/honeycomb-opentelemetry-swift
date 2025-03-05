import Foundation
import OpenTelemetrySdk
import PersistenceExporter

private func createCachesSubdirectory(_ path: String) -> URL? {
    guard
        let cachesDirectoryURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first
    else {
        return nil
    }

    let subdirectoryURL = cachesDirectoryURL.appendingPathComponent(path, isDirectory: true)

    do {
        try FileManager.default.createDirectory(
            at: subdirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    } catch {
        return nil
    }

    return subdirectoryURL
}
var spanSubdirectoryURL = createCachesSubdirectory("honeycomb/span-cache")!
var metricSubdirectoryURL = createCachesSubdirectory("honeycomb/metric-cache")!

func createPersistenceMetricExporter(_ metricExporter: MetricExporter) -> MetricExporter {
    do {
        return try PersistenceMetricExporterDecorator(
            metricExporter: metricExporter,
            storageURL: metricSubdirectoryURL
        )
    } catch {
        print(
            "Could not initialize PersistenceMetricExporter, metrics will not be persisted across network failures: \(error)"
        )
        return metricExporter
    }
}

func createPersistenceSpanExporter(_ spanExporter: SpanExporter) -> SpanExporter {
    do {
        return try PersistenceSpanExporterDecorator(
            spanExporter: spanExporter,
            storageURL: spanSubdirectoryURL
        )
    } catch {
        print(
            "Could not initialize PersistenceSpanExporter, spans will not be persisted across network failures: \(error)"
        )
        return spanExporter
    }
}
