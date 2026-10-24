#!/usr/bin/env bash
# Runs the three setups against a local OTLP sink and diffs attribute key sets.
# Requires: a Swift 6 toolchain, python3 with `opentelemetry-proto` installed in $PY (default python3).
set -euo pipefail
cd "$(dirname "$0")"
PY=${PY:-python3}
OUT=${OUT:-/tmp/passthrough-out}
PORT=${PORT:-4318}
mkdir -p "$OUT"; rm -f "$OUT"/*.jsonl
BIN=$(cd ../.. && swift build --product PassthroughHarness --show-bin-path)/PassthroughHarness
(cd ../.. && swift build --product PassthroughHarness >/dev/null)
for mode in current upstream passthrough; do
  : > "$OUT/$mode.jsonl"
  $PY sink.py "$PORT" "$OUT/$mode.jsonl" & SINK=$!
  sleep 1
  "$BIN" "$mode" "$PWD" "http://127.0.0.1:$PORT" >/dev/null
  sleep 1; kill $SINK; wait $SINK 2>/dev/null || true
  echo "$mode: $(wc -l < "$OUT/$mode.jsonl") requests"
done
$PY diff.py "$OUT"
