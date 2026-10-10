import Foundation
import Testing
@testable import UnadlyCore

@Suite("Download naming")
struct DownloadNamingTests {
    let folder = URL(fileURLWithPath: "/tmp/downloads")

    @Test("Free names are used as is")
    func free() {
        #expect(DownloadNaming.uniqueURL(in: folder, for: "report.pdf", exists: { _ in false }).lastPathComponent == "report.pdf")
    }

    @Test("Taken names get a number before the extension")
    func numbered() {
        let taken: Set = ["report.pdf", "report 2.pdf"]
        let url = DownloadNaming.uniqueURL(in: folder, for: "report.pdf") { taken.contains($0.lastPathComponent) }
        #expect(url.lastPathComponent == "report 3.pdf")
    }

    @Test("Names without an extension")
    func noExtension() {
        let url = DownloadNaming.uniqueURL(in: folder, for: "README") { $0.lastPathComponent == "README" }
        #expect(url.lastPathComponent == "README 2")
    }

    @Test("Can't escape the folder or hide the file", arguments: ["../../etc/passwd", "a/b:c.txt", ".hidden", "", "   "])
    func sanitised(name: String) {
        let url = DownloadNaming.uniqueURL(in: folder, for: name, exists: { _ in false })
        #expect(url.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path)
        #expect(!url.lastPathComponent.hasPrefix("."))
        #expect(!url.lastPathComponent.isEmpty)
    }
}
