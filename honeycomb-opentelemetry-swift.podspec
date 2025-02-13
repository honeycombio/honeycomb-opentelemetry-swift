#
# Be sure to run `pod lib lint honeycomb-opentelemetry-swift.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'honeycomb-opentelemetry-swift'
  s.version          = '0.1.0'
  s.summary          = 'Honeycomb wrapper for [OpenTelemetry](https://opentelemetry.io) on iOS and macOS.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/honeycombio/honeycomb-opentelemetry-swift'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { '' => '' }
  s.source           = { :git => 'https://github.com/honeycombio/honeycomb-opentelemetry-swift', :tag => s.version.to_s }

  s.ios.deployment_target = "13.0"
  s.tvos.deployment_target = "13.0"
  s.watchos.deployment_target = "6.0"

  s.source_files = 'Sources/Honeycomb/**/*.swift'
  
  # s.resource_bundles = {
  #   'honeycomb-opentelemetry-swift' => ['honeycomb-opentelemetry-swift/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'OpenTelemetry-Swift-Api', '~> 1.13.0'
  s.dependency 'OpenTelemetry-Swift-Sdk', '~> 1.13.0'
  s.dependency 'OpenTelemetry-Swift-Protocol-Exporter-Common', '~> 1.13.0'
  s.dependency 'OpenTelemetry-Swift-Protocol-Exporter-Http', '~> 1.13.0'
  s.dependency 'OpenTelemetry-Swift-SdkResourceExtension', '~> 1.13.0'
  s.dependency 'OpenTelemetry-Swift-StdoutExporter', '~> 1.13.0'
end
