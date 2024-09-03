# UTILITY FUNCS

# Span names for a given scope
# Arguments: $1 - scope name
span_names_for() {
	spans_from_scope_named $1 | jq '.name'
}

# Attributes for a given scope
# Arguments: $1 - scope name
span_attributes_for() {
	spans_from_scope_named $1 | \
		jq ".attributes[]"
}

# A single span attribute
# Arguments:
#   $1 - scope
#   $2 - span name
#   $3 - attribute key
#   $4 - attribute type
attribute_for_span_key() {
	attributes_from_span_named $1 $2 | \
		jq "select (.key == \"$3\").value" | \
		jq ".${4}Value"
}

# A single log attribute
# Arguments:
#   $1 - scope
#   $2 - attribute key
#   $3 - attribute type
attribute_for_log_key() {
	logs_from_scope_named $1 | \
		jq ".attributes[]" | \
		jq "select (.key == \"$2\").value" | \
		jq ".${3}Value"
}

# All attributes from a span
# Arguments:
#   $1 - scope
#   $2 - span name
attributes_from_span_named() {
	spans_from_scope_named $1 | \
		jq "select (.name == \"$2\").attributes[]"
}

# All resource attributes
resource_attributes_received() {
	spans_received | jq ".resource.attributes[]?"
}

# Spans for a given scope
# Arguments: $1 - scope name
spans_from_scope_named() {
	spans_received | jq ".scopeSpans[] | select(.scope.name == \"$1\").spans[]"
}

# Logs for a given scope
# Arguments: $1 - scope name
logs_from_scope_named() {
	logs_received | jq ".scopeLogs[] | select(.scope.name == \"$1\").logRecords[]"
}

# All spans received
spans_received() {
	jq ".resourceSpans[]?" ./collector/data.json
}

# All logs received
logs_received() {
	jq ".resourceLogs[]?" ./collector/data.json
}

# ASSERTION HELPERS

# Fail and display details if the expected and actual values do not
# equal. Details include both values.
#
# Inspired by bats-assert * bats-support, but dramatically simplified
# Arguments:
# $1 - actual result
# $2 - expected result
assert_equal() {
	if [[ $1 != "$2" ]]; then
		{
			echo
			echo "-- 💥 values are not equal 💥 --"
			echo "expected : $2"
			echo "actual   : $1"
			echo "--"
			echo
		} >&2 # output error to STDERR
		return 1
	fi
}

# Fail and display details if the actual value is empty.
# Arguments: $1 - actual result
assert_not_empty() {
	EMPTY=(\"\")
	if [[ "$1" == "${EMPTY}" ]]; then
		{
			echo
			echo "-- 💥 value is empty 💥 --"
			echo "value : $1"
			echo "--"
			echo
		} >&2 # output error to STDERR
		return 1
	fi
}
