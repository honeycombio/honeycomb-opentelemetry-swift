set -e

SDK=$(xcodebuild -showsdks | grep iphonesimulator | sed -e 's/^.*-sdk //')
echo "SDK: $SDK"

if [[ "$SMOKE_TEST_DESTINATION" != "" ]]; then
    DESTINATION="$SMOKE_TEST_DESTINATION"
else
    # Local default: follow whatever runtime the developer has installed.
    # CI pins explicit versions instead -- see .circleci/config.yml.
    DESTINATION="platform=iOS Simulator,name=iPhone 17,OS=latest"
fi
echo "DESTINATION: $DESTINATION"

xcodebuild test -scheme HoneycombTests -sdk "$SDK" -destination "$DESTINATION"
xcodebuild test -scheme SmokeTest -sdk "$SDK" -destination "$DESTINATION"
