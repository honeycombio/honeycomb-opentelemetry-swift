set -e

# pod lib lint honeycomb-opentelemetry-swift.podspec

SDK=$(xcodebuild -showsdks | grep iphonesimulator | sed -e 's/^.*-sdk //')
echo "SDK: $SDK"

DESTINATION="OS=18.2,name=iPhone 16"

pod install --repo-update
xcodebuild test -workspace CocoaPodsTest.xcworkspace -scheme CocoaPodsTest -sdk "$SDK" -destination "$DESTINATION" -verbose

