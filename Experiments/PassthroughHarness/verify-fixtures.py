#!/usr/bin/env python3
"""Check that every attribute key in the hand-built fixtures appears as a string literal in the
source it claims to come from. This guards the fixtures against drift and against typos such as
`body_size` vs `body.size`. It does not prove the fixtures are complete.

usage: verify-fixtures.py UPSTREAM_SWIFT_CHECKOUT UPSTREAM_CORE_CHECKOUT
"""
import json, os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.abspath(os.path.join(here, "..", ".."))


def corpus(*roots):
    text = ""
    for root in roots:
        for d, _, files in os.walk(root):
            for f in files:
                if f.endswith(".swift"):
                    text += open(os.path.join(d, f), errors="ignore").read()
    return text


def present(key, text):
    if f'"{key}"' in text:
        return True
    # Honeycomb and upstream build "metrickit.diagnostic.<kind>.<key>" from two literals.
    m = re.match(r"metrickit\.diagnostic\.([a-z_]+)\.(.+)$", key)
    return bool(m) and f'"{m.group(1)}"' in text and f'"{m.group(2)}"' in text


def check(fixture_file, text, label):
    bad = []
    for f in json.load(open(os.path.join(here, fixture_file)))["fixtures"]:
        for k in f["attributes"]:
            if not present(k, text):
                bad.append((f["id"], k))
    print(f"{label}: {'all keys found' if not bad else 'MISSING ' + str(bad)}")
    return not bad


ok = check("fixtures-honeycomb.json", corpus(os.path.join(repo, "Sources"), sys.argv[2]), "Honeycomb fixtures vs this repo's Sources (+ core semantic conventions)")
ok &= check("fixtures-upstream.json", corpus(sys.argv[1], sys.argv[2]), "upstream fixtures vs opentelemetry-swift + core sources")
sys.exit(0 if ok else 1)
