import Foundation

/// A list of ad-server hostnames.
public struct HostList: Equatable, Sendable {
    public let hosts: [String]

    /// Parses plain lists (`host` per line) and hosts-file lists (`0.0.0.0 host`).
    /// Ignores comments, blank lines and invalid entries; lowercases, de-duplicates and sorts.
    public init(parsing text: String) {
        var unique = Set<String>()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            guard let last = line.split(whereSeparator: \.isWhitespace).last else { continue }
            let host = last.lowercased()
            if Self.isValidHost(host) { unique.insert(host) }
        }
        hosts = unique.sorted()
    }

    /// A short, stable fingerprint of the list, used to cache compiled rules.
    public var fingerprint: String {
        // FNV-1a: stable across launches, unlike Swift's seeded Hasher.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in hosts.joined(separator: "\n").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 36)
    }

    static func isValidHost(_ host: String) -> Bool {
        guard host.contains("."), host.count <= 253, !["0.0.0.0", "127.0.0.1", "localhost"].contains(host) else {
            return false
        }
        return host.range(of: #"^[a-z0-9_-]+(\.[a-z0-9_-]+)+$"#, options: .regularExpression) != nil
    }
}
