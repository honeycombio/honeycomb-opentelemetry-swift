#!/usr/bin/env bats

load test_helpers/utilities

CONTAINER_NAME="ios-test"
SMOKE_TEST_SCOPE="@honeycombio/smoke-test"

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

# A helper just for MetricKit attributes, because there's so many of them.
# Arguments:
#   $1 - attribute key
#   $2 - attribute type
mkattr() {
  scope="@honeycombio/instrumentation-metric-kit"
  span="MXMetricPayload"
  attribute_for_key $scope $span $1 $2
}

@test "MetricKit values are present and units are converted" {
  assert_equal "$(mkattr "metrickit.includes_multiple_application_versions" bool)" false
  assert_equal "$(mkattr "metrickit.latest_application-version" string)" '"3.14.159"'
  assert_equal "$(mkattr "metrickit.cpu.cpu_time" double)" 1
  assert_equal "$(mkattr "metrickit.cpu.instruction_count" double)" 2
  assert_equal "$(mkattr "metrickit.gpu.time" double)" 10800  # 3 hours
  assert_equal "$(mkattr "metrickit.cellular_condition.bars_average" double)" 4
  assert_equal "$(mkattr "metrickit.app_time.foreground_time" double)" 300          # 5 minutes
  assert_equal "$(mkattr "metrickit.app_time.background_time" double)" 0.000006     # 6 microseconds
  assert_equal "$(mkattr "metrickit.app_time.background_audio_time" double)" 0.007  # 7 milliseconds
  assert_equal "$(mkattr "metrickit.app_time.background_location_time" double)" 480 # 8 minutes
  assert_equal "$(mkattr "metrickit.location_activity.best_accuracy_time" double)" 9
  assert_equal "$(mkattr "metrickit.location_activity.best_accuracy_for_nav_time" double)" 10
  assert_equal "$(mkattr "metrickit.location_activity.accuracy_10m_time" double)"  11
  assert_equal "$(mkattr "metrickit.location_activity.accuracy_100m_time" double)" 12
  assert_equal "$(mkattr "metrickit.location_activity.accuracy_1km_time" double)" 13
  assert_equal "$(mkattr "metrickit.location_activity.accuracy_3km_time" double)" 14
  assert_equal "$(mkattr "metrickit.network_transfer.wifi_upload" double)" 15                 # 15 B
  assert_equal "$(mkattr "metrickit.network_transfer.wifi_download" double)" 16000            # 16 KB
  assert_equal "$(mkattr "metrickit.network_transfer.cellular_upload" double)" 17000000       # 17 MB
  assert_equal "$(mkattr "metrickit.network_transfer.cellular_download" double)" 18000000000  # 18 GB
  assert_equal "$(mkattr "metrickit.app_launch.time_to_first_draw_average" double)" 1140            # 19 minutes
  assert_equal "$(mkattr "metrickit.app_launch.app_resume_time_average" double)" 1200               # 20 minutes
  assert_equal "$(mkattr "metrickit.app_launch.optimized_time_to_first_draw_average" double)" 1260  # 21 minutes
  assert_equal "$(mkattr "metrickit.app_launch.extended_launch_average" double)" 1320               # 22 minutes
  assert_equal "$(mkattr "metrickit.app_responsiveness.hang_time_average" double)" 82800  # 23 hours
  assert_equal "$(mkattr "metrickit.diskio.logical_write_count" double)" 24000000000000  # 24 TB
  assert_equal "$(mkattr "metrickit.memory.peak_memory_usage" double)" 25
  assert_equal "$(mkattr "metrickit.memory.suspended_memory_average" double)" 26
  assert_equal "$(mkattr "metrickit.display.pixel_luminance_average" double)" 27
  assert_equal "$(mkattr "metrickit.animation.scroll_hitch_time_ratio" double)" 28
  assert_equal "$(mkattr "metrickit.metadata.pid" int)" '"29"'
  assert_equal "$(mkattr "metrickit.metadata.app_build_version" string)" '"build"'
  assert_equal "$(mkattr "metrickit.metadata.device_type" string)" '"device"'
  assert_equal "$(mkattr "metrickit.metadata.is_test_flight_app" bool)" true
  assert_equal "$(mkattr "metrickit.metadata.low_power_mode_enabled" bool)" true
  assert_equal "$(mkattr "metrickit.metadata.os_version" string)" '"os"'
  assert_equal "$(mkattr "metrickit.metadata.platform_arch" string)" '"arch"'
  assert_equal "$(mkattr "metrickit.metadata.region_format" string)" '"format"'
  assert_equal "$(mkattr "metrickit.app_exit.foreground.normal_app_exit_count" int)" '"30"'
  assert_equal "$(mkattr "metrickit.app_exit.foreground.memory_resource_limit_exit-count" int)" '"31"'
  assert_equal "$(mkattr "metrickit.app_exit.foreground.bad_access_exit_count" int)" '"32"'
  assert_equal "$(mkattr "metrickit.app_exit.foreground.abnormal_exit_count" int)" '"33"'
  assert_equal "$(mkattr "metrickit.app_exit.foreground.illegal_instruction_exit_count" int)" '"34"'
  assert_equal "$(mkattr "metrickit.app_exit.foreground.app_watchdog_exit_count" int)" '"35"'
  assert_equal "$(mkattr "metrickit.app_exit.background.normal_app_exit_count" int)" '"36"'
  assert_equal "$(mkattr "metrickit.app_exit.background.memory_resource_limit_exit_count" int)" '"37"'
  assert_equal "$(mkattr "metrickit.app_exit.background.cpu_resource_limit_exit_count" int)" '"38"'
  assert_equal "$(mkattr "metrickit.app_exit.background.memory_pressure_exit_count" int)" '"39"'
  assert_equal "$(mkattr "metrickit.app_exit.background.bad_access-exit_count" int)" '"40"'
  assert_equal "$(mkattr "metrickit.app_exit.background.abnormal_exit_count" int)" '"41"'
  assert_equal "$(mkattr "metrickit.app_exit.background.illegal_instruction_exit_count" int)" '"42"'
  assert_equal "$(mkattr "metrickit.app_exit.background.app_watchdog_exit_count" int)" '"43"'
  assert_equal "$(mkattr "metrickit.app_exit.background.suspended_with_locked_file_exit_count" int)" '"44"'
  assert_equal "$(mkattr "metrickit.app_exit.background.background_task_assertion_timeout_exit_count" int)" '"45"'
}

@test "MXSignpostMetric data is present" {
  scope="@honeycombio/instrumentation-metric-kit"
  span="MXSignpostMetric"

  result=$(attributes_from_span_named $scope $span | jq .key | sort | uniq)

   assert_equal "$result" '"signpost.category"
"signpost.count"
"signpost.cpu_time"
"signpost.hitch_time_ratio"
"signpost.logical_write_count"
"signpost.memory_average"
"signpost.name"'
}