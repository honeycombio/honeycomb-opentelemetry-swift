set -e

SDK="iphonesimulator17.5"
DESTINATION="OS=17.5,name=iPhone 15"

xcodebuild test -scheme honeycomb-opentelemetry-swift -sdk "$SDK" -destination "$DESTINATION"

