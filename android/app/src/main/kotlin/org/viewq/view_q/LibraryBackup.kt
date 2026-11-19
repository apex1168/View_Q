package org.viewq.view_q

import android.graphics.BitmapFactory
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

internal object LibraryBackup {
    private const val format = "view-q-library-v1"
    private const val maxImage = 100L * 1024 * 1024
    private const val maxArchive = 8L * 1024 * 1024 * 1024
    private const val maxMetadata = 2L * 1024 * 1024
    private const val maxTotalMetadata = 32L * 1024 * 1024
    private const val maxScreenshots = 10_000

    data class Record(
        val id: String,
        val created: Long,
        val status: String,
        val text: String,
        val favorite: Boolean,
        val image: File,
        val categoryOverride: String = "",
    )

    data class Restored(val added: Int, val favorites: Set<String>)

    fun write(output: OutputStream, library: LibraryStore, favorites: Set<String>): Int {
        var count = 0
        var imageBytes = 0L
        var metadataBytes = 0L
        ZipOutputStream(output.buffered()).use { zip ->
            zip.setLevel(java.util.zip.Deflater.BEST_SPEED)
            fun entry(name: String, write: () -> Unit) {
                zip.putNextEntry(ZipEntry(name))
                write()
                zip.closeEntry()
            }
            entry("format") { zip.write(format.toByteArray()) }
            library.forBackup(favorites) { record ->
                val metadata = JSONObject()
                    .put("id", record.id).put("created", record.created)
                    .put("status", record.status).put("text", record.text)
                    .put("favorite", record.favorite).put("categoryOverride", record.categoryOverride).toString().toByteArray()
                metadataBytes += metadata.size
                require(metadata.size.toLong() <= maxMetadata && metadataBytes <= maxTotalMetadata) { "Backup text exceeds the supported size." }
                require(count < maxScreenshots) { "This library exceeds the backup limit." }
                entry("record-$count") { zip.write(metadata) }
                entry("image-$count") {
                    imageBytes += record.image.inputStream().use { copyLimited(it, zip, minOf(maxImage, maxArchive - imageBytes)) }
                }
                count++
            }
            entry("complete") { zip.write(count.toString().toByteArray()) }
        }
        return count
    }

    fun restore(input: InputStream, library: LibraryStore, cache: File): Restored {
        val work = File(cache, "view-q-restore-${UUID.randomUUID()}")
        check(work.mkdir()) { "Could not prepare restore storage." }
        try {
            val records = mutableListOf<Record>()
            val ids = hashSetOf<String>()
            var total = 0L
            var metadataRemaining = maxTotalMetadata
            ZipInputStream(input.buffered()).use { zip ->
                require(zip.nextEntry?.name == "format" && readString(zip, 64) == format) {
                    "Choose a View Q backup."
                }
                while (true) {
                    val entry = zip.nextEntry ?: error("The backup is incomplete.")
                    if (entry.name == "complete") {
                        require(readString(zip, 20).toIntOrNull() == records.size && zip.nextEntry == null) {
                            "The backup is incomplete or invalid."
                        }
                        break
                    }
                    require(entry.name == "record-${records.size}" && records.size < maxScreenshots) { "Invalid backup record." }
                    val metadata = readString(zip, minOf(maxMetadata, metadataRemaining))
                    metadataRemaining -= metadata.toByteArray().size
                    val json = JSONObject(metadata)
                    val id = json.getString("id")
                    require(UUID.fromString(id).toString() == id && ids.add(id)) { "Invalid screenshot ID." }
                    val status = json.getString("status")
                    require(status in setOf("pending", "done", "failed")) { "Invalid screenshot status." }
                    val text = json.getString("text")
                    require(text.length <= 200_000) { "Backup text is too long." }
                    require(zip.nextEntry?.name == "image-${records.size}") { "Backup image is missing." }
                    val image = File(work, "$id.img")
                    total += image.outputStream().use { copyLimited(zip, it, minOf(maxImage, maxArchive - total)) }
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(image.path, bounds)
                    require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Backup contains an unreadable image." }
                    val category = json.optString("categoryOverride")
                    require(category in setOf("", "Receipt", "Link", "OTP", "Note", "Travel", "Deliveries", "Payments", "Events", "Conversations", "Documents"))
                    records += Record(id, json.getLong("created"), status, text, json.optBoolean("favorite"), image, category)
                }
            }
            return library.restoreBackup(records)
        } finally {
            work.deleteRecursively()
        }
    }

    private fun readString(input: InputStream, limit: Long): String =
        java.io.ByteArrayOutputStream().let {
            copyLimited(input, it, limit)
            it.toString(Charsets.UTF_8.name())
        }

    private fun copyLimited(input: InputStream, output: OutputStream, limit: Long): Long {
        val buffer = ByteArray(64 * 1024)
        var copied = 0L
        while (true) {
            val length = input.read(buffer)
            if (length < 0) return copied
            copied += length
            require(copied <= limit) { "The backup exceeds the supported size." }
            output.write(buffer, 0, length)
        }
    }
}
