package org.viewq.view_q

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.os.Build
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/** The only durable state. Pending rows are also the crash-recovery OCR queue. */
class LibraryStore(private val context: Context) : SQLiteOpenHelper(
    context, File(context.noBackupFilesDir, "library.sqlite").absolutePath, null, 9
), java.io.Closeable {
    // SQLiteOpenHelper itself became AutoCloseable only on newer Android releases.
    // Declare our own Closeable contract so Kotlin use{} is safe on API 24–28 too.
    override fun close() { super.close() }
    val images = File(context.noBackupFilesDir, "images").apply { mkdirs() }
    private fun thumbnail(name: String) = File(images, "$name.webp")

    private fun makeThumbnail(image: File, width: Int, height: Int) {
        val longest = maxOf(width, height)
        var sample = 1
        while (longest / sample > 600) sample *= 2
        val bitmap = BitmapFactory.decodeFile(image.path,
            BitmapFactory.Options().apply { inSampleSize = sample }) ?: return
        val scale = minOf(1.0, 300.0 / maxOf(bitmap.width, bitmap.height))
        val scaled = Bitmap.createScaledBitmap(bitmap, maxOf(1, (bitmap.width * scale).toInt()),
            maxOf(1, (bitmap.height * scale).toInt()), true)
        val target = thumbnail(image.name)
        val partial = File(images, "${target.name}.part")
        try {
            @Suppress("DEPRECATION")
            val format = if (Build.VERSION.SDK_INT >= 30) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
            if (partial.outputStream().use { scaled.compress(format, 70, it) }) partial.renameTo(target)
        } finally {
            partial.delete()
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
        }
    }
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE shots(id TEXT PRIMARY KEY, path TEXT NOT NULL, created INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending', text TEXT NOT NULL DEFAULT '', generation INTEGER NOT NULL DEFAULT 0, category_override TEXT NOT NULL DEFAULT '')")
        db.execSQL("CREATE VIRTUAL TABLE search USING fts4(id, text, tokenize=unicode61)")
        installTrigramIndex(db)
        installSummaries(db)
        installReadIndexes(db)
    }
    override fun onConfigure(db: SQLiteDatabase) {
        db.rawQuery("PRAGMA busy_timeout=5000", null).use { it.moveToFirst() }
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) installTrigramIndex(db)
        if (oldVersion in 3 until 5) db.execSQL("DROP TABLE IF EXISTS summaries")
        if (oldVersion < 5) installSummaries(db)
        if (oldVersion < 6) db.execSQL("UPDATE shots SET status='pending' WHERE status='failed' OR (status='done' AND text='')")
        if (oldVersion < 7) installReadIndexes(db)
        if (oldVersion < 8) {
            db.execSQL("ALTER TABLE shots ADD COLUMN generation INTEGER NOT NULL DEFAULT 0")
            db.execSQL("DROP TRIGGER IF EXISTS update_substring")
            val trigram = hasTrigram(db)
            if (trigram) {
                db.execSQL("DELETE FROM substring_search")
                db.execSQL("INSERT INTO substring_search(id,text) SELECT id,text FROM shots WHERE status!='deleted' AND text!=''")
                installTrigramUpdate(db)
            }
        }
        if (oldVersion < 9) db.execSQL("ALTER TABLE shots ADD COLUMN category_override TEXT NOT NULL DEFAULT ''")
    }

    private fun installReadIndexes(db: SQLiteDatabase) {
        db.execSQL("CREATE INDEX IF NOT EXISTS shots_library_order ON shots(created DESC,id) WHERE status!='deleted'")
        db.execSQL("CREATE INDEX IF NOT EXISTS shots_pending_order ON shots(created,id) WHERE status='pending'")
    }

    private fun installSummaries(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE summaries(id TEXT PRIMARY KEY, category TEXT NOT NULL, summary TEXT NOT NULL, facts TEXT NOT NULL)")
        db.rawQuery("SELECT id,text FROM shots WHERE status='done' AND text!=''", null).use { rows ->
            while (rows.moveToNext()) saveSummary(db, rows.getString(0), ScreenshotSummary.from(rows.getString(1)))
        }
    }

    private fun saveSummary(db: SQLiteDatabase, id: String, summary: ScreenshotSummary) {
        db.insertOrThrow("summaries", null, ContentValues().apply {
            put("id", id)
            put("category", summary.category)
            put("summary", summary.summary)
            put("facts", summary.facts)
        })
    }

    private fun installTrigramIndex(db: SQLiteDatabase) {
        try {
            db.execSQL("CREATE VIRTUAL TABLE substring_search USING fts5(id UNINDEXED, text, tokenize='trigram')")
        } catch (failure: android.database.sqlite.SQLiteException) {
            val message = failure.message.orEmpty()
            if ("no such module" in message || "no such tokenizer" in message) return
            throw failure
        }
        db.execSQL("INSERT INTO substring_search(id,text) SELECT id,text FROM shots WHERE status='done'")
        installTrigramUpdate(db)
        db.execSQL("""CREATE TRIGGER delete_substring AFTER DELETE ON shots BEGIN
            DELETE FROM substring_search WHERE id=old.id; END""")
    }

    private fun hasTrigram(db: SQLiteDatabase): Boolean = try {
        // Android builds may retain a virtual table schema without its module.
        db.rawQuery("SELECT rowid FROM substring_search LIMIT 1", null).use { it.moveToFirst() }
        true
    } catch (_: android.database.sqlite.SQLiteException) {
        false
    }

    private fun installTrigramUpdate(db: SQLiteDatabase) {
        db.execSQL("""CREATE TRIGGER update_substring AFTER UPDATE OF text,status ON shots BEGIN
            DELETE FROM substring_search WHERE id=old.id;
            INSERT INTO substring_search(id,text) SELECT new.id,new.text WHERE new.status!='deleted' AND new.text!='';
            END""")
    }

    fun save(uri: Uri): String {
        val id = UUID.randomUUID().toString()
        val part = File(images, "$id.part")
        val image = File(images, "$id.img")
        try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(part).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        require(total <= 100L * 1024 * 1024) { "This image is too large (maximum 100 MB)." }
                        output.write(buffer, 0, count)
                    }
                    output.fd.sync()
                }
            } ?: error("The image is no longer available. Please share it again.")
            val info = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(part.path, info)
            require(info.outWidth > 0 && info.outHeight > 0) { "This file is not a supported image." }
            check(part.renameTo(image)) { "Could not store the image." }
            try { makeThumbnail(image, info.outWidth, info.outHeight) }
            catch (_: java.io.IOException) { /* Original remains available. */ }
            writableDatabase.insertOrThrow("shots", null, ContentValues().apply {
                put("id", id); put("path", image.name); put("created", System.currentTimeMillis())
            })
            return id
        } catch (error: Exception) { part.delete(); thumbnail(image.name).delete(); image.delete(); throw error }
    }

    fun indexStatus(): Map<String, Int> = readableDatabase.rawQuery(
        "SELECT COUNT(*), COUNT(CASE WHEN status='done' THEN 1 END), COUNT(CASE WHEN status='pending' THEN 1 END) FROM shots WHERE status!='deleted'", null
    ).use {
        it.moveToFirst()
        mapOf("total" to it.getInt(0), "indexed" to it.getInt(1), "pending" to it.getInt(2))
    }

    data class BrowseOptions(
        val offset: Int = 0, val limit: Int = 60, val category: String = "",
        val from: Long? = null, val until: Long? = null, val ids: List<String>? = null
    )

    fun list(query: String, screenshotId: String? = null, previews: Boolean = false, browse: BrowseOptions? = null): List<Map<String, Any>> {
        val words = SEARCH_WORD.findAll(query).take(16).map { it.value.lowercase(java.util.Locale.ROOT) }.distinct().toList()
        if (query.isNotBlank() && words.isEmpty()) return emptyList()
        val db = readableDatabase
        val useTrigram = words.isNotEmpty() && words.all { it.codePointCount(0, it.length) >= 3 } &&
            hasTrigram(db)
        val fields = "s.id,s.path,s.created,s.status,s.text"
        val summaryFields = "coalesce(nullif(s.category_override,''),m.category,'') as category,coalesce(m.summary,'') as summary,${if (previews) "''" else "coalesce(m.facts,'')"} as facts"
        val summaries = "LEFT JOIN summaries m ON m.id=s.id"
        val previewFields = "s.id,s.path,s.created,s.status,''"
        val flags = "length(s.text)>0 as hasText,(instr(lower(s.text),'http://')>0 OR instr(lower(s.text),'https://')>0 OR instr(lower(s.text),'www.')>0) as hasLink"
        val (sql, args) = when {
            screenshotId != null -> "SELECT $fields,substr(s.text,1,150),$summaryFields FROM shots s $summaries WHERE s.id=? AND s.status!='deleted'" to arrayOf(screenshotId)
            words.isEmpty() -> "SELECT ${if (previews) previewFields else fields},substr(s.text,1,150),$summaryFields,$flags FROM shots s $summaries WHERE s.status!='deleted' ORDER BY s.created DESC,s.id" to emptyArray<String>()
            useTrigram -> "SELECT ${if (previews) previewFields else fields},snippet(substring_search,1,'','',' … ',16),$summaryFields,$flags FROM substring_search JOIN shots s ON s.id=substring_search.id $summaries WHERE substring_search MATCH ? AND s.status!='deleted' ORDER BY bm25(substring_search),s.created DESC,s.id" to
                arrayOf(words.joinToString(" AND ") { "\"$it\"" })
            else -> {
                // System SQLite on some Android devices lacks trigram indexing.
                val filters = words.joinToString(" AND ") { "instr(lower(s.text),?)>0" }
                "SELECT $fields,'',$summaryFields,$flags FROM shots s $summaries WHERE s.status!='deleted' AND $filters ORDER BY instr(lower(s.text),?)=0,s.created DESC,s.id" to
                    (words + words.joinToString(" ")).toTypedArray()
            }
        }
        fun scoped(source: String, arguments: Array<String>, page: Boolean): Pair<String, Array<String>> {
            if (browse == null) return source to arguments
            val conditions = mutableListOf("1=1")
            val values = arguments.toMutableList()
            if (browse.category == "Link") conditions += "(category='Link' OR hasLink=1)"
            else if (browse.category.isNotEmpty()) { conditions += "category=?"; values += browse.category }
            browse.from?.let { conditions += "created>=?"; values += it.toString() }
            browse.until?.let { conditions += "created<?"; values += it.toString() }
            browse.ids?.let { ids ->
                if (ids.isEmpty()) conditions += "0"
                else { conditions += "id IN (${ids.joinToString(",") { "?" }})"; values += ids }
            }
            var result = "SELECT * FROM ($source) WHERE ${conditions.joinToString(" AND ")}"
            if (page) {
                result += " LIMIT ? OFFSET ?"
                values += (browse.limit.coerceIn(1, 100) + 1).toString()
                values += browse.offset.coerceAtLeast(0).toString()
            }
            return result to values.toTypedArray()
        }
        val (scopedSql, scopedArgs) = scoped(sql, args, true)
        val exact = db.rawQuery(scopedSql, scopedArgs).use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    val transcript = cursor.getString(4)
                    val snippet = cursor.getString(5).ifEmpty { searchSnippet(transcript, words) }
                    add(searchRow(cursor, snippet, previews = previews))
                }
            }
        }
        if (exact.isNotEmpty() || words.isEmpty() || words.none(::canApproximate) || (browse?.offset ?: 0) > 0) return exact
        // Do bounded fuzzy matching only after indexed/literal search finds nothing.
        val fallback = "SELECT $fields,'',$summaryFields,$flags FROM shots s $summaries WHERE s.status!='deleted' AND s.text!='' ORDER BY s.created DESC,s.id LIMIT 400"
        val (fuzzySql, fuzzyArgs) = scoped(fallback, emptyArray(), false)
        return db.rawQuery(fuzzySql, fuzzyArgs).use { cursor ->
            buildList {
                while (size < 40 && cursor.moveToNext()) {
                    val transcript = cursor.getString(4)
                    val lower = transcript.lowercase(java.util.Locale.ROOT)
                    val missing = words.filterNot(lower::contains)
                    if (missing.any { !canApproximate(it) }) continue
                    val tokens = SEARCH_WORD.findAll(lower).take(3500).map { it.value }.toSet()
                    val corrections = missing.map { term -> tokens.firstOrNull { closeWord(term, it) } }
                    if (corrections.any { it == null }) continue
                    val matched = corrections.filterNotNull() + words.filter(lower::contains)
                    add(searchRow(cursor, searchSnippet(transcript, matched), corrections.filterNotNull(), previews))
                }
            }
        }
    }

    private fun searchRow(cursor: android.database.Cursor, snippet: String, approximate: List<String> = emptyList(), previews: Boolean = false): Map<String, Any> =
        mapOf("id" to cursor.getString(0), "path" to File(images,cursor.getString(1)).path,
            "thumbnail" to thumbnail(cursor.getString(1)).takeIf { it.isFile }?.path.orEmpty(),
            "created" to cursor.getLong(2), "status" to cursor.getString(3), "text" to if (previews) "" else cursor.getString(4),
            "category" to cursor.getString(6), "summary" to cursor.getString(7), "facts" to if (previews) "" else cursor.getString(8),
            "hasText" to if (cursor.columnCount > 9) cursor.getInt(9) != 0 else cursor.getString(4).isNotBlank(),
            "hasLink" to (cursor.columnCount > 10 && cursor.getInt(10) != 0),
            "snippet" to snippet.replace(SPACE, " ").trim(), "approximate" to approximate)
    private fun searchSnippet(text: String, words: List<String>): String {
        val clean = text.replace(SPACE, " ").trim()
        val hit = words.map { clean.indexOf(it, ignoreCase = true) }.filter { it >= 0 }.minOrNull() ?: 0
        val start = (hit - 16).coerceAtLeast(0)
        val end = (start + 140).coerceAtMost(clean.length)
        return (if (start > 0) "…" else "") + clean.substring(start, end) + if (end < clean.length) "…" else ""
    }

    private companion object {
        val SEARCH_WORD = Regex("[\\p{L}\\p{N}]+")
        val SPACE = Regex("\\s+")
        fun canApproximate(term: String) = term.length in 5..32 && term.all(Char::isLetter)
        fun closeWord(term: String, token: String): Boolean {
            if (kotlin.math.abs(term.length - token.length) > 1) return false
            val shorter = if (term.length <= token.length) term else token
            val longer = if (term.length <= token.length) token else term
            var index = 0
            while (index < shorter.length && shorter[index] == longer[index]) index++
            if (shorter.length == longer.length) {
                if (index == shorter.length) return true
                if (shorter.regionMatches(index + 1, longer, index + 1, shorter.length - index - 1)) return true
                return index + 1 < shorter.length && shorter[index] == longer[index + 1] &&
                    shorter[index + 1] == longer[index] &&
                    shorter.regionMatches(index + 2, longer, index + 2, shorter.length - index - 2)
            }
            return shorter.regionMatches(index, longer, index + 1, shorter.length - index)
        }
    }
    data class PendingJob(val first: String, val second: File, val generation: Long)

    fun pending(): PendingJob? = readableDatabase.rawQuery(
        "SELECT id,path,generation FROM shots WHERE status='pending' ORDER BY created,id LIMIT 1", null
    ).use { if (it.moveToFirst()) PendingJob(it.getString(0), File(images,it.getString(1)), it.getLong(2)) else null }

    fun owns(job: PendingJob): Boolean = readableDatabase.rawQuery(
        "SELECT 1 FROM shots WHERE id=? AND status='pending' AND generation=?",
        arrayOf(job.first, job.generation.toString())
    ).use { it.moveToFirst() }

    fun finish(id: String, text: String?, failed: Boolean, generation: Long) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val previous = db.rawQuery("SELECT text FROM shots WHERE id=? AND status='pending' AND generation=?", arrayOf(id, generation.toString())).use {
                if (it.moveToFirst()) it.getString(0) else return
            }
            val transcript = if (failed || text.isNullOrBlank()) previous else text
            val done = !failed || transcript.isNotBlank()
            val summary = transcript.takeIf { it.isNotBlank() }?.let { ScreenshotSummary.from(it) }
            val count = db.update("shots", ContentValues().apply {
                put("status", if (done) "done" else "failed"); put("text", transcript)
            }, "id=? AND status='pending' AND generation=?", arrayOf(id, generation.toString()))
            if (count == 1) {
                replaceIndex(db, id, transcript, done, summary)
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    fun correctText(id: String, transcript: String) {
        require(transcript.length <= 200_000) { "Screenshot text is too long." }
        val db = writableDatabase
        val summary = transcript.takeIf { it.isNotBlank() }?.let { ScreenshotSummary.from(it) }
        db.beginTransaction()
        try {
            val count = db.update("shots", ContentValues().apply {
                put("status", "done")
                put("text", transcript)
            }, "id=? AND status!='deleted'", arrayOf(id))
            check(count == 1) { "This screenshot is no longer saved." }
            db.execSQL("UPDATE shots SET generation=generation+1 WHERE id=?", arrayOf(id))
            replaceIndex(db, id, transcript, true, summary)
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    fun setCategory(id: String, category: String) {
        require(category in setOf("", "Receipt", "Link", "OTP", "Note", "Travel", "Deliveries", "Payments", "Events", "Conversations", "Documents"))
        val count = writableDatabase.update("shots", ContentValues().apply { put("category_override", category) },
            "id=? AND status!='deleted'", arrayOf(id))
        check(count == 1) { "This screenshot is no longer saved." }
    }

    private fun replaceIndex(db: SQLiteDatabase, id: String, text: String, done: Boolean, summary: ScreenshotSummary?) {
        db.delete("search", "id=?", arrayOf(id))
        db.delete("summaries", "id=?", arrayOf(id))
        if (done) db.insertOrThrow("search", null, ContentValues().apply { put("id", id); put("text", text) })
        if (summary != null) saveSummary(db, id, summary)
    }
    internal fun forBackup(favorites: Set<String>, consume: (LibraryBackup.Record) -> Unit) {
        readableDatabase.rawQuery("SELECT id,path,created,status,text,category_override FROM shots WHERE status!='deleted' ORDER BY created", null).use { rows ->
            while (rows.moveToNext()) {
                val id = rows.getString(0)
                consume(LibraryBackup.Record(id, rows.getLong(2), rows.getString(3), rows.getString(4),
                    id in favorites, File(images, rows.getString(1)), rows.getString(5)))
            }
        }
    }

    internal fun restoreBackup(records: List<LibraryBackup.Record>): LibraryBackup.Restored {
        val db = writableDatabase
        val moved = mutableListOf<File>()
        val favorites = mutableSetOf<String>()
        var committed = false
        try {
            db.beginTransaction()
            try {
                for (record in records) {
                    val existing = db.rawQuery("SELECT status FROM shots WHERE id=?", arrayOf(record.id)).use {
                        if (it.moveToFirst()) it.getString(0) else null
                    }
                    if (existing == "deleted") continue
                    if (record.favorite) favorites += record.id
                    if (existing != null) continue
                    val image = File(images, "${UUID.randomUUID()}.img")
                    check(record.image.renameTo(image)) { "Could not restore image storage." }
                    moved += image
                    db.insertOrThrow("shots", null, ContentValues().apply {
                        put("id", record.id)
                        put("path", image.name)
                        put("created", record.created)
                        put("status", record.status)
                        put("text", record.text)
                        put("category_override", record.categoryOverride)
                    })
                    val summary = record.text.takeIf { it.isNotBlank() }?.let { ScreenshotSummary.from(it) }
                    replaceIndex(db, record.id, record.text, record.status == "done", summary)
                    // FTS5 is normally populated by the UPDATE trigger after OCR.
                    if (record.text.isNotBlank()) db.execSQL("UPDATE shots SET status=status WHERE id=?", arrayOf(record.id))
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
            committed = true
            return LibraryBackup.Restored(moved.size, favorites)
        } finally {
            if (!committed) moved.forEach { it.delete() }
        }
    }
    fun retry(id: String) { writableDatabase.execSQL("UPDATE shots SET status='pending',generation=generation+1 WHERE id=? AND status IN ('failed','done')", arrayOf(id)) }
    fun delete(id: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.execSQL("UPDATE shots SET status='deleted',text='' WHERE id=?", arrayOf(id))
            db.delete("search", "id=?", arrayOf(id))
            db.delete("summaries", "id=?", arrayOf(id))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        cleanupDeleted()
        compactIfNeeded(db)
    }
    private fun compactIfNeeded(db: SQLiteDatabase) {
        fun pragma(name: String): Long = db.rawQuery("PRAGMA $name", null).use {
            if (it.moveToFirst()) it.getLong(0) else 0L
        }
        val free = pragma("freelist_count")
        val pages = pragma("page_count")
        // SQLite reuses free pages. Rewrite only when the savings justify the I/O.
        if (free * pragma("page_size") >= 4L * 1024 * 1024 && free * 4 >= pages) {
            try { db.execSQL("VACUUM") }
            catch (_: android.database.sqlite.SQLiteException) { /* Delete already committed. */ }
        }
    }
    fun cleanupDeleted() {
        val db = writableDatabase
        db.rawQuery("SELECT id,path FROM shots WHERE status='deleted'", null).use {
            while (it.moveToNext()) {
                val file = File(images,it.getString(1))
                check(!file.exists() || file.delete()) { "Could not remove the stored file. Try again." }
                thumbnail(file.name).delete()
                db.delete("shots", "id=? AND status='deleted'", arrayOf(it.getString(0)))
            }
        }
        // A process can die between rename and INSERT. Only remove old, unreferenced files.
        val referenced = db.rawQuery("SELECT path FROM shots", null).use { cursor -> buildSet { while(cursor.moveToNext()) add(cursor.getString(0)) } }
        images.listFiles()?.filter {
            it.name.removeSuffix(".webp") !in referenced && System.currentTimeMillis()-it.lastModified()>86_400_000
        }?.forEach { it.delete() }
    }
}
