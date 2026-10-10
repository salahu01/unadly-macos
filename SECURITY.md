# Security policy

Unadly is a macOS web browser built on Apple's WebKit. It has no accounts, no server of its own
and no analytics. Pages load straight from each website; Unadly never sees or relays your traffic.

What it stores on your Mac:

- Pinned sites: `~/Library/Preferences/com.salahu01.unadly.plist`
- Cookies, cache and site data: WebKit's default website data store for the app
- Compiled ad-blocking rules: WebKit's content rule list store

Web content runs in WebKit's sandboxed processes, separate from the app. Popups a page opens
without a click are blocked.

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private reporting: open the repository's
**Security** tab and choose **Report a vulnerability**. You can expect an acknowledgement within a
few days.

Supported version: the latest release.
