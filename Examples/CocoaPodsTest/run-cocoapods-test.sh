set -e

pod lib lint --allow-warnings ../../honeycomb-opentelemetry-swift.podspec

xcodebuild -showsdks | grep iphonesimulator
SDK=$(xcodebuild -showsdks | grep iphonesimulator | sed -e 's/^.*-sdk //')
echo "SDK: $SDK"

DESTINATION="OS=18.2,name=iPhone 16"

pod install --repo-update
xcodebuild test -workspace CocoaPodsTest.xcworkspace -scheme CocoaPodsTest -sdk "$SDK" -showdestinations
xcodebuild test -workspace CocoaPodsTest.xcworkspace -scheme CocoaPodsTest -sdk "$SDK" -destination "$DESTINATION" -verbose

