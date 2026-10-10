import SwiftUI

@main
struct UnadlyApp: App {
    init() {
        AdBlocker.shared.load()
        // `open -a Unadly --args https://example.com` opens that page in the first window.
        PendingLaunch.url = CommandLine.arguments.dropFirst()
            .compactMap(URL.init(string:))
            .first { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
    }

    var body: some Scene {
        WindowGroup {
            BrowserWindow()
        }
        .defaultSize(width: 1200, height: 800)
        // Web links handed to Unadly (dropped on the Dock icon, "Open With") open in a window.
        .handlesExternalEvents(matching: ["http", "https"])
        .commands {
            CommandGroup(replacing: .help) {
                Link("Unadly on GitHub", destination: URL(string: "https://github.com/salahu01/unadly-macos")!)
            }
        }
    }
}

/// A link passed on the command line, opened by the first window that appears.
@MainActor
enum PendingLaunch {
    static var url: URL?

    static func take() -> URL? {
        defer { url = nil }
        return url
    }
}
