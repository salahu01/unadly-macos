import Foundation
import Testing
@testable import UnadlyCore

@Suite("AddressParser")
struct AddressParserTests {
    @Test("Bare domains open over HTTPS", arguments: [
        ("example.com", "https://example.com"),
        ("en.wikipedia.org/wiki/Mac", "https://en.wikipedia.org/wiki/Mac"),
        ("news.ycombinator.com?p=2", "https://news.ycombinator.com?p=2"),
        ("example.com:8443/path", "https://example.com:8443/path"),
    ])
    func bareDomains(input: String, expected: String) {
        #expect(AddressParser.url(for: input)?.absoluteString == expected)
    }

    @Test("Full URLs are kept as typed")
    func fullURLs() {
        #expect(AddressParser.url(for: "http://example.com/a?b=c")?.absoluteString == "http://example.com/a?b=c")
        #expect(AddressParser.url(for: "  https://example.com  ")?.absoluteString == "https://example.com")
    }

    @Test("localhost opens over HTTP")
    func localhost() {
        #expect(AddressParser.url(for: "localhost:3000")?.absoluteString == "http://localhost:3000")
    }

    @Test("Anything else is a search", arguments: ["hello world", "swift", "what is 2.5 + 1", "file:///etc/passwd"])
    func searches(input: String) throws {
        let url = try #require(AddressParser.url(for: input))
        #expect(url.host() == "duckduckgo.com")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }
        #expect(query?.value == input)
    }

    @Test("Empty input gives nothing")
    func empty() {
        #expect(AddressParser.url(for: "") == nil)
        #expect(AddressParser.url(for: "   \n") == nil)
    }

    @Test("Site root keeps scheme, host and port only")
    func siteRoot() {
        let page = URL(string: "https://www.example.com:8443/a/b?c=d#e")!
        #expect(AddressParser.siteRoot(of: page)?.absoluteString == "https://www.example.com:8443/")
        #expect(AddressParser.siteRoot(of: URL(string: "about:blank")!) == nil)
        #expect(AddressParser.siteRoot(of: URL(string: "file:///tmp/x.html")!) == nil)
    }
}
