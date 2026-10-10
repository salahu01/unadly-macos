import Foundation
import Testing
@testable import UnadlyCore

@Suite("Content rules and host lists")
struct ContentRulesTests {
    @Test("Parses plain and hosts-file formats, skipping junk")
    func parse() {
        let text = """
            # comment
            ads.example.com
            0.0.0.0 tracker.example.net   # trailing comment
            127.0.0.1 localhost
            0.0.0.0 0.0.0.0
            ADS.EXAMPLE.COM
            not a host!
            single

            cdn.ads-r-us.io
            """
        #expect(HostList(parsing: text).hosts == ["ads.example.com", "cdn.ads-r-us.io", "tracker.example.net"])
    }

    @Test("Fingerprint is stable and changes with the list")
    func fingerprint() {
        let a = HostList(parsing: "a.com\nb.com")
        #expect(a.fingerprint == HostList(parsing: "b.com\na.com").fingerprint)
        #expect(a.fingerprint != HostList(parsing: "a.com\nc.com").fingerprint)
    }

    @Test("Blocking rules match the host and subdomains as third party only")
    func blockingRules() throws {
        let json = try ContentRules.blockingRules(for: ["ads.example.com"])
        let rules = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: [String: Any]]])
        #expect(rules.count == 1)
        let trigger = try #require(rules[0]["trigger"])
        let filter = try #require(trigger["url-filter"] as? String)
        #expect(trigger["load-type"] as? [String] == ["third-party"])
        #expect(rules[0]["action"]?["type"] as? String == "block")

        let regex = try NSRegularExpression(pattern: filter)
        func matches(_ s: String) -> Bool { regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }
        #expect(matches("https://ads.example.com/x.js"))
        #expect(matches("https://cdn.ads.example.com:443/x.js"))
        #expect(!matches("https://notads.example.com/x.js"))
        #expect(!matches("https://ads.example.com.evil.net/x.js"))
        #expect(!matches("https://example.com/?ref=ads.example.com/"))
    }

    @Test("Cosmetic rule hides ad slots")
    func cosmetic() throws {
        let json = try ContentRules.cosmeticRules()
        #expect(json.contains("css-display-none"))
        #expect(json.contains("adsbygoogle"))
    }

    @Test("Chunks stay within WebKit's per-list size")
    func chunks() {
        let hosts = (0..<(ContentRules.maxRulesPerList * 2 + 5)).map { "h\($0).com" }
        let chunks = ContentRules.chunks(of: hosts)
        #expect(chunks.count == 3)
        #expect(chunks.allSatisfy { $0.count <= ContentRules.maxRulesPerList })
        #expect(chunks.flatMap { $0 } == hosts)
    }
}
