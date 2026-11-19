import Foundation
import ImageIO

enum ViewQError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(value) = self { return value }; return nil }
}

enum SharedInbox {
    static let maxBytes = 100 * 1024 * 1024
    static func excludeBackup(_ url: URL) throws {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }
    static func directory() throws -> URL {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ViewQAppGroup") as? String,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw ViewQError.message("Shared storage is unavailable. Check the App Group signing settings.")
        }
        let directory = root.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try excludeBackup(directory)
        return directory
    }
    static func validate(_ url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maxBytes else { throw ViewQError.message("Choose an image smaller than 100 MB.") }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw ViewQError.message("This file is not a supported image.") }
    }
    /// Called INSIDE the provider callback, before its temporary URL expires.
    static func save(_ source: URL) throws {
        try validate(source)
        let root = try directory()
        let id = UUID().uuidString
        let partial = root.appendingPathComponent(id + ".part")
        let ready = root.appendingPathComponent(id + ".img")
        do {
            try FileManager.default.copyItem(at: source, to: partial)
            try excludeBackup(partial)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: partial.path)
            let file = try FileHandle(forWritingTo: partial)
            try file.synchronize(); try file.close()
            try FileManager.default.moveItem(at: partial, to: ready)
        } catch { try? FileManager.default.removeItem(at: partial); throw error }
    }
}
