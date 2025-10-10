#!/usr/bin/env bats

export LC_ALL=C

load test_helpers/utilities

CONTAINER_NAME="ios-test"
SMOKE_TEST_SCOPE="io.honeycomb.smoke-test"

setup_file() {
  echo "# 🚧 preparing test" >&3
}
teardown_file() {
  cp collector/data.json collector/data-results/data-${CONTAINER_NAME}.json
}

@test "SDK can send spans" {
  result=$(span_names_for ${SMOKE_TEST_SCOPE})
  assert_equal "$result" '"test-span"'
}

@test "SDK can emits session.id" {
  name="test-span"
  attr_name="session.id"
  type="string"
  result=$(attribute_for_span_key $SMOKE_TEST_SCOPE $name $attr_name $type | sort)
  assert_not_empty "$result"
}

@test "SDK has default resources" {
  assert_equal "$(resource_attributes_received | jq 'select (.key == "telemetry.sdk.language").value.stringValue' | uniq)" '"swift"'
  assert_equal "$(resource_attributes_received | jq 'select (.key == "service.name").value.stringValue' | uniq)" '"ios-test"'
  assert_equal "$(resource_attributes_received | jq 'select (.key == "service.version").value.stringValue' | uniq)" '"0.0.1"'
  assert_equal "$(resource_attributes_received | jq 'select (.key == "device.model.identifier").value.stringValue' | uniq)" '"arm64"'
  assert_not_empty "$(resource_attributes_received | jq 'select (.key == "device.id").value.stringValue' | uniq)"
  assert_equal "$(resource_attributes_received | jq 'select (.key == "os.type").value.stringValue' | uniq)" '"darwin"'
  assert_equal "$(resource_attributes_received | jq 'select (.key == "os.description").value.stringValue' | uniq)" '"iOS Version 17.5 (Build 21F79)"'
  assert_equal "$(resource_attributes_received | jq 'select (.key == "os.name").value.stringValue' | uniq)" '"iOS"'
  assert_equal "$(resource_attributes_received | jq 'select (.key == "os.version").value.stringValue' | uniq)" '"17.5.0"'
}

@test "Spans have network attributes" {
  name="test-span"
  attr_name="network.connection.type"
  type="string"
  result=$(attribute_for_span_key $SMOKE_TEST_SCOPE $name $attr_name $type | sort)
  assert_not_empty "$result"
}

@test "Spans have device semantic convention attributes" {
  name="test-span"

  # device.manufacturer should be hardcoded to "Apple"
  result=$(attribute_for_span_key $SMOKE_TEST_SCOPE $name "device.manufacturer" string)
  assert_equal "$result" '"Apple"'

  # device.model.name should be present
  result=$(attribute_for_span_key $SMOKE_TEST_SCOPE $name "device.model.name" string)
  assert_not_empty "$result"
}

@test "SDK sends correct resource attributes" {
  result=$(resource_attributes_received | jq ".key" | sort | uniq)
  assert_equal "$result" '"app.bundle.executable"
"app.bundle.shortVersionString"
"app.bundle.version"
"app.debug.binaryName"
"app.debug.build_uuid"
"device.id"
"device.model.identifier"
"honeycomb.distro.runtime_version"
"honeycomb.distro.version"
"os.description"
"os.name"
"os.type"
"os.version"
"service.name"
"service.version"
"telemetry.distro.name"
"telemetry.distro.version"
"telemetry.sdk.language"
"telemetry.sdk.name"
"telemetry.sdk.version"'

  result=$(resource_attribute_named "telemetry.sdk.language" "string" | uniq)
  assert_equal "$result" '"swift"'

  assert_equal $(resource_attribute_named "service.name" "string" | uniq) '"ios-test"'
  assert_equal $(resource_attribute_named "service.version" "string" | uniq) '"0.0.1"'
}

# A helper just for MetricKit attributes, because there's so many of them.
# Arguments:
#   $1 - attribute key
#   $2 - attribute type
mk_attr() {
  scope="io.honeycomb.metrickit"
  span="MXMetricPayload"
  attribute_for_span_key $scope $span $1 $2
}

@test "MetricKit values are present and units are converted" {
  assert_equal "$(mk_attr "metrickit.includes_multiple_application_versions" bool)" false
  assert_equal "$(mk_attr "metrickit.latest_application_version" string)" '"3.14.159"'
  assert_equal "$(mk_attr "metrickit.cpu.cpu_time" double)" 1
  assert_equal "$(mk_attr "metrickit.cpu.instruction_count" double)" 2
  assert_equal "$(mk_attr "metrickit.gpu.time" double)" 10800  # 3 hours
  assert_equal "$(mk_attr "metrickit.cellular_condition.bars_average" double)" 4
  assert_equal "$(mk_attr "metrickit.app_time.foreground_time" double)" 300          # 5 minutes
  assert_equal "$(mk_attr "metrickit.app_time.background_time" double)" 0.000006     # 6 microseconds
  assert_equal "$(mk_attr "metrickit.app_time.background_audio_time" double)" 0.007  # 7 milliseconds
  assert_equal "$(mk_attr "metrickit.app_time.background_location_time" double)" 480 # 8 minutes
  assert_equal "$(mk_attr "metrickit.location_activity.best_accuracy_time" double)" 9
  assert_equal "$(mk_attr "metrickit.location_activity.best_accuracy_for_nav_time" double)" 10
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_10m_time" double)"  11
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_100m_time" double)" 12
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_1km_time" double)" 13
  assert_equal "$(mk_attr "metrickit.location_activity.accuracy_3km_time" double)" 14
  assert_equal "$(mk_attr "metrickit.network_transfer.wifi_upload" double)" 15                 # 15 B
  assert_equal "$(mk_attr "metrickit.network_transfer.wifi_download" double)" 16000            # 16 KB
  assert_equal "$(mk_attr "metrickit.network_transfer.cellular_upload" double)" 17000000       # 17 MB
  assert_equal "$(mk_attr "metrickit.network_transfer.cellular_download" double)" 18000000000  # 18 GB
  assert_equal "$(mk_attr "metrickit.app_launch.time_to_first_draw_average" double)" 1140            # 19 minutes
  assert_equal "$(mk_attr "metrickit.app_launch.app_resume_time_average" double)" 1200               # 20 minutes
  assert_equal "$(mk_attr "metrickit.app_launch.optimized_time_to_first_draw_average" double)" 1260  # 21 minutes
  assert_equal "$(mk_attr "metrickit.app_launch.extended_launch_average" double)" 1320               # 22 minutes
  assert_equal "$(mk_attr "metrickit.app_responsiveness.hang_time_average" double)" 82800  # 23 hours
  assert_equal "$(mk_attr "metrickit.diskio.logical_write_count" double)" 24000000000000  # 24 TB
  assert_equal "$(mk_attr "metrickit.memory.peak_memory_usage" double)" 25
  assert_equal "$(mk_attr "metrickit.memory.suspended_memory_average" double)" 26
  assert_equal "$(mk_attr "metrickit.display.pixel_luminance_average" double)" 27
  assert_equal "$(mk_attr "metrickit.animation.scroll_hitch_time_ratio" double)" 28
  assert_equal "$(mk_attr "metrickit.metadata.pid" int)" '"29"'
  assert_equal "$(mk_attr "metrickit.metadata.app_build_version" string)" '"build"'
  assert_equal "$(mk_attr "metrickit.metadata.device_type" string)" '"device"'
  assert_equal "$(mk_attr "metrickit.metadata.is_test_flight_app" bool)" true
  assert_equal "$(mk_attr "metrickit.metadata.low_power_mode_enabled" bool)" true
  assert_equal "$(mk_attr "metrickit.metadata.os_version" string)" '"os"'
  assert_equal "$(mk_attr "metrickit.metadata.platform_arch" string)" '"arch"'
  assert_equal "$(mk_attr "metrickit.metadata.region_format" string)" '"format"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.normal_app_exit_count" int)" '"30"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.memory_resource_limit_exit-count" int)" '"31"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.bad_access_exit_count" int)" '"32"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.abnormal_exit_count" int)" '"33"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.illegal_instruction_exit_count" int)" '"34"'
  assert_equal "$(mk_attr "metrickit.app_exit.foreground.app_watchdog_exit_count" int)" '"35"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.normal_app_exit_count" int)" '"36"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.memory_resource_limit_exit_count" int)" '"37"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.cpu_resource_limit_exit_count" int)" '"38"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.memory_pressure_exit_count" int)" '"39"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.bad_access-exit_count" int)" '"40"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.abnormal_exit_count" int)" '"41"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.illegal_instruction_exit_count" int)" '"42"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.app_watchdog_exit_count" int)" '"43"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.suspended_with_locked_file_exit_count" int)" '"44"'
  assert_equal "$(mk_attr "metrickit.app_exit.background.background_task_assertion_timeout_exit_count" int)" '"45"'
}

@test "MXSignpostMetric data is present" {
  scope="io.honeycomb.metrickit"
  span="MXSignpostMetric"

  result=$(attributes_from_span_named $scope $span | jq .key | sort | uniq)

   assert_equal "$result" '"SampleRate"
"app.metadata"
"device.isBatteryMonitoringEnabled"
"device.isLowPowerModeEnabled"
"device.isMultitaskingSupported"
"device.localizedModel"
"device.manufacturer"
"device.model"
"device.model.name"
"device.name"
"device.orientation"
"device.systemName"
"device.systemVersion"
"device.userInterfaceIdiom"
"network.connection.type"
"screen.name"
"screen.path"
"session.id"
"signpost.category"
"signpost.count"
"signpost.cpu_time"
"signpost.hitch_time_ratio"
"signpost.logical_write_count"
"signpost.memory_average"
"signpost.name"'
}

# A helper just for MetricKit /diagnostic/ attributes, because there's so many of them.
# Arguments:
#   $1 - attribute key
#   $2 - attribute type
mk_diag_attr() {
  scope="io.honeycomb.metrickit"
  attribute_for_log_key $scope $1 $2
}

@test "MetricKit diagnostic values are present and units are converted" {
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.cpu_exception.total_cpu_time" double)" 3180        # 53 minutes
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.cpu_exception.total_sampled_time" double)" 194400  # 54 hours
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.disk_write_exception.total_writes_caused" double)" 55000000  # 55 MB
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.hang.hang_duration" double)" 56
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.hang.exception.stacktrace_json" string)" '"fake json stacktrace"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.mach_exception.type" int)" '"57"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.mach_exception.name" string)" '"Unknown exception type: 57"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.mach_exception.description" string)" '"Unknown exception type: 57"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.code" int)" '"58"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.signal" int)" '"59"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.signal.name" string)" '"Unknown signal: 59"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.signal.description" string)" '"Unknown signal: 59"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.message" string)" '"message: 1 2"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.type" string)" '"ExceptionType"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.termination_reason" string)" '"reason"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.name" string)" '"MyCrash"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.objc.classname" string)" '"MyClass"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.crash.exception.stacktrace_json" string)" '"fake json stacktrace"'
  assert_equal "$(mk_diag_attr "metrickit.diagnostic.app_launch.launch_duration" double)" 60
}

@test "URLSession all requests are present" {
  result=$(attribute_for_span_key "io.honeycomb.urlsession" GET request-id string | sort)
  assert_equal "$result" '"data-async-obj"
"data-async-obj-session"
"data-async-url"
"data-async-url-session"
"data-callback-obj"
"data-callback-obj-session"
"data-callback-obj-task"
"data-callback-obj-task-session"
"data-callback-url"
"data-callback-url-session"
"data-callback-url-task"
"data-callback-url-task-session"
"download-async-obj"
"download-async-obj-session"
"download-async-url"
"download-async-url-session"
"download-callback-obj"
"download-callback-obj-session"
"download-callback-obj-task"
"download-callback-obj-task-session"
"download-callback-url"
"download-callback-url-session"
"download-callback-url-task"
"download-callback-url-task-session"
"upload-async-obj"
"upload-async-obj-session"
"upload-callback-obj"
"upload-callback-obj-session"
"upload-callback-obj-task"
"upload-callback-obj-task-session"'
}

@test "URLSession attributes are correct" {
  result=$(attribute_for_span_key "io.honeycomb.urlsession" GET http.response.status_code int | uniq -c)
  assert_equal "$result" '  30 "200"'

  result=$(attribute_for_span_key "io.honeycomb.urlsession" GET server.address string | uniq -c)
  assert_equal "$result" '  30 "localhost"'
}

@test "Render Instrumentation attributes are correct" {
  # we got the spans we expect
  result=$(span_names_for "io.honeycomb.view" | sort | uniq -c)
  assert_equal "$result" '   7 "View Body"
   7 "View Render"'

  # the View Render spans are tracking the views we expect
  total_duration=$(attribute_for_span_key "io.honeycomb.view" "View Render" "view.name" string | sort)
  assert_equal "$total_duration" '"expensive text 1"
"expensive text 2"
"expensive text 3"
"expensive text 4"
"main view"
"nested expensive text"
"nested expensive view"'
}

@test "UIViewController attributes are correct" {
    result=$(attributes_from_span_named "io.honeycomb.uikit" viewDidAppear \
        | jq "select (.key == \"screen.name\")" \
        | jq "select (.value.stringValue == \"UIKit Menu\").value.stringValue" \
        | uniq)
    assert_equal "$result" '"UIKit Menu"'

    result=$(attributes_from_span_named "io.honeycomb.uikit" viewDidDisappear \
        | jq "select (.key == \"screen.name\")" \
        | jq "select (.value.stringValue == \"UIKit Menu\").value.stringValue" \
        | uniq)
    assert_equal "$result" '"UIKit Menu"'

        result=$(attributes_from_span_named "io.honeycomb.uikit" viewDidAppear \
        | jq "select (.key == \"screen.name\")" \
        | jq "select (.value.stringValue == \"UI KIT SCREEN OVERRIDE\").value.stringValue" \
        | uniq)
    assert_equal "$result" '"UI KIT SCREEN OVERRIDE"'

    result=$(attributes_from_span_named "io.honeycomb.uikit" viewDidDisappear \
        | jq "select (.key == \"screen.name\")" \
        | jq "select (.value.stringValue == \"UI KIT SCREEN OVERRIDE\").value.stringValue" \
        | uniq)
    assert_equal "$result" '"UI KIT SCREEN OVERRIDE"'
}

@test "UITabView attributes are correct" {
    result=$(attributes_from_span_named "io.honeycomb.uikit" viewDidAppear \
        | jq "select (.key == \"view.class\")" \
        | jq "select (.value.stringValue == \"SwiftUI.UIKitTabBarController\").value.stringValue" \
        | uniq)
    assert_equal "$result" '"SwiftUI.UIKitTabBarController"'
}

@test "UIKit touch events are captured" {
    assert_not_empty $(spans_on_view_named "io.honeycomb.uikit" "Touch Began" "Simple Button")
    assert_not_empty $(spans_on_view_named "io.honeycomb.uikit" "Touch Began" "accessibleButton")
    assert_not_empty $(spans_on_view_named "io.honeycomb.uikit" "Touch Began" "switch")

    assert_not_empty $(spans_on_view_named "io.honeycomb.uikit" "Touch Ended" "Simple Button")
    assert_not_empty $(spans_on_view_named "io.honeycomb.uikit" "Touch Ended" "accessibleButton")
    # UISwitch does not support Touch Ended events at this time. Apple sets the view to null.

    screen_name_attr=$(attributes_from_span_named "io.honeycomb.uikit" "Touch Began" \
        | jq "select (.key == \"screen.name\")" \
        | jq "select (.value.stringValue == \"UI KIT SCREEN OVERRIDE\").value.stringValue" \
        | uniq
    )
    assert_equal "$screen_name_attr" '"UI KIT SCREEN OVERRIDE"'

    screen_path_attr=$(attributes_from_span_named "io.honeycomb.uikit" "Touch Began" \
        | jq "select (.key == \"screen.path\")" \
        | jq "select (.value.stringValue == \"/SwiftUI.UIKitTabBarController/UIKitNavigationRoot/UI KIT SCREEN OVERRIDE\").value.stringValue" \
        | uniq
    )
    assert_equal "$screen_path_attr" '"/SwiftUI.UIKitTabBarController/UIKitNavigationRoot/UI KIT SCREEN OVERRIDE"'

    screen_name_attr=$(attributes_from_span_named "io.honeycomb.uikit" "Touch Began" \
        | jq "select (.key == \"screen.name\")" \
        | jq "select (.value.stringValue == \"UIKit Menu\").value.stringValue" \
        | uniq
    )
    assert_equal "$screen_name_attr" '"UIKit Menu"'

    screen_path_attr=$(attributes_from_span_named "io.honeycomb.uikit" "Touch Began" \
        | jq "select (.key == \"screen.path\")" \
        | jq "select (.value.stringValue == \"/SwiftUI.UIKitTabBarController/UIKitNavigationRoot/UIKit Menu\").value.stringValue" \
        | uniq
    )
    assert_equal "$screen_path_attr" '"/SwiftUI.UIKitTabBarController/UIKitNavigationRoot/UIKit Menu"'
}

@test "UIKit click events are captured" {
    assert_not_empty $(spans_on_view_named "io.honeycomb.uikit" "click" "Simple Button")
    assert_not_empty $(spans_on_view_named "io.honeycomb.uikit" "click" "accessibleButton")
}

@test "UIKit touch events have all attributes" {
    span=$(spans_on_view_named "io.honeycomb.uikit" "click" "accessibleButton")

    name=$(echo "$span" | jq '.attributes[] | select(.key == "view.name").value.stringValue')
    assert_equal "$name" '"accessibleButton"'

    class=$(echo "$span" | jq '.attributes[] | select(.key == "view.class").value.stringValue')
    assert_equal "$class" '"UIButton"'

    label=$(echo "$span" | jq '.attributes[] | select(.key == "view.accessibilityLabel").value.stringValue')
    assert_equal "$label" '"Accessible Button"'

    identifier=$(echo "$span" | jq '.attributes[] | select(.key == "view.accessibilityIdentifier").value.stringValue')
    assert_equal "$identifier" '"accessibleButton"'

    text=$(echo "$span" | jq '.attributes[] | select(.key == "view.titleLabel.text").value.stringValue')
    assert_equal "$text" '"Accessible Button"'
}

@test "Navigation spans are correct" {
    result=$(attribute_for_span_key "io.honeycomb.navigation" "NavigationTo" "screen.name" string | sort | uniq -c)
    root_count=$(echo "$result" | grep "\/")
    stack_root_count=$(echo "$result" | grep "NavigationStackRoot")
    yosemite_count=$(echo "$result" | grep "Yosemite")

    assert_equal "$root_count" '   1 "/"'
    assert_equal "$stack_root_count" '   1 "NavigationStackRoot"'
    assert_equal "$yosemite_count" '   3 "{\"name\":\"Yosemite\"}"'

    split_view_paths=$(attribute_for_span_key "io.honeycomb.navigation" "NavigationTo" "screen.path" string | sort | uniq -c | grep "Split View")
    assert_equal "$split_view_paths" '   1 "/Split View Parks Root"
   2 "/\"Split View Parks Root\"/{\"name\":\"Yosemite\"}"
   1 "/\"Split View Parks Root\"/{\"name\":\"Yosemite\"}/{\"name\":\"Oak Tree\"}"'

    navigation_to_attributes=$(attributes_from_span_named "io.honeycomb.navigation" "NavigationTo" | jq .key | sort | uniq)
    assert_equal "$navigation_to_attributes" '"SampleRate"
"app.metadata"
"device.isBatteryMonitoringEnabled"
"device.isLowPowerModeEnabled"
"device.isMultitaskingSupported"
"device.localizedModel"
"device.manufacturer"
"device.model"
"device.model.name"
"device.name"
"device.orientation"
"device.systemName"
"device.systemVersion"
"device.userInterfaceIdiom"
"navigation.trigger"
"network.connection.type"
"screen.name"
"screen.path"
"session.id"'

    result=$(attribute_for_span_key "io.honeycomb.navigation" "NavigationFrom" "screen.name" string \
        | sort \
        | uniq -c)
    yosemite_count=$(echo "$result" | grep "Yosemite")
    assert_equal "$yosemite_count" '   3 "{\"name\":\"Yosemite\"}"'

    navigation_from_attributes=$(attributes_from_span_named "io.honeycomb.navigation" "NavigationFrom" | jq .key | sort | uniq)
    assert_equal "$navigation_from_attributes" '"SampleRate"
"app.metadata"
"device.isBatteryMonitoringEnabled"
"device.isLowPowerModeEnabled"
"device.isMultitaskingSupported"
"device.localizedModel"
"device.manufacturer"
"device.model"
"device.model.name"
"device.name"
"device.orientation"
"device.systemName"
"device.systemVersion"
"device.userInterfaceIdiom"
"navigation.trigger"
"network.connection.type"
"screen.active.time"
"screen.name"
"screen.path"
"session.id"'

    split_view_paths=$(attribute_for_span_key "io.honeycomb.navigation" "NavigationFrom" "screen.path" string | sort | uniq -c | grep "Split View")
    assert_equal "$split_view_paths" '   2 "/\"Split View Parks Root\"/{\"name\":\"Yosemite\"}"
   1 "/\"Split View Parks Root\"/{\"name\":\"Yosemite\"}/{\"name\":\"Oak Tree\"}"'
}

@test "Navigation attributes are correct" {
    result=$(attribute_for_span_key "io.honeycomb.view" "View Render" "screen.name" string | uniq)
    assert_equal "$result" '"View Instrumentation"'
}

@test "Span Processor gets added correctly" {
    result=$(spans_received | jq ".attributes[] | select (.key == \"app.metadata\").value.stringValue" "app.metadata" string | uniq)
}

@test "NSException attributes are correct" {
    stacktrace=$(attribute_for_exception_log_of_type "TestException" "exception.stacktrace" string)
    type=$(attribute_for_exception_log_of_type "TestException" "exception.type" string)
    message=$(attribute_for_exception_log_of_type "TestException" "exception.message" string)
    session_id=$(attribute_for_exception_log_of_type "TestException" "session.id" string)
    severity=$(logs_from_scope_named "io.honeycomb.error" \
        | jq "select(.attributes[].value.stringValue == \"TestException\") | .severityText")

    assert_not_empty "$stacktrace"
    assert_equal "$message" '"Exception Handling reason"'
    assert_equal "$type" '"TestException"'
    assert_equal "$severity" '"FATAL"'
    assert_not_empty "$session_id"
}

@test "NSError attributes are correct" {
    code=$(attribute_for_exception_log_of_type "NSError" "nserror.code" int)
    domain=$(attribute_for_exception_log_of_type "NSError" "nserror.domain" string)
    type=$(attribute_for_exception_log_of_type "NSError" "error.type" string)
    message=$(attribute_for_exception_log_of_type "NSError" "error.message" string)
    session_id=$(attribute_for_exception_log_of_type "NSError" "session.id" string)
    severity=$(logs_from_scope_named "io.honeycomb.error" \
        | jq "select(.attributes[].value.stringValue == \"NSError\") | .severityText")

    assert_equal "$code" '"-1"'
    assert_equal "$domain" '"Test Error"'
    assert_equal "$type" '"NSError"'
    assert_equal "$message" "\"The operation couldn’t be completed. (Test Error error -1.)\""
    assert_equal "$severity" '"ERROR"'
    assert_not_empty "$session_id"
}

@test "Swift Error attributes are correct" {
    type=$(attribute_for_exception_log_of_type "TestError" "error.type" string)
    message=$(attribute_for_exception_log_of_type "TestError" "error.message" string)
    session_id=$(attribute_for_exception_log_of_type "TestError" "session.id" string)
    severity=$(logs_from_scope_named "io.honeycomb.error" \
        | jq "select(.attributes[].value.stringValue == \"TestError\") | .severityText")

    assert_equal "$type" '"TestError"'
    assert_equal "$message" "\"The operation couldn’t be completed. (SmokeTest.TestError error 0.)\""
    assert_equal "$severity" '"ERROR"'
    assert_not_empty "$session_id"
}
