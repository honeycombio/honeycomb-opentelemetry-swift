# Local Development

## Prerequisites

**Required:**

- Xcode 16.0 or later (from the [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835))

Development and unit tests are done within Xcode. However, there is also a smoke-test, which must be run using the included Makefile.

## Smoke Tests

Smoke tests use Xcode Command Line Tools and Docker using `docker-compose`, exporting telemetry to a local collector.
Tests are run using `bats-core` and `jq`, bash tools to make assertions against the telemetry output.

**Required for Smoke Tests:**

- Xcode Command-line Tools
- [`bats-core`](https://bats-core.readthedocs.io/en/stable/) and [`jq`](https://jqlang.github.io/jq/)
- Docker & Docker Compose
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/) is a reliable choice if you don't have your own preference.

**Initial Setup**

To install the Xcode Command Line Tools, first install and run Xcode. Then run:

```sh
xcode-select --install
```

Install `bats-core` and `jq` for local testing:

```sh
brew install bats-core
brew install jq
```

**Running Tests**

Smoke tests can be run with `make` targets.

```sh
make smoke
```

The results of both the tests themselves and the telemetry collected by the collector are in a file `data.json` in the `smoke-tests/collector/` directory.

After smoke tests are done, tear down docker containers:

```sh
make unsmoke
```
