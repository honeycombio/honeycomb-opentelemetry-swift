import Foundation
import OpenTelemetrySdk
import PersistenceExporter

private enum PersistenceError: Error {
    case obtainCacheLibraryError
}

private func createCachesSubdirectory(_ path: String) throws -> URL {
    guard
        let cachesDirectoryURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first
    else {
        throw PersistenceError.obtainCacheLibraryError
    }

    let subdirectoryURL = cachesDirectoryURL.appendingPathComponent(path, isDirectory: true)

    try FileManager.default.createDirectory(
        at: subdirectoryURL,
        withIntermediateDirectories: true,
        attributes: nil
    )

    return subdirectoryURL
}

func createPersistenceMetricExporter(_ metricExporter: MetricExporter) -> MetricExporter {
    do {
        let metricSubdirectoryURL = try createCachesSubdirectory("honeycomb/metric-cache")
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
        var spanSubdirectoryURL = try createCachesSubdirectory("honeycomb/span-cache")
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
