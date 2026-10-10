import SwiftUI
import UnadlyCore
import WebKit

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Window

struct BrowserWindow: View {
    @StateObject private var browser = Browser()
    @ObservedObject private var pins = PinStore.shared
    @FocusState private var addressFocused: Bool

    var body: some View {
        ZStack {
            WebView(webView: browser.webView)
                .opacity(browser.showingHome ? 0 : 1)
                .allowsHitTesting(!browser.showingHome)
                .accessibilityHidden(browser.showingHome)
            if browser.showingHome {
                HomeView(browser: browser)
            }
        }
        .overlay(alignment: .top) {
            if browser.isLoading && !browser.showingHome {
                ProgressView(value: browser.progress)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .frame(height: 2)
                    .accessibilityLabel("Loading")
            }
        }
        .navigationTitle(browser.title)
        .toolbar { toolbar }
        .background {
            // ⌘L focuses the address bar, as in Safari.
            Button("Focus address bar") { addressFocused = true }
                .keyboardShortcut("l", modifiers: .command)
                .hidden()
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            if let url = PendingLaunch.take() { browser.open(url) }
        }
        .onOpenURL { browser.open($0) }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Back", systemImage: "chevron.left", action: browser.goBack)
                .disabled(!browser.canGoBackOrHome)
                .keyboardShortcut("[", modifiers: .command)
            Button("Forward", systemImage: "chevron.right", action: browser.goForward)
                .disabled(!browser.canGoForwardFromHere)
                .keyboardShortcut("]", modifiers: .command)
            Button("Home", systemImage: "house", action: browser.goHome)
                .keyboardShortcut("h", modifiers: [.command, .shift])
        }
        ToolbarItem(placement: .principal) {
            TextField("Search or type a website address", text: $browser.address)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 280, idealWidth: 520, maxWidth: 640)
                .focused($addressFocused)
                .onSubmit {
                    browser.open(browser.address)
                    addressFocused = false
                }
                .accessibilityLabel("Address and search")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let site = browser.siteRoot {
                let pinned = pins.contains(site)
                Button(pinned ? "Unpin from Home" : "Pin to Home", systemImage: pinned ? "star.fill" : "star") {
                    pins.toggle(site)
                }
                .foregroundStyle(pinned ? .yellow : .primary)
                .keyboardShortcut("d", modifiers: .command)
            }
            Button("Reload", systemImage: "arrow.clockwise", action: browser.reload)
                .disabled(browser.showingHome)
                .keyboardShortcut("r", modifiers: .command)
            ShieldStatus(popupsBlocked: browser.popupsBlocked)
        }
    }
}

private struct ShieldStatus: View {
    let popupsBlocked: Int

    var body: some View {
        let hosts = AdBlocker.shared.hostCount
        let detail = hosts > 0 ? "Blocking ads from \(hosts.formatted()) servers." : "Ad blocking is starting."
        let popups = popupsBlocked > 0 ? " \(popupsBlocked) popups blocked in this window." : ""
        Image(systemName: "shield.lefthalf.filled")
            .foregroundStyle(.green)
            .help(detail + popups)
            .accessibilityLabel(detail + popups)
    }
}

// MARK: - Home

struct HomeView: View {
    @ObservedObject var browser: Browser
    @ObservedObject private var pins = PinStore.shared
    @State private var query = ""
    @State private var addingSite = false
    @State private var newSite = ""
    @FocusState private var newSiteFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 84, maximum: 96), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 60)
                (Text("Un") + Text("adly").foregroundStyle(.green))
                    .font(.system(size: 60, weight: .semibold))
                    .kerning(-2)
                    .accessibilityLabel("Unadly")
                    .accessibilityAddTraits(.isHeader)

                TextField("Search or type a website address", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(Capsule().strokeBorder(.green.opacity(0.7)))
                    .frame(maxWidth: 580)
                    .onSubmit { browser.open(query) }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(pins.pins) { pin in
                        PinTile(pin: pin, onOpen: { browser.open(pin.url) }, onRemove: { pins.remove(pin.url) })
                    }
                    Button {
                        addingSite.toggle()
                        newSiteFocused = addingSite
                    } label: {
                        TileLabel(title: "Add site") { Image(systemName: "plus").font(.title3) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a site to Home")
                }
                .frame(maxWidth: 580)

                if addingSite {
                    HStack {
                        TextField("Site address, for example wikipedia.org", text: $newSite)
                            .textFieldStyle(.roundedBorder)
                            .focused($newSiteFocused)
                            .onSubmit(addSite)
                        Button("Pin", action: addSite)
                            .keyboardShortcut(.defaultAction)
                            .disabled(newSite.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .frame(maxWidth: 580)
                }

                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var footnote: String {
        let hosts = AdBlocker.shared.hostCount
        return hosts > 0
            ? "Ads blocked on every site: \(hosts.formatted()) ad servers, filtered on your Mac."
            : "Ads blocked on every site, filtered on your Mac."
    }

    private func addSite() {
        guard let url = AddressParser.url(for: newSite), url.host() != AddressParser.searchEngine.host(),
              let root = AddressParser.siteRoot(of: url) else { return }
        pins.add(root)
        newSite = ""
        addingSite = false
    }
}

struct PinTile: View {
    let pin: Pin
    let onOpen: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false
    @State private var icon: NSImage?

    var body: some View {
        Button(action: onOpen) {
            TileLabel(title: pin.label) {
                if let icon {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 24, height: 24)
                } else {
                    Text(pin.label.prefix(1).uppercased()).font(.system(size: 18, weight: .semibold))
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(hovering ? 0.07 : 0)))
        }
        .buttonStyle(.plain)
        .help(pin.url.absoluteString)
        .accessibilityLabel("Open \(pin.label)")
        .onHover { hovering = $0 }
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button("Unpin \(pin.label)", systemImage: "xmark.circle.fill", action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
        }
        .contextMenu {
            Button("Unpin \(pin.label)", action: onRemove)
        }
        .accessibilityAction(named: "Unpin", onRemove)
        .task(id: pin.url) { icon = await FaviconLoader.shared.icon(for: pin) }
    }
}

struct TileLabel<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: Icon

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.primary.opacity(0.09))
                .frame(width: 46, height: 46)
                .overlay(icon)
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 84)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
