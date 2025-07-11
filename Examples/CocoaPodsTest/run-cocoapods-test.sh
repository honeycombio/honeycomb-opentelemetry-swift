set -e

pod install --repo-update

xcodebuild -showsdks | grep iphonesimulator
SDK=$(xcodebuild -showsdks | grep iphonesimulator | sed -e 's/^.*-sdk //')
echo "SDK: $SDK"

xcodebuild test -workspace CocoaPodsTest.xcworkspace -scheme CocoaPodsTest -sdk "$SDK" -showdestinations
DESTINATION="OS=18.5,name=iPhone 16"
echo "DESTINATION: $DESTINATION"

xcodebuild test -workspace CocoaPodsTest.xcworkspace -scheme CocoaPodsTest -sdk "$SDK" -destination "$DESTINATION" -verbose
