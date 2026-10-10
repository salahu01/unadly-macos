import Foundation
import Testing
@testable import UnadlyCore

@Suite("Pins")
struct PinTests {
    @Test("Labels use the site name", arguments: [
        ("https://en.wikipedia.org/", "wikipedia"),
        ("https://www.bbc.co.uk/", "bbc"),
        ("https://github.com/", "github"),
        ("https://timesofindia.indiatimes.com/", "indiatimes"),
        ("http://localhost:3000/", "localhost"),
    ])
    func labels(url: String, expected: String) {
        #expect(Pin(url: URL(string: url)!).label == expected)
    }

    @Test("Icon candidates are absolute, best first")
    func iconCandidates() {
        let pin = Pin(url: URL(string: "https://example.com/")!)
        #expect(pin.iconCandidates.map(\.absoluteString) == [
            "https://example.com/apple-touch-icon.png",
            "https://example.com/favicon.ico",
        ])
    }

    @Test("Adding is idempotent and keeps order")
    func add() {
        var list = PinList()
        let a = URL(string: "https://a.com/")!, b = URL(string: "https://b.com/")!
        list.add(a); list.add(b); list.add(a)
        #expect(list.pins.map(\.url) == [a, b])
    }

    @Test("Toggle adds then removes")
    func toggle() {
        var list = PinList()
        let a = URL(string: "https://a.com/")!
        list.toggle(a)
        #expect(list.contains(a))
        list.toggle(a)
        #expect(!list.contains(a))
    }

    @Test("Decoding drops duplicates")
    func dedupe() {
        let a = URL(string: "https://a.com/")!
        let list = PinList(pins: [Pin(url: a), Pin(url: a)])
        #expect(list.pins.count == 1)
    }

    @Test("Round-trips through JSON")
    func codable() throws {
        var list = PinList()
        list.add(URL(string: "https://a.com/")!)
        list.add(URL(string: "https://b.com/")!)
        let decoded = try JSONDecoder().decode(PinList.self, from: JSONEncoder().encode(list))
        #expect(decoded == list)
    }

    @Test("Move reorders")
    func move() {
        var list = PinList()
        let urls = ["https://a.com/", "https://b.com/", "https://c.com/"].map { URL(string: $0)! }
        urls.forEach { list.add($0) }
        list.move(from: IndexSet(integer: 2), to: 0)
        #expect(list.pins.map(\.url) == [urls[2], urls[0], urls[1]])
    }
}
