import AppKit
import UnadlyCore

/// Fetches and caches site icons for pin tiles. Tries each candidate URL in order.
@MainActor
final class FaviconLoader {
    static let shared = FaviconLoader()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage?, Never>] = [:]
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }()

    func icon(for pin: Pin) async -> NSImage? {
        if let cached = cache.object(forKey: pin.url as NSURL) { return cached }
        if let task = inFlight[pin.url] { return await task.value }

        let candidates = pin.iconCandidates
        let session = self.session
        let task = Task<NSImage?, Never> {
            for url in candidates {
                guard let (data, response) = try? await session.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let image = NSImage(data: data), image.isValid else { continue }
                return image
            }
            return nil
        }
        inFlight[pin.url] = task
        let image = await task.value
        inFlight[pin.url] = nil
        if let image { cache.setObject(image, forKey: pin.url as NSURL) }
        return image
    }
}
