import Foundation

/// Turns what a user typed into the address bar into a URL to load.
public enum AddressParser {
    /// Search engine used when the input isn't a web address.
    public static let searchEngine = URL(string: "https://duckduckgo.com/")!

    /// - Returns: a web address for inputs like `example.com`, `https://x.org/a`, or
    ///   `localhost:3000`; otherwise a search URL. `nil` for empty input.
    public static func url(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = webAddress(text) { return url }

        var components = URLComponents(url: searchEngine, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        return components.url
    }

    private static func webAddress(_ text: String) -> URL? {
        guard !text.contains(" ") else { return nil }

        if let scheme = URL(string: text)?.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return URL(string: text)
        }

        // host[.tld][:port][/path...] — needs a dot, or be localhost with an optional port.
        let pattern = #"^(localhost|[\p{L}\p{N}-]+(\.[\p{L}\p{N}-]+)+)(:\d{1,5})?([/?#]\S*)?$"#
        guard text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }

        let isLocal = text.lowercased().hasPrefix("localhost")
        return URL(string: (isLocal ? "http://" : "https://") + text)
    }

    /// The site's root address (`https://host/`) for a page URL, used for pins.
    public static func siteRoot(of url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port
        components.path = "/"
        return components.url
    }
}
