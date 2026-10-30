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

if [[ "$SMOKE_UPSTREAM" == "true" ]]; then
    # Passthrough experiment: same app, upstream URLSession and MetricKit instrumentation on.
    # The unit tests do not depend on this switch and already run in the other legs.
    export TEST_RUNNER_SMOKE_UPSTREAM=1
else
    xcodebuild test -scheme HoneycombTests -sdk "$SDK" -destination "$DESTINATION"
fi
xcodebuild test -scheme SmokeTest -sdk "$SDK" -destination "$DESTINATION"
