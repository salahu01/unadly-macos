import Foundation

public enum DownloadNaming {
    /// A file URL in `folder` for `filename` that doesn't exist yet:
    /// `report.pdf` → `report 2.pdf` → `report 3.pdf` …
    /// Path separators in the suggested name are replaced so a site can't write outside `folder`.
    public static func uniqueURL(in folder: URL, for filename: String,
                                 exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        var name = filename.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.hasPrefix(".") { name = "download" + name }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var number = 2
        while exists(candidate) {
            candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)")
            number += 1
        }
        return candidate
    }
}
