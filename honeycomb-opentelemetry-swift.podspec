#
# Be sure to run `make cocoapods-tests' to ensure this is a valid spec before submitting.
#
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'honeycomb-opentelemetry-swift'
  s.module_name      = 'Honeycomb'
  s.version          = '0.0.14'
  s.summary          = 'Honeycomb wrapper for [OpenTelemetry](https://opentelemetry.io) on iOS and macOS.'

  s.homepage         = 'https://github.com/honeycombio/honeycomb-opentelemetry-swift'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { '' => '' }
  s.source           = {
    :git => 'https://github.com/honeycombio/honeycomb-opentelemetry-swift.git',
    :tag => s.version.to_s
  }

  s.swift_version = "5.10"
  s.ios.deployment_target = "13.0"
  s.tvos.deployment_target = "13.0"
  s.watchos.deployment_target = "6.0"

  s.source_files = 'Sources/Honeycomb/**/*.swift'

  s.dependency 'OpenTelemetry-Swift-Api', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-Sdk', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-Protocol-Exporter-Common', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-Protocol-Exporter-Http', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-SdkResourceExtension', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-StdoutExporter', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-DataCompression', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-BaggagePropagationProcessor', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-Instrumentation-NetworkStatus', '~> 1.17.1'
  s.dependency 'OpenTelemetry-Swift-PersistenceExporter', '~> 1.17.1'

  s.pod_target_xcconfig = {
    "OTHER_SWIFT_FLAGS" => "-module-name Honeycomb -package-name honeycomb_opentelemetry_swift"
  }
end
