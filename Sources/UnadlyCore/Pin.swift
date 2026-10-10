import Foundation

/// A site pinned to the home page.
public struct Pin: Codable, Identifiable, Hashable, Sendable {
    public var url: URL
    public var id: URL { url }

    public init(url: URL) {
        self.url = url
    }

    /// Short name for the tile: `en.wikipedia.org` → `wikipedia`, `www.bbc.co.uk` → `bbc`.
    public var label: String {
        guard let host = url.host(), !host.isEmpty else { return url.absoluteString }
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return parts.first ?? host }
        let secondLevelSuffixes: Set = ["co", "com", "org", "net", "gov", "ac", "edu"]
        let usesSecondLevel = parts.count > 2 && secondLevelSuffixes.contains(parts[parts.count - 2])
        return parts[parts.count - (usesSecondLevel ? 3 : 2)]
    }

    /// Icon locations to try, best first.
    public var iconCandidates: [URL] {
        ["/apple-touch-icon.png", "/favicon.ico"].compactMap { URL(string: $0, relativeTo: url)?.absoluteURL }
    }
}

/// Ordered list of pins with no duplicates. Persistence is left to the caller.
public struct PinList: Codable, Equatable, Sendable {
    public private(set) var pins: [Pin]

    public init(pins: [Pin] = []) {
        var seen = Set<URL>()
        self.pins = pins.filter { seen.insert($0.url).inserted }
    }

    public func contains(_ url: URL) -> Bool { pins.contains { $0.url == url } }

    public mutating func add(_ url: URL) {
        guard !contains(url) else { return }
        pins.append(Pin(url: url))
    }

    public mutating func remove(_ url: URL) {
        pins.removeAll { $0.url == url }
    }

    public mutating func toggle(_ url: URL) {
        contains(url) ? remove(url) : add(url)
    }

    public mutating func move(from source: IndexSet, to destination: Int) {
        // Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, without importing SwiftUI.
        let moving = source.map { pins[$0] }
        let insertAt = destination - source.count(in: 0..<destination)
        for index in source.reversed() { pins.remove(at: index) }
        pins.insert(contentsOf: moving, at: insertAt)
    }
}
