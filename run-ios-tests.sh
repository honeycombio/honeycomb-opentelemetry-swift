set -e

SDK="iphonesimulator17.5"
DESTINATION="OS=17.5,name=iPhone 15"

xcodebuild test -scheme HoneycombTests -sdk "$SDK" -destination "$DESTINATION"
xcodebuild test -scheme SmokeTest -sdk "$SDK" -destination "$DESTINATION"

