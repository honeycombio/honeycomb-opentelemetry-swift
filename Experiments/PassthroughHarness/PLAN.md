# Plan: the Honeycomb Swift SDK as a configuration wrapper over opentelemetry-swift

Status: exploration. The decisions in section 7 are defaults carried over from the equivalent web experiment, plus open questions. Written so it can be reused as a public PR description: it names only public packages and public upstream issues, and contains no keys, customer data or internal links.

"Upstream" below means [open-telemetry/opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) and [opentelemetry-swift-core](https://github.com/open-telemetry/opentelemetry-swift-core). This repo pins both at `2.5.1`. The latest release is `2.6.0`. `main` is ahead of `2.6.0` and contains an unreleased `Crash` instrumentation.

**Short answer.** On Apple platforms upstream only covers URLSession, MetricKit, sessions, network status, resource detection and a baggage processor. About a quarter of this repo's code (873 of 3,392 lines in `Sources/`) can be deleted in favor of upstream, and that part can be made to emit Honeycomb's shapes with configuration plus two small shapers. About a fifth (655 lines: UIKit view and touch instrumentation, SwiftUI view and navigation instrumentation, the uncaught-exception handler) has no upstream equivalent at all. So "no bespoke instrumentation" cannot be reached today for iOS. It depends on upstream work that is planned but not released (section 4, gaps 1 and 2).

## 1. What was validated locally, and what was not

The orb is Linux (Debian 12, x86_64). I installed the Swift 6.4.1 toolchain from swift.org. There is no macOS runner.

**Which targets build on Linux.**

| Target | Linux |
| --- | --- |
| `Honeycomb` at `main` | Does not build. The first error is `no such module 'MachO'`. Behind it: `SwiftUI`, the Objective-C runtime (swizzling), `NSException`, `@objc`, and upstream products that are Darwin-only. |
| `Honeycomb` on this branch | Builds. The Apple-only code is excluded in `Package.swift` or guarded with `#if canImport`. Cost: 6 source files excluded (`Networking/` has four, plus `HoneycombInstrumentedView.swift` and `HoneycombUncaughtExceptions.swift`), 4 files with local guards, 34 `#if canImport(ObjectiveC)` around `@objc` in `HoneycombOptions.swift`, one `XCTContext` shim in a test. |
| Upstream `URLSessionInstrumentation`, `MetricKitInstrumentation`, `NetworkStatus`, `ResourceExtension`, `Crash` | Darwin-only products. They cannot be built or run here. |
| Upstream `Sessions`, `BaggagePropagationProcessor`, OTLP HTTP exporters, `PersistenceExporter`, SDK | Build and run. |

**What ran.** Everything below used a local OTLP/HTTP sink on loopback, a fake API key, and no network.

| Setup | What it is | Runs real code from |
| --- | --- | --- |
| A. `current` | `Honeycomb.configure` with today's defaults. | This repo, real: options, resource, sampler, session, baggage, navigation spans, error logging, exporters. |
| B. `upstream` | Bare opentelemetry-swift, only exporter configuration filled in. | Upstream SDK and exporters. |
| C. `passthrough` | `Honeycomb.configure` with `otelUrlSessionInstrumentationEnabled` and `otelMetricKitInstrumentationEnabled` on, so the shapers are installed. | This repo and the new shapers. |

The *instrumentation output* in all three setups is a hand-built fixture, because the instrumentations themselves are Apple-only. `fixtures-honeycomb.json` is what this repo's code emits, copied from its Swift source. `fixtures-upstream.json` is what upstream `2.5.1` and `2.6.0` emit, copied from the named upstream source files. `verify-fixtures.py` checks that every attribute key in a fixture appears as a string literal in the source it cites. It caught one real mistake in the first draft: upstream writes `http.request.body.size`, not `body_size`. The fixtures are not captures from a device. In setup C, the span name, the tracer scope and the transport-failure attributes are what `Passthrough/UpstreamInstrumentationConfiguration.swift` is expected to produce. That file is Apple-only and was never compiled (see "not validated").

**Results.**

* **Wire.** Traces, logs and metrics go to `/v1/traces`, `/v1/logs`, `/v1/metrics`. Content type is `application/x-protobuf`. Headers `x-honeycomb-team`, `x-honeycomb-dataset` (classic key shape) and `x-otlp-version` are present in A and C. Resource keys `honeycomb.distro.*`, `telemetry.distro.*`, `service.*` and `deployment.environment` are present in A and C and absent in B. Linux has no `ResourceExtension`, so `os.*`, `device.*` and `app.*` resource keys are not covered.
* **Shape, A against C** (seven fixture pairs):

| Fixture | Result |
| --- | --- |
| URLSession `GET 200`, `POST 201`, `GET 404`, transport failure | Identical scope, span name, status, attribute key set and values. |
| MetricKit hang diagnostic, MetricKit crash diagnostic | Identical scope, key set and values. Event name cleared. |
| Crash: Honeycomb uncaught exception against upstream `device.crash` | Same scope, severity and attribute names after shaping. Different by nature: `thread.name` is missing, the values differ (it is a different crash mechanism), and the event name `device.crash` remains. |

* **Shape, B against A** (what a team gets from upstream alone):

| Area | Difference |
| --- | --- |
| Scope | URLSession scope is `NSURLSession`, MetricKit scope is `MetricKit`. |
| Span name | `HTTP GET` instead of `GET`. |
| URLSession attributes | Adds `url.path`, `http.request.body.size`, `http.response.body.size`. Renames `http.scheme` to `url.scheme`. |
| URLSession status | Status is `ERROR` for every 4xx and 5xx. Honeycomb leaves it unset. |
| Transport failure | `http.response.status_code = 0` and status `ERROR: 0`. Honeycomb has no status code, `error.type`, `error.message`, `nserror.domain`, `nserror.code`, and the error description as status. |
| MetricKit diagnostics | `exception.stacktrace` instead of `metrickit.diagnostic.<kind>.exception.stacktrace_json`. Adds `exception.type`, `exception.message` and an event name. |
| Every span | No `SampleRate`, `session.id`, `screen.name`, `screen.path` (these are Honeycomb processors). |
| Resource | No `honeycomb.distro.*` or `telemetry.distro.*`. |
| Headers | No `x-otlp-version`. |

* **MetricKit metrics span.** Spans `MXMetricPayload`, `MXSignpostMetric` and `MXDiagnosticPayload` use the same names, and all 77 attribute-key literals are identical between `MetricKitSubscriber.swift` and upstream `MetricKitInstrumentation.swift` (a static `diff` of the extracted keys). No processor is needed for them, only the scope (`MetricKitConfiguration(tracer:)`).
* **Unit tests.** 36 tests run on Linux: 28 existing plus 8 new. 35 pass. The one failure is `testOptionsFromPlist`. It fails only on Linux, because `Data(contentsOf:)` cannot read a `data:` URL in swift-corelibs-foundation. Two mutation checks (removing the transport-failure guard in the URLSession shaper, hard-coding the diagnostic kind in the MetricKit shaper) each made a new test fail.
* **Blast radius of deleting the replaced code.** Deleting `Networking/` (271 lines), `MetricKitSubscriber.swift` (560) and `CompositeSpanProcessor.swift` (42) leaves these references, found by `grep` because the code cannot be compiled here: `Honeycomb.swift` (two call sites), `Tests/ProxyURLSessionTaskDelegateTests.swift` (336 lines, tests the deleted class), and `Examples/SmokeTest/SmokeTest/ContentView.swift`, which calls the **public** functions `reportMetrics(payload:)` and `reportDiagnostics(payload:)` to inject fake MetricKit data. Upstream's equivalents are internal; its public entry point is `didReceive(_:)`. Two public builder setters (`setURLSessionInstrumentationEnabled`, `setMetricKitInstrumentationEnabled`) and their two option properties exist only for the deleted code. The options tests assert their defaults. This is a source-breaking change for any app that calls those two functions.
* **Swift 6 language mode probe.** Compiling the Linux-buildable part of `Honeycomb` with `-swift-version 6` stops at the first error: `SessionNotificationBridge` captures `self` in a `@Sendable` closure. The compiler stops after the first failing file, so the full list is unknown.

**Findings from the harness that are not about shapes.**

* *Metrics are never exported.* `Honeycomb.configure` builds a `MeterProviderSdk` with a reader but no view. In the harness a counter created through the global meter provider produced nothing in A and C. Bare upstream with a catch-all view (`InstrumentSelector` `.*`, as upstream's own examples do) exported it. Adding the same view line inside `Honeycomb.configure` made A export metrics; I then reverted that change, because it is outside this experiment.
* *Every log is one HTTP request.* `SimpleLogRecordProcessor` exports on the calling thread. Five logs produced five requests.
* `SessionLogRecordProcessor` in `2.5.1` returns `.success` from `forceFlush` and `shutdown` without calling the wrapped processor. `2.6.0` fixes it (upstream PR 1193). Moving to a batching log processor needs `2.6.0`.
* `Package.resolved` is rewritten by Linux resolution (it drops the Darwin-only pins). Never commit it from Linux.

**Not validated (needs macOS or a device).**

* `Passthrough/UpstreamInstrumentationConfiguration.swift`, the only code that touches upstream's Apple-only API. Written against the upstream sources, never compiled.
* The upstream instrumentations themselves: real span and log content, delegate coverage, `async` APIs, third-party SDK interaction, launch cost.
* MetricKit payloads, `MXCallStackTree` JSON, stack trace transform.
* UIKit, SwiftUI, touch, navigation, `NSSetUncaughtExceptionHandler`, CoreTelephony and `NetworkStatus`.
* Resource detection (`DefaultResources`, `app.*` keys, build UUID), session persistence on iOS, offline caching, gRPC export, binary size, the SmokeTest app and `smoke-e2e.bats`.
* Swift 6 language mode beyond the first error.

## 2. Disposition of today's bespoke code (3,392 lines in `Sources/Honeycomb`)

| Code | Lines | Class | Upstream equivalent | Fate |
| --- | --- | --- | --- | --- |
| `Networking/*` (URLSession swizzling, task delegate proxy) | 271 | Instrumentation | `URLSessionInstrumentation` | **Delete.** Replace with upstream plus configuration and `urlSessionSpanShaper` (section 3). Tests `ProxyURLSessionTaskDelegateTests` go with it. |
| `MetricKitSubscriber.swift` | 560 | Instrumentation | `MetricKitInstrumentation` | **Delete.** Configuration plus `metricKitLogRecordShaper`. |
| `CompositeSpanProcessor.swift` | 42 | Plain glue | `TracerProviderBuilder.add(spanProcessor:)` already composes processors | **Delete.** |
| `UIKit/*` (viewDidAppear/Disappear spans, touch and click spans) | 299 | Instrumentation | None. Planned upstream for views, not for interactions (gap 1). | **Keep** until decided. |
| `HoneycombNavigationSpanInstrumentation.swift` (NavigationTo/From, `screen.name` and `screen.path` on every span) | 263 | Instrumentation and processor | None | **Keep** until decided. |
| `HoneycombInstrumentedView.swift` (`View Render`, `View Body`) | 70 | Instrumentation (manual API) | None | **Keep** until decided. |
| `HoneycombUncaughtExceptions.swift` | 23 | Instrumentation | `Crash` (KSCrash), unreleased (gap 2) | **Keep** until upstream releases and the decision in section 7 is made. |
| `Honeycomb.swift` | 491 | SDK shell | `OpenTelemetry` registration, provider builders | **Keep, shrinks.** Stays the wrapper. Exporter selection and OTLP configuration remain Honeycomb's job. |
| `HoneycombOptions.swift`, `HoneycombOptionsSource.swift`, `HoneycombOptionsError.swift` | 838 | Configuration glue | None (upstream has no Honeycomb or `OTEL_*` option builder) | **Keep.** This is the wrapper. |
| `HoneycombDeterministicSampler.swift` | 63 | Sampler (configuration) | `Samplers.traceIdRatio` has no `SampleRate` attribute | **Keep.** |
| `AppInfoResources.swift` | 97 | Resource | `ResourceExtension` has no `app.bundle.*` or build UUID | **Keep.** Could become a resource provider. |
| `UIDeviceSpanProcessor.swift` | 122 | Span processor | `ResourceExtension` gives device data on the resource, not per span | **Keep.** |
| `NetworkStatusSpanProcessor.swift` | 46 | Span processor over upstream `NetworkStatus` | Already upstream | **Keep.** |
| `PersistenceExporters.swift` | 56 | Glue over upstream `PersistenceExporter` | Already upstream | **Keep.** Covers spans and metrics only, not logs. |
| `Session/*` | 89 | Compatibility shim over upstream `Sessions` | Already upstream | **Keep.** Public `HoneycombSession` and deprecated notifications. |
| `AttributeValueExtensions.swift`, `HoneycombDebug.swift`, `HoneycombVersion.swift` | 62 | Glue | None | **Keep.** |

Totals: delete 873, instrumentation with no upstream equivalent 655, configuration glue and shell 1,864.

## 3. Shape adapters (the processors)

Swift differs from the web in three ways that decide the design.

1. A `SpanProcessor` sees a finished span read-only (`onEnd(span: ReadableSpan)`). `SpanData` is mutable only through `setting…` methods, and has **no setter for the instrumentation scope**. So span shaping happens in a `SpanExporter` decorator, `ShapingSpanExporter`. The scope has to be fixed where the tracer is created, which both upstream instrumentations allow (`tracer:` in `URLSessionInstrumentationConfiguration` and `MetricKitConfiguration`).
2. A `LogRecordProcessor` is a chain: it receives a copy and chooses what the next processor sees. It can drop a record or rebuild it completely, including the scope, through `ReadableLogRecord`'s public initializer. So `ShapeLogRecordProcessor` needs none of the web SDK's sibling-processor workarounds.
3. `SpanExporter` is `Sendable`, so decorators are `@unchecked Sendable` and shapers are `@Sendable` closures.

```diagram
upstream instrumentation ──span──▶ SessionSpanProcessor, Baggage, SampleRate ──▶ BatchSpanProcessor
                                                                                   │
                                                          ShapingSpanExporter(urlSessionSpanShaper)
                                                                                   │
                                                                      [PersistenceExporter] ──▶ OTLP

upstream instrumentation ──log──▶ SessionLogRecordProcessor ──▶ ShapeLogRecordProcessor ──▶ log processor ──▶ OTLP
                                                                (metricKit, crash shapers)
```

Shaping sits outside the persistence decorator, so cached data is already in Honeycomb's shape.

| Upstream output | Honeycomb shape | Where it is done |
| --- | --- | --- |
| URLSession span in scope `NSURLSession`, name `HTTP GET` | Scope `io.honeycomb.urlsession`, name `GET` | Configuration: `tracer:` and `nameSpan:` |
| `url.scheme` | `http.scheme` | `urlSessionSpanShaper` |
| `url.path`, `http.request.body.size`, `http.response.body.size` | Removed (kept with `keepUpstreamAdditions: true`) | `urlSessionSpanShaper` |
| Status `ERROR` on HTTP 4xx and 5xx | Status unset | `urlSessionSpanShaper`. Transport failures keep `ERROR`. |
| Transport failure: status code `0`, status `ERROR: 0` | No status code. `error.type`, `error.message`, `nserror.domain`, `nserror.code` and the description as status. | Status code in the shaper. The rest in the `receivedError` hook (`recordTransportFailure`). |
| Span for each OTLP export request | None | Configuration: `shouldInstrument` checks the `x-otlp-version` header, as today |
| `traceparent` header injected | Not injected | Configuration: `shouldInjectTracingHeaders { false }` (decision 2) |
| MetricKit spans in scope `MetricKit` | Scope `io.honeycomb.metrickit` | Configuration: `MetricKitConfiguration(tracer:logger:)` |
| MetricKit stack trace in OTel's simplified JSON | Apple's JSON | Configuration: `useAppleStacktraceFormat: true` |
| Diagnostic log `exception.stacktrace` | `metrickit.diagnostic.<kind>.exception.stacktrace_json` | `metricKitLogRecordShaper` (kind comes from the `name` attribute) |
| Diagnostic log `exception.type`, `exception.message`, event name | Removed | `metricKitLogRecordShaper` (kept with `keepUpstreamAdditions: true`) |
| `device.crash` log in scope `io.opentelemetry.kscrash` | Scope `io.honeycomb.error`, severity `FATAL` | `upstreamCrashLogRecordShaper` |
| Everything else (sessions, baggage, sampler, device, network status, navigation) | Unchanged | Existing processors |

The shapers are installed only when the existing opt-in flags `otelUrlSessionInstrumentationEnabled` and `otelMetricKitInstrumentationEnabled` are on. With the flags off, `Honeycomb.configure` behaves exactly as before. This repo already had those flags (`2.4.0`). What was missing was the shaping: before this branch, turning the flag on changed the scope only, so the span name, attributes and status all differed.

## 4. Gaps processors cannot close

Ordered by how likely they are to matter.

| # | Gap | Effect | Way forward |
| --- | --- | --- | --- |
| 1 | **No upstream UIKit, SwiftUI, touch or navigation instrumentation.** Upstream has none of: `viewDidAppear`/`viewDidDisappear` spans, `Touch Began/Ended/Cancelled` and `click` spans, `View Render`/`View Body` spans, `NavigationTo`/`NavigationFrom`, and the `screen.name`/`screen.path` attribute on every span. Upstream issue 990 ("Understanding iOS Instrumentation current state") tracks it. A maintainer outlined upstreaming crashes, UIKit and SwiftUI views (time to first appear), startup and hangs, and wrote that there is no roadmap for interactions or `os.log`. The issue lists no merged PR for views. The mobile semantic conventions (`device.app.lifecycle`, `app.screen.click`, `app.widget.click`, `app.crash`, `app.jank`) are still in development status. | "No bespoke instrumentation" is not reachable. 655 lines stay. `screen.name` and `screen.path` on every span depend on the UIKit swizzle and on the navigation code, so they go away if those do. | Decision 1. Options: keep in the core product; move to an optional product (for example `HoneycombUIKit`) so the core is a pure wrapper; or contribute upstream and re-shape later. Whichever is chosen, the attribute names (`screen.name`) are Honeycomb's, not the draft semantic conventions' (`app.screen.name`), so a rename needs the dual-emit practice from the README. |
| 2 | **Crash reporting.** Upstream `main` has a `Crash` product (KSCrash, PR 1003 merged 2026-10-13, so not in `2.6.0` from 2026-10-01). It reports on the next launch with the original timestamp, event name `device.crash`, `exception.type`, `exception.message`, and an Apple-format report as `exception.stacktrace`. Honeycomb's handler logs an `NSException` in process (fatal severity, scope `io.honeycomb.error`, `callStackSymbols`, `thread.name`) and sleeps 3 s. | Different mechanism: it covers signals and Mach exceptions, which Honeycomb does not, and it loses `NSException`'s `callStackSymbols` format and `thread.name`. It adds a third-party Apple-only dependency (KSCrash `2.6.x`), a launch cost, and needs an unreleased upstream revision. | Keep the handler until upstream releases it. The scope and severity shaper exists and is tested. Decision 3. |
| 3 | **URLSession runtime behavior is unverified, and differs by design.** Upstream scans every loaded Objective-C class when it is created. Upstream issue 895 reports about 500 ms of launch time, still open; a docs PR (1172) is open. This repo's `2.4.1` changelog records a crash during `Honeycomb.configure` from that scan, which is why the upstream path is opt-in. Honeycomb's own instrumentation swizzles only `URLSession.init` and `URLSessionTask.resume`. Upstream also injects `traceparent` by default, which Honeycomb never did. It creates a second `NetworkStatus` (CoreTelephony) on first use, on whichever thread makes the first request, which `NetworkStatusSpanProcessor` documents as a hang risk. | Possible launch regression, crash risk and a changed propagation behavior. None of this can be seen on Linux. | Phase 1 measures it on a device. Pass `delegateClassesToInstrument` if the scan cost is real. Decision 2 for header injection. Keep the opt-in flag until Phase 1 passes. |
| 4 | **Client `spanProcessor` sees upstream's shape.** `HoneycombOptions.setSpanProcessor` receives `onStart` and `onEnd` before export. Shaping happens at export, so `onEnd` still sees `url.scheme`, status `ERROR` on 404 and `http.response.status_code = 0`. This is the same class of problem as the web SDK's changed hook signatures. | Apps with a custom processor that reads those fields change behavior. | Ship the shim approach already decided for the web: do the same edits on the live span in upstream's `createdRequest`, `receivedResponse` and `receivedError` hooks, so every processor sees the final shape. This is possible for URLSession. MetricKit needs no such change: its spans already match, and Honeycomb has no client log processor option. Needs macOS to build and test. |
| 5 | **MetricKit public API and format.** `reportMetrics(payload:)` and `reportDiagnostics(payload:)` are public here and used by the SmokeTest app. Upstream keeps them internal. Upstream's default stack trace format is a simplified JSON; it silently fell back to Apple's format in `2.5.1` (upstream issue 1148, fixed in `2.5.2`). The scope version is `0.0.1`, not the Honeycomb version. | A deprecation and a source break for callers. Choosing Apple's format keeps today's data but ignores upstream's proposed format. | Keep deprecated forwarding functions that call `MetricKitInstrumentation.didReceive` (decision 4 shims). Migrate the SmokeTest app. `smoke-e2e.bats` already asserts the `io.honeycomb.metrickit` scope and all converted values, so it is the contract test for this change. Decide the stack trace format (decision 2). |
| 6 | **Dependency and toolchain.** Honeycomb pins `2.5.1` exactly; `2.5.2` and `2.6.0` fix duplicate spans, the task-delegate crash class, `http`/`https` filtering, and session flush delegation. `2.6.0` also rewrote `SessionManager`. The manifest here is `swift-tools-version: 5.10`, upstream is `6.0` (already documented: Xcode 16 or later). Upstream's README marks the API and SDK stable; the instrumentation libraries carry no stability label, and MetricKit is missing from its list of instrumentation libraries. | Every upstream minor can change shapes. A wrapper with no bespoke code is exposed to that. | Phase 0 bumps to `2.6.0` and re-runs the SmokeTest suite. Keep the exact pin and the contract test as the guard. Decision 5. |
| 7 | **Shell findings that are not shape gaps.** (a) No metric view, so application metrics are dropped. (b) `SimpleLogRecordProcessor`: one request per log. (c) Persistence covers spans and metrics, not logs. | These are present today. (a) and (b) show up as soon as users rely on the wrapper for metrics and logs. | Fix (a) and (b) as separate changes, not as part of the swap. (b) needs `2.6.0` (session processor flush). |
| 8 | **Sessions are already upstream; small deltas remain.** Honeycomb's default timeout is 4 hours; upstream's is 30 minutes. `Honeycomb.currentSession()` calls `getSession()`, which counts as activity. Deprecated notifications are bridged. `2.6.0` adds explicit end and reset. | Low. Decision 6 from the web plan ("use upstream session management") is already true here. | Keep. Re-check session start and end events after the `2.6.0` bump. |
| 9 | **Sendable and Swift 6.** The package builds in Swift 5 language mode. `HoneycombOptions` holds a non-`Sendable` `SpanProcessor`. `Honeycomb`, `HoneycombNavigationProcessor` and the uncaught-exception handler keep mutable static state. The first Swift 6 error is in `SessionNotificationBridge`. | Not a blocker for the wrapper. Upstream compiles in Swift 6 with `@unchecked Sendable` and `nonisolated(unsafe)`. | Stay in Swift 5 mode for now. Count the errors in Xcode before deciding. New code here is `Sendable`-clean. |
| 10 | **Scope is immutable on `SpanData`.** A future upstream instrumentation that takes no `tracer:` parameter cannot be re-scoped by any processor. | Saved queries that filter on `io.honeycomb.*` scopes would break for it. | Ask upstream to take a tracer or scope on every instrumentation, or accept the upstream scope for new features. |

## 5. Phases

**Phase 0. Foundations (mergeable on their own).**

1. Bump `opentelemetry-swift` and `-core` to `2.6.0`; run the SmokeTest suite on macOS; re-check session behavior.
2. Keep the Linux build: the `Package.swift` exclusions, the `#if` guards, and a Linux CI job that runs `swift test`. This gives CI feedback on options, sampler and shapers without a macOS runner.
3. Turn `Experiments/PassthroughHarness` into a contract test: sink, fixtures, key-set diff. On macOS, replace the hand-built fixtures with captured output.
4. Fix the shell findings (gap 7a, 7b) as separate changes.

**Phase 1. Shapers, opt-in (this branch).** Run upstream URLSession and MetricKit behind the existing flags, with `Passthrough/` installed. Exit criteria: (a) `UpstreamInstrumentationConfiguration.swift` compiles on macOS; (b) a device or simulator run of the harness fixtures against real instrumentation shows no unexplained key differences, per URLSession case (200, 404, timeout, `async`, `AsyncImage`, a third-party networking library); (c) `smoke-e2e.bats` passes with both flags on; (d) launch time with the upstream URLSession scan measured against today's swizzle, with and without `delegateClassesToInstrument`; (e) no crash in `Honeycomb.configure` on a cold start across the supported OS range; (f) decision on gap 4.

**Phase 2. Swap the shell.** The flags default to on. Delete `Networking/`, `MetricKitSubscriber.swift`, `CompositeSpanProcessor.swift` and their tests. Keep deprecated no-op setters (`setURLSessionInstrumentationEnabled`, `setMetricKitInstrumentationEnabled`) and deprecated forwarding for `reportMetrics`/`reportDiagnostics`. Exit: SmokeTest and `smoke-e2e.bats` pass with the bespoke code gone; 873 lines removed; no change in any key set in the contract test.

**Phase 3. Upstream asks** (issues first, PRs if welcome): UIKit/SwiftUI view instrumentation (issue 990), a `Crash` release and a way to set its scope, a documented way to avoid the URLSession class scan, a tracer or scope parameter on every instrumentation (gap 10), `screen.name` against `app.screen.name`, interaction events.

**Phase 4. Release.** Gap 5 removes public API, so this is a major version. Follow the README's practice of dual-emit and deprecation windows for any renamed field. Decide the fate of `UIKit/`, navigation and view instrumentation (gap 1). Update the README dependency table.

## 6. Experiment PR

* Branch: `experiment/upstream-passthrough-identify-gaps`.
* Opened as a **draft**. Title follows the repo's conventional-commit check (`maint:` is an allowed type).
* Goal: show what builds and runs without a Mac, make the shaping real code behind the existing flags, and record the gaps. Failing or missing validation here is the output, not a defect.
* Public-repo rules: only public packages and upstream issues, fake keys and loopback endpoints, no customer, ticket, chat or roadmap references.

What is in the branch:

* `Package.swift`, `Sources/Honeycomb/AppInfoResources.swift`, `HoneycombNavigationSpanInstrumentation.swift`, `Honeycomb.swift`, `HoneycombOptions.swift` and one test: Linux build only. No behavior change.
* `Sources/Honeycomb/Honeycomb.swift`: installs the shapers when the two existing upstream flags are on; uses the new configuration functions.
* `Sources/Honeycomb/Passthrough/`: `ShapingSpanExporter`, `ShapeLogRecordProcessor`, the URLSession, MetricKit and crash shapers, and the Apple-only configuration.
* `Tests/Honeycomb/PassthroughShapeTests.swift`: eight tests.
* `Experiments/PassthroughHarness/`: the Swift harness, the sink, the fixtures, the diff and fixture check, and this plan.

## 7. Decisions

Carried over from the web experiment and applied here:

1. *Accept loss of span-based click-to-request parenting in favor of upstream's event shape.* **Not applicable, and the reason differs.** Honeycomb's `click` span is created and ended immediately in `sendEvent`. It is never the active span, so no request was ever parented under it. There is nothing to lose. Upstream has no touch instrumentation to adopt (gap 1).
2. *Use upstream session management.* Already true since `2.4.0`.
3. *Ship compatibility shims for changed hook signatures.* Applies to `reportMetrics`/`reportDiagnostics`, the removed option setters, and the client `spanProcessor` (gaps 4 and 5).

Open decisions:

1. **UI instrumentation (gap 1).** Keep in core, split into an optional product, or push upstream?
2. **Parity or adopt upstream's shape,** per difference. Defaults used in this branch are parity (keeps saved queries working). The changes to consider adopting: status `ERROR` on 4xx and 5xx; the extra URLSession attributes; `traceparent` injection (a behavior change for third-party hosts, but makes the README's manual propagation steps unnecessary); the MetricKit additions; Apple's against upstream's simplified stack trace format.
3. **Crash (gap 2).** Wait for an upstream release and accept KSCrash as a dependency, or keep the `NSException` handler?
4. **Public API.** Is removing `reportMetrics`/`reportDiagnostics` and the setters a major version, or do shims keep it a minor?
5. **Pinning.** Keep exact pins and bump to `2.6.0` first?
6. **Shell fixes.** Fix the missing metric view and the unbatched log export now, separately from this work?
7. **Swift 6 language mode.** In scope for the wrapper or not?
8. Who files the upstream issues (Phase 3) and when.

## How to rerun

```sh
# Linux, Swift 6 toolchain, python3 with opentelemetry-proto installed
swift test                                     # 36 tests, 1 Linux-only failure (plist from a data: URL)
cd Experiments/PassthroughHarness
PY=path/to/python ./run.sh                     # builds, runs the three setups against sink.py, prints the diff
python3 verify-fixtures.py <opentelemetry-swift checkout>/Sources <opentelemetry-swift-core checkout>/Sources
```
