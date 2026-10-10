import AppKit
import OSLog
import UnadlyCore
import WebKit

/// Saves downloads to the user's Downloads folder, never overwriting an existing file,
/// and shows the finished file in Finder.
@MainActor
final class DownloadManager: NSObject, WKDownloadDelegate {
    static let shared = DownloadManager()
    private let logger = Logger(subsystem: "com.salahu01.unadly", category: "Downloads")
    private var destinations: [ObjectIdentifier: URL] = [:]

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                 suggestedFilename: String) async -> URL? {
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = DownloadNaming.uniqueURL(in: folder, for: suggestedFilename)
        destinations[ObjectIdentifier(download)] = destination
        return destination
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let url = destinations.removeValue(forKey: ObjectIdentifier(download)) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        destinations.removeValue(forKey: ObjectIdentifier(download))
        logger.error("Download failed: \(error.localizedDescription, privacy: .public)")
    }
}
