#!/usr/bin/env bats

# Checks for the "configuration wrapper over upstream" experiment. These run in two configurations
# against the same app and the same assertions:
#
#   baseline : Honeycomb's own URLSession and MetricKit instrumentation (SMOKE_EXPECT_UPSTREAM unset)
#   upstream : upstream's instrumentation plus the shapers in Sources/Honeycomb/Passthrough
#              (SMOKE_EXPECT_UPSTREAM=true)
#
# The baseline run checks the fixtures in Experiments/PassthroughHarness against reality. The
# upstream run checks that the shapers turn upstream's real output into the same shape.

export LC_ALL=C

load test_helpers/utilities

URLSESSION="io.honeycomb.urlsession"
TIMING="io.honeycomb.smoke-test.timing"

# Prints the keys of every span with the given name in the URLSession scope, sorted.
url_span_keys() {
  spans_from_scope_named $URLSESSION | jq -r "select(.name == \"$1\").attributes[].key" | sort
}

# Prints "error" or "unset" for the status of the single span with the given name.
url_span_status() {
  spans_from_scope_named $URLSESSION | jq -r "select(.name == \"$1\") | ((.status.code // 0) | tostring)" \
    | sed -e 's/^2$/error/' -e 's/^STATUS_CODE_ERROR$/error/' -e 's/^0$/unset/' -e 's/^STATUS_CODE_UNSET$/unset/'
}

@test "the leg runs the configuration it claims to" {
  actual=$(spans_from_scope_named $TIMING | jq -r '.attributes[] | select(.key == "upstream").value.boolValue' | sort -u)
  if [[ "$SMOKE_EXPECT_UPSTREAM" == "true" ]]; then
    assert_equal "$actual" "true"
  else
    assert_equal "$actual" "false"
  fi
}

@test "Honeycomb.configure timing is recorded" {
  values=$(spans_from_scope_named $TIMING | jq -r '.attributes[] | select(.key == "configure.ms").value.doubleValue')
  assert_not_empty "$values"
  # Shown in the CI log. Simulator timing is indicative only.
  echo "# configure.ms (upstream=${SMOKE_EXPECT_UPSTREAM:-false}): $(echo $values | tr '\n' ' ')" >&3
}

@test "a 404 response keeps Honeycomb's shape" {
  assert_equal "$(spans_from_scope_named $URLSESSION | jq -r 'select(.name == "DELETE").name' | wc -l | tr -d ' ')" "1"

  assert_equal "$(attribute_for_span_key $URLSESSION DELETE http.response.status_code int)" '"404"'
  assert_equal "$(attribute_for_span_key $URLSESSION DELETE http.scheme string)" '"http"'
  assert_equal "$(attribute_for_span_key $URLSESSION DELETE http.request.method string)" '"DELETE"'
  assert_equal "$(url_span_status DELETE)" "unset"

  keys=$(url_span_keys DELETE)
  for absent in url.scheme url.path http.request.body.size http.response.body.size error.type; do
    if echo "$keys" | grep -qx "$absent"; then
      echo "unexpected attribute $absent on the 404 span" >&2
      return 1
    fi
  done
  echo "# 404 span keys: $(echo $keys | tr '\n' ' ')" >&3
}

@test "a refused connection keeps Honeycomb's shape" {
  assert_equal "$(spans_from_scope_named $URLSESSION | jq -r 'select(.name == "PATCH").name' | wc -l | tr -d ' ')" "1"
  assert_equal "$(url_span_status PATCH)" "error"

  assert_not_empty "$(attribute_for_span_key $URLSESSION PATCH error.type string | grep NSURLErrorDomain)"
  assert_not_empty "$(attribute_for_span_key $URLSESSION PATCH error.message string)"
  assert_equal "$(attribute_for_span_key $URLSESSION PATCH nserror.domain string)" '"NSURLErrorDomain"'
  assert_not_empty "$(attribute_for_span_key $URLSESSION PATCH nserror.code int)"

  keys=$(url_span_keys PATCH)
  for absent in http.response.status_code url.scheme url.path; do
    if echo "$keys" | grep -qx "$absent"; then
      echo "unexpected attribute $absent on the refused-connection span" >&2
      return 1
    fi
  done
  echo "# refused span keys: $(echo $keys | tr '\n' ' ')" >&3
}

@test "the app sends no trace propagation headers" {
  log="mock-server/requests.jsonl"
  [[ -f "$log" ]] || skip "mock server request log not found (mock server ran elsewhere)"
  total=$(wc -l < "$log" | tr -d ' ')
  propagated=$(jq -r 'select(.headers.traceparent != null or .headers.baggage != null) | .url' "$log" | wc -l | tr -d ' ')
  echo "# $total requests reached the mock server, $propagated with traceparent or baggage" >&3
  [[ "$total" -gt 0 ]]
  assert_equal "$propagated" "0"
}

@test "MetricKit diagnostic logs have Honeycomb's attributes only" {
  records=$(logs_from_scope_named "io.honeycomb.metrickit" | jq -r '.attributes[].key' | sort -u)
  assert_not_empty "$records"
  for absent in exception.stacktrace exception.type exception.message; do
    if echo "$records" | grep -qx "$absent"; then
      echo "unexpected log attribute $absent" >&2
      return 1
    fi
  done
  names=$(logs_from_scope_named "io.honeycomb.metrickit" | jq -r '.eventName // empty' | sort -u)
  assert_equal "$names" ""
}
