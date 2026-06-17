# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Kronos is an NTP client library in Swift that provides a monotonic clock unaffected by device clock changes. This repo (`prex-ios-alien-kronos`) is Prex's fork of [MobileNativeFoundation/Kronos](https://github.com/MobileNativeFoundation/Kronos), with Prex-specific concurrency hardening (Swift 6 migration, `Clock2`).

## Build & test

The package builds three ways — SPM (`Package.swift`), Bazel (`MODULE.bazel`/`BUILD`), and CocoaPods (`Kronos.podspec`). Prefer SPM for local work:

```bash
swift build
swift test                                    # all tests
swift test --filter KronosTests.ClockTests    # single test class
swift test --filter KronosTests.ClockTests/testFoo   # single test
swiftlint lint --strict                        # lint (config: .swiftlint.yml)
```

Do **not** run `xcodebuild` — it is slow; ask the developer to test in Xcode instead. The `Makefile` targets (`make test-iOS`, `test-OSX`, `test-tvOS`) drive `xcodebuild` and are CI-oriented.

The package uses `swift-tools-version:6.1` (Swift 6 language mode, strict concurrency on by default). Some tests in `Tests/KronosTests/` depend on live network NTP responses.

## Architecture

The flow is: **`Clock2.sync` → `NTPClient.query` → `DNSResolver` + `NTPPacket` over `CFSocket` UDP → `TimeFreeze` (monotonic offset) → `TimeStorage` (persistence).**

- **`Clock2`** (`Sources/Clock2.swift`) — the clock used by Prex. An `enum` (namespace) whose mutable static state (`latestOffset`, `storage`, `_log`) is guarded by a single `NSLock` (`protection`); fields are `nonisolated(unsafe)` deliberately rather than converting to an actor, because the underlying `NTPClient` must run on the main thread. `sync`/`reset` are `@MainActor` and assert `Thread.isMainThread`; `now`/`offset`/`storedNow` are thread-safe getters. `now` recomputes from the stored offset on every call.
- **`Clock`** (`Sources/Clock.swift`) — original upstream clock, **`@available(*, deprecated, renamed: "Clock2")`**. Kept for reference only; do not build new functionality on it.
- **`NTPClient`** (`Sources/NTPClient.swift`) — resolves a pool to up to `kMaximumNTPServers` (5) addresses, fires `numberOfSamples` (4) recursive queries per server, and computes the final offset as the **median of the lowest-delay response per server** (after filtering by `kMaximumResultDispersion`). Networking is raw `CFSocket` UDP with manual `Unmanaged` retain/release bridging of an ObjC-block callback — handle this memory management carefully when editing.
- **`TimeFreeze`** (`Sources/TimeFreeze.swift`) — the heart of monotonicity. `systemUptime()` derives a stable timestamp from kernel boot time (`sysctl KERN_BOOTTIME`) using a retry loop to avoid a race between reading boot time and wall-clock time (see the linked Apple-forum justifications in comments). Sub-second precision is intentionally lost due to a Darwin limitation. Persists/restores via dictionary; restore returns `nil` if the device has rebooted since.
- **`TimeStorage`** (`Sources/TimeStorage.swift`) — `UserDefaults`-backed persistence. `TimeStoragePolicy` selects `.standard` or `.appGroup(...)` to share synced time between an app and its extensions.
- **`NTPPacket`** / **`NTPProtocol`** — NTP PDU encode/decode and validation. **`InternetAddress`**, **`DNSResolver`**, **`Data+Bytes`**, **`NSTimer+ClosureKit`** are supporting socket/DNS/byte utilities.

## Conventions

- Concurrency: the codebase favors `NSLock` + `nonisolated(unsafe)` over actors (see `Clock2` rationale) because the socket layer is main-thread-bound. Per global rules, never use `@unchecked Sendable`.
- `.swiftlint.yml` enforces a 110-char line length and mandatory trailing commas; `variable_name`, `nesting`, `opening_brace`, `valid_docs` are disabled (the code uses NTP-style short names like `PDU`).
- Add a `CHANGELOG.md` entry for user-facing changes (per `CONTRIBUTING.md`).
- `Sources/PrivacyInfo.xcprivacy` is shipped as a bundled resource — keep it in sync if data-use changes.
