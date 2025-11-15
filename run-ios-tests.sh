set -e

SDK=$(xcodebuild -showsdks | grep iphonesimulator | sed -e 's/^.*-sdk //')
echo "SDK: $SDK"

if [[ "$SMOKE_TEST_DESTINATION" != "" ]]; then
    DESTINATION="$SMOKE_TEST_DESTINATION"
else
    DESTINATION="OS=17.5,name=iPhone 15"
fi
echo "DESTINATION: $DESTINATION"

xcodebuild test -scheme HoneycombTests -sdk "$SDK" -destination "$DESTINATION"
xcodebuild test -scheme SmokeTest -sdk "$SDK" -destination "$DESTINATION"
