import AppKit
import Combine
import UnadlyCore
import WebKit

/// One browser window: a WKWebView plus the state the toolbar shows.
@MainActor
final class Browser: NSObject, ObservableObject {
    let webView: WKWebView

    @Published private(set) var showingHome = true
    @Published var address = ""
    @Published private(set) var title = "Unadly"
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var popupsBlocked = 0

    private var subscriptions: Set<AnyCancellable> = []

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.mediaTypesRequiringUserActionForPlayback = []
        // A bare WKWebView user agent lacks "Safari", and some sites then serve broken pages.
        config.applicationNameForUserAgent = "Version/18.0 Safari/605.1.15"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self

        AdBlocker.shared.whenReady { [weak self] in
            guard let controller = self?.webView.configuration.userContentController else { return }
            AdBlocker.shared.ruleLists.forEach(controller.add)
        }
        observeWebView()
    }

    private func observeWebView() {
        webView.publisher(for: \.canGoBack).sink { [weak self] in self?.canGoBack = $0 }.store(in: &subscriptions)
        webView.publisher(for: \.canGoForward).sink { [weak self] in self?.canGoForward = $0 }.store(in: &subscriptions)
        webView.publisher(for: \.isLoading).sink { [weak self] in self?.isLoading = $0 }.store(in: &subscriptions)
        webView.publisher(for: \.estimatedProgress).sink { [weak self] in self?.progress = $0 }.store(in: &subscriptions)
        webView.publisher(for: \.title).sink { [weak self] _ in self?.refreshTitle() }.store(in: &subscriptions)
        webView.publisher(for: \.url).sink { [weak self] url in
            guard let self, !self.showingHome, let url else { return }
            self.address = url.absoluteString
        }.store(in: &subscriptions)
    }

    private func refreshTitle() {
        guard !showingHome else { return }
        if let pageTitle = webView.title, !pageTitle.isEmpty {
            title = pageTitle
        } else {
            title = webView.url?.host() ?? "Unadly"
        }
    }

    // MARK: Navigation

    /// The current site's root address, for pinning. `nil` on the home page.
    var siteRoot: URL? {
        guard !showingHome, let url = webView.url else { return nil }
        return AddressParser.siteRoot(of: url)
    }

    var canGoBackOrHome: Bool { !showingHome }
    var canGoForwardFromHere: Bool { canGoForward || (showingHome && webView.url != nil) }

    /// Opens what the user typed: a web address, or a search.
    func open(_ input: String) {
        guard let url = AddressParser.url(for: input) else { return }
        open(url)
    }

    func open(_ url: URL) {
        showingHome = false
        address = url.absoluteString
        title = url.host() ?? "Unadly"
        // On first launch the ad list is still compiling; wait so the first page is filtered too.
        AdBlocker.shared.whenReady { [weak self] in
            self?.webView.load(URLRequest(url: url))
        }
    }

    func goHome() {
        webView.stopLoading()
        showingHome = true
        title = "Unadly"
        address = ""
    }

    /// Back from a site's first page returns to the home page.
    func goBack() {
        guard !showingHome else { return }
        if webView.canGoBack { webView.goBack() } else { goHome() }
    }

    func goForward() {
        if showingHome, webView.url != nil {
            showingHome = false
            address = webView.url?.absoluteString ?? ""
            refreshTitle()
        } else {
            webView.goForward()
        }
    }

    func reload() {
        guard !showingHome else { return }
        webView.reload()
    }
}

// MARK: - WKNavigationDelegate

extension Browser: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else { return (.cancel, preferences) }
        if action.shouldPerformDownload { return (.download, preferences) }
        if ["http", "https", "about", "blob", "data"].contains(scheme) { return (.allow, preferences) }
        // mailto:, tel:, app links: hand to macOS, but only when the user clicked them.
        if action.navigationType == .linkActivated { NSWorkspace.shared.open(url) }
        return (.cancel, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if !response.canShowMIMEType { return .download }
        let disposition = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        return disposition.lowercased().hasPrefix("attachment") ? .download : .allow
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = DownloadManager.shared
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = DownloadManager.shared
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error, for: webView.url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error, for: webView.url)
    }

    private func showError(_ error: Error, for url: URL?) {
        let error = error as NSError
        // Cancelled loads (a new address typed mid-load) and WebKit's own "frame load
        // interrupted" for downloads and blocked frames aren't worth an error page.
        guard error.code != NSURLErrorCancelled, error.domain != "WebKitErrorDomain" else { return }
        let failingURL = (error.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? url
        webView.loadHTMLString(ErrorPage.html(message: error.localizedDescription, url: failingURL), baseURL: nil)
    }
}

// MARK: - WKUIDelegate

extension Browser: WKUIDelegate {
    /// A link the user clicked opens here in the same window; windows a script opens on
    /// its own (popup and popunder ads) are dropped.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.navigationType == .linkActivated {
            webView.load(action.request)
        } else {
            popupsBlocked += 1
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {
        _ = Self.alert(title: frame.securityOrigin.host, message: message, buttons: ["OK"])
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        Self.alert(title: frame.securityOrigin.host, message: message, buttons: ["OK", "Cancel"]) == .alertFirstButtonReturn
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
        let field = NSTextField(string: defaultText ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = prompt
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        return panel.runModal() == .OK ? panel.urls : nil
    }

    private static func alert(title: String, message: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title.isEmpty ? "This page says" : title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        return alert.runModal()
    }
}

// MARK: - Error page

enum ErrorPage {
    static func html(message: String, url: URL?) -> String {
        let address = url.map { "<p class=url>\(escape($0.absoluteString))</p>" } ?? ""
        return """
            <!doctype html><meta charset="utf-8"><meta name="color-scheme" content="light dark">
            <title>Can't open this page</title>
            <style>
              body { font: 15px/1.5 -apple-system, sans-serif; max-width: 480px; margin: 20vh auto; padding: 0 16px; }
              h1 { font-size: 22px; } .url { color: GrayText; word-break: break-all; }
            </style>
            <h1>Can't open this page</h1>\(address)<p>\(escape(message))</p>
            """
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
