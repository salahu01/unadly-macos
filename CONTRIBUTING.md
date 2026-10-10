# Contributing

Thanks for helping make Unadly better. Bug reports, ideas and pull requests are all welcome.

## Build and run

Requirements: macOS 14 or later, Xcode 16 or later (Swift 6).

```bash
swift test                          # unit tests (UnadlyCore)
UNADLY_ARCHS=arm64 ./tools/bundle.sh  # build/Unadly.app for this Mac, fast
open build/Unadly.app
```

`./tools/bundle.sh` with no options builds a universal (Apple silicon + Intel) app.
`./tools/make-dmg.sh` packages it into a DMG. You can also open `Package.swift` in Xcode.

Open a page directly when testing: `open build/Unadly.app --args https://example.com`.

## Project layout

| Path | What's there |
|---|---|
| `Sources/UnadlyCore/` | Platform-independent logic: address parsing, pins, ad-block rule generation. Unit tested. |
| `Sources/Unadly/` | The app: SwiftUI windows, `WKWebView` browser, ad blocker, downloads. |
| `Tests/UnadlyCoreTests/` | Swift Testing tests for `UnadlyCore`. |
| `Resources/` | Info.plist, icon, entitlements, privacy manifest, the ad-server list. |
| `tools/` | Build, DMG, icon and blocklist scripts. |

## Guidelines

- Keep logic that doesn't need AppKit or WebKit in `UnadlyCore`, with tests.
- The app builds in Swift 6 language mode with strict concurrency; keep it warning-free.
- No analytics, telemetry or network requests other than the pages the user opens and the
  icons of their pinned sites.
- Ad lists must have a licence that allows redistribution. Credit them in `CREDITS.md` and `NOTICE`.
- Run `swift test` and build the app before opening a pull request.

## Updating the ad list

```bash
./tools/update-blocklist.sh
```

## Releasing

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`, and add a
   `CHANGELOG.md` entry.
2. `./tools/bundle.sh && ./tools/make-dmg.sh` (set `SIGN_IDENTITY` and `NOTARY_PROFILE` for a
   Developer ID signed, notarised build).
3. Or run the **Release** workflow from the Actions tab with the new tag.

By contributing you agree that your contributions are licensed under the Apache License 2.0.
