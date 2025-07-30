# A script to set a specific version of opentelemetry-swift to depend on.
# This is intended for automated testing, and not to be used manually.
#
# usage: ./set-otel-version.sh 1.2.3
#
set -e

sed -i "" -e 's/opentelemetry-swift.git", [a-z]*: "[0-9.]*"/opentelemetry-swift.git", exact: "'$1'"/' Package.swift
