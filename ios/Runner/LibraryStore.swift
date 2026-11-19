import Foundation
import SQLite3

final class LibraryStore {
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()
    let root: URL
    let images: URL
    private let inboxOverride: URL?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    init(rootOverride: URL? = nil, inboxOverride: URL? = nil) throws {
        self.inboxOverride = inboxOverride
        root = try rootOverride ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ViewQ", isDirectory: true)
        images = root.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try SharedInbox.excludeBackup(root)
        guard sqlite3_open_v2(root.appendingPathComponent("library.sqlite").path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { throw ViewQError.message("Could not open library.") }
        sqlite3_busy_timeout(db, 5000)
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA synchronous=FULL")
        try execute("CREATE TABLE IF NOT EXISTS shots(id TEXT PRIMARY KEY,path TEXT NOT NULL,created INTEGER NOT NULL,status TEXT NOT NULL DEFAULT 'pending',text TEXT NOT NULL DEFAULT '')")
        if try !rows("PRAGMA table_info(shots)").contains(where: { $0[1] == "generation" }) {
            try execute("ALTER TABLE shots ADD COLUMN generation INTEGER NOT NULL DEFAULT 0")
        }
        if try !rows("PRAGMA table_info(shots)").contains(where: { $0[1] == "category_override" }) {
            try execute("ALTER TABLE shots ADD COLUMN category_override TEXT NOT NULL DEFAULT ''")
        }
        try execute("CREATE VIRTUAL TABLE IF NOT EXISTS search USING fts4(id,text,tokenize=unicode61)")
    }
    deinit { sqlite3_close(db) }
    private func statement(_ sql: String, _ values: [String]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement = statement else { throw ViewQError.message("Could not read the library.") }
        for (index, value) in values.enumerated() { sqlite3_bind_text(statement,Int32(index+1),value,-1,transient) }
        return statement
    }
    private func execute(_ sql: String, _ values: [String] = []) throws {
        let stmt = try statement(sql,values); defer { sqlite3_finalize(stmt) }
        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else { throw ViewQError.message("Could not update the library. Check available storage.") }
    }
    private func rows(_ sql: String, _ values: [String] = []) throws -> [[String]] {
        let stmt = try statement(sql,values); defer { sqlite3_finalize(stmt) }
        var output: [[String]] = []
        while true {
            let code = sqlite3_step(stmt)
            if code == SQLITE_DONE { return output }
            guard code == SQLITE_ROW else { throw ViewQError.message("Could not read the library.") }
            output.append((0..<sqlite3_column_count(stmt)).map { index in
                sqlite3_column_text(stmt,index).map { String(cString: $0) } ?? ""
            })
        }
    }
    func importInbox() throws {
        lock.lock(); defer { lock.unlock() }
        let inbox = try inboxOverride ?? SharedInbox.directory()
        for file in try FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: [.contentModificationDateKey]) {
            if file.pathExtension == "part" {
                let date = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
                if date.timeIntervalSinceNow < -86400 { try? FileManager.default.removeItem(at: file) }
                continue
            }
            guard file.pathExtension == "img" else { continue }
            let id = file.deletingPathExtension().lastPathComponent
            guard UUID(uuidString: id) != nil else { continue }
            if try rows("SELECT id FROM shots WHERE id=?",[id]).isEmpty {
                try SharedInbox.validate(file)
                let target = images.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: file,to: target) }
                let copied = try FileHandle(forWritingTo: target)
                try copied.synchronize(); try copied.close()
                let created = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
                try execute("INSERT INTO shots(id,path,created) VALUES(?,?,?)",[id,target.lastPathComponent,String(Int64(created.timeIntervalSince1970*1000))])
            }
            try FileManager.default.removeItem(at: file)
        }
        try cleanup()
    }
    func indexStatus() throws -> [String: Int] {
        lock.lock(); defer { lock.unlock() }
        let counts = try rows("SELECT COUNT(*), COUNT(CASE WHEN status='done' THEN 1 END), COUNT(CASE WHEN status='pending' THEN 1 END) FROM shots WHERE status!='deleted'").first ?? ["0","0","0"]
        return ["total": Int(counts[0]) ?? 0, "indexed": Int(counts[1]) ?? 0, "pending": Int(counts[2]) ?? 0]
    }
    func list(_ query: String, screenshotID: String? = nil, previews: Bool = false) throws -> [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        let words = query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.prefix(16)
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && words.isEmpty { return [] }
        let filters = words.map { _ in "instr(lower(text),?)>0" }.joined(separator: " AND ")
        let sql = screenshotID != nil
            ? "SELECT id,path,created,status,text,category_override FROM shots WHERE id=? AND status!='deleted'"
            : words.isEmpty
            ? "SELECT id,path,created,status,text,category_override FROM shots WHERE status!='deleted' ORDER BY created DESC"
            : "SELECT id,path,created,status,text,category_override FROM shots WHERE status!='deleted' AND \(filters) ORDER BY instr(lower(text),?)=0,created DESC"
        let values = screenshotID.map { [$0] } ?? (words.isEmpty ? [] : Array(words) + [words.joined(separator: " ")])
        return try rows(sql, values).map {
            let clean = $0[4].split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            let first = words.compactMap { clean.range(of: $0, options: .caseInsensitive)?.lowerBound }.min() ?? clean.startIndex
            let start = clean.index(first, offsetBy: -16, limitedBy: clean.startIndex) ?? clean.startIndex
            let snippet = (start == clean.startIndex ? "" : "…") + String(clean[start...].prefix(140))
            let text = $0[4].lowercased()
            let hasLink = ["http://", "https://", "www."].contains { text.contains($0) }
            let hasCode = text.range(of: "\\b(otp|verification code|security code|one.time (?:password|code))\\b", options: .regularExpression) != nil
            let category = !$0[5].isEmpty ? $0[5] : hasCode ? "OTP" : hasLink ? "Link" : clean.isEmpty ? "" : "Note"
            return ["id":$0[0],"path":images.appendingPathComponent($0[1]).path,"created":Int64($0[2]) ?? 0,"status":$0[3],"text":previews ? "" : $0[4],"snippet":snippet,"hasText": !clean.isEmpty,"hasLink": hasLink,"category": category]
        }
    }
    func setCategory(_ id: String, category: String) throws {
        guard ["", "Receipt", "Link", "OTP", "Note", "Travel", "Deliveries", "Payments", "Events", "Conversations", "Documents"].contains(category) else {
            throw ViewQError.message("Unknown category.")
        }
        lock.lock(); defer { lock.unlock() }
        try execute("UPDATE shots SET category_override=? WHERE id=? AND status!='deleted'", [category,id])
        guard sqlite3_changes(db) == 1 else { throw ViewQError.message("This screenshot is no longer saved.") }
    }
    func correctText(_ id: String, text: String) throws {
        guard text.utf16.count <= 200_000 else { throw ViewQError.message("Screenshot text is too long.") }
        lock.lock(); defer { lock.unlock() }
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("UPDATE shots SET status='done',text=? WHERE id=? AND status!='deleted'", [text,id])
            guard sqlite3_changes(db) == 1 else { throw ViewQError.message("This screenshot is no longer saved.") }
            try execute("UPDATE shots SET generation=generation+1 WHERE id=?", [id])
            try execute("DELETE FROM search WHERE id=?", [id])
            try execute("INSERT INTO search(id,text) VALUES(?,?)", [id,text])
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func pending() throws -> (String, URL, Int64)? {
        lock.lock(); defer { lock.unlock() }
        guard let row = try rows("SELECT id,path,generation FROM shots WHERE status='pending' ORDER BY created LIMIT 1").first else { return nil }
        return (row[0],images.appendingPathComponent(row[1]),Int64(row[2]) ?? 0)
    }
    func finish(_ id: String, text: String?, failed: Bool, generation: Int64) throws {
        lock.lock(); defer { lock.unlock() }
        try execute("BEGIN IMMEDIATE")
        do {
            if let previous = try rows("SELECT text FROM shots WHERE id=? AND status='pending' AND generation=?", [id,String(generation)]).first?.first {
                let transcript = failed || (text ?? "").isEmpty ? previous : (text ?? "")
                let done = !failed || !transcript.isEmpty
                try execute("UPDATE shots SET status=?,text=? WHERE id=? AND status='pending'",[done ? "done" : "failed",transcript,id])
                try execute("DELETE FROM search WHERE id=?", [id])
                if done { try execute("INSERT INTO search(id,text) VALUES(?,?)",[id,transcript]) }
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func retry(_ id: String) throws {
        lock.lock(); defer { lock.unlock() }
        try execute("UPDATE shots SET status='pending',generation=generation+1 WHERE id=? AND status IN ('failed','done')",[id])
    }
    func delete(_ id: String) throws {
        lock.lock(); defer { lock.unlock() }
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("UPDATE shots SET status='deleted',text='' WHERE id=?",[id])
            try execute("DELETE FROM search WHERE id=?",[id])
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
        try cleanup()
    }
    private func cleanup() throws {
        for row in try rows("SELECT id,path FROM shots WHERE status='deleted'") {
            let file = images.appendingPathComponent(row[1])
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            try execute("DELETE FROM shots WHERE id=? AND status='deleted'",[row[0]])
        }
    }
}
