set -e

SDK=$(xcodebuild -showsdks | grep iphonesimulator | sed -e 's/^.*-sdk //')
echo "SDK: $SDK"

DESTINATION="OS=17.5,name=iPhone 15"

xcodebuild test -scheme HoneycombTests -sdk "$SDK" -destination "$DESTINATION"
xcodebuild test -scheme SmokeTest -sdk "$SDK" -destination "$DESTINATION"

